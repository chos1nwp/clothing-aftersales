#!/usr/bin/env bash
# 端到端跑通一条完整链路，并逐条验证关键业务规则。
#
# 注意：请求体必须通过 stdin 以 --data-binary 传入。
# Git Bash 调用 Windows 原生 curl.exe 时会把命令行参数按 GBK 编码，
# 中文 JSON 会变成非法 UTF-8 字节，服务端报 Invalid UTF-8 middle byte。
set -u
BASE=http://localhost:8080
CJ=/tmp/cj_consumer.txt; SJ=/tmp/cj_cs.txt; WJ=/tmp/cj_wh.txt; OJ=/tmp/cj_other.txt
rm -f $CJ $SJ $WJ $OJ

step() { echo; echo "── $1"; }
post() { curl -s -b "$1" -c "$1" -X POST -H 'Content-Type: application/json; charset=utf-8' --data-binary @- "$BASE$2"; }
get() { curl -s -b "$1" "$BASE$2"; }
show() { node -e "$1" <<< "$(cat -)"; }

step "重置演示数据（保证脚本可重复执行）"
DB_PASS=$(grep -o 'AFTERSALES_DB_PASSWORD=.*' application-local.properties | cut -d= -f2-)
MYSQL_PWD="$DB_PASS" mysql -u aftersales --default-character-set=utf8mb4 clothing_aftersales < sql/data.sql 2>/dev/null \
  && echo "  sql/data.sql 已重新执行" || echo "  重置失败：请检查 application-local.properties 与 MySQL 服务"

step "0. 三个岗位分别登录"
post $CJ /api/auth/login <<< '{"username":"xiaolin","password":"123456"}' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  消费者 "+JSON.parse(s).data.displayName)'
post $SJ /api/auth/login <<< '{"username":"cs01","password":"123456"}' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  客服   "+JSON.parse(s).data.displayName)'
post $WJ /api/auth/login <<< '{"username":"wh01","password":"123456"}' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  仓库   "+JSON.parse(s).data.displayName)'

step "1. 可售后数量（商品16 针织开衫 / 商品1 白色L码衬衫已有一张进行中售后单）"
get $CJ /api/consumer/orders | show '
let s=require("fs").readFileSync(0,"utf8");
for(const ord of JSON.parse(s).data) for(const it of ord.items)
  if(it.id===16||it.id===1) console.log(`  商品${it.id} ${it.productName} ${it.color}/${it.size} 订单${ord.orderNo} 购买${it.quantity} 可售后${it.afterSaleableQuantity} 在售后期内=${ord.afterSaleOpen}`);'

step "2. 小林对商品16发起换货申请"
RESP=$(post $CJ /api/aftersales <<'JSON'
{"orderItemId":16,"type":"EXCHANGE","quantity":1,"reasonCode":"SIZE","description":"收到后发现袖长偏短，想换一码"}
JSON
)
echo "  $RESP"
ID=$(node -e 'let s=require("fs").readFileSync(0,"utf8");process.stdout.write(String(JSON.parse(s).data));' <<< "$RESP")
echo "  新售后单 id=$ID"

step "3. 规则校验（四条都应被拦下）"
echo -n "  3a 同一商品重复申请 → "; post $CJ /api/aftersales <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"orderItemId":16,"type":"EXCHANGE","quantity":1,"reasonCode":"SIZE","description":"再次提交看看会不会被拦住"}
JSON
echo -n "  3b 额度已被历史售后单占用（商品15 已完成换货1件）→ "; post $CJ /api/aftersales <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"orderItemId":15,"type":"RETURN","quantity":1,"reasonCode":"SIZE","description":"这条裤子也想退掉看看额度是否已经用完"}
JSON
echo -n "  3c 申请他人订单商品 → "; post $CJ /api/aftersales <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"orderItemId":11,"type":"RETURN","quantity":1,"reasonCode":"OTHER","description":"测试越权申请别人的商品"}
JSON
echo -n "  3d 超过售后期限 → "; post $CJ /api/aftersales <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"orderItemId":3,"type":"RETURN","quantity":1,"reasonCode":"OTHER","description":"签收已经十八天了才来申请退货"}
JSON

step "4. 客服查看待审核队列"
get $SJ "/api/staff/aftersales?status=PENDING_REVIEW" | show '
let s=require("fs").readFileSync(0,"utf8");
for(const a of JSON.parse(s).data) console.log(`  ${a.aftersalesNo} ${a.productName} ${a.typeLabel} 申请人=${a.consumerName} 状态=${a.statusLabel}`);'

step "5. 客服要求补充材料"
post $SJ "/api/staff/aftersales/$ID/review" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  "+JSON.parse(s).message)'
{"action":"NEED_SUPPLEMENT","note":"请补充平铺测量照片，确认袖长实际尺寸"}
JSON
get $CJ "/api/aftersales/$ID" | show 'let s=require("fs").readFileSync(0,"utf8");let a=JSON.parse(s).data;console.log("  消费者看到状态: "+a.statusLabel);'

step "6. 消费者补充后重新提交"
post $CJ "/api/aftersales/$ID/resubmit" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  "+JSON.parse(s).message)'
{"description":"已测量：袖长比同款短约2厘米，平铺照片已上传"}
JSON
get $CJ "/api/aftersales/$ID" | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  现在状态: "+JSON.parse(s).data.statusLabel);'

step "7. 客服同意退回并给出退回指引"
post $SJ "/api/staff/aftersales/$ID/review" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  "+JSON.parse(s).message)'
{"action":"APPROVE_RETURN","note":"符合换货条件","returnGuidance":"退回至：杭州市余杭区文一西路1234号A栋售后仓，收件人售后组"}
JSON

step "8. 关键规则：消费者还没寄回，仓库能否提前登记收货？"
echo -n "  → "; post $WJ "/api/staff/aftersales/$ID/receive" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"parcelNo":"SF0000000001"}
JSON

step "9. 消费者确认已寄出"
post $CJ "/api/aftersales/$ID/mark-shipped" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  "+JSON.parse(s).message)'
{"parcelNo":"SF1234567890"}
JSON

step "10. 仓库登记收货（状态不变，只多一条收货记录）"
post $WJ "/api/staff/aftersales/$ID/receive" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");console.log("  "+JSON.parse(s).message)'
{"parcelNo":"SF1234567890"}
JSON
get $WJ "/api/aftersales/$ID" | show 'let s=require("fs").readFileSync(0,"utf8");let a=JSON.parse(s).data;let w=a.warehouseRecord||{};console.log("  状态="+a.statusLabel+"  已收货="+(w.receivedAt?"是":"否")+"  已验货="+(w.inspectionResult?"是":"否"));'

step "11. 仓库直接验货前先试一次不写现象的异常"
echo -n "  异常但不写现象 → "; post $WJ "/api/staff/aftersales/$ID/inspect" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"result":"ABNORMAL"}
JSON
echo -n "  正常登记异常 → "; post $WJ "/api/staff/aftersales/$ID/inspect" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"result":"ABNORMAL","issueDescription":"退回的开衫有明显穿着起球和咖啡渍，不具备换货条件"}
JSON
get $SJ "/api/aftersales/$ID" | show 'let s=require("fs").readFileSync(0,"utf8");let a=JSON.parse(s).data;console.log("  客服视角: 状态="+a.statusLabel+" 验货="+a.warehouseRecord.inspectionResult+" 现象="+a.warehouseRecord.issueDescription);'

step "12. 客服在验货后给出最终结论（拒绝）"
echo -n "  不写理由 → "; post $SJ "/api/staff/aftersales/$ID/finalize" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"action":"FINAL_REJECT"}
JSON
echo -n "  写明理由 → "; post $SJ "/api/staff/aftersales/$ID/finalize" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"action":"FINAL_REJECT","note":"退回商品已穿着并污损，不符合换货条件，商品将原路寄回"}
JSON

step "13. 消费者视角时间线（内部记录应被过滤）"
get $CJ "/api/aftersales/$ID" | show '
let s=require("fs").readFileSync(0,"utf8");let a=JSON.parse(s).data;
console.log("  最终状态="+a.statusLabel);
a.timeline.forEach(t=>console.log(`   · ${t.action} [${t.operatorRole}] ${t.note}`));'

step "14. 客服视角时间线（含内部记录，标注是否对消费者可见）"
get $SJ "/api/staff/aftersales/$ID/timeline" | show '
let s=require("fs").readFileSync(0,"utf8");
JSON.parse(s).data.forEach(t=>console.log(`   · ${t.action} by ${t.operatorName}(${t.operatorRole}) 对消费者可见=${t.visibleToConsumer}`));'

step "15. 越权：张三访问小林的售后单"
post $OJ /api/auth/login <<< '{"username":"zhangsan","password":"123456"}' > /dev/null
get $OJ "/api/aftersales/$ID" | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("  ["+d.code+"] "+d.message);'

step "16. 已关闭的售后单不能再改"
echo -n "  仓库再登记一次收货 → "; post $WJ "/api/staff/aftersales/$ID/receive" <<'JSON' | show 'let s=require("fs").readFileSync(0,"utf8");let d=JSON.parse(s);console.log("["+d.code+"] "+d.message)'
{"parcelNo":"SF9999999999"}
JSON

echo
echo "本次演示售后单 id=$ID"
