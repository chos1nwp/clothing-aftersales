# 第六章 · 接口联调记录

> 项目：服装网店退换货处理系统（AI 全栈课程贯穿式大作业 · 常规赛道选题二）
> 记录时间：2026-09-30 　联调环境：本机 Windows + JDK 17.0.20 + Maven 3.9.16 + MySQL 8.0.46 + Spring Boot 3.2.5（内嵌 Tomcat，端口 8080）
> 前端：`src/main/resources/static` 下的静态页面 + 原生 JS，无构建步骤

## 1. 联调口径

本项目判断「联调通过」的标准不是页面能点开，而是**同一次业务事实在四个地方对得上**：

```
页面上看到的文案/按钮  ←→  接口返回的字段  ←→  数据库里的行  ←→  业务状态机里允许的状态
```

四边 any 一处不一致，就算缺陷，需要写进第七章的 Review 记录并修掉。

## 2. 角色 → 页面 → 接口 → 数据表

| 岗位账号 | 页面 | 主要接口 | 读写的表 |
| --- | --- | --- | --- |
| 消费者 小林 `xiaolin` | `consumer-orders.html` 我的订单 | `GET /api/consumer/orders` | `shop_order`、`order_item`、`aftersales_order`（算可售后数量） |
| 消费者 | `consumer-apply.html?item={id}` 申请售后 | `POST /api/aftersales` | `aftersales_order`、`aftersales_action_log` |
| 消费者 | `consumer-list.html` 我的售后单 | `GET /api/aftersales/mine?status=` | `aftersales_order` |
| 消费者 | `detail.html?id=` 详情与操作 | `GET /api/aftersales/{id}`、`POST /api/aftersales/{id}/mark-shipped\|resubmit\|cancel\|evidence` | `aftersales_order`、`aftersales_evidence`、`aftersales_action_log` |
| 售后客服 陈静 `cs01` / 售后负责人 李明 `cs02` | `cs-workbench.html` 客服工作台 | `GET /api/staff/aftersales/stats`、`GET /api/staff/aftersales?status=&type=&keyword=` | `aftersales_order` 聚合计数 |
| 售后客服 | `detail.html?id=` 审核与结论 | `POST /api/staff/aftersales/{id}/review\|finalize`、`GET /api/staff/aftersales/{id}/timeline` | `aftersales_order`、`aftersales_action_log` |
| 仓库 刘伟 `wh01` | `warehouse-workbench.html` 仓库工作台（4 个页签） | `GET /api/staff/aftersales?status=`（页签自己传状态，不带状态即全部） | `aftersales_order` + `warehouse_record`（批量带出） |
| 仓库 | `detail.html?id=` 收货与验货 | `POST /api/staff/aftersales/{id}/receive\|inspect` | `warehouse_record`、`aftersales_action_log` |
| 全部岗位 | `index.html` 登录 | `POST /api/auth/login`、`POST /api/auth/logout`、`GET /api/auth/current` | `app_user` |

会话用 `HttpSession`，权限由 `@RequireRole` + `AuthInterceptor` 在服务端判定；页面只是**不显示**无权按钮，接口仍然独立拦截（见第七章越权测试）。

## 3. 一次状态变化的三方对应（真实数据）

取验收测试跑完的一张换货单 `id=43`（AS202609300043，张三的直筒牛仔裤，换货 1 件）。

接口与数据库：

```
aftersales_order
id  aftersales_no    order_item_id  type      quantity  status     refund_amount  closed_at
43  AS202609300043   5              EXCHANGE  1         COMPLETED  NULL           已写入

aftersales_action_log（时间线，按 id 顺序即业务顺序）
action           from_status         to_status           operator_role  visible_to_consumer
APPLY            NULL                PENDING_REVIEW      CONSUMER       1
APPROVE_RETURN   PENDING_REVIEW      WAIT_RETURN         CS             1
MARK_SHIPPED     WAIT_RETURN         WAIT_RECEIPT        CONSUMER       1
RECEIVE          WAIT_RECEIPT        WAIT_RECEIPT        WAREHOUSE      0
INSPECT_PASS     WAIT_RECEIPT        WAIT_FINAL_REVIEW   WAREHOUSE      0
FINAL_EXCHANGE   WAIT_FINAL_REVIEW   COMPLETED           CS             1

warehouse_record
aftersales_id  parcel_no      received_at  inspection_result  inspected_at
43             ZT5566778899   已写入        PASS               已写入
```

三条关键对应关系，正是需求里「收到退货 / 验货完成 / 售后结束是三个不同业务事实」的落点：

1. **`RECEIVE` 的 `from_status` 与 `to_status` 都是 `WAIT_RECEIPT`** —— 登记收货只在 `warehouse_record` 落时间，不推进状态机；页面上仓库工作台该单从「待收货」页签移到「已收货待验货」页签，靠的是 `warehouseRecord.receivedAt` 有没有值，而不是状态变了。
2. **`INSPECT_PASS` 把状态推到 `WAIT_FINAL_REVIEW`（页面显示「待确认」），但 `closed_at` 仍为 NULL** —— 验货合格不等于售后结束，退款/补发必须等客服结论。
3. **`RECEIVE`、`INSPECT_PASS` 的 `visible_to_consumer=0`** —— 同一条时间线按角色过滤：消费者详情页看不到这两条内部记录，客服详情页看得到并标注「对消费者可见=否」。

同一批数据里的退款单 `id=42`（针织开衫，退货 1 件）证明金额口径：

```
42  AS202609300042  16  RETURN  1  COMPLETED  189.00
```

`189.00 = order_item.unit_price(189.00) × aftersales_order.quantity(1)`，由服务端在 `FINAL_REFUND` 分支写入；验收用例 F2/F3 专门在请求体里夹带 `"refundAmount": 0.01`，落库仍是 699.00（那张单的单价），证明前端传不进金额。

## 4. 前后端字段对齐要点

| 对齐项 | 结论 |
| --- | --- |
| 状态中文名 | 以 `AftersalesStatus` 枚举为唯一来源，接口返回 `statusLabel`，前端 `common.js` 的 `STATUS_LABEL` 只作兜底。曾出现前端把 `WAIT_FINAL_REVIEW` 写成「待客服确认」、后端是「待确认」的漂移，已统一为「待确认」（缺陷 D-03） |
| 时间格式 | 后端返回 `LocalDateTime` 的 ISO 字符串，前端统一走 `formatTime()` 显示为 `YYYY-MM-DD HH:mm:ss` |
| 动作名 | `ACTION_LABEL` 覆盖 13 个 `ActionCode`，时间线展示中文动作文案，避免「FINAL_REJECT」直接给业务人员看 |
| 可售后数量 | `afterSaleableQuantity` = 购买数量 − 未被拒绝/取消的售后数量；`openAftersales` 表示该商品是否已有进行中的售后单（缺陷 D-05 新增），申请页和订单页据此置灰 |
| 仓库记录 | 列表接口一次性带出 `warehouseRecord`（`WarehouseMapper.findByAftersalesIds` 批量查），避免工作台逐行查询 |
| 错误提示 | 统一响应封套 `{code,message,data}`，前端把 `message` 原样显示；409 走冲突提示并在 1.2 秒后自动刷新详情 |

## 5. 浏览器实测记录（三条角色链路）

用真实浏览器点击（非接口模拟）验证过的路径：

1. `index.html` 点「消费者 · 小林」芯片 → 自动填充账号密码 → 登录后跳转 `consumer-orders.html`；芯片只是填表单，提交仍走 `POST /api/auth/login`。
2. 订单列表中「纯棉商务衬衫 白色/L」按钮置灰并提示「已有处理中的售后，先处理完再申请」；「针织开衫」可点 → `consumer-apply.html?item=16` 显示可售后数量与截止日期 → 提交后跳转详情页（`AS202609300025`）。
3. 详情页消费者视角只有「填写寄回单号 / 补充材料 / 撤销申请」，点「我不处理了，撤销这张售后单」→ 确认框 → 状态变「已取消」，时间线补 `CANCEL`，订单列表该商品可售后数量恢复为 1。
4. 未登录直接访问 `consumer-orders.html` → 接口 401 → 前端 `bootstrap()` 送回登录页（会话是服务端事实，页面跳转只是体验）。
5. 仓库视角详情页出现「登记收到退回包裹」，收货后状态仍是「待收货」，页签移到「已收货待验货」；验货「异常」不写现象时行内报错；写清现象后状态变「待确认」。
6. 客服视角「给出最终结论」面板只按单据类型给出合法结论（换货单不会出现「同意退款」）；结论说明不足 5 字时行内提示，提交成功后卡片显示模拟退款金额。
7. 并发：在两个客服会话同时对同一张待审核单点「同意退回」，失败一方收到冲突提示 toast「该售后单不在待审核状态，可能已被其他客服处理」，页面 1.2 秒后自动刷新为最新状态。
8. 越权：消费者在地址栏改 `detail.html?id=` 访问他人售后单，页面显示错误卡片「售后单不存在或你无权查看」，不渲染任何单据字段。

## 6. 联调环境的两个注意事项

1. **改完静态页面必须重启应用**：`src/main/resources/static` 在构建时被复制到 `target/classes`，浏览器读的是副本；只刷新页面不改构建产物会看到旧版。已在 `application.properties` 里把静态资源改为协商缓存（`spring.web.resources.cache.period=0` + `no-cache`），浏览器每次都带 `ETag/Last-Modified` 回源校验。
2. **Windows + Git Bash 下不能用命令行参数传中文 JSON**：`curl.exe` 的 argv 会被按 GBK 编码，服务端报 `Invalid UTF-8 middle byte`。所有演示与测试脚本统一用 `--data-binary @-` 从 stdin 传请求体。
