# 第三章成果 · 可实现设计

对应第二章需求说明书 `docs/02-requirements.md`。本章给出页面、数据、接口三层设计，以及四者之间的对应关系，作为第四章编码的直接依据。

---

## 1. 技术选型与运行时结构

| 层 | 选型 | 说明 |
| --- | --- | --- |
| 浏览器前端 | 原生 HTML + CSS + JavaScript（无构建步骤） | 静态页面放在 Spring Boot `resources/static`，`fetch` 调用后端 JSON 接口 |
| 后端 | Spring Boot 3.2 + Spring MVC | JDK 17，Maven 构建 |
| 数据访问 | MyBatis 3（mybatis-spring-boot-starter 3.0） | XML 映射 + 注解混用，SQL 集中在 XML |
| 数据库 | MySQL 8.0.46，库名 `clothing_aftersales`，utf8mb4 | 应用账号 `aftersales`，非 root |
| 会话与权限 | `HttpSession` + Servlet Filter + 角色注解校验 | 教学项目不引入 Spring Security，权限逻辑显式可读 |
| 文件上传 | 本地目录 `uploads/`（gitignore），数据库只存路径 | 仅 jpg/png，单文件 ≤ 5MB，最多 6 张 |

选择无构建前端的原因：交付底线要求"在新目录或新环境重新运行"，去掉 node 构建链能显著降低复现成本，同时页面结构仍然真实对应接口和字段。

---

## 2. 状态机（设计的核心）

8 个状态，与第二章"关键规则"一一对应：

| 编码 | 中文 | 含义 | 谁能推进 |
| --- | --- | --- | --- |
| `PENDING_REVIEW` | 待审核 | 申请已提交，等待客服判断条件 | 客服 |
| `NEED_SUPPLEMENT` | 待补充 | 客服要求补充材料 | 消费者 |
| `WAIT_RETURN` | 待退回 | 客服已同意退回并给出退回指引 | 消费者 |
| `WAIT_RECEIPT` | 待收货 | 消费者确认已寄出，等仓库收货 | 仓库 |
| `WAIT_FINAL_REVIEW` | 待确认 | 仓库已登记收货与验货结论，等客服下结论 | 客服 |
| `COMPLETED` | 已完成 | 换货已补发 / 退货已记录模拟退款，售后单关闭 | 终态 |
| `REJECTED` | 已拒绝 | 客服拒绝，必须留理由，售后单关闭 | 终态 |
| `CANCELLED` | 已取消 | 消费者在客服处理前主动撤销 | 终态 |

### 2.1 允许的跳转（白名单，未列出的跳转一律 409 拒绝）

```text
PENDING_REVIEW  --客服 要求补充-->  NEED_SUPPLEMENT
PENDING_REVIEW  --客服 同意退回-->  WAIT_RETURN
PENDING_REVIEW  --客服 拒绝------>  REJECTED
PENDING_REVIEW  --消费者 取消---->  CANCELLED

NEED_SUPPLEMENT --消费者 补充重提>  PENDING_REVIEW
NEED_SUPPLEMENT --消费者 取消---->  CANCELLED

WAIT_RETURN     --消费者 确认寄出>  WAIT_RECEIPT
WAIT_RETURN     --消费者 取消---->  CANCELLED

WAIT_RECEIPT    --仓库 登记收货-->  WAIT_RECEIPT   （只写收货记录，状态不变）
WAIT_RECEIPT    --仓库 登记验货-->  WAIT_FINAL_REVIEW

WAIT_FINAL_REVIEW --客服 确认换货--> COMPLETED
WAIT_FINAL_REVIEW --客服 确认退货--> COMPLETED
WAIT_FINAL_REVIEW --客服 拒绝------> REJECTED

COMPLETED / REJECTED / CANCELLED  --任何角色-->  不允许再变更
```

### 2.2 由状态机强制保证的业务事实

- **"收到退货"≠"售后结束"**：`WAIT_FINAL_REVIEW` 是仓库验货后的必经状态，仓库无接口可以直达 `COMPLETED`；
- **仓库不能提前登记**：`receive` 和 `inspect` 接口都先校验当前状态必须是 `WAIT_RECEIPT`，否则返回冲突；
- **拒绝、要求补充、验货异常必须填原因**：这三类动作的 `note` 字段后端做非空校验（≥ 5 字），前端也校验；
- **换货必须有补发单号**：`finalize` 动作 = 换货时 `trackingNo` 必填；退货时退款金额由服务端按快照计算，不接受前端传入。

### 2.3 可售后数量

```text
可售后数量 = order_item.quantity
           − Σ(该 order_item 上状态不属于 REJECTED / CANCELLED 的售后单申请数量)
```

即被拒绝或已取消的申请不占用额度，进行中与已完成的都占用。提交申请时服务端重新计算并校验，不信任前端显示值。

---

## 3. 数据库设计

7 张表。5 个核心业务对象：用户、订单、订单商品、售后单、仓库记录（外加凭证和时间线两张明细表）。

### 3.1 `app_user` 账号与岗位

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| username | VARCHAR(64) UNIQUE | 登录名 |
| password_hash | VARCHAR(100) | SHA-256 加盐（教学用，见"已知限制"） |
| display_name | VARCHAR(64) | |
| role | VARCHAR(20) | `CONSUMER` / `CS` / `WAREHOUSE` |
| phone | VARCHAR(20) | 脱敏虚构号码 |
| created_at | DATETIME | |

### 3.2 `shop_order` 模拟订单

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| order_no | VARCHAR(32) UNIQUE | 如 `SO20260912001` |
| user_id | BIGINT | 归属消费者，FK→app_user |
| status | VARCHAR(20) | 固定用 `COMPLETED` / `SHIPPED`，只有 COMPLETED 可申请 |
| placed_at | DATETIME | 下单时间 |
| completed_at | DATETIME | 签收/完成时间，用于判断售后期限 |
| after_sale_days | INT | 该店售后期限天数，默认 7 |

### 3.3 `order_item` 订单商品

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| order_id | BIGINT | FK→shop_order |
| product_name | VARCHAR(128) | 如"纯棉商务衬衫" |
| color | VARCHAR(32) | |
| size | VARCHAR(16) | S/M/L/XL |
| quantity | INT | 购买数量 |
| unit_price | DECIMAL(10,2) | 单价，退款金额按它算 |

### 3.4 `aftersales_order` 售后单（主单据）

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| aftersales_no | VARCHAR(32) UNIQUE | 如 `AS20260920001` |
| order_item_id | BIGINT | FK→order_item，申请针对的具体商品 |
| consumer_user_id | BIGINT | FK→app_user，冗余便于归属校验与查询 |
| type | VARCHAR(20) | `RETURN` 退货 / `EXCHANGE` 换货 |
| reason_code | VARCHAR(32) | `SIZE` 尺码不合适 / `DAMAGED` 破损 / `WRONG_ITEM` 错发 / `QUALITY` 质量问题 / `OTHER` |
| quantity | INT | 申请数量 |
| description | VARCHAR(500) | 消费者说明 |
| status | VARCHAR(24) | 见第 2 节 |
| return_guidance | VARCHAR(500) | 客服同意退回时填写的退回指引 |
| consumer_parcel_no | VARCHAR(64) | 消费者填的寄回包裹号（模拟） |
| refund_amount | DECIMAL(10,2) | 模拟退款金额，服务端算 |
| resend_tracking_no | VARCHAR(64) | 换货模拟补发单号 |
| final_note | VARCHAR(500) | 客服最终结论说明 |
| created_at / updated_at / closed_at | DATETIME | |

索引：`(consumer_user_id, status)`、`(order_item_id, status)`、`status`。

### 3.5 `aftersales_evidence` 图片凭证

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| aftersales_id | BIGINT | FK |
| file_path | VARCHAR(255) | 服务器相对路径 |
| original_name | VARCHAR(128) | |
| uploaded_by | BIGINT | FK→app_user |
| created_at | DATETIME | |

### 3.6 `warehouse_record` 仓库收货与验货记录

一个售后单一条（未关闭前重复登记被拒绝）。

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| aftersales_id | BIGINT UNIQUE | FK |
| parcel_no | VARCHAR(64) | 实际收到包裹号 |
| received_at | DATETIME | 收货时间 |
| received_by | BIGINT | 收货登记人 |
| inspection_result | VARCHAR(16) | `PASS` / `ABNORMAL`，未验货为 NULL |
| issue_description | VARCHAR(500) | 验货异常现象，`ABNORMAL` 时必填 |
| inspected_at | DATETIME | |
| inspected_by | BIGINT | |

**设计说明**：收货和验货放在同一条记录、但走两个不同接口，正是为了让"已收货但未验货"这个中间状态可见——这是题目强调的三个不同业务事实之一。

### 3.7 `aftersales_action_log` 时间线

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| id | BIGINT PK AI | |
| aftersales_id | BIGINT | FK |
| action | VARCHAR(32) | `APPLY` / `SUPPLEMENT_REQUEST` / `APPROVE_RETURN` / `REJECT` / `RESUBMIT` / `MARK_SHIPPED` / `RECEIVE` / `INSPECT_PASS` / `INSPECT_ABNORMAL` / `FINAL_EXCHANGE` / `FINAL_REFUND` / `FINAL_REJECT` / `CANCEL` |
| from_status / to_status | VARCHAR(24) | 变更前后状态 |
| operator_user_id | BIGINT | |
| operator_role | VARCHAR(20) | 冗余存储，防止账号后续变更导致历史失真 |
| note | VARCHAR(500) | 操作说明 |
| visible_to_consumer | TINYINT(1) | 是否对消费者可见 |
| created_at | DATETIME | |

---

## 4. 页面结构设计

### 4.1 页面清单（7 个 HTML，3 个工作台视图）

| 文件 | 面向 | 内容 |
| --- | --- | --- |
| `index.html` | 未登录 | 登录表单 + 三个演示岗位账号快捷入口 |
| `consumer-orders.html` | 消费者 | 我的订单列表，展开订单商品，显示可售后数量与"申请售后"按钮 |
| `consumer-apply.html` | 消费者 | 申请表单：类型、数量、原因、说明、图片上传 |
| `consumer-list.html` | 消费者 | 我的售后单列表 + 状态筛选 |
| `detail.html` | 三角色共用 | 售后单详情：基础信息、凭证、仓库记录、时间线，按角色和状态显示不同操作区 |
| `cs-workbench.html` | 售后客服 | 待办看板（待审核 N / 待确认 N）+ 全部售后单查询 |
| `warehouse-workbench.html` | 仓库 | 待收货队列 + 收货登记 + 验货结果登记 |

导航按角色显示：消费者看"我的订单/我的售后"，客服看"客服工作台"，仓库看"仓库工作台"。

### 4.2 关键操作流程

```text
消费者：我的订单 → 选商品 → 申请售后 → 提交 → 我的售后看到"待审核"
        → 若"待补充"：详情页补凭证 → 重新提交
        → 若"待退回"：看退回指引 → 填包裹号 → 确认已寄出
客服：  工作台待审核 → 详情页核对（订单、期限、数量、凭证）→ 三个动作按钮之一
        → 待确认后：查看验货记录 → 确认换货（填补发单号）/确认退货/拒绝
仓库：  待收货队列 → 登记收货（包裹号）→ 登记验货（合格 / 异常+现象）
```

### 4.3 页面状态设计（每页都实现）

| 状态 | 表现 |
| --- | --- |
| 加载中 | 表格区域显示"加载中…"占位行，按钮提交后禁用防重复提交 |
| 空数据 | 明确文案："你还没有已完成的订单"，不留白屏 |
| 成功 | 顶部绿色提示条 + 列表自动刷新 |
| 失败（参数/规则） | 400：把后端 `message` 显示在对应表单项下方 |
| 冲突（状态不允许） | 409：橙色提示"当前状态不允许此操作，可能已被他人处理"，并重新拉取详情 |
| 无权限 | 403：显示"无权查看该售后单"，不暴露该单是否存在 |
| 未登录 | 401：前端跳回 `index.html` |

---

## 5. 接口清单

统一响应体：`{ "code": 0, "message": "ok", "data": ... }`；HTTP 状态码同时表达类别（200/400/401/403/409/500）。

### 5.1 认证

| 方法 | 路径 | 角色 | 输入 | 输出 |
| --- | --- | --- | --- | --- |
| POST | `/api/auth/login` | 公开 | `{username, password}` | `{id, username, displayName, role}`，写 session |
| POST | `/api/auth/logout` | 登录 | — | code 0 |
| GET | `/api/auth/me` | 登录 | — | 当前用户，未登录 401 |

### 5.2 消费者

| 方法 | 路径 | 说明 | 关键校验 |
| --- | --- | --- | --- |
| GET | `/api/consumer/orders` | 本人已完成订单及商品，附带每个商品的 `afterSaleableQuantity` | 只查本人 `user_id` |
| POST | `/api/aftersales` | 创建申请：`{orderItemId, type, quantity, reasonCode, description}` | 归属本人、订单 COMPLETED、期限内、数量 ≤ 可售后、无进行中单 |
| POST | `/api/aftersales/{id}/evidence` | multipart 上传图片 | 只能传给自己的单、进行中状态 |
| POST | `/api/aftersales/{id}/resubmit` | 补充后重新提交 `{description}` | 状态必须 `NEED_SUPPLEMENT`，归属本人 |
| POST | `/api/aftersales/{id}/mark-shipped` | `{parcelNo}` | 状态必须 `WAIT_RETURN` |
| POST | `/api/aftersales/{id}/cancel` | — | 状态属于 {待审核, 待补充, 待退回} |
| GET | `/api/aftersales/mine` | 本人售后单列表 `?status=` | 强制 `consumer_user_id = session.uid` |
| GET | `/api/aftersales/{id}` | 详情（消费者视图：时间线仅 `visible_to_consumer=1`） | 非本人 → 403 |

### 5.3 客服

| 方法 | 路径 | 说明 | 关键校验 |
| --- | --- | --- | --- |
| GET | `/api/staff/aftersales` | 列表 `?status=&type=&keyword=&limit=50` | CS 与仓库都可查，仓库默认过滤待收货队列 |
| GET | `/api/staff/aftersales/stats` | 各状态数量（工作台待办角标） | |
| POST | `/api/staff/aftersales/{id}/review` | `{action: APPROVE_RETURN\|NEED_SUPPLEMENT\|REJECT, note, returnGuidance}` | 状态 `PENDING_REVIEW`；REJECT 与 NEED_SUPPLEMENT 时 note 必填 |
| POST | `/api/staff/aftersales/{id}/finalize` | `{action: FINAL_EXCHANGE\|FINAL_REFUND\|FINAL_REJECT, trackingNo, note}` | 状态 `WAIT_FINAL_REVIEW`；必须有验货记录；换货必填 trackingNo；异常结论 note 必填 |

### 5.4 仓库

| 方法 | 路径 | 说明 | 关键校验 |
| --- | --- | --- | --- |
| POST | `/api/staff/aftersales/{id}/receive` | `{parcelNo}` | 状态必须 `WAIT_RECEIPT`，未存在 warehouse_record |
| POST | `/api/staff/aftersales/{id}/inspect` | `{result: PASS\|ABNORMAL, issueDescription}` | 状态 `WAIT_RECEIPT` 且已收货；ABNORMAL 时 issueDescription 必填 |

### 5.5 时间线

`GET /api/staff/aftersales/{id}/timeline` — 客服视图返回全部记录（含内部备注）。

---

## 6. 页面 → 接口 → Java 对象 → 数据库字段 对应表

| 页面区域 | 接口 | Java 对象 | 数据库字段 |
| --- | --- | --- | --- |
| 我的订单：商品名/颜色/尺码 | `GET /api/consumer/orders` | `OrderItemViewDTO` ← `OrderItemDO` | `order_item.product_name, color, size, quantity, unit_price` |
| 我的订单：可售后数量 | 同上（服务端计算后放入 DTO） | `OrderItemViewDTO.afterSaleableQuantity` | `order_item.quantity` − `aftersales_order.quantity`(非终态) 聚合 |
| 申请表单：售后类型 | `POST /api/aftersales` | `AftersalesCreateDTO.type` | `aftersales_order.type` |
| 申请表单：原因 | 同上 | `AftersalesCreateDTO.reasonCode` | `aftersales_order.reason_code` |
| 详情页：状态标签 | `GET /api/aftersales/{id}` | `AftersalesDetailDTO.status` | `aftersales_order.status` |
| 详情页：退回指引 | 同上 | `AftersalesDetailDTO.returnGuidance` | `aftersales_order.return_guidance` |
| 详情页：凭证缩略图 | 同上 | `EvidenceDTO.filePath` | `aftersales_evidence.file_path` |
| 详情页：模拟退款金额 | 同上 | `AftersalesDetailDTO.refundAmount` | `aftersales_order.refund_amount` |
| 客服"同意退回"表单 | `POST /{id}/review` | `ReviewDTO.action, returnGuidance` | 写 `status`、`return_guidance` + 插入 `aftersales_action_log` |
| 客服工作台待办数量 | `GET /api/staff/aftersales/stats` | `StatusCountDTO` | `aftersales_order` 按 `status` 分组计数 |
| 仓库"登记收货"表单 | `POST /{id}/receive` | `ReceiveDTO.parcelNo` | `warehouse_record.parcel_no, received_at, received_by` |
| 仓库"验货结果"表单 | `POST /{id}/inspect` | `InspectDTO.result` | `warehouse_record.inspection_result, issue_description` |
| 客服"确认换货"表单 | `POST /{id}/finalize` | `FinalizeDTO.trackingNo` | `aftersales_order.resend_tracking_no, status` |
| 时间线每一行 | `GET .../timeline` | `ActionLogDTO` | `aftersales_action_log.*` |

命名约定：`XxxDO` 对应表、`XxxDTO` 对应接口出入参、`XxxViewDTO` 是页面视图对象；Mapper 方法名与 XML 中 SQL id 同名。

---

## 7. 虚构数据规模（接近真实规模用于检查页面）

- 3 个岗位账号 + 3 个消费者账号（共 6 个 `app_user`）；
- 8 笔订单、16 条订单商品（衬衫、牛仔裤、连衣裙、外套等，含 1 笔未签收订单、1 笔超期订单用于测边界）；
- 10 张售后单，覆盖全部 8 种状态，其中 1 张验货异常、1 张被拒绝、1 张已取消；
- 约 40 条时间线记录（由脚本按各状态插入）；
- 演示账号密码统一为 `123456`（虚构，写进 README）。

---

## 8. 设计评审与修改记录

| 编号 | 问题 | 原方案 | 修改后 | 依据 |
| --- | --- | --- | --- | --- |
| R1 | 收货与验货是否分两张表 | 分 `receipt` 和 `inspection` | 合并为 `warehouse_record`，但拆两个接口 | 减少对象数量满足"4-7 个核心业务对象"，同时保留"已收货未验货"中间态 |
| R2 | 消费者可见时间线 | 全部展示 | 加 `visible_to_consumer` 字段过滤 | 需求 4.4：内部记录与对外说明分开 |
| R3 | 退款金额来源 | 前端提交 | 服务端按 `unit_price × quantity` 计算并快照入库 | 防止前端篡改，且符合"模拟退款不接真实资金" |
| R4 | 已拒绝/已取消是否占用可售后额度 | 占用 | 不占用 | 否则消费者一次被误拒就永久失去售后资格，业务上不合理 |
| R5 | 权限实现方式 | 引入 Spring Security | HttpSession + Filter + Service 层归属校验 | 课程要求"权限逻辑清楚可检查"，减少黑盒配置 |

---

## 9. 留给编码阶段的约束提醒

1. 所有状态变更必须在同一个 Service 方法内完成"改状态 + 插时间线"，用 `@Transactional` 保证原子性；
2. 列表接口一律按角色加归属条件，不允许"前端传 userId"；
3. 并发场景（两个客服同时处理一张单）用 `UPDATE ... WHERE id=? AND status=?` 乐观校验，影响行数 0 视为冲突返回 409；
4. 上传文件写本地目录时校验扩展名与大小，存储文件名用 UUID，禁止使用用户原始文件名拼接路径（防目录穿越）。
