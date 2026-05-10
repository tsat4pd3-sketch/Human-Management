from flask import Flask, render_template, request, jsonify, redirect, url_for, flash
from flask_sqlalchemy import SQLAlchemy
from datetime import date, datetime
import json
import os

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///attendance.db'
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False
app.config['SECRET_KEY'] = 'ppe-attendance-secret-key-2024'

db = SQLAlchemy(app)


# ─── Models ──────────────────────────────────────────────────────────────────

class ProductionLine(db.Model):
    __tablename__ = 'production_lines'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    description = db.Column(db.String(255))
    capacity = db.Column(db.Integer, default=0)
    employees = db.relationship('Employee', backref='line', lazy=True)
    ppe_requirements = db.relationship('PPERequirement', backref='line', lazy=True)

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'description': self.description,
            'capacity': self.capacity,
        }


class PPEItem(db.Model):
    __tablename__ = 'ppe_items'
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False, unique=True)
    name_th = db.Column(db.String(100), nullable=False)
    icon = db.Column(db.String(50), default='shield')

    def to_dict(self):
        return {'id': self.id, 'name': self.name, 'name_th': self.name_th, 'icon': self.icon}


class PPERequirement(db.Model):
    __tablename__ = 'ppe_requirements'
    id = db.Column(db.Integer, primary_key=True)
    line_id = db.Column(db.Integer, db.ForeignKey('production_lines.id'), nullable=False)
    ppe_item_id = db.Column(db.Integer, db.ForeignKey('ppe_items.id'), nullable=False)
    is_mandatory = db.Column(db.Boolean, default=True)
    ppe_item = db.relationship('PPEItem')

    def to_dict(self):
        return {
            'id': self.id,
            'line_id': self.line_id,
            'ppe_item_id': self.ppe_item_id,
            'ppe_name': self.ppe_item.name_th,
            'ppe_icon': self.ppe_item.icon,
            'is_mandatory': self.is_mandatory,
        }


class Employee(db.Model):
    __tablename__ = 'employees'
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.String(20), nullable=False, unique=True)
    name = db.Column(db.String(100), nullable=False)
    position = db.Column(db.String(100))
    line_id = db.Column(db.Integer, db.ForeignKey('production_lines.id'), nullable=False)
    is_active = db.Column(db.Boolean, default=True)
    attendances = db.relationship('Attendance', backref='employee', lazy=True)

    def to_dict(self):
        return {
            'id': self.id,
            'employee_id': self.employee_id,
            'name': self.name,
            'position': self.position,
            'line_id': self.line_id,
            'line_name': self.line.name if self.line else '',
            'is_active': self.is_active,
        }


class Attendance(db.Model):
    __tablename__ = 'attendances'
    id = db.Column(db.Integer, primary_key=True)
    employee_id = db.Column(db.Integer, db.ForeignKey('employees.id'), nullable=False)
    date = db.Column(db.Date, nullable=False, default=date.today)
    check_in_time = db.Column(db.DateTime, default=datetime.now)
    status = db.Column(db.String(20), default='present')  # present, absent, late
    ppe_checks = db.relationship('PPECheck', backref='attendance', lazy=True)

    __table_args__ = (db.UniqueConstraint('employee_id', 'date', name='unique_attendance'),)

    def ppe_compliant(self):
        line_reqs = PPERequirement.query.filter_by(
            line_id=self.employee.line_id, is_mandatory=True
        ).all()
        if not line_reqs:
            return True
        checked_ids = {c.ppe_item_id for c in self.ppe_checks if c.is_wearing}
        required_ids = {r.ppe_item_id for r in line_reqs}
        return required_ids.issubset(checked_ids)

    def to_dict(self):
        return {
            'id': self.id,
            'employee_id': self.employee_id,
            'employee_name': self.employee.name if self.employee else '',
            'employee_code': self.employee.employee_id if self.employee else '',
            'line_name': self.employee.line.name if self.employee and self.employee.line else '',
            'date': self.date.isoformat(),
            'check_in_time': self.check_in_time.strftime('%H:%M') if self.check_in_time else '',
            'status': self.status,
            'ppe_compliant': self.ppe_compliant(),
        }


class PPECheck(db.Model):
    __tablename__ = 'ppe_checks'
    id = db.Column(db.Integer, primary_key=True)
    attendance_id = db.Column(db.Integer, db.ForeignKey('attendances.id'), nullable=False)
    ppe_item_id = db.Column(db.Integer, db.ForeignKey('ppe_items.id'), nullable=False)
    is_wearing = db.Column(db.Boolean, default=False)
    ppe_item = db.relationship('PPEItem')


# ─── Page Routes ─────────────────────────────────────────────────────────────

@app.route('/')
def dashboard():
    return render_template('dashboard.html')

@app.route('/checkin')
def checkin():
    return render_template('checkin.html')

@app.route('/employees')
def employees():
    return render_template('employees.html')

@app.route('/ppe-management')
def ppe_management():
    return render_template('ppe_management.html')

@app.route('/report')
def report():
    return render_template('report.html')


# ─── API: Dashboard ──────────────────────────────────────────────────────────

@app.route('/api/dashboard/summary')
def api_dashboard_summary():
    target_date = request.args.get('date', date.today().isoformat())
    try:
        target_date = date.fromisoformat(target_date)
    except ValueError:
        target_date = date.today()

    lines = ProductionLine.query.all()
    summary = []
    total_present = 0
    total_ppe_ok = 0

    for line in lines:
        emp_ids = [e.id for e in line.employees if e.is_active]
        total_emp = len(emp_ids)
        att_records = Attendance.query.filter(
            Attendance.employee_id.in_(emp_ids),
            Attendance.date == target_date
        ).all() if emp_ids else []

        present_count = len(att_records)
        ppe_ok = sum(1 for a in att_records if a.ppe_compliant())

        total_present += present_count
        total_ppe_ok += ppe_ok

        summary.append({
            'line_id': line.id,
            'line_name': line.name,
            'total_employees': total_emp,
            'present': present_count,
            'absent': total_emp - present_count,
            'ppe_compliant': ppe_ok,
            'ppe_non_compliant': present_count - ppe_ok,
            'attendance_rate': round(present_count / total_emp * 100, 1) if total_emp > 0 else 0,
        })

    total_employees = sum(s['total_employees'] for s in summary)
    return jsonify({
        'date': target_date.isoformat(),
        'total_employees': total_employees,
        'total_present': total_present,
        'total_absent': total_employees - total_present,
        'total_ppe_compliant': total_ppe_ok,
        'lines': summary,
    })


@app.route('/api/dashboard/recent-checkins')
def api_recent_checkins():
    target_date = request.args.get('date', date.today().isoformat())
    try:
        target_date = date.fromisoformat(target_date)
    except ValueError:
        target_date = date.today()

    records = (
        Attendance.query
        .filter(Attendance.date == target_date)
        .order_by(Attendance.check_in_time.desc())
        .limit(20)
        .all()
    )
    return jsonify([r.to_dict() for r in records])


@app.route('/api/dashboard/weekly-trend')
def api_weekly_trend():
    from datetime import timedelta
    today = date.today()
    result = []
    for i in range(6, -1, -1):
        d = today - timedelta(days=i)
        count = Attendance.query.filter(Attendance.date == d).count()
        result.append({'date': d.isoformat(), 'count': count})
    return jsonify(result)


# ─── API: Check-in ────────────────────────────────────────────────────────────

@app.route('/api/checkin', methods=['POST'])
def api_checkin():
    data = request.get_json()
    emp_code = data.get('employee_code', '').strip()

    emp = Employee.query.filter_by(employee_id=emp_code, is_active=True).first()
    if not emp:
        return jsonify({'success': False, 'message': 'ไม่พบรหัสพนักงาน'}), 404

    today = date.today()
    existing = Attendance.query.filter_by(employee_id=emp.id, date=today).first()
    if existing:
        return jsonify({'success': False, 'message': f'{emp.name} เช็คชื่อแล้วในวันนี้'}), 409

    # Validate mandatory PPE
    line_reqs = PPERequirement.query.filter_by(line_id=emp.line_id, is_mandatory=True).all()
    ppe_data = data.get('ppe_checks', {})
    missing_ppe = []
    for req in line_reqs:
        if not ppe_data.get(str(req.ppe_item_id), False):
            missing_ppe.append(req.ppe_item.name_th)

    att = Attendance(
        employee_id=emp.id,
        date=today,
        check_in_time=datetime.now(),
        status='present',
    )
    db.session.add(att)
    db.session.flush()

    for req in PPERequirement.query.filter_by(line_id=emp.line_id).all():
        chk = PPECheck(
            attendance_id=att.id,
            ppe_item_id=req.ppe_item_id,
            is_wearing=bool(ppe_data.get(str(req.ppe_item_id), False)),
        )
        db.session.add(chk)

    db.session.commit()

    return jsonify({
        'success': True,
        'message': f'เช็คชื่อสำเร็จ: {emp.name}',
        'employee': emp.to_dict(),
        'ppe_compliant': len(missing_ppe) == 0,
        'missing_ppe': missing_ppe,
    })


@app.route('/api/employee/lookup')
def api_employee_lookup():
    code = request.args.get('code', '').strip()
    emp = Employee.query.filter_by(employee_id=code, is_active=True).first()
    if not emp:
        return jsonify({'found': False}), 404

    reqs = PPERequirement.query.filter_by(line_id=emp.line_id).all()
    today = date.today()
    already_checked = Attendance.query.filter_by(employee_id=emp.id, date=today).first() is not None

    return jsonify({
        'found': True,
        'employee': emp.to_dict(),
        'ppe_requirements': [r.to_dict() for r in reqs],
        'already_checked_in': already_checked,
    })


# ─── API: Employees ───────────────────────────────────────────────────────────

@app.route('/api/employees', methods=['GET'])
def api_list_employees():
    emps = Employee.query.all()
    return jsonify([e.to_dict() for e in emps])


@app.route('/api/employees', methods=['POST'])
def api_create_employee():
    data = request.get_json()
    if Employee.query.filter_by(employee_id=data['employee_id']).first():
        return jsonify({'success': False, 'message': 'รหัสพนักงานซ้ำ'}), 409
    emp = Employee(
        employee_id=data['employee_id'],
        name=data['name'],
        position=data.get('position', ''),
        line_id=int(data['line_id']),
        is_active=True,
    )
    db.session.add(emp)
    db.session.commit()
    return jsonify({'success': True, 'employee': emp.to_dict()})


@app.route('/api/employees/<int:emp_id>', methods=['PUT'])
def api_update_employee(emp_id):
    emp = Employee.query.get_or_404(emp_id)
    data = request.get_json()
    emp.name = data.get('name', emp.name)
    emp.position = data.get('position', emp.position)
    emp.line_id = int(data.get('line_id', emp.line_id))
    emp.is_active = data.get('is_active', emp.is_active)
    db.session.commit()
    return jsonify({'success': True, 'employee': emp.to_dict()})


@app.route('/api/employees/<int:emp_id>', methods=['DELETE'])
def api_delete_employee(emp_id):
    emp = Employee.query.get_or_404(emp_id)
    emp.is_active = False
    db.session.commit()
    return jsonify({'success': True})


# ─── API: Production Lines ────────────────────────────────────────────────────

@app.route('/api/lines', methods=['GET'])
def api_list_lines():
    lines = ProductionLine.query.all()
    return jsonify([l.to_dict() for l in lines])


@app.route('/api/lines', methods=['POST'])
def api_create_line():
    data = request.get_json()
    line = ProductionLine(
        name=data['name'],
        description=data.get('description', ''),
        capacity=int(data.get('capacity', 0)),
    )
    db.session.add(line)
    db.session.commit()
    return jsonify({'success': True, 'line': line.to_dict()})


@app.route('/api/lines/<int:line_id>', methods=['PUT'])
def api_update_line(line_id):
    line = ProductionLine.query.get_or_404(line_id)
    data = request.get_json()
    line.name = data.get('name', line.name)
    line.description = data.get('description', line.description)
    line.capacity = int(data.get('capacity', line.capacity))
    db.session.commit()
    return jsonify({'success': True, 'line': line.to_dict()})


# ─── API: PPE ─────────────────────────────────────────────────────────────────

@app.route('/api/ppe-items', methods=['GET'])
def api_list_ppe():
    items = PPEItem.query.all()
    return jsonify([i.to_dict() for i in items])


@app.route('/api/ppe-requirements/<int:line_id>', methods=['GET'])
def api_line_ppe_requirements(line_id):
    reqs = PPERequirement.query.filter_by(line_id=line_id).all()
    return jsonify([r.to_dict() for r in reqs])


@app.route('/api/ppe-requirements', methods=['POST'])
def api_save_ppe_requirements():
    data = request.get_json()
    line_id = data['line_id']
    items = data['items']  # [{ppe_item_id, is_mandatory}, ...]

    PPERequirement.query.filter_by(line_id=line_id).delete()
    for item in items:
        req = PPERequirement(
            line_id=line_id,
            ppe_item_id=item['ppe_item_id'],
            is_mandatory=item.get('is_mandatory', True),
        )
        db.session.add(req)
    db.session.commit()
    return jsonify({'success': True})


# ─── API: Reports ─────────────────────────────────────────────────────────────

@app.route('/api/report/attendance')
def api_report_attendance():
    from datetime import timedelta
    start_str = request.args.get('start')
    end_str = request.args.get('end')
    line_id = request.args.get('line_id')

    try:
        start = date.fromisoformat(start_str) if start_str else date.today()
        end = date.fromisoformat(end_str) if end_str else date.today()
    except ValueError:
        start = end = date.today()

    query = Attendance.query.filter(Attendance.date >= start, Attendance.date <= end)
    if line_id:
        emp_ids = [e.id for e in Employee.query.filter_by(line_id=int(line_id)).all()]
        query = query.filter(Attendance.employee_id.in_(emp_ids))

    records = query.order_by(Attendance.date.desc(), Attendance.check_in_time.desc()).all()
    return jsonify([r.to_dict() for r in records])


# ─── Seed Data ────────────────────────────────────────────────────────────────

def seed_data():
    if ProductionLine.query.count() > 0:
        return

    lines_data = [
        {'name': 'ไลน์ A - ประกอบชิ้นส่วน', 'description': 'สายการผลิตประกอบชิ้นส่วนหลัก', 'capacity': 20},
        {'name': 'ไลน์ B - เชื่อมโลหะ', 'description': 'สายการผลิตงานเชื่อม', 'capacity': 15},
        {'name': 'ไลน์ C - พ่นสี', 'description': 'สายการผลิตงานพ่นสีและเคลือบ', 'capacity': 10},
        {'name': 'ไลน์ D - บรรจุภัณฑ์', 'description': 'สายการผลิตบรรจุและจัดส่ง', 'capacity': 25},
        {'name': 'ไลน์ E - ตรวจสอบคุณภาพ', 'description': 'แผนก QC ตรวจสอบสินค้า', 'capacity': 8},
    ]
    lines = []
    for ld in lines_data:
        l = ProductionLine(**ld)
        db.session.add(l)
        lines.append(l)

    ppe_data = [
        {'name': 'safety_helmet', 'name_th': 'หมวกนิรภัย', 'icon': 'hard-hat'},
        {'name': 'safety_glasses', 'name_th': 'แว่นตานิรภัย', 'icon': 'glasses'},
        {'name': 'ear_protection', 'name_th': 'ที่ครอบหู/ที่อุดหู', 'icon': 'ear'},
        {'name': 'safety_gloves', 'name_th': 'ถุงมือนิรภัย', 'icon': 'hand'},
        {'name': 'safety_shoes', 'name_th': 'รองเท้านิรภัย', 'icon': 'boot'},
        {'name': 'safety_vest', 'name_th': 'เสื้อกั๊กสะท้อนแสง', 'icon': 'vest'},
        {'name': 'face_shield', 'name_th': 'หน้ากากป้องกันใบหน้า', 'icon': 'face-shield'},
        {'name': 'respirator', 'name_th': 'หน้ากากกรองอากาศ', 'icon': 'mask'},
        {'name': 'welding_mask', 'name_th': 'หน้ากากเชื่อม', 'icon': 'welding'},
        {'name': 'apron', 'name_th': 'ผ้ากันเปื้อน', 'icon': 'apron'},
    ]
    ppe_items = []
    for pd_item in ppe_data:
        p = PPEItem(**pd_item)
        db.session.add(p)
        ppe_items.append(p)

    db.session.flush()

    # PPE requirements per line
    line_ppe_map = {
        0: [0, 1, 3, 4, 5],        # Line A: helmet, glasses, gloves, shoes, vest
        1: [0, 1, 2, 3, 4, 5, 6, 8],  # Line B: + face shield, welding mask
        2: [0, 1, 4, 5, 7, 9],     # Line C: + respirator, apron
        3: [4, 5],                  # Line D: shoes, vest
        4: [1, 3, 4, 5],            # Line E: glasses, gloves, shoes, vest
    }
    for li, ppe_indices in line_ppe_map.items():
        for pi in ppe_indices:
            req = PPERequirement(line_id=lines[li].id, ppe_item_id=ppe_items[pi].id, is_mandatory=True)
            db.session.add(req)

    # Sample employees
    emp_data = [
        ('EMP001', 'สมชาย ใจดี', 'ช่างประกอบ', 0),
        ('EMP002', 'สมหญิง มานะ', 'ช่างประกอบ', 0),
        ('EMP003', 'วิชัย สุขใจ', 'หัวหน้าไลน์', 0),
        ('EMP004', 'นิรันดร์ แข็งแรง', 'ช่างประกอบ', 0),
        ('EMP005', 'พรทิพย์ รักงาน', 'ช่างประกอบ', 0),
        ('EMP006', 'ประเสริฐ เชื่อมดี', 'ช่างเชื่อม', 1),
        ('EMP007', 'สุรชัย ไฟแรง', 'ช่างเชื่อม', 1),
        ('EMP008', 'มานพ มั่นคง', 'หัวหน้าไลน์', 1),
        ('EMP009', 'อรุณี สีสวย', 'ช่างพ่นสี', 2),
        ('EMP010', 'ธนกร ระวังดี', 'ช่างพ่นสี', 2),
        ('EMP011', 'ลลิตา บรรจุดี', 'พนักงานบรรจุ', 3),
        ('EMP012', 'สิทธิชัย รวดเร็ว', 'พนักงานบรรจุ', 3),
        ('EMP013', 'กนกวรรณ พิถีพิถัน', 'พนักงาน QC', 4),
        ('EMP014', 'ชัยวัฒน์ ตรวจสอบ', 'หัวหน้า QC', 4),
        ('EMP015', 'นภาพร ละเอียด', 'พนักงาน QC', 4),
    ]
    for code, name, pos, li in emp_data:
        emp = Employee(employee_id=code, name=name, position=pos, line_id=lines[li].id)
        db.session.add(emp)

    db.session.commit()
    print("Seed data created successfully.")


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
        seed_data()
    app.run(debug=True, port=5000)
