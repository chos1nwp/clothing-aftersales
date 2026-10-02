# 第九章 · 部署说明、发布版本与已知限制

> 本章记录「换一个目录、换一台机器能不能跑起来」这件事的**做法和实测结果**。
> 第 4 节的新目录验证是在 2026-10-02 真实执行并留下输出的，不是计划；其中第一次运行就抓到一个测试脚本自身的缺陷（D-14），已修并回归。

## 1. 发布版本

| 项 | 值 |
| --- | --- |
| 分支 | `master`（单分支按章顺序提交，见 `docs/05-ai-collaboration.md` §3） |
| 发布标签 | `v1.0.0-course`（annotated tag，指向第十章交付提交） |
| 版本号 | `pom.xml` 中 `1.0.0`，产物 `target/clothing-aftersales-1.0.0.jar` |
| 固定内容 | 源码 + `sql/` 三个脚本 + `scripts/` 三个验证脚本 + `docs/` 九份文档 + `README.md` |
| 不入库 | `application-local.properties`、`.mysql-pass`、`.mysql-app-pass`、`target/`、`uploads/`（`.gitignore`） |

核对与复现某个发布版本：

```bash
git tag -n                       # 看标签说明
git checkout v1.0.0-course       # 固定版本工作区
mvn -DskipTests package && java -jar target/clothing-aftersales-1.0.0.jar
bash scripts/acceptance-test.sh  # 89 项断言，退出码 0
```

## 2. 环境与依赖

| 组件 | 实测版本 | 用途 | 缺失时症状 |
| --- | --- | --- | --- |
| JDK 17 | 17.0.20.1 | 运行 | `mvn` 报 `invalid target release: 17` |
| Maven | 3.9.16 | 构建 | 命令不存在 |
| MySQL | 8.0.46 | 存储 | 启动日志 `Communications link failure` |
| Node.js | v24.18.0 | 仅供验证脚本解析 JSON | 脚本报 `node: command not found` |
| bash（Git Bash） | 5.x | 跑三个脚本 | Windows 下必须用 Git Bash，cmd/PowerShell 跑不了 |

框架：Spring Boot 3.2.5 + MyBatis（starter）+ 原生 Session 鉴权；前端静态 HTML/JS，**没有 npm 构建**。

## 3. 初始化与启动（可复制的命令序列）

```bash
# 0) 确认在项目根目录：应用从当前目录读 application-local.properties，uploads/ 也相对当前目录
cd clothing-aftersales

# 1) 建库 + 建专用账号（改 sql/init-db.sql 里的两处占位口令，用 root 执行一次）
mysql -u root -p < sql/init-db.sql

# 2) 本地凭据文件（不入库）
printf 'AFTERSALES_DB_PASSWORD=上一步的口令\n' > application-local.properties

# 3) 建表 + 灌虚构演示数据
DB_PASS=$(grep -o 'AFTERSALES_DB_PASSWORD=.*' application-local.properties | cut -d= -f2-)
MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/schema.sql
MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql

# 4) 启动：开发方式或打包方式二选一
mvn spring-boot:run
mvn -DskipTests package && java -jar target/clothing-aftersales-1.0.0.jar

# 5) 打开 http://localhost:8080/ ，账号见 README §3（密码统一 123456）
```

三个 SQL 的分工：`init-db.sql` 建库和账号（需 root）→ `schema.sql` 建表（**开头是 DROP TABLE IF EXISTS**，可重复执行）→ `data.sql` 灌数据（同样先 DELETE 再 INSERT）。应用账号 `aftersales` 只授权 `clothing_aftersales.*`，不使用 root。

**关于 `mvn -o`（离线）**：`spring-boot:run` 与 `compile` 可离线；首次 `package` 需要联网拉打包插件，拉过之后 `-o` 也能打包。这条结论来自第 4 节的实测（第一次离线打包失败）。

**上传目录**：`app.upload-dir=uploads` 是相对路径，`EvidenceService` 在首次上传时 `Files.createDirectories` 创建，因此新目录不需要手工建 `uploads/`；换启动目录会导致凭证落点变化，URL `/uploads/**` 由 `WebConfig` 映射到**当前工作目录**下的绝对路径。

## 4. 新目录重跑验证（2026-10-02 实测）

按本章第 3 节命令在一个全新目录里执行，结果如下。

```bash
cd C:/Users/hp/Documents/Qoder/2026-09-30/bea0e00d
git clone C:/Users/hp/Documents/Qoder/2026-09-30/bea0e00d/clothing-aftersales verify-fresh/clothing-aftersales
ls verify-fresh/clothing-aftersales     # README.md  docs  pom.xml  scripts  sql  src
```

克隆出来的目录**没有** `application-local.properties`、`target/`、`uploads/`——正好等于新环境。

| 步骤 | 结果 |
| --- | --- |
| `sql/schema.sql` + `sql/data.sql` | 通过：7 张表重建，`aftersales_order` 10 行演示数据 |
| 首次 `mvn -o -DskipTests package` | **失败** `PluginResolutionException`（打包插件未缓存）→ 去掉 `-o` 后成功，产物 26,722,246 字节；再次 `-o` 通过 |
| `java -jar target/clothing-aftersales-1.0.0.jar` | `Tomcat started on port 8080` / `Started AftersalesApplication in 3.934 seconds` |
| `bash scripts/acceptance-test.sh` | 首轮 **87 通过 / 1 失败（E4）**；修脚本后连续三轮 **89 通过 / 0 失败，退出码 0** |
| `bash scripts/flow-demo.sh` | 通过，9 条 `[4xx]` 规则拦截语原文照旧 |
| `SKIP_RESET=1 bash scripts/happy-path-demo.sh` | 通过：退货退款 `¥189`（单价×1）、换货补发单号 `SF5566778899` |
| 浏览器三岗位链路 | 通过，见下表 |

**E4 那次失败是什么**（登记为 D-14）：并发用例 E1 用 `$((E1C1 + E1C2))` 判定「一 0 一 409」，而 `code` 取值失败时返回**空串**，bash 算术把空串当 0——于是「没读到响应」也能凑出 409 让 E1 假通过，紧接着 E4 去读那个空文件就必然失败。补了 E1a 断言「两个并发响应都解析出了数字业务码」，让取证断裂显式报错，而不是伪装成业务结论。修的是**脚本**，不是放宽断言：E1 的判定条件反而更严了。

### 4.1 三岗位演示与三方对账（新目录实例，换货单 id=37 / AS202610020037）

| 岗位与动作 | 页面证据 | 接口/数据库证据 |
| --- | --- | --- |
| 消费者 `xiaolin` 申请换货 | 详情页标题「AS202610020037 · 已完成」，订单页该商品当时「可售后 1」可点 | `POST /api/aftersales` → id=37，状态 待审核 |
| 客服 `cs01` 同意退回 | 客服工作台「待审核」列出 2 张，含新单 | `APPROVE_RETURN`：`PENDING_REVIEW → WAIT_RETURN`，`visible=1` |
| 消费者填寄回单号 | 时间线「消费者已寄回 · 待收货 · 单号 SF7788990011」 | `MARK_SHIPPED`：`WAIT_RETURN → WAIT_RECEIPT` |
| 仓库 `wh01` 登记收货 | 仓库工作台该单从「待收货」移到「已收货待验货」 | `RECEIVE`：**状态仍是 `WAIT_RECEIPT`**，只写 `warehouse_record.received_at = 2026-10-02 19:28:32`，`visible=0` |
| 仓库验货合格 | 队列进入「已交客服」 | `INSPECT_PASS`：`WAIT_RECEIPT → WAIT_FINAL_REVIEW`，`inspection_result = PASS`（19:29:20），`visible=0` |
| 客服下结论补发 | 详情页「换货已补发，单号 SF2026100201」，消费者时间线**只有 4 条**（内部两条不显示） | `FINAL_EXCHANGE`：`WAIT_FINAL_REVIEW → COMPLETED`，`refund_amount = NULL`、`resend_tracking_no = SF2026100201`、`closed_at = 2026-10-02 19:29:37` |

数据库侧一次查全（就是上面那行的来源，可直接复跑）：

```sql
select id, aftersales_no, status, refund_amount, resend_tracking_no, closed_at
  from aftersales_order where id = 37;
select action, from_status, to_status, operator_role, visible_to_consumer
  from aftersales_action_log where aftersales_id = 37 order by id;
select received_at, inspected_at, inspection_result, parcel_no
  from warehouse_record where aftersales_id = 37;
```

顺带验证了演示数据的**时间可复现性**：`sql/data.sql` 的日期全部相对 `NOW()` 生成，重灌之后订单签收变成 2026-10-01、售后截止 2026-10-08，「在售后期内 / 已超期」两类样本分布不变——新机器任何时间初始化都能跑出同样的演示效果。

验证结束后已删除 `verify-fresh/`（临时目录，含凭据文件副本，不留在工作区）。

## 5. 已知限制（不隐瞒）

| 类别 | 限制 | 影响与替代 |
| --- | --- | --- |
| 鉴权 | Session + `@RequireRole` 注解，自写拦截器，**无 CSRF Token、无密码策略、无失败锁定、无记住我** | 演示级；生产需换过滤器链、CsrfToken、密码哈希成本与策略。已在第七章作为「确认保留的设计决定」登记 |
| 测试 | 端到端脚本 + 数据库断言；**没有 JUnit 单元/集成测试**；浏览器部分依赖人工（本轮为 DOM 结构快照 + 接口链路，完整鼠标走位在原目录实例做过，见 `docs/06-integration.md` §5） | 规则变更靠 89 项断言兜底，纯函数级重构缺保护网 |
| 并发 | 乐观并发条件是 `where id=? and status=?`（状态即版本） | 同一单据若将来要多字段并行修改，需要真正的行版本号 |
| 金额 | 退款 = 单价 × 数量的**模拟值** | 不处理优惠券分摊、运费、部分退款、多次售后拆分 |
| 存储 | 凭证图片本地磁盘 + UUID 重命名 | 多实例部署需换对象存储；磁盘满、扩展名伪装未压测 |
| 部署 | 单进程内嵌 Tomcat，8080 端口硬编码在 `application.properties`（可 `--server.port` 覆盖） | 无 HTTPS、无容器化、无反代配置；课程范围外 |
| 未做 | 性能/压力测试、安全扫描、可访问性（a11y）、国际化 | 明确未覆盖，见 `docs/08-test-report.md` §8 |
| 平台 | 三个脚本假设 Git Bash + Windows 路径习惯（`/tmp`、GBK 控制台） | Linux/macOS 下 `iconv` 步骤可省，curl 中文问题不存在 |

## 6. 恢复方法

| 症状 | 判定 | 恢复动作 |
| --- | --- | --- |
| 演示数据被点乱了、脚本结果怪异 | 无法确定当前状态 | `MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql`（三个脚本开头也是这句，可任意时刻执行） |
| 表结构不匹配（例如手工改过库） | `Unknown column` / 字段对不上 | 重跑 `sql/schema.sql` 再 `sql/data.sql`；会**丢弃全部业务数据**，需要先确认无需保留 |
| `Access denied for user 'aftersales'` | 口令两处不一致 | 改 `application-local.properties` 与 `sql/init-db.sql` 为同一口令；不要改 `application.properties`（那是要提交的） |
| `Communications link failure` / `Unknown database` | MySQL 未启动或库没建 | 启动服务；`mysql -u root -p < sql/init-db.sql` 后重跑第 3 节 ③ |
| `Web server failed to start. Port 8080 was already in use` | 端口被占 | `java -jar target/clothing-aftersales-1.0.0.jar --server.port=8081`；脚本侧用 `BASE=http://localhost:8081 bash scripts/acceptance-test.sh`（另两个脚本端口硬编码，需临时改 `BASE`） |
| 改了页面/代码但表现没变 | 静态资源是 `target/classes` 里的副本 | 重启应用；浏览器已配 `Cache-Control: no-cache` 回源校验 |
| 服务端报 `Invalid UTF-8 middle byte` | Git Bash 下 curl 命令行参数是 GBK | 请求体走 `--data-binary @-`（三个脚本都已这样写） |
| 脚本输出中文乱码 | 控制台 GBK | 管道接 `iconv -f UTF-8 -t UTF-8 -c` |
| 上传的图片访问不到 | `uploads/` 相对启动目录 | 从项目根目录启动；或把 `app.upload-dir` 改成绝对路径 |
| 会话过期后页面点了没反应 | 接口 401 | 前端 `common.js` 统一跳回 `index.html`，重新登录即可，无需清 Cookie |

## 7. 发布前检查清单（每次交付前跑一遍）

```bash
# 1) 回归
bash scripts/acceptance-test.sh && bash scripts/flow-demo.sh && SKIP_RESET=1 bash scripts/happy-path-demo.sh
# 2) 文档里的接口路径逐个复核（第九章实测就是这样抓到 D-12/D-13 的）
# 3) 凭据不入库
git status --short --untracked-files=all
git diff --cached | grep -cE '<口令特征>'      # 输出必须是 0；注意 grep 无匹配时退出码是 1，看数字不看退出码
# 4) 差异复核（看有没有不相干的行被删）
git show <commit> --stat && git show <commit> -- src/main/resources/application.properties
```
