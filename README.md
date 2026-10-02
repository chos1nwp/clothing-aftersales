# 服装网店退换货处理系统

课程贯穿式大作业（常规赛道 · 选题二）。三类岗位——**消费者 / 售后客服 / 仓库**——围绕同一张售后单协作，把它从「申请」一路推到「已完成 / 已拒绝」，中间每一次状态变化都能在**页面、接口、数据库**三处同时看到证据。

主链路（异常收束与正常收束都跑通了，见 `scripts/`）：

```
消费者申请 → 客服审核（可要求补充材料）→ 同意退回 → 消费者确认寄出
        → 仓库登记收货 → 仓库验货 → 客服最终结论（退款 / 换货补发 / 拒绝）→ 单据关闭
```

- 技术路线：浏览器前端 + Java 后端 + MyBatis + 关系数据库（课程硬性要求，未偏离）
- 不做的事：购物车、支付、真实资金、多商品合并售后。退款是**服务端算出的模拟金额**（单价 × 数量）

---

## 1. 环境要求

| 组件 | 本 project 实测版本 | 说明 |
| --- | --- | --- |
| JDK | 17.0.20.1（Microsoft Build） | 语言级别 17 |
| Maven | 3.9.16 | 运行期依赖已在本地仓库缓存；但**首次执行 `package` 需要联网**取打包插件（`spring-boot:run` 只需编译插件，可离线）。本机的插件已在第九章新目录验证时下载完毕，之后 `-o` 离线打包也能通过 |
| MySQL | 8.0.46 | 库、表、演示数据全部 utf8mb4 |
| Node.js | v24.18.0 | 只给验证脚本做 JSON 断言用，不参与构建 |
| 浏览器 | Chrome / Edge | 前端是静态 HTML + 原生 JS，**没有构建步骤** |

后端框架：Spring Boot 3.2.5 + MyBatis（starter）+ 原生 Session 鉴权（`@RequireRole` 注解 + 拦截器，未引入 Spring Security）。

---

## 2. 从零跑起来（五步）

> 所有命令都在**项目根目录**执行。应用从当前目录读取 `application-local.properties`，`uploads/` 也是相对当前目录创建的——换目录启动会连不上库、上传找不到盘路径。

**① 建库与专用账号**（需要 root 口令一次）

```bash
# 打开 sql/init-db.sql，把两处 <请替换成本地密码> 换成同一个自定义口令
mysql -u root -p < sql/init-db.sql
```

**② 写本地凭据文件**（该文件已被 `.gitignore` 忽略，永不提交）

```bash
# 项目根目录新建 application-local.properties，内容一行：
AFTERSALES_DB_PASSWORD=上一步设置的口令
```

**③ 建表 + 灌虚构演示数据**

```bash
DB_PASS=$(grep -o 'AFTERSALES_DB_PASSWORD=.*' application-local.properties | cut -d= -f2-)
MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/schema.sql
MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql
```

演示数据的日期是相对 `NOW()` 生成的（`DATE_SUB(NOW(), INTERVAL n DAY)`），所以任何时候重新初始化都能跑出「在售后期内」和「已超期」两类样本，不需要改代码。

**④ 启动**

```bash
mvn spring-boot:run                     # 开发方式
# 或者打包后运行：
mvn -DskipTests package && java -jar target/clothing-aftersales-1.0.0.jar
```

**⑤ 打开** <http://localhost:8080/>

---

## 3. 演示账号

密码统一 `123456`（哈希为 `SHA2('用户名:123456', 256)`，写在 `sql/data.sql` 里，全部是虚构账号）。登录页有角色芯片，点一下自动填表。

| 岗位 | 账号 | 姓名 | 登录后进入 | 能做什么 |
| --- | --- | --- | --- | --- |
| 消费者 | `xiaolin` | 小林 | `consumer-orders.html` | 申请售后、补充材料、确认寄出、撤销、看时间线 |
| 消费者 | `zhangsan` | 张三 | `consumer-orders.html` | 用于演示**越权**：读别人的单会被 403 拦下 |
| 消费者 | `wangxiaohong` | 王小红 | `consumer-orders.html` | 备用账号 |
| 售后客服 | `cs01` | 客服陈静 | `cs-workbench.html` | 审核、要求补充、给最终结论 |
| 售后客服 | `cs02` | 负责人李明 | `cs-workbench.html` | 第二个客服，用于演示并发同意退回 |
| 仓库 | `wh01` | 仓库刘伟 | `warehouse-workbench.html` | 登记收货、验货（不能改单据状态之外的结论） |

页面清单：`index.html` 登录 · `consumer-orders.html` 订单与可售后数量 · `consumer-apply.html` 申请 · `consumer-list.html` 我的售后 · `detail.html` 详情与时间线 · `cs-workbench.html` 客服工作台 · `warehouse-workbench.html` 仓库工作台。

---

## 4. 五分钟演示脚本（答辩用）

1. `xiaolin` 登录 → 订单页对「针织开衫」点申请售后，选**换货** → 提交后自动进详情页，状态「待审核」。
2. 换 `cs01` → 客服工作台「待审核」→ 先点**要求补充材料**（状态变「待补充」）→ 回 `xiaolin` 补充说明重新提交 → 状态回到「待审核」→ `cs01` **同意退回**。
3. `xiaolin` 确认已寄出 → `wh01` 仓库工作台「待收货」→ **登记收货**：页面状态**仍是待收货**，只是多了一条收货记录（收货 ≠ 推进状态，这是本系统的关键规则）。
4. `wh01` **验货通过** → 状态「待确认」→ `cs01` 给结论：换货填补发单号（退货则显示服务端算出的退款金额）→ 状态「已完成」，`closed_at` 落库。
5. 反向证据（数据库侧，同一个 id）：

```sql
select status, refund_amount, resend_tracking_no, closed_at
  from aftersales_order where id = <刚跑完的单号>;

select action, from_status, to_status, operator_role, visible_to_consumer
  from aftersales_action_log where aftersales_id = <同一 id> order by id;

select received_at, inspected_at, inspection_result, inspection_note
  from warehouse_record where aftersales_id = <同一 id>;
```

三条要点必须同时成立：**收货不推进状态**、**验货通过不等于售后结束**（结束只发生在客服给结论时）、**仓库的两条记录 `visible_to_consumer=0`**（消费者时间线里看不到，客服视图里能看到）。

6. 规则拦截（现场演示最有说服力的一条）：客服还没同意退回时，`wh01` 直接登记收货 → 返回 409「客服尚未同意退回或消费者尚未确认寄回，仓库不能提前登记收货」。更多拦截语原文见 `docs/08-test-report.md` 第 5.3 节。

---

## 5. 验证脚本

三个脚本都会先重置演示数据，因此可以反复跑；脚本自身退出码就是结论。

```bash
bash scripts/acceptance-test.sh          # 回归入口：88 项断言，退出码 0 为全通过
bash scripts/flow-demo.sh                # 异常收束链路 + 关键规则拦截语（人可读）
SKIP_RESET=1 bash scripts/happy-path-demo.sh   # 正常收束链路，沿用上一条链路的数据
```

`acceptance-test.sh` 每组断言同时看三件事：接口返回码与提示语、页面会读的字段、数据库里的行。覆盖正常 / 异常 / 边界 / 并发 / 越权 / 数据对账 / 错误处理。

**Windows + Git Bash 的两个坑**（Linux / macOS 下不存在）：

- 脚本里的中文请求体必须走 `--data-binary @-` 从 stdin 传入。Git Bash 调用原生 `curl.exe` 时命令行参数按 GBK 编码，中文 JSON 会变成非法 UTF-8 字节，服务端报 `Invalid UTF-8 middle byte`。
- 控制台与日志输出是 GBK，重定向到文件后按需转码：`bash scripts/flow-demo.sh | iconv -f UTF-8 -t UTF-8 -c`。

---

## 6. 目录结构

```
clothing-aftersales/
├── pom.xml
├── sql/                      init-db.sql（建库建账号模板）· schema.sql（建表）· data.sql（虚构演示数据）
├── src/main/java/.../aftersales/
│   ├── common/               统一返回封套、BizException、@RequireRole、鉴权拦截器、全局异常处理
│   ├── config/               WebConfig（拦截器与 /uploads/** 资源映射）
│   ├── controller/           登录、消费者、客服、仓库、凭证上传
│   ├── entity / mapper / dto 实体、MyBatis 接口与 XML、视图对象
│   └── service/              状态机与业务规则（AftersalesFlowService 等）
├── src/main/resources/
│   ├── application.properties 端口、数据源占位、MyBatis、上传与缓存配置
│   ├── mapper/*.xml           SQL 全部在这里，便于逐条核对
│   └── static/                七个页面 + common.js + styles.css
├── scripts/                  三个可重复执行的验证脚本
├── docs/                     按章交付的过程文档（见下表）
└── application-local.properties   【不入库】本地数据库口令
```

## 7. 文档索引（按课程阶段）

| 阶段 | 文件 | 内容 |
| --- | --- | --- |
| 第二章 需求 | `docs/02-requirements.md` | 角色与场景、业务规则、MVP 范围与不做的项、6 个需求验收示例 |
| 第三章 设计 | `docs/03-design.md` | 状态机与白名单转移、表结构、接口清单、页面流程 |
| 第四章 编码 | 本 README + `src/` | 工程骨架、规则与状态流转实现、三岗位工作台 |
| 第五章 AI 协作 | `docs/05-ai-collaboration.md` | 任务卡与判据、9 次提交与验证方式、三次失误复盘 |
| 第六章 联调 | `docs/06-integration.md` | 岗位 → 页面 → 接口 → 表 对照；一次状态变化的三方证据 |
| 第七章 Review | `docs/07-code-review.md` | 四维自查清单 + 缺陷 D-01…D-13 |
| 第八章 测试 | `docs/08-test-report.md` | 88 项断言的用例矩阵、真实输出、缺陷回归、未覆盖范围 |
| 第九章 部署 | `docs/09-deployment.md` | 环境与初始化、发布版本、故障恢复、已知限制 |
| 第十章 复盘 | `docs/10-retrospective.md` | 交付清单核对、评分维度自评、若重做的取舍、答辩走位 |
| — | `docs/reference-project-canonical.md` | 课程题目原文存档 |

## 8. 已知限制（详版见 `docs/09-deployment.md` 第 5 节）

- 鉴权是演示级：Session + `@RequireRole`，无 CSRF Token、无密码策略、无登录失败锁定。
- 测试是端到端脚本 + 数据库断言，**没有 JUnit 单元/集成测试**，浏览器部分为人工点击。
- 退款金额只是「单价 × 数量」，不处理优惠券分摊、运费、部分退款。
- 凭证图片存本地磁盘（UUID 重命名），多实例部署需换对象存储。
- 并发用「状态即版本条件」的乐观更新（`where id=? and status=?`，冲突返回 409），不支持同一单据多字段并行修改。
- 未做性能测试与安全测试。

## 9. 恢复方法（最常见三条）

| 现象 | 处理 |
| --- | --- |
| 数据被演示搞乱了 / 脚本跑出奇怪结果 | `MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql`（全量重灌演示数据，三个脚本开头也是这一步） |
| 改了 HTML/CSS/JS 但页面没变化 | 静态资源会被复制进 `target/classes`，需要**重启应用**；浏览器侧已配 `Cache-Control: no-cache` 回源校验 |
| 启动报 `Access denied for user 'aftersales'` | `application-local.properties` 里的口令与 `sql/init-db.sql` 设置的不一致；两处改成同一个即可，不需要改 `application.properties` |
