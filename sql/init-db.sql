-- ============================================================
-- 数据库与账号初始化（需 root 或具备建库授权权限的账号执行）
--
--   执行方式：mysql -u root -p < sql/init-db.sql
--
-- 请把下面两处的 <请替换成本地密码> 换成同一个密码，
-- 并把该密码只写进项目根目录的 application-local.properties
-- （该文件已在 .gitignore 中，禁止提交）。
-- ============================================================

CREATE DATABASE IF NOT EXISTS clothing_aftersales
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;

-- 应用使用专用账号，不用 root：只授权本库，口令与本地配置文件一致
CREATE USER IF NOT EXISTS 'aftersales'@'localhost' IDENTIFIED BY '<请替换成本地密码>';

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER
  ON clothing_aftersales.* TO 'aftersales'@'localhost';

FLUSH PRIVILEGES;
