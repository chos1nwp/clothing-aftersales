#!/usr/bin/env bash
# 第六至八章验收测试：对接口返回、页面可见数据和数据库落库结果同时断言，输出 PASS/FAIL 并以退出码表示整体结果。
#
# 与 flow-demo.sh / happy-path-demo.sh 的区别：那两个脚本给人看过程，本脚本给机器判定通过与否，
# 改完状态流转或权限规则后跑这一个就能知道有没有回归。
#
# 注意：请求体必须通过 stdin 以 --data-binary 传入。
# Git Bash 调用 Windows 原生 curl.exe 时会把命令行参数按 GBK 编码，
# 中文 JSON 会变成非法 UTF-8 字节，服务端报 Invalid UTF-8 middle byte。
set -u
BASE=${BASE:-http://localhost:8080}
CJ=/tmp/at_xiaolin.txt; ZJ=/tmp/at_zhangsan.txt; WJ=/tmp/at_wang.txt
S1=/tmp/at_cs01.txt; S2=/tmp/at_cs02.txt; WH=/tmp/at_wh01.txt; NO=/tmp/at_anon.txt
rm -f $CJ $ZJ $WJ $S1 $S2 $WH $NO

pass=0
fail=0
FAILED=""

step() { echo; echo "── $1"; }
check_eq() {
  if [ "$3" = "$2" ]; then
    pass=$((pass + 1)); echo "  PASS  $1"
  else
    fail=$((fail + 1)); FAILED="$FAILED\n    - $1（期望 $2，实际 $3）"
    echo "  FAIL  $1（期望 $2，实际 $3）"
  fi
}
check_has() {
  case "$3" in
    *"$2"*) pass=$((pass + 1)); echo "  PASS  $1" ;;
    *) fail=$((fail + 1)); FAILED="$FAILED\n    - $1（响应里没有 $2）"
       echo "  FAIL  $1（响应里没有 $2，实际 $3）" ;;
  esac
}

post() { curl -s -b "$1" -c "$1" -X POST -H 'Content-Type: application/json; charset=utf-8' --data-binary @- "$BASE$2"; }
get() { curl -s -b "$1" "$BASE$2"; }
raw() { curl -s "$BASE$1"; }
code() { node -e 'let s=require("fs").readFileSync(0,"utf8");process.stdout.write(String(JSON.parse(s).code))'; }
message() { node -e 'let s=require("fs").readFileSync(0,"utf8");process.stdout.write(String(JSON.parse(s).message))'; }
# 用法：echo "$RESP" | pick .status  /  pick .refundAmount
pick() { node -e '
let s = require("fs").readFileSync(0, "utf8");
let d = JSON.parse(s).data;
for (const k of process.argv[1].split(".").filter(Boolean)) {
  d = (d === null || d === undefined) ? undefined : d[k];
}
process.stdout.write(d === undefined || d === null ? "null" : String(d));
' "$1"; }
db() { MYSQL_PWD="$DB_PASS" mysql -u aftersales -N -B --default-character-set=utf8mb4 clothing_aftersales -e "$1"; }

apply() { # apply <cookie> <itemId> <type> <quantity> <description>
  post "$1" /api/aftersales <<JSON
{"orderItemId":$2,"type":"$3","quantity":$4,"reasonCode":"SIZE","description":"$5"}
JSON
}

step "重置演示数据（脚本可重复执行）"
DB_PASS=$(grep -o 'AFTERSALES_DB_PASSWORD=.*' application-local.properties | cut -d= -f2-)
if [ "${SKIP_RESET:-0}" != "1" ]; then
  MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql 2>/dev/null \
    && echo "  sql/data.sql 已重新执行" || { echo "  无法连接数据库，请先按 README 配置 application-local.properties"; exit 2; }
fi

step "登录六个工作台账号"
for pair in "$CJ:xiaolin" "$ZJ:zhangsan" "$WJ:wangxiaohong" "$S1:cs01" "$S2:cs02" "$WH:wh01"; do
  jar=${pair%%:*}; name=${pair##*:}
  c=$(post "$jar" /api/auth/login <<< "{\"username\":\"$name\",\"password\":\"123456\"}" | code)
  check_eq "登录 $name" 0 "$c"
done

# ============ 组 A：正常链路（退货退款）============
step "组 A 正常链路：退货申请 → 审核 → 寄回 → 收货 → 验货 → 确认退款"
R=$(apply $CJ 16 RETURN 1 "袖长偏短，想直接退掉")
check_eq "A1 消费者提交退货申请" 0 "$(echo "$R" | code)"
IDA=$(echo "$R" | pick .)
check_eq "A2 申请后状态为待审核" PENDING_REVIEW "$(get $CJ "/api/aftersales/$IDA" | pick .status)"
check_has "A3 客服待审核队列能看到这张单" "$IDA" "$(get $S1 '/api/staff/aftersales?status=PENDING_REVIEW' | node -e '
let s=require("fs").readFileSync(0,"utf8");
process.stdout.write(JSON.parse(s).data.map(a => a.id).join(","));')"

R=$(post $S1 "/api/staff/aftersales/$IDA/review" <<'JSON'
{"action":"APPROVE_RETURN","note":"在售后期内且说明清楚，同意退回","returnGuidance":"退回至杭州市余杭区文一西路1234号售后仓"}
JSON
)
check_eq "A4 客服同意退回" 0 "$(echo "$R" | code)"
check_eq "A5 同意后状态为待退回" WAIT_RETURN "$(get $CJ "/api/aftersales/$IDA" | pick .status)"

R=$(post $CJ "/api/aftersales/$IDA/mark-shipped" <<'JSON'
{"parcelNo":"SF8811223344"}
JSON
)
check_eq "A6 消费者填写寄回单号" 0 "$(echo "$R" | code)"
check_eq "A7 寄回后状态为待收货" WAIT_RECEIPT "$(get $WH "/api/aftersales/$IDA" | pick .status)"

R=$(post $WH "/api/staff/aftersales/$IDA/receive" <<'JSON'
{"parcelNo":"SF8811223344"}
JSON
)
check_eq "A8 仓库登记收到包裹" 0 "$(echo "$R" | code)"
check_eq "A9 收货不改变售后状态（收货只是业务事实之一）" WAIT_RECEIPT "$(get $WH "/api/aftersales/$IDA" | pick .status)"
check_eq "A10 数据库里有收货时间" 1 "$(db "select count(*) from warehouse_record where aftersales_id=$IDA and received_at is not null;")"

R=$(post $WH "/api/staff/aftersales/$IDA/inspect" <<'JSON'
{"result":"PASS"}
JSON
)
check_eq "A11 仓库验货合格" 0 "$(echo "$R" | code)"
check_eq "A12 验货后进入待确认" WAIT_FINAL_REVIEW "$(get $S1 "/api/aftersales/$IDA" | pick .status)"

R=$(post $CJ "/api/staff/aftersales/$IDA/finalize" <<'JSON'
{"action":"FINAL_REFUND","note":"消费者不能替客服下结论"}
JSON
)
check_eq "A13 消费者调用客服接口被拒" 403 "$(echo "$R" | code)"

R=$(post $S1 "/api/staff/aftersales/$IDA/finalize" <<'JSON'
{"action":"FINAL_REFUND","note":"商品完好，同意退款"}
JSON
)
check_eq "A14 客服确认退款" 0 "$(echo "$R" | code)"
check_eq "A15 最终状态为已完成" COMPLETED "$(db "select status from aftersales_order where id=$IDA;")"
check_eq "A16 退款金额由服务端按单价×数量算出（针织开衫 ¥189 × 1）" 189.00 "$(db "select refund_amount from aftersales_order where id=$IDA;")"
check_eq "A17 关闭时间已写入" 1 "$(db "select count(*) from aftersales_order where id=$IDA and closed_at is not null;")"
check_eq "A18 时间线动作顺序与链路一致" \
  "APPLY,APPROVE_RETURN,MARK_SHIPPED,RECEIVE,INSPECT_PASS,FINAL_REFUND" \
  "$(db "select group_concat(action order by id) from aftersales_action_log where aftersales_id=$IDA;")"

# ============ 组 B：正常链路（换货补发）============
step "组 B 正常链路：换货申请 → 验货合格 → 补发（换货不能按退货收口）"
R=$(apply $ZJ 5 EXCHANGE 1 "牛仔裤腰围偏紧，想换大一号")
check_eq "B1 张三提交换货申请" 0 "$(echo "$R" | code)"
IDB=$(echo "$R" | pick .)
post $S2 "/api/staff/aftersales/$IDB/review" <<'JSON' | code >/dev/null
{"action":"APPROVE_RETURN","note":"符合换货条件","returnGuidance":"退回售后仓，注意附原包装"}
JSON
post $ZJ "/api/aftersales/$IDB/mark-shipped" <<'JSON' | code >/dev/null
{"parcelNo":"ZT5566778899"}
JSON
post $WH "/api/staff/aftersales/$IDB/receive" <<'JSON' | code >/dev/null
{"parcelNo":"ZT5566778899"}
JSON
post $WH "/api/staff/aftersales/$IDB/inspect" <<'JSON' | code >/dev/null
{"result":"PASS"}
JSON

R=$(post $S2 "/api/staff/aftersales/$IDB/finalize" <<'JSON'
{"action":"FINAL_REFUND","note":"先把类型用错试一次"}
JSON
)
check_eq "B2 换货单按退货处理被拒" 400 "$(echo "$R" | code)"
check_has "B3 拒绝原因说明是类型不符" "不能按退货处理" "$(echo "$R" | message)"

R=$(post $S2 "/api/staff/aftersales/$IDB/finalize" <<'JSON'
{"action":"FINAL_EXCHANGE","note":"同意换货"}
JSON
)
check_eq "B4 换货不填补发单号被拒" 400 "$(echo "$R" | code)"

R=$(post $S2 "/api/staff/aftersales/$IDB/finalize" <<'JSON'
{"action":"FINAL_EXCHANGE","note":"同意换货，已安排补发","trackingNo":"SF9988776655"}
JSON
)
check_eq "B5 换货补发收口" 0 "$(echo "$R" | code)"
check_eq "B6 补发单号已落库" SF9988776655 "$(db "select resend_tracking_no from aftersales_order where id=$IDB;")"
check_eq "B7 换货不产生退款金额" NULL "$(db "select ifnull(refund_amount,'NULL') from aftersales_order where id=$IDB;")"

# ============ 组 C：边界 ============
step "组 C 边界：重复申请、数量、期限、归属、参数校验、撤销释放额度"
R=$(apply $WJ 14 RETURN 1 "第一张，尺码不合适")
check_eq "C1 王小红提交申请" 0 "$(echo "$R" | code)"
IDC=$(echo "$R" | pick .)
R=$(apply $WJ 14 RETURN 1 "同一件商品再提交一次")
check_eq "C2 同一商品重复申请被拒" 409 "$(echo "$R" | code)"
check_has "C3 提示说清为什么被拒" "已有正在处理中的售后" "$(echo "$R" | message)"

R=$(apply $ZJ 12 RETURN 2 "羊绒围巾只买了一条却想退两条")
check_eq "C4 数量超出可售后数量被拒" 400 "$(echo "$R" | code)"
check_has "C5 提示给出当前最多可申请数量" "最多可申请 1 件" "$(echo "$R" | message)"

R=$(apply $CJ 3 RETURN 1 "签收十八天后才来申请")
check_eq "C6 超过售后期限被拒" 400 "$(echo "$R" | code)"
check_has "C7 提示说明售后期限" "已超过售后期限" "$(echo "$R" | message)"

R=$(apply $CJ 11 RETURN 1 "试试能不能对别人的订单发起售后")
check_eq "C8 对他人订单商品申请被拒" 403 "$(echo "$R" | code)"

R=$(post $WJ /api/aftersales <<'JSON'
{"orderItemId":14,"type":"RETURN","quantity":0,"reasonCode":"SIZE","description":"数量填零看看参数校验"}
JSON
)
check_eq "C9 数量为 0 被参数校验拦下" 400 "$(echo "$R" | code)"

R=$(post $ZJ /api/aftersales/2/cancel)
check_eq "C10 待补充状态下消费者也能撤销（演示数据里张三那张待补充单）" 0 "$(echo "$R" | code)"
check_eq "C11 撤销后状态为已取消" CANCELLED "$(db "select status from aftersales_order where id=2;")"
check_eq "C12 撤销后可售后数量恢复" 1 "$(get $ZJ /api/consumer/orders | node -e '
let s = require("fs").readFileSync(0, "utf8");
let items = JSON.parse(s).data.flatMap(o => o.items).filter(i => String(i.id) === process.argv[1]);
process.stdout.write(items.length ? String(items[0].afterSaleableQuantity) : "notfound");
' 6)"
R=$(post $WH /api/staff/aftersales/2/receive <<'JSON'
{"parcelNo":"不该成功的单号"}
JSON
)
check_eq "C13 已关闭的售后单不能再登记收货" 409 "$(echo "$R" | code)"
check_has "C14 提示说明单据已关闭" "已关闭" "$(echo "$R" | message)"

# ============ 组 D：异常流转 ============
step "组 D 异常流：要求补充材料、验货异常不自动关闭、客服据此拒绝"
R=$(apply $ZJ 12 RETURN 1 "围巾起球，说明先写得比较含糊")
check_eq "D0 新建一张用于补充材料流程的单" 0 "$(echo "$R" | code)"
IDN=$(echo "$R" | pick .)
R=$(post $S1 "/api/staff/aftersales/$IDN/review" <<'JSON'
{"action":"NEED_SUPPLEMENT","note":"缺少洗涤状态说明，请补充后重新提交"}
JSON
)
check_eq "D1 客服要求补充材料" 0 "$(echo "$R" | code)"
check_eq "D2 要求补充后状态为待补充" NEED_SUPPLEMENT "$(db "select status from aftersales_order where id=$IDN;")"
R=$(post $ZJ "/api/aftersales/$IDN/resubmit" <<'JSON'
{"description":"已补充：商品仅试戴未洗涤，吊牌完整，照片已上传"}
JSON
)
check_eq "D3 消费者补充后重新提交" 0 "$(echo "$R" | code)"
check_eq "D4 重新提交后回到待审核" PENDING_REVIEW "$(db "select status from aftersales_order where id=$IDN;")"
check_eq "D5 时间线保留了两次往来记录" 2 \
  "$(db "select count(*) from aftersales_action_log where aftersales_id=$IDN and action in ('SUPPLEMENT_REQUEST','RESUBMIT');")"

R=$(post $S1 "/api/staff/aftersales/$IDC/review" <<'JSON'
{"action":"REJECT"}
JSON
)
check_eq "D6 拒绝不写理由被拒" 400 "$(echo "$R" | code)"
R=$(post $S1 "/api/staff/aftersales/$IDC/review" <<'JSON'
{"action":"REJECT","note":"说明过于笼统，且该商品已超期，无法受理"}
JSON
)
check_eq "D7 写明理由后拒绝成立" 0 "$(echo "$R" | code)"
check_eq "D8 拒绝后状态为已拒绝" REJECTED "$(db "select status from aftersales_order where id=$IDC;")"

R=$(post $WH /api/staff/aftersales/4/inspect <<'JSON'
{"result":"ABNORMAL"}
JSON
)
check_eq "D9 还没收货就登记验货被拒" 409 "$(echo "$R" | code)"
check_has "D10 提示先登记收货" "请先登记收到退回包裹" "$(echo "$R" | message)"
post $WH /api/staff/aftersales/4/receive <<'JSON' | code >/dev/null
{"parcelNo":"JD7788990011"}
JSON
R=$(post $WH /api/staff/aftersales/4/inspect <<'JSON'
{"result":"ABNORMAL"}
JSON
)
check_eq "D11 验货异常不写现象被拒" 400 "$(echo "$R" | code)"
R=$(post $WH /api/staff/aftersales/4/inspect <<'JSON'
{"result":"ABNORMAL","issueDescription":"衬衫有明显穿着褶皱与咖啡渍，不具备二次销售条件"}
JSON
)
check_eq "D12 写明现象后异常登记成功" 0 "$(echo "$R" | code)"
check_eq "D13 验货异常只把单据交给客服，不自动关闭" WAIT_FINAL_REVIEW "$(db "select status from aftersales_order where id=4;")"
check_eq "D14 此时关闭时间为空" NULL "$(db "select ifnull(cast(closed_at as char),'NULL') from aftersales_order where id=4;")"

R=$(post $WH "/api/staff/aftersales/4/finalize" <<'JSON'
{"action":"FINAL_REJECT","note":"仓库不能自己判定退款或换货"}
JSON
)
check_eq "D15 仓库调用客服结论接口被拒" 403 "$(echo "$R" | code)"
R=$(post $S1 /api/staff/aftersales/4/finalize <<'JSON'
{"action":"FINAL_REJECT","note":"商品已穿着污损，不符合退货条件，将原路寄回"}
JSON
)
check_eq "D16 客服据验货异常拒绝申请" 0 "$(echo "$R" | code)"
check_eq "D17 最终状态为已拒绝" REJECTED "$(db "select status from aftersales_order where id=4;")"
check_eq "D18 消费者看不到仓库内部记录" 0 \
  "$(db "select count(*) from aftersales_action_log where aftersales_id=4 and action in ('RECEIVE','INSPECT_ABNORMAL') and visible_to_consumer=1;")"
check_eq "D19 客服能看到内部记录" 2 \
  "$(db "select count(*) from aftersales_action_log where aftersales_id=4 and action in ('RECEIVE','INSPECT_ABNORMAL');")"

# ============ 组 E：并发与越权 ============
step "组 E 并发与越权：两个客服同时处理同一张单、跨账号读取、未登录访问"
BODY='{"action":"APPROVE_RETURN","note":"并发窗口之一","returnGuidance":"退回售后仓"}'
CONCDIR=$(mktemp -d)
( post $S1 /api/staff/aftersales/1/review <<< "$BODY" > "$CONCDIR/cs01" ) &
( post $S2 /api/staff/aftersales/1/review <<< "$BODY" > "$CONCDIR/cs02" ) &
wait
E1C1=$(code < "$CONCDIR/cs01")
E1C2=$(code < "$CONCDIR/cs02")
# 空响应或坏 JSON 会让取值变成空串，而 $(( )) 把空串当 0 —— 那样「没读到结果」会被蒙成「409+0」。
# 先断言两边都解析出了数字码，失败时能一眼看出是取证环节断了，不是并发规则松了。
check_eq "E1a 两个并发响应都解析出了数字业务码" 1 \
  "$(node -e 'let v=require("fs").readFileSync(0,"utf8").trim().split(/\s+/);process.stdout.write(v.length===2&&v.every(x=>/^\d+$/.test(x))?"1":"0");' <<< "$E1C1 $E1C2")"
LOSERSLOT="$CONCDIR/cs$([ "$E1C1" = "0" ] && echo 02 || echo 01)"
check_eq "E1 两名客服同时同意退回，只有一份写入成功（0+409）" 409 "$((E1C1 + E1C2))"
check_eq "E2 同意退回的动作只记录一次" 1 \
  "$(db "select count(*) from aftersales_action_log where aftersales_id=1 and action='APPROVE_RETURN';")"
check_eq "E3 并发后状态只前进了一步" WAIT_RETURN "$(db "select status from aftersales_order where id=1;")"
check_has "E4 失败的一方拿到可理解的冲突提示" "其他客服" "$(message < "$LOSERSLOT")"
rm -rf "$CONCDIR"

R=$(get $ZJ /api/aftersales/$IDA)
check_eq "E5 张三读取小林的售后单被拒" 403 "$(echo "$R" | code)"
check_has "E6 拒绝时不泄露单据内容" "无权查看" "$(echo "$R" | message)"
check_eq "E7 张三的售后列表里查不到这张单" 0 \
  "$(get $ZJ '/api/aftersales/mine' | node -e '
let s=require("fs").readFileSync(0,"utf8");
let d=JSON.parse(s).data.filter(a=>String(a.id)===process.argv[1]);
process.stdout.write(String(d.length));' "$IDA")"
R=$(raw /api/staff/aftersales)
check_eq "E8 未登录访问客服接口" 401 "$(echo "$R" | code)"
R=$(raw /api/consumer/orders)
check_eq "E9 未登录访问消费者接口" 401 "$(echo "$R" | code)"
R=$(get $CJ /api/staff/aftersales)
check_eq "E10 消费者访问客服列表被拒" 403 "$(echo "$R" | code)"

# ============ 组 F：数据与页面口径一致（联调证据）============
step "组 F 联调对账：接口计数、金额与状态标签和数据库一致"
STAT_TOTAL=$(get $S1 /api/staff/aftersales/stats | node -e '
let s=require("fs").readFileSync(0,"utf8");
let d=JSON.parse(s).data;
process.stdout.write(String(d.reduce((n, x) => n + Number(x.count), 0)));')
check_eq "F1 工作台状态计数之和 = 数据库售后单总数" "$(db 'select count(*) from aftersales_order;')" "$STAT_TOTAL"

R=$(post $S2 /api/staff/aftersales/5/finalize <<'JSON'
{"action":"FINAL_REFUND","note":"验货合格且在售后期内，同意退款","refundAmount":0.01,"status":"COMPLETED"}
JSON
)
check_eq "F2 客服确认退款（请求里夹带金额和状态）" 0 "$(echo "$R" | code)"
check_eq "F3 金额以服务端单价×数量为准，前端传不进来" 699.00 "$(db "select refund_amount from aftersales_order where id=5;")"
check_has "F4 页面状态标签与后端枚举一致（WAIT_FINAL_REVIEW=待确认）" "待确认" "$(get $S1 /api/aftersales/6 | pick .statusLabel)"
check_eq "F5 详情页时间线条数 = aftersales_action_log 条数" \
  "$(db 'select count(*) from aftersales_action_log where aftersales_id=5;')" \
  "$(get $S1 /api/staff/aftersales/5/timeline | node -e '
let s=require("fs").readFileSync(0,"utf8");
process.stdout.write(String(JSON.parse(s).data.length));')"
check_eq "F6 仓库工作台一次带出收货验货记录（不再逐行查询）" 1 \
  "$(get $WH '/api/staff/aftersales?status=WAIT_FINAL_REVIEW' | node -e '
let s=require("fs").readFileSync(0,"utf8");
let d=JSON.parse(s).data.filter(a=>a.warehouseRecord && a.warehouseRecord.receivedAt);
process.stdout.write(String(d.length >= 1 ? 1 : 0));')"

# ============ 组 G：错误处理 ============
step "组 G 错误处理：非法路径参数、非法请求体，都不能变成 500 或泄露堆栈信息"
R=$(get $CJ /api/aftersales/abc)
check_eq "G1 售后单编号不是数字时返回 400" 400 "$(echo "$R" | code)"
check_has "G2 提示指出地址不合法" "不合法" "$(echo "$R" | message)"
R=$(post $S1 /api/staff/aftersales/1/review <<'JSON'
{"action":"APPROVE_RETURN", 这不是合法 JSON}
JSON
)
check_eq "G3 请求体不是合法 JSON 时返回 400" 400 "$(echo "$R" | code)"
check_has "G4 提示用户刷新重试而不是抛内部错误" "格式不正确" "$(echo "$R" | message)"
LEAK=$(printf '%s\n%s\n' "$(message <<< "$R")" "$(get $CJ /api/aftersales/abc | message)" | node -e '
let s=require("fs").readFileSync(0,"utf8");
process.stdout.write(s.includes("Exception") ? "leaked" : "clean");')
check_eq "G5 返回给浏览器的提示里不含异常类名" clean "$LEAK"
# /api/auth/current 是本次写联调文档时敲错的一个地址，留下它作为「404 不能报成 500」的样本
R=$(raw /api/auth/current)
check_eq "G6 不存在的接口地址返回 404 而不是 500" 404 "$(echo "$R" | code)"
check_has "G7 提示说明是地址不存在，不是服务故障" "不存在" "$(echo "$R" | message)"

step "验收结果"
echo "  通过 $pass 项，失败 $fail 项"
if [ "$fail" -gt 0 ]; then
  printf "  失败用例：%b\n" "$FAILED"
  exit 1
fi
echo "  全部用例通过（数据库当前停留在最后一次运行产生的状态，重跑会自动重置）"
