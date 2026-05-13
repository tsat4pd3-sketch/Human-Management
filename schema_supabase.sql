-- ============================================================
--  Employee Attendance & PPE Dashboard — Supabase / PostgreSQL
--  วิธีใช้: เปิด Supabase Dashboard → SQL Editor → วางทั้งหมด → Run
-- ============================================================

-- ─── Extensions ──────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── ไลน์การผลิต ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS production_lines (
  id          SERIAL        PRIMARY KEY,
  name        VARCHAR(100)  NOT NULL UNIQUE,
  description VARCHAR(255),
  capacity    SMALLINT      NOT NULL DEFAULT 0,
  created_at  TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- ─── ประเภทอุปกรณ์ PPE ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS ppe_items (
  id       SERIAL       PRIMARY KEY,
  name     VARCHAR(100) NOT NULL UNIQUE,
  name_th  VARCHAR(100) NOT NULL,
  icon     VARCHAR(50)  NOT NULL DEFAULT 'shield'
);

-- ─── ข้อกำหนด PPE ต่อไลน์ ────────────────────────────────────
CREATE TABLE IF NOT EXISTS ppe_requirements (
  id           SERIAL      PRIMARY KEY,
  line_id      INT         NOT NULL REFERENCES production_lines(id) ON DELETE CASCADE,
  ppe_item_id  INT         NOT NULL REFERENCES ppe_items(id)        ON DELETE CASCADE,
  is_mandatory BOOLEAN     NOT NULL DEFAULT TRUE,
  UNIQUE (line_id, ppe_item_id)
);

-- ─── พนักงาน ──────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS employees (
  id           SERIAL       PRIMARY KEY,
  employee_id  VARCHAR(20)  NOT NULL UNIQUE,
  name         VARCHAR(100) NOT NULL,
  position     VARCHAR(100),
  line_id      INT          NOT NULL REFERENCES production_lines(id),
  is_active    BOOLEAN      NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_employees_line     ON employees(line_id);
CREATE INDEX IF NOT EXISTS idx_employees_active   ON employees(is_active);

-- ─── บันทึกการเข้างานรายวัน ───────────────────────────────────
CREATE TABLE IF NOT EXISTS attendances (
  id            SERIAL      PRIMARY KEY,
  employee_id   INT         NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
  date          DATE        NOT NULL DEFAULT CURRENT_DATE,
  check_in_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  status        VARCHAR(10) NOT NULL DEFAULT 'present'
                            CHECK (status IN ('present','late','absent')),
  UNIQUE (employee_id, date)
);
CREATE INDEX IF NOT EXISTS idx_att_date     ON attendances(date);
CREATE INDEX IF NOT EXISTS idx_att_emp_date ON attendances(employee_id, date);

-- ─── บันทึกการตรวจสอบ PPE ────────────────────────────────────
CREATE TABLE IF NOT EXISTS ppe_checks (
  id            SERIAL   PRIMARY KEY,
  attendance_id INT      NOT NULL REFERENCES attendances(id) ON DELETE CASCADE,
  ppe_item_id   INT      NOT NULL REFERENCES ppe_items(id),
  is_wearing    BOOLEAN  NOT NULL DEFAULT FALSE,
  UNIQUE (attendance_id, ppe_item_id)
);

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
ON CONFLICT (name) DO UPDATE SET name_th = EXCLUDED.name_th;

-- ============================================================
--  Seed: ไลน์การผลิต
-- ============================================================
INSERT INTO production_lines (name, description, capacity) VALUES
  ('ไลน์ A - ประกอบชิ้นส่วน', 'สายการผลิตประกอบชิ้นส่วนหลัก', 20),
  ('ไลน์ B - เชื่อมโลหะ',     'สายการผลิตงานเชื่อม',            15),
  ('ไลน์ C - พ่นสี',          'สายการผลิตงานพ่นสีและเคลือบ',   10),
  ('ไลน์ D - บรรจุภัณฑ์',     'สายการผลิตบรรจุและจัดส่ง',      25),
  ('ไลน์ E - ตรวจสอบคุณภาพ', 'แผนก QC ตรวจสอบสินค้า',         8)
ON CONFLICT (name) DO UPDATE SET description = EXCLUDED.description;

-- ============================================================
--  Seed: ข้อกำหนด PPE ต่อไลน์
-- ============================================================
INSERT INTO ppe_requirements (line_id, ppe_item_id, is_mandatory)
SELECT l.id, p.id, TRUE
FROM production_lines l, ppe_items p
WHERE
  (l.name LIKE '%ไลน์ A%' AND p.name IN (
    'safety_helmet','safety_glasses','safety_gloves','safety_shoes','safety_vest'))
  OR (l.name LIKE '%ไลน์ B%' AND p.name IN (
    'safety_helmet','safety_glasses','ear_protection','safety_gloves',
    'safety_shoes','safety_vest','face_shield','welding_mask'))
  OR (l.name LIKE '%ไลน์ C%' AND p.name IN (
    'safety_helmet','safety_glasses','safety_shoes','safety_vest','respirator','apron'))
  OR (l.name LIKE '%ไลน์ D%' AND p.name IN (
    'safety_shoes','safety_vest'))
  OR (l.name LIKE '%ไลน์ E%' AND p.name IN (
    'safety_glasses','safety_gloves','safety_shoes','safety_vest'))
ON CONFLICT (line_id, ppe_item_id) DO NOTHING;

-- ============================================================
--  Seed: พนักงานตัวอย่าง
-- ============================================================
INSERT INTO employees (employee_id, name, position, line_id)
SELECT v.employee_id, v.name, v.position, l.id
FROM (VALUES
  ('EMP001','สมชาย ใจดี',       'ช่างประกอบ',   'ไลน์ A%'),
  ('EMP002','สมหญิง มานะ',      'ช่างประกอบ',   'ไลน์ A%'),
  ('EMP003','วิชัย สุขใจ',      'หัวหน้าไลน์',  'ไลน์ A%'),
  ('EMP004','นิรันดร์ แข็งแรง', 'ช่างประกอบ',   'ไลน์ A%'),
  ('EMP005','พรทิพย์ รักงาน',   'ช่างประกอบ',   'ไลน์ A%'),
  ('EMP006','ประเสริฐ เชื่อมดี','ช่างเชื่อม',   'ไลน์ B%'),
  ('EMP007','สุรชัย ไฟแรง',     'ช่างเชื่อม',   'ไลน์ B%'),
  ('EMP008','มานพ มั่นคง',      'หัวหน้าไลน์',  'ไลน์ B%'),
  ('EMP009','อรุณี สีสวย',      'ช่างพ่นสี',    'ไลน์ C%'),
  ('EMP010','ธนกร ระวังดี',     'ช่างพ่นสี',    'ไลน์ C%'),
  ('EMP011','ลลิตา บรรจุดี',    'พนักงานบรรจุ', 'ไลน์ D%'),
  ('EMP012','สิทธิชัย รวดเร็ว', 'พนักงานบรรจุ', 'ไลน์ D%'),
  ('EMP013','กนกวรรณ พิถีพิถัน','พนักงาน QC',   'ไลน์ E%'),
  ('EMP014','ชัยวัฒน์ ตรวจสอบ', 'หัวหน้า QC',   'ไลน์ E%'),
  ('EMP015','นภาพร ละเอียด',    'พนักงาน QC',   'ไลน์ E%')
) AS v(employee_id, name, position, line_like)
JOIN production_lines l ON l.name LIKE v.line_like
ON CONFLICT (employee_id) DO UPDATE
  SET position = EXCLUDED.position, line_id = EXCLUDED.line_id;

-- ============================================================
--  View: สรุปการเข้างานวันนี้
-- ============================================================
CREATE OR REPLACE VIEW v_attendance_today AS
SELECT
  a.id,
  e.employee_id                        AS employee_code,
  e.name                               AS employee_name,
  e.position,
  l.name                               AS line_name,
  a.date,
  a.check_in_time,
  a.status,
  CASE
    WHEN COUNT(r.id) = 0 THEN TRUE
    WHEN SUM(CASE WHEN r.is_mandatory AND NOT COALESCE(c.is_wearing, FALSE) THEN 1 ELSE 0 END) = 0
    THEN TRUE ELSE FALSE
  END AS ppe_compliant
FROM attendances a
JOIN employees        e ON e.id = a.employee_id
JOIN production_lines l ON l.id = e.line_id
LEFT JOIN ppe_requirements r ON r.line_id = e.line_id
LEFT JOIN ppe_checks       c ON c.attendance_id = a.id AND c.ppe_item_id = r.ppe_item_id
WHERE a.date = CURRENT_DATE
GROUP BY a.id, e.employee_id, e.name, e.position, l.name, a.date, a.check_in_time, a.status;

-- ============================================================
--  View: สรุปแต่ละไลน์การผลิตวันนี้
-- ============================================================
CREATE OR REPLACE VIEW v_daily_line_summary AS
SELECT
  l.id                                      AS line_id,
  l.name                                    AS line_name,
  l.capacity,
  COUNT(DISTINCT e.id)                      AS total_employees,
  COUNT(DISTINCT a.id)                      AS present_count,
  COUNT(DISTINCT e.id) - COUNT(DISTINCT a.id) AS absent_count,
  COALESCE(SUM(CASE WHEN vt.ppe_compliant THEN 1 ELSE 0 END), 0) AS ppe_compliant_count,
  CURRENT_DATE                              AS report_date
FROM production_lines l
LEFT JOIN employees         e  ON e.line_id = l.id AND e.is_active
LEFT JOIN attendances        a  ON a.employee_id = e.id AND a.date = CURRENT_DATE
LEFT JOIN v_attendance_today vt ON vt.id = a.id
GROUP BY l.id, l.name, l.capacity;

-- ============================================================
--  Row Level Security (RLS) — เปิดใช้ถ้าต้องการ
--  (ปิดไว้ก่อนสำหรับ backend access ผ่าน service_role key)
-- ============================================================
-- ALTER TABLE production_lines ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE employees        ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE attendances      ENABLE ROW LEVEL SECURITY;
-- ALTER TABLE ppe_checks       ENABLE ROW LEVEL SECURITY;
