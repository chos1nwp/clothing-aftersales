-- ============================================================
-- 服装网店退换货处理系统 · 建表脚本
-- MySQL 8.0 / utf8mb4
-- 用法：mysql -u aftersales -p clothing_aftersales < sql/schema.sql
-- ============================================================

SET NAMES utf8mb4;

DROP TABLE IF EXISTS aftersales_action_log;
DROP TABLE IF EXISTS aftersales_evidence;
DROP TABLE IF EXISTS warehouse_record;
DROP TABLE IF EXISTS aftersales_order;
DROP TABLE IF EXISTS order_item;
DROP TABLE IF EXISTS shop_order;
DROP TABLE IF EXISTS app_user;

-- 账号与岗位
CREATE TABLE app_user (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  username      VARCHAR(64)  NOT NULL COMMENT '登录名',
  password_hash VARCHAR(100) NOT NULL COMMENT 'SHA2(username:password, 256)',
  display_name  VARCHAR(64)  NOT NULL,
  role          VARCHAR(20)  NOT NULL COMMENT 'CONSUMER / CS / WAREHOUSE',
  phone         VARCHAR(20)  DEFAULT NULL COMMENT '虚构脱敏号码',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uk_app_user_username (username)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='系统账号';

-- 模拟订单
CREATE TABLE shop_order (
  id              BIGINT      NOT NULL AUTO_INCREMENT,
  order_no        VARCHAR(32) NOT NULL,
  user_id         BIGINT      NOT NULL COMMENT '归属消费者',
  status          VARCHAR(20) NOT NULL COMMENT 'SHIPPED 已发货 / COMPLETED 已完成',
  placed_at       DATETIME    NOT NULL,
  completed_at    DATETIME    DEFAULT NULL COMMENT '签收完成时间',
  after_sale_days INT         NOT NULL DEFAULT 7 COMMENT '售后期限天数',
  PRIMARY KEY (id),
  UNIQUE KEY uk_shop_order_no (order_no),
  KEY idx_shop_order_user (user_id, status),
  CONSTRAINT fk_shop_order_user FOREIGN KEY (user_id) REFERENCES app_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='模拟订单';

-- 订单商品
CREATE TABLE order_item (
  id           BIGINT        NOT NULL AUTO_INCREMENT,
  order_id     BIGINT        NOT NULL,
  product_name VARCHAR(128)  NOT NULL,
  color        VARCHAR(32)   NOT NULL,
  size         VARCHAR(16)   NOT NULL,
  quantity     INT           NOT NULL,
  unit_price   DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  KEY idx_order_item_order (order_id),
  CONSTRAINT fk_order_item_order FOREIGN KEY (order_id) REFERENCES shop_order (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='订单商品';

-- 售后单（主单据）
CREATE TABLE aftersales_order (
  id                  BIGINT        NOT NULL AUTO_INCREMENT,
  aftersales_no       VARCHAR(32)   NOT NULL,
  order_item_id       BIGINT        NOT NULL,
  consumer_user_id    BIGINT        NOT NULL,
  type                VARCHAR(20)   NOT NULL COMMENT 'RETURN 退货 / EXCHANGE 换货',
  reason_code         VARCHAR(32)   NOT NULL COMMENT 'SIZE / DAMAGED / WRONG_ITEM / QUALITY / OTHER',
  quantity            INT           NOT NULL,
  description         VARCHAR(500)  NOT NULL,
  status              VARCHAR(24)   NOT NULL COMMENT '见设计文档第 2 节状态机',
  return_guidance     VARCHAR(500)  DEFAULT NULL,
  consumer_parcel_no  VARCHAR(64)   DEFAULT NULL,
  refund_amount       DECIMAL(10,2) DEFAULT NULL COMMENT '模拟退款金额，服务端计算',
  resend_tracking_no  VARCHAR(64)   DEFAULT NULL COMMENT '换货模拟补发单号',
  final_note          VARCHAR(500)  DEFAULT NULL,
  created_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at          DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  closed_at           DATETIME      DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_aftersales_no (aftersales_no),
  KEY idx_as_consumer (consumer_user_id, status),
  KEY idx_as_item (order_item_id, status),
  KEY idx_as_status (status),
  CONSTRAINT fk_as_item FOREIGN KEY (order_item_id) REFERENCES order_item (id),
  CONSTRAINT fk_as_consumer FOREIGN KEY (consumer_user_id) REFERENCES app_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='售后单';

-- 图片凭证
CREATE TABLE aftersales_evidence (
  id            BIGINT       NOT NULL AUTO_INCREMENT,
  aftersales_id BIGINT       NOT NULL,
  file_path     VARCHAR(255) NOT NULL COMMENT '服务器相对路径',
  original_name VARCHAR(128) NOT NULL,
  uploaded_by   BIGINT       NOT NULL,
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_evidence_as (aftersales_id),
  CONSTRAINT fk_evidence_as FOREIGN KEY (aftersales_id) REFERENCES aftersales_order (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='售后图片凭证';

-- 仓库收货与验货记录
CREATE TABLE warehouse_record (
  id                BIGINT       NOT NULL AUTO_INCREMENT,
  aftersales_id     BIGINT       NOT NULL,
  parcel_no         VARCHAR(64)  DEFAULT NULL COMMENT '实际收到包裹号',
  received_at       DATETIME     DEFAULT NULL,
  received_by       BIGINT       DEFAULT NULL,
  inspection_result VARCHAR(16)  DEFAULT NULL COMMENT 'PASS / ABNORMAL，NULL 表示未验货',
  issue_description VARCHAR(500) DEFAULT NULL COMMENT '验货异常现象',
  inspected_at      DATETIME     DEFAULT NULL,
  inspected_by      BIGINT       DEFAULT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uk_warehouse_as (aftersales_id),
  CONSTRAINT fk_warehouse_as FOREIGN KEY (aftersales_id) REFERENCES aftersales_order (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='仓库收货与验货';

-- 售后时间线
CREATE TABLE aftersales_action_log (
  id                  BIGINT       NOT NULL AUTO_INCREMENT,
  aftersales_id       BIGINT       NOT NULL,
  action              VARCHAR(32)  NOT NULL,
  from_status         VARCHAR(24)  DEFAULT NULL,
  to_status           VARCHAR(24)  NOT NULL,
  operator_user_id    BIGINT       NOT NULL,
  operator_role       VARCHAR(20)  NOT NULL COMMENT '冗余存储，防账号变更导致历史失真',
  note                VARCHAR(500) DEFAULT NULL,
  visible_to_consumer TINYINT(1)   NOT NULL DEFAULT 1,
  created_at          DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_log_as (aftersales_id, created_at),
  CONSTRAINT fk_log_as FOREIGN KEY (aftersales_id) REFERENCES aftersales_order (id),
  CONSTRAINT fk_log_operator FOREIGN KEY (operator_user_id) REFERENCES app_user (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci COMMENT='售后操作时间线';
