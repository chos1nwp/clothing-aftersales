-- ============================================================
-- 服装网店退换货处理系统 · 初始化虚构数据
-- 全部为虚构姓名、单号与金额，不含任何真实个人数据
-- 用法：mysql -u aftersales -p clothing_aftersales < sql/data.sql
-- 演示账号统一密码：123456
-- ============================================================

SET NAMES utf8mb4;

DELETE FROM aftersales_action_log;
DELETE FROM aftersales_evidence;
DELETE FROM warehouse_record;
DELETE FROM aftersales_order;
DELETE FROM order_item;
DELETE FROM shop_order;
DELETE FROM app_user;

-- ---------- 账号（密码 = SHA2(username:123456, 256)） ----------
INSERT INTO app_user (id, username, password_hash, display_name, role, phone) VALUES
 (1, 'xiaolin',      SHA2('xiaolin:123456', 256),      '小林',       'CONSUMER',  '138-0000-0001'),
 (2, 'zhangsan',     SHA2('zhangsan:123456', 256),     '张三',       'CONSUMER',  '138-0000-0002'),
 (3, 'wangxiaohong', SHA2('wangxiaohong:123456', 256), '王小红',     'CONSUMER',  '138-0000-0003'),
 (4, 'cs01',         SHA2('cs01:123456', 256),         '客服陈静',   'CS',        '0571-8888-0001'),
 (5, 'cs02',         SHA2('cs02:123456', 256),         '负责人李明', 'CS',        '0571-8888-0002'),
 (6, 'wh01',         SHA2('wh01:123456', 256),         '仓库刘伟',   'WAREHOUSE', '0571-8888-0003');

-- ---------- 模拟订单 ----------
-- order2 完成于 18 天前，用于测"超过售后期限"；order5 未签收，用于测"订单未完成不可申请"
INSERT INTO shop_order (id, order_no, user_id, status, placed_at, completed_at, after_sale_days) VALUES
 (1, 'SO20260901001', 1, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 12 DAY), DATE_SUB(NOW(), INTERVAL 5 DAY),  7),
 (2, 'SO20260902002', 1, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 20 DAY), DATE_SUB(NOW(), INTERVAL 18 DAY), 7),
 (3, 'SO20260903003', 2, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 10 DAY), DATE_SUB(NOW(), INTERVAL 3 DAY),  7),
 (4, 'SO20260904004', 3, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 9 DAY),  DATE_SUB(NOW(), INTERVAL 2 DAY),  7),
 (5, 'SO20260905005', 1, 'SHIPPED',   DATE_SUB(NOW(), INTERVAL 1 DAY),  NULL,                             7),
 (6, 'SO20260906006', 2, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 8 DAY),  DATE_SUB(NOW(), INTERVAL 4 DAY),  7),
 (7, 'SO20260907007', 3, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 7 DAY),  DATE_SUB(NOW(), INTERVAL 6 DAY),  7),
 (8, 'SO20260908008', 1, 'COMPLETED', DATE_SUB(NOW(), INTERVAL 6 DAY),  DATE_SUB(NOW(), INTERVAL 1 DAY),  7);

-- ---------- 订单商品 ----------
INSERT INTO order_item (id, order_id, product_name, color, size, quantity, unit_price) VALUES
 (1,  1, '纯棉商务衬衫',   '白色', 'L',  2, 129.00),
 (2,  1, '纯棉商务衬衫',   '蓝色', 'M',  1, 129.00),
 (3,  2, '亚麻休闲短袖',   '米色', 'XL', 1,  89.00),
 (4,  2, '薄款防晒开衫',   '灰色', 'F',  1,  99.00),
 (5,  3, '直筒牛仔裤',     '深蓝', '30', 1, 199.00),
 (6,  3, '连帽卫衣',       '黑色', 'M',  1, 259.00),
 (7,  4, '法式碎花连衣裙', '杏色', 'S',  1, 329.00),
 (8,  4, '高腰百褶半身裙', '墨绿', 'M',  2, 159.00),
 (9,  5, '运动速干T恤',    '红色', 'L',  1,  69.00),
 (10, 5, '速干运动短裤',   '黑色', 'L',  1,  59.00),
 (11, 6, '双面绒大衣',     '驼色', 'M',  1, 699.00),
 (12, 6, '羊绒围巾',       '灰色', 'F',  1, 149.00),
 (13, 7, '条纹长袖T恤',    '黑白', 'M',  1, 119.00),
 (14, 7, '冰丝短袖',       '浅蓝', 'L',  2,  79.00),
 (15, 8, '休闲西装裤',     '藏青', '31', 1, 239.00),
 (16, 8, '针织开衫',       '奶白', 'M',  1, 189.00);

-- ---------- 售后单：10 张，覆盖全部 8 种状态 ----------
INSERT INTO aftersales_order
 (id, aftersales_no, order_item_id, consumer_user_id, type, reason_code, quantity, description, status,
  return_guidance, consumer_parcel_no, refund_amount, resend_tracking_no, final_note, created_at, closed_at) VALUES
 -- 主链路演示单：小林 2 件白衬衫中退 1 件，当前在待收货
 (4, 'AS20260920004', 1, 1, 'RETURN', 'SIZE', 1,
  '买大了两件只想退一件，吊牌还在没有穿过', 'WAIT_RECEIPT',
  '请退回至：杭州市余杭区文一西路 1234 号 A 栋售后仓，收件人售后组，电话 0571-8888-0001',
  'SF7788990011', NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 4 DAY), NULL),
 -- 待审核：蓝色衬衫
 (1, 'AS20260920001', 2, 1, 'EXCHANGE', 'SIZE', 1,
  '收到后发现 M 码偏小，想换成 L 码', 'PENDING_REVIEW',
  NULL, NULL, NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 6 HOUR), NULL),
 -- 待补充：张三卫衣破损，说明过简
 (2, 'AS20260920002', 6, 2, 'RETURN', 'DAMAGED', 1,
  '有问题', 'NEED_SUPPLEMENT',
  NULL, NULL, NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 3 DAY), NULL),
 -- 待退回：王小红连衣裙错发
 (3, 'AS20260920003', 7, 3, 'EXCHANGE', 'WRONG_ITEM', 1,
  '下单的是杏色 S，收到的是墨绿 M，尺码颜色都不对', 'WAIT_RETURN',
  '请退回至：杭州市余杭区文一西路 1234 号 A 栋售后仓，收件人售后组，电话 0571-8888-0001',
  NULL, NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 2 DAY), NULL),
 -- 待客服确认（验货合格）：张三外套质量问题
 (5, 'AS20260920005', 11, 2, 'RETURN', 'QUALITY', 1,
  '袖口开线，穿一次就脱线了', 'WAIT_FINAL_REVIEW',
  '请退回至：杭州市余杭区文一西路 1234 号 A 栋售后仓，收件人售后组',
  'YT1122334455', NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 5 DAY), NULL),
 -- 待客服确认（验货异常）：王小红衬衫已洗涤
 (6, 'AS20260920006', 13, 3, 'EXCHANGE', 'SIZE', 1,
  '想换小一码', 'WAIT_FINAL_REVIEW',
  '请退回至：杭州市余杭区文一西路 1234 号 A 栋售后仓，收件人售后组',
  'ZT6677889900', NULL, NULL, NULL, DATE_SUB(NOW(), INTERVAL 6 DAY), NULL),
 -- 已完成（换货）：小林西装裤补发
 (7, 'AS20260920007', 15, 1, 'EXCHANGE', 'SIZE', 1,
  '腰围偏紧，换 32 码', 'COMPLETED',
  '请退回至：杭州市余杭区文一西路 1234 号 A 栋售后仓，收件人售后组',
  'SF5566778899', NULL, 'SF9900112233',
  '验货合格，已安排补发 32 码', DATE_SUB(NOW(), INTERVAL 8 DAY), DATE_SUB(NOW(), INTERVAL 1 DAY)),
 -- 已完成（退货退款）：王小红半身裙 2 件退 1 件
 (8, 'AS20260920008', 8, 3, 'RETURN', 'OTHER', 1,
  '风格不合适，未穿过', 'COMPLETED',
  '请退回至：杭州市余杭区文一西路 1234 号 A 栋售后仓，收件人售后组',
  'JD3344556677', 159.00, NULL,
  '验货合格，模拟退款 159.00 元', DATE_SUB(NOW(), INTERVAL 7 DAY), DATE_SUB(NOW(), INTERVAL 2 DAY)),
 -- 已拒绝：小林对 18 天前签收的订单申请退货，超期被拒（order2 用于期限边界演示）
 (9, 'AS20260920009', 3, 1, 'RETURN', 'OTHER', 1,
  '不太喜欢', 'REJECTED',
  NULL, NULL, NULL, NULL,
  '该订单签收已超过 7 天售后期限，且商品无质量问题描述，不予退货', DATE_SUB(NOW(), INTERVAL 15 DAY), DATE_SUB(NOW(), INTERVAL 14 DAY)),
 -- 已取消：王小红自行撤销
 (10, 'AS20260920010', 14, 3, 'EXCHANGE', 'SIZE', 1,
  '想换 L 码', 'CANCELLED',
  NULL, NULL, NULL, NULL,
  '消费者表示暂时不需要换货，主动撤销', DATE_SUB(NOW(), INTERVAL 9 DAY), DATE_SUB(NOW(), INTERVAL 9 DAY));

-- ---------- 凭证（记录路径，演示图片由 demo 目录占位文件提供） ----------
INSERT INTO aftersales_evidence (id, aftersales_id, file_path, original_name, uploaded_by, created_at) VALUES
 (1, 5, 'demo/quality-coat.jpg',  '袖口开线照片.jpg', 2, DATE_SUB(NOW(), INTERVAL 5 DAY)),
 (2, 6, 'demo/washed-shirt.jpg',  '衬衫洗涤标照片.jpg', 3, DATE_SUB(NOW(), INTERVAL 6 DAY)),
 (3, 7, 'demo/pants-waist.jpg',   '腰围测量照片.jpg', 1, DATE_SUB(NOW(), INTERVAL 8 DAY)),
 (4, 4, 'demo/shirt-tag.jpg',     '吊牌照片.jpg',     1, DATE_SUB(NOW(), INTERVAL 4 DAY));

-- ---------- 仓库收货与验货记录 ----------
INSERT INTO warehouse_record
 (id, aftersales_id, parcel_no, received_at, received_by, inspection_result, issue_description, inspected_at, inspected_by) VALUES
 -- 已收货已验货（合格）→ 待客服确认
 (1, 5, 'YT1122334455', DATE_SUB(NOW(), INTERVAL 2 DAY), 6, 'PASS',     NULL,                       DATE_SUB(NOW(), INTERVAL 2 DAY), 6),
 -- 已收货已验货（异常）→ 待客服确认
 (2, 6, 'ZT6677889900', DATE_SUB(NOW(), INTERVAL 1 DAY), 6, 'ABNORMAL', '商品水洗标已拆开，有明显洗涤痕迹和柔顺剂气味，不具备换货条件', DATE_SUB(NOW(), INTERVAL 1 DAY), 6),
 -- 已完成换货的历史记录
 (3, 7, 'SF5566778899', DATE_SUB(NOW(), INTERVAL 3 DAY), 6, 'PASS',     NULL,                       DATE_SUB(NOW(), INTERVAL 3 DAY), 6),
 -- 已完成退款的历史记录
 (4, 8, 'JD3344556677', DATE_SUB(NOW(), INTERVAL 3 DAY), 6, 'PASS',     NULL,                       DATE_SUB(NOW(), INTERVAL 3 DAY), 6);

 -- 注意：AS4 处于 WAIT_RECEIPT，故意不建 warehouse_record，用于演示"客服同意后仓库才可登记"

-- ---------- 时间线 ----------
INSERT INTO aftersales_action_log
 (aftersales_id, action, from_status, to_status, operator_user_id, operator_role, note, visible_to_consumer, created_at) VALUES
 -- AS4 主链路
 (4, 'APPLY',           NULL,             'PENDING_REVIEW',    1, 'CONSUMER',  '提交退货申请，商品为白色L码纯棉衬衫1件', 1, DATE_SUB(NOW(), INTERVAL 4 DAY)),
 (4, 'APPROVE_RETURN',  'PENDING_REVIEW', 'WAIT_RETURN',       4, 'CS',        '在售后期限内，吊牌完好描述清楚，同意退回', 1, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (4, 'MARK_SHIPPED',    'WAIT_RETURN',    'WAIT_RECEIPT',      1, 'CONSUMER',  '已通过顺丰寄出，包裹号 SF7788990011',     1, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 -- AS1 待审核
 (1, 'APPLY',           NULL,             'PENDING_REVIEW',    1, 'CONSUMER',  '提交换货申请，M 码换 L 码',               1, DATE_SUB(NOW(), INTERVAL 6 HOUR)),
 -- AS2 待补充
 (2, 'APPLY',           NULL,             'PENDING_REVIEW',    2, 'CONSUMER',  '提交退货申请',                             1, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (2, 'SUPPLEMENT_REQUEST','PENDING_REVIEW','NEED_SUPPLEMENT',   4, 'CS',        '描述过于笼统，请补充破损部位照片和破损情况说明', 1, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 -- AS3 待退回
 (3, 'APPLY',           NULL,             'PENDING_REVIEW',    3, 'CONSUMER',  '提交换货申请，收到商品与下单不一致',      1, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 (3, 'APPROVE_RETURN',  'PENDING_REVIEW', 'WAIT_RETURN',       4, 'CS',        '核对订单记录确为错发，同意退回后补发杏色S码', 1, DATE_SUB(NOW(), INTERVAL 1 DAY)),
 -- AS5 待确认（验货合格）
 (5, 'APPLY',           NULL,             'PENDING_REVIEW',    2, 'CONSUMER',  '提交退货申请，袖口开线',                  1, DATE_SUB(NOW(), INTERVAL 5 DAY)),
 (5, 'APPROVE_RETURN',  'PENDING_REVIEW', 'WAIT_RETURN',       4, 'CS',        '质量问题在售后期内，同意退回',            1, DATE_SUB(NOW(), INTERVAL 4 DAY)),
 (5, 'MARK_SHIPPED',    'WAIT_RETURN',    'WAIT_RECEIPT',      2, 'CONSUMER',  '已寄出 YT1122334455',                     1, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (5, 'RECEIVE',         'WAIT_RECEIPT',   'WAIT_RECEIPT',      6, 'WAREHOUSE', '收到包裹 YT1122334455，外包装完好',       0, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 (5, 'INSPECT_PASS',    'WAIT_RECEIPT',   'WAIT_FINAL_REVIEW', 6, 'WAREHOUSE', '验货合格，袖口确为开线，吊牌齐全',        0, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 -- AS6 待确认（验货异常）
 (6, 'APPLY',           NULL,             'PENDING_REVIEW',    3, 'CONSUMER',  '提交换货申请',                            1, DATE_SUB(NOW(), INTERVAL 6 DAY)),
 (6, 'APPROVE_RETURN',  'PENDING_REVIEW', 'WAIT_RETURN',       5, 'CS',        '同意退回换码',                            1, DATE_SUB(NOW(), INTERVAL 5 DAY)),
 (6, 'MARK_SHIPPED',    'WAIT_RETURN',    'WAIT_RECEIPT',      3, 'CONSUMER',  '已寄出 ZT6677889900',                     1, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 (6, 'RECEIVE',         'WAIT_RECEIPT',   'WAIT_RECEIPT',      6, 'WAREHOUSE', '收到包裹 ZT6677889900',                   0, DATE_SUB(NOW(), INTERVAL 1 DAY)),
 (6, 'INSPECT_ABNORMAL','WAIT_RECEIPT',   'WAIT_FINAL_REVIEW', 6, 'WAREHOUSE', '水洗标已拆且有洗涤痕迹，不符合换货条件，转客服判断', 0, DATE_SUB(NOW(), INTERVAL 1 DAY)),
 -- AS7 已完成换货
 (7, 'APPLY',           NULL,             'PENDING_REVIEW',    1, 'CONSUMER',  '提交换货申请，腰围偏紧',                  1, DATE_SUB(NOW(), INTERVAL 8 DAY)),
 (7, 'APPROVE_RETURN',  'PENDING_REVIEW', 'WAIT_RETURN',       4, 'CS',        '同意退回换 32 码',                        1, DATE_SUB(NOW(), INTERVAL 7 DAY)),
 (7, 'MARK_SHIPPED',    'WAIT_RETURN',    'WAIT_RECEIPT',      1, 'CONSUMER',  '已寄出 SF5566778899',                     1, DATE_SUB(NOW(), INTERVAL 5 DAY)),
 (7, 'RECEIVE',         'WAIT_RECEIPT',   'WAIT_RECEIPT',      6, 'WAREHOUSE', '收到 SF5566778899',                       0, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (7, 'INSPECT_PASS',    'WAIT_RECEIPT',   'WAIT_FINAL_REVIEW', 6, 'WAREHOUSE', '验货合格',                                0, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (7, 'FINAL_EXCHANGE',  'WAIT_FINAL_REVIEW','COMPLETED',       4, 'CS',        '验货合格，已安排补发 32 码，单号 SF9900112233', 1, DATE_SUB(NOW(), INTERVAL 1 DAY)),
 -- AS8 已完成退款
 (8, 'APPLY',           NULL,             'PENDING_REVIEW',    3, 'CONSUMER',  '提交退货申请 1 件',                       1, DATE_SUB(NOW(), INTERVAL 7 DAY)),
 (8, 'APPROVE_RETURN',  'PENDING_REVIEW', 'WAIT_RETURN',       4, 'CS',        '同意退回',                                1, DATE_SUB(NOW(), INTERVAL 6 DAY)),
 (8, 'MARK_SHIPPED',    'WAIT_RETURN',    'WAIT_RECEIPT',      3, 'CONSUMER',  '已寄出 JD3344556677',                     1, DATE_SUB(NOW(), INTERVAL 4 DAY)),
 (8, 'RECEIVE',         'WAIT_RECEIPT',   'WAIT_RECEIPT',      6, 'WAREHOUSE', '收到 JD3344556677',                       0, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (8, 'INSPECT_PASS',    'WAIT_RECEIPT',   'WAIT_FINAL_REVIEW', 6, 'WAREHOUSE', '验货合格',                                0, DATE_SUB(NOW(), INTERVAL 3 DAY)),
 (8, 'FINAL_REFUND',    'WAIT_FINAL_REVIEW','COMPLETED',       5, 'CS',        '同意退货，模拟退款 159.00 元',             1, DATE_SUB(NOW(), INTERVAL 2 DAY)),
 -- AS9 已拒绝（超期）
 (9, 'APPLY',           NULL,             'PENDING_REVIEW',    1, 'CONSUMER',  '提交退货申请',                            1, DATE_SUB(NOW(), INTERVAL 15 DAY)),
 (9, 'REJECT',          'PENDING_REVIEW', 'REJECTED',          4, 'CS',        '该订单签收已超过 7 天售后期限，且无质量问题描述，不予退货', 1, DATE_SUB(NOW(), INTERVAL 14 DAY)),
 -- AS10 已取消
 (10,'APPLY',           NULL,             'PENDING_REVIEW',    3, 'CONSUMER',  '提交换货申请',                            1, DATE_SUB(NOW(), INTERVAL 9 DAY)),
 (10,'CANCEL',          'PENDING_REVIEW', 'CANCELLED',         3, 'CONSUMER',  '暂时不需要换货，主动撤销',                1, DATE_SUB(NOW(), INTERVAL 9 DAY));
