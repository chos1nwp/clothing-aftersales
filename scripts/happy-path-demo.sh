#!/usr/bin/env bash
# 正常收束路径：补齐 flow-demo.sh 没走到的两种结束状态——
#   A. 退货 → 验货通过 → 客服确认模拟退款（COMPLETED，refund_amount 由服务端算出）
#   B. 换货 → 验货通过 → 客服确认补发（COMPLETED，resend_tracking_no）
# 可独立执行，会先重置演示数据。
set -u
BASE=http://localhost:8080
CJ=/tmp/hc.txt; SJ=/tmp/hs.txt; WJ=/tmp/hw.txt
rm -f $CJ $SJ $WJ

step() { echo; echo "── $1"; }
post() { curl -s -b "$1" -c "$1" -X POST -H 'Content-Type: application/json; charset=utf-8' --data-binary @- "$BASE$2"; }
get() { curl -s -b "$1" "$BASE$2"; }
msg() { node -e 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'; }

step "重置演示数据"
DB_PASS=$(grep -o 'AFTERSALES_DB_PASSWORD=.*' application-local.properties | cut -d= -f2-)
MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql 2>/dev/null \
  && echo "  sql/data.sql 已重新执行" || echo "  重置失败：请检查 MySQL"

step "登录"
post $CJ /api/auth/login <<< '{"username":"xiaolin","password":"123456"}' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  消费者 "+JSON.parse(s).data.displayName)'
post $SJ /api/auth/login <<< '{"username":"cs01","password":"123456"}'   | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  客服   "+JSON.parse(s).data.displayName)'
post $WJ /api/auth/login <<< '{"username":"wh01","password":"123456"}'   | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  仓库   "+JSON.parse(s).data.displayName)'

# ---------- A. 退货退款 ----------
step "A. 商品16 申请退货"
RESP=$(post $CJ /api/aftersales <<'JSON'
{"orderItemId":16,"type":"RETURN","quantity":1,"reasonCode":"SIZE","description":"尺码不合适，直接退掉"}
JSON
)
A_ID=$(node -e 'let s=require("fs").readFileSync(0,"utf8");process.stdout.write(String(JSON.parse(s).data))' <<< "$RESP")
echo "  售后单 id=$A_ID"

post $SJ "/api/staff/aftersales/$A_ID/review" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  客服同意退回 → "+JSON.parse(s).message)'
{"action":"APPROVE_RETURN","note":"在售后期内，同意退货","returnGuidance":"退回至：杭州市余杭区文一西路1234号A栋售后仓，收件人售后组"}
JSON
post $CJ "/api/aftersales/$A_ID/mark-shipped" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  消费者寄回 → "+JSON.parse(s).message)'
{"parcelNo":"YT7788990011"}
JSON
post $WJ "/api/staff/aftersales/$A_ID/receive" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  仓库收货 → "+JSON.parse(s).message)'
{"parcelNo":"YT7788990011"}
JSON
post $WJ "/api/staff/aftersales/$A_ID/inspect" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  仓库验货通过 → "+JSON.parse(s).message)'
{"result":"PASS"}
JSON
echo -n "  重复提交验货结果 → "
post $WJ "/api/staff/aftersales/$A_ID/inspect" <<'JSON' | msg
{"result":"PASS"}
JSON
post $SJ "/api/staff/aftersales/$A_ID/finalize" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  客服确认退款 → "+JSON.parse(s).message)'
{"action":"FINAL_REFUND","note":"验货通过，按实际退货数量模拟退款"}
JSON
get $CJ "/api/aftersales/$A_ID" | node -e '
let s=require("fs").readFileSync(0,"utf8");let a=JSON.parse(s).data;
console.log(`  消费者看到：${a.statusLabel} 退款金额=¥${a.refundAmount}（单价¥${a.unitPrice} × ${a.quantity}件）`);'

# ---------- B. 换货补发 ----------
step "B. 沿用演示数据里那张待审核的换货单（商品1 衬衫）"
# id 只走 stdout，说明文字走 stderr，避免命令替换把日志一起塞进变量
B_ID=$(get $SJ "/api/staff/aftersales?status=PENDING_REVIEW" | node -e '
let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s).data.find(a=>a.type==="EXCHANGE");
console.error("  取到 "+d.aftersalesNo+" "+d.productName+" "+d.typeLabel+" 申请人="+d.consumerName+" 状态="+d.statusLabel);
process.stdout.write(String(d.id));')
echo "  售后单 id=$B_ID"

post $SJ "/api/staff/aftersales/$B_ID/review" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  客服同意退回 → "+JSON.parse(s).message)'
{"action":"APPROVE_RETURN","note":"同意换货，请退回原商品","returnGuidance":"退回至：杭州市余杭区文一西路1234号A栋售后仓，收件人售后组"}
JSON
post $CJ "/api/aftersales/$B_ID/mark-shipped" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  消费者寄回 → "+JSON.parse(s).message)'
{"parcelNo":"ZTO1122334455"}
JSON
post $WJ "/api/staff/aftersales/$B_ID/receive" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  仓库收货 → "+JSON.parse(s).message)'
{"parcelNo":"ZTO1122334455"}
JSON
post $WJ "/api/staff/aftersales/$B_ID/inspect" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  仓库验货通过 → "+JSON.parse(s).message)'
{"result":"PASS"}
JSON
echo -n "  换货却填退款结论（验货通过的商品应补发，不该退款）→ "
post $SJ "/api/staff/aftersales/$B_ID/finalize" <<'JSON' | msg
{"action":"FINAL_REFUND","note":"先看看会不会被拦住"}
JSON
echo -n "  换货补发但不给单号 → "
post $SJ "/api/staff/aftersales/$B_ID/finalize" <<'JSON' | msg
{"action":"FINAL_EXCHANGE","note":"同意补发，等待填写快递单号"}
JSON
post $SJ "/api/staff/aftersales/$B_ID/finalize" <<'JSON' | node -e 'let s=require("fs").readFileSync(0,"utf8");console.log("  换货补发 → "+JSON.parse(s).message)'
{"action":"FINAL_EXCHANGE","trackingNo":"SF5566778899","note":"已按原尺码重新发出"}
JSON
get $SJ "/api/aftersales/$B_ID" | node -e '
let s=require("fs").readFileSync(0,"utf8");let a=JSON.parse(s).data;
console.log(`  客服看到：${a.statusLabel} 补发单号=${a.resendTrackingNo} 退款金额=${a.refundAmount}`);'

step "C. 仓库验货通过 ≠ 售后结束：核对两张单据的结束时间"
get $SJ "/api/staff/aftersales?status=COMPLETED" | node -e '
let s=require("fs").readFileSync(0,"utf8");
JSON.parse(s).data.forEach(a=>console.log(`  ${a.aftersalesNo} ${a.typeLabel} ${a.statusLabel} 关闭于 ${a.closedAt}`));'

echo
echo "本次演示售后单：退货退款 id=$A_ID，换货补发 id=$B_ID"
