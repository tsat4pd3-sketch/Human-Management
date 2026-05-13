-- ============================================================
--  Employee Attendance & PPE Dashboard — MySQL Schema
--  Encoding: utf8mb4 (รองรับภาษาไทย)
-- ============================================================

CREATE DATABASE IF NOT EXISTS attendance_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE attendance_db;

-- ─── ไลน์การผลิต ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS production_lines (
  id          INT UNSIGNED    NOT NULL AUTO_INCREMENT,
  name        VARCHAR(100)    NOT NULL,
  description VARCHAR(255)    DEFAULT NULL,
  capacity    SMALLINT        NOT NULL DEFAULT 0,
  created_at  TIMESTAMP       NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_line_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── ประเภทอุปกรณ์ PPE ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS ppe_items (
  id       INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  name     VARCHAR(100)  NOT NULL COMMENT 'ชื่อ key ภาษาอังกฤษ',
  name_th  VARCHAR(100)  NOT NULL COMMENT 'ชื่อภาษาไทย',
  icon     VARCHAR(50)   NOT NULL DEFAULT 'shield',
  PRIMARY KEY (id),
  UNIQUE KEY uq_ppe_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── ข้อกำหนด PPE ต่อไลน์ ────────────────────────────────────
CREATE TABLE IF NOT EXISTS ppe_requirements (
  id           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  line_id      INT UNSIGNED  NOT NULL,
  ppe_item_id  INT UNSIGNED  NOT NULL,
  is_mandatory TINYINT(1)    NOT NULL DEFAULT 1 COMMENT '1=บังคับ, 0=แนะนำ',
  PRIMARY KEY (id),
  UNIQUE KEY uq_line_ppe (line_id, ppe_item_id),
  CONSTRAINT fk_req_line FOREIGN KEY (line_id)
    REFERENCES production_lines (id) ON DELETE CASCADE,
  CONSTRAINT fk_req_ppe  FOREIGN KEY (ppe_item_id)
    REFERENCES ppe_items (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── พนักงาน ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees (
  id           INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  employee_id  VARCHAR(20)   NOT NULL COMMENT 'รหัสพนักงาน',
  name         VARCHAR(100)  NOT NULL,
  position     VARCHAR(100)  DEFAULT NULL,
  line_id      INT UNSIGNED  NOT NULL,
  is_active    TINYINT(1)    NOT NULL DEFAULT 1,
  created_at   TIMESTAMP     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_employee_id (employee_id),
  KEY idx_line (line_id),
  KEY idx_active (is_active),
  CONSTRAINT fk_emp_line FOREIGN KEY (line_id)
    REFERENCES production_lines (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── บันทึกการเข้างานรายวัน ───────────────────────────────────
CREATE TABLE IF NOT EXISTS attendances (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  employee_id   INT UNSIGNED  NOT NULL,
  date          DATE          NOT NULL,
  check_in_time DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
  status        ENUM('present','late','absent') NOT NULL DEFAULT 'present',
  PRIMARY KEY (id),
  UNIQUE KEY uq_attendance (employee_id, date),
  KEY idx_date (date),
  KEY idx_emp_date (employee_id, date),
  CONSTRAINT fk_att_emp FOREIGN KEY (employee_id)
    REFERENCES employees (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ─── บันทึกการตรวจสอบ PPE ────────────────────────────────────
CREATE TABLE IF NOT EXISTS ppe_checks (
  id            INT UNSIGNED  NOT NULL AUTO_INCREMENT,
  attendance_id INT UNSIGNED  NOT NULL,
  ppe_item_id   INT UNSIGNED  NOT NULL,
  is_wearing    TINYINT(1)    NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  UNIQUE KEY uq_check (attendance_id, ppe_item_id),
  CONSTRAINT fk_chk_att FOREIGN KEY (attendance_id)
    REFERENCES attendances (id) ON DELETE CASCADE,
  CONSTRAINT fk_chk_ppe FOREIGN KEY (ppe_item_id)
    REFERENCES ppe_items (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ============================================================
--  Seed: ประเภทอุปกรณ์ PPE
-- ============================================================
INSERT INTO ppe_items (name, name_th, icon) VALUES
  ('safety_helmet',  'หมวกนิรภัย',             'hard-hat'),
  ('safety_glasses', 'แว่นตานิรภัย',           'glasses'),
  ('ear_protection', 'ที่ครอบหู/ที่อุดหู',      'ear'),
  ('safety_gloves',  'ถุงมือนิรภัย',            'hand'),
  ('safety_shoes',   'รองเท้านิรภัย',           'boot'),
  ('safety_vest',    'เสื้อกั๊กสะท้อนแสง',     'vest'),
  ('face_shield',    'หน้ากากป้องกันใบหน้า',    'face-shield'),
  ('respirator',     'หน้ากากกรองอากาศ',        'mask'),
  ('welding_mask',   'หน้ากากเชื่อม',           'welding'),
  ('apron',          'ผ้ากันเปื้อน',            'apron')
ON DUPLICATE KEY UPDATE name_th = VALUES(name_th);

-- ============================================================
--  Seed: ไลน์การผลิต
-- ============================================================
INSERT INTO production_lines (name, description, capacity) VALUES
  ('ไลน์ A - ประกอบชิ้นส่วน', 'สายการผลิตประกอบชิ้นส่วนหลัก', 20),
  ('ไลน์ B - เชื่อมโลหะ',     'สายการผลิตงานเชื่อม',            15),
  ('ไลน์ C - พ่นสี',          'สายการผลิตงานพ่นสีและเคลือบ',   10),
  ('ไลน์ D - บรรจุภัณฑ์',     'สายการผลิตบรรจุและจัดส่ง',      25),
  ('ไลน์ E - ตรวจสอบคุณภาพ', 'แผนก QC ตรวจสอบสินค้า',         8)
ON DUPLICATE KEY UPDATE description = VALUES(description);

-- ============================================================
--  Seed: ข้อกำหนด PPE ต่อไลน์
--  (อ้างอิง id ของ ppe_items ตาม INSERT ลำดับด้านบน)
-- ============================================================
INSERT INTO ppe_requirements (line_id, ppe_item_id, is_mandatory)
SELECT l.id, p.id, 1
FROM production_lines l, ppe_items p
WHERE
  -- ไลน์ A: หมวก, แว่น, ถุงมือ, รองเท้า, เสื้อกั๊ก
  (l.name LIKE '%ไลน์ A%' AND p.name IN (
    'safety_helmet','safety_glasses','safety_gloves','safety_shoes','safety_vest'))
  OR
  -- ไลน์ B: เพิ่ม ที่ครอบหู, หน้ากาก, หน้ากากเชื่อม
  (l.name LIKE '%ไลน์ B%' AND p.name IN (
    'safety_helmet','safety_glasses','ear_protection','safety_gloves',
    'safety_shoes','safety_vest','face_shield','welding_mask'))
  OR
  -- ไลน์ C: เพิ่ม respirator, ผ้ากันเปื้อน
  (l.name LIKE '%ไลน์ C%' AND p.name IN (
    'safety_helmet','safety_glasses','safety_shoes','safety_vest',
    'respirator','apron'))
  OR
  -- ไลน์ D: รองเท้า, เสื้อกั๊ก
  (l.name LIKE '%ไลน์ D%' AND p.name IN (
    'safety_shoes','safety_vest'))
  OR
  -- ไลน์ E: แว่น, ถุงมือ, รองเท้า, เสื้อกั๊ก
  (l.name LIKE '%ไลน์ E%' AND p.name IN (
    'safety_glasses','safety_gloves','safety_shoes','safety_vest'))
ON DUPLICATE KEY UPDATE is_mandatory = VALUES(is_mandatory);

-- ============================================================
--  Seed: พนักงานตัวอย่าง
-- ============================================================
INSERT INTO employees (employee_id, name, position, line_id)
SELECT emp.employee_id, emp.name, emp.position, l.id
FROM (
  SELECT 'EMP001' employee_id, 'สมชาย ใจดี'       name, 'ช่างประกอบ'  position, 'ไลน์ A%' line_like UNION ALL
  SELECT 'EMP002',             'สมหญิง มานะ',      'ช่างประกอบ',              'ไลน์ A%'  UNION ALL
  SELECT 'EMP003',             'วิชัย สุขใจ',      'หัวหน้าไลน์',             'ไลน์ A%'  UNION ALL
  SELECT 'EMP004',             'นิรันดร์ แข็งแรง', 'ช่างประกอบ',              'ไลน์ A%'  UNION ALL
  SELECT 'EMP005',             'พรทิพย์ รักงาน',   'ช่างประกอบ',              'ไลน์ A%'  UNION ALL
  SELECT 'EMP006',             'ประเสริฐ เชื่อมดี','ช่างเชื่อม',              'ไลน์ B%'  UNION ALL
  SELECT 'EMP007',             'สุรชัย ไฟแรง',     'ช่างเชื่อม',              'ไลน์ B%'  UNION ALL
  SELECT 'EMP008',             'มานพ มั่นคง',      'หัวหน้าไลน์',             'ไลน์ B%'  UNION ALL
  SELECT 'EMP009',             'อรุณี สีสวย',      'ช่างพ่นสี',               'ไลน์ C%'  UNION ALL
  SELECT 'EMP010',             'ธนกร ระวังดี',     'ช่างพ่นสี',               'ไลน์ C%'  UNION ALL
  SELECT 'EMP011',             'ลลิตา บรรจุดี',    'พนักงานบรรจุ',            'ไลน์ D%'  UNION ALL
  SELECT 'EMP012',             'สิทธิชัย รวดเร็ว', 'พนักงานบรรจุ',            'ไลน์ D%'  UNION ALL
  SELECT 'EMP013',             'กนกวรรณ พิถีพิถัน','พนักงาน QC',              'ไลน์ E%'  UNION ALL
  SELECT 'EMP014',             'ชัยวัฒน์ ตรวจสอบ', 'หัวหน้า QC',              'ไลน์ E%'  UNION ALL
  SELECT 'EMP015',             'นภาพร ละเอียด',    'พนักงาน QC',              'ไลน์ E%'
) emp
JOIN production_lines l ON l.name LIKE emp.line_like
ON DUPLICATE KEY UPDATE position = VALUES(position), line_id = VALUES(line_id);

-- ============================================================
--  Useful Views
-- ============================================================

CREATE OR REPLACE VIEW v_attendance_today AS
SELECT
  a.id,
  e.employee_id   AS employee_code,
  e.name          AS employee_name,
  e.position,
  l.name          AS line_name,
  a.date,
  a.check_in_time,
  a.status,
  -- PPE compliance: 1 ถ้าใส่ครบทุกชิ้นที่บังคับ
  CASE WHEN COUNT(r.id) = 0 THEN 1
       WHEN SUM(CASE WHEN r.is_mandatory = 1 AND (c.is_wearing IS NULL OR c.is_wearing = 0) THEN 1 ELSE 0 END) = 0
       THEN 1 ELSE 0 END AS ppe_compliant
FROM attendances a
JOIN employees        e ON e.id = a.employee_id
JOIN production_lines l ON l.id = e.line_id
LEFT JOIN ppe_requirements r ON r.line_id = e.line_id
LEFT JOIN ppe_checks       c ON c.attendance_id = a.id AND c.ppe_item_id = r.ppe_item_id
WHERE a.date = CURDATE()
GROUP BY a.id, e.employee_id, e.name, e.position, l.name, a.date, a.check_in_time, a.status;

CREATE OR REPLACE VIEW v_daily_line_summary AS
SELECT
  l.id            AS line_id,
  l.name          AS line_name,
  l.capacity,
  COUNT(DISTINCT e.id)                                AS total_employees,
  COUNT(DISTINCT a.id)                                AS present_count,
  COUNT(DISTINCT e.id) - COUNT(DISTINCT a.id)         AS absent_count,
  COALESCE(SUM(vt.ppe_compliant), 0)                  AS ppe_compliant_count,
  CURDATE()                                           AS report_date
FROM production_lines l
LEFT JOIN employees        e  ON e.line_id = l.id AND e.is_active = 1
LEFT JOIN attendances      a  ON a.employee_id = e.id AND a.date = CURDATE()
LEFT JOIN v_attendance_today vt ON vt.id = a.id
GROUP BY l.id, l.name, l.capacity;
