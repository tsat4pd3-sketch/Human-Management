"""Run this script to add demo attendance data for testing the dashboard."""
import random
from datetime import date, datetime, timedelta
from app import app, db, seed_data, Employee, Attendance, PPECheck, PPERequirement


def seed_demo_attendance(days=7):
    with app.app_context():
        db.create_all()
        seed_data()

        employees = Employee.query.filter_by(is_active=True).all()
        today = date.today()

        for offset in range(days - 1, -1, -1):
            target_date = today - timedelta(days=offset)
            for emp in employees:
                if random.random() < 0.15:  # 15% absent
                    continue

                if Attendance.query.filter_by(employee_id=emp.id, date=target_date).first():
                    continue

                hour = random.randint(7, 9)
                minute = random.randint(0, 59)
                check_time = datetime(target_date.year, target_date.month, target_date.day, hour, minute)

                att = Attendance(
                    employee_id=emp.id,
                    date=target_date,
                    check_in_time=check_time,
                    status='late' if hour >= 8 else 'present',
                )
                db.session.add(att)
                db.session.flush()

                reqs = PPERequirement.query.filter_by(line_id=emp.line_id).all()
                for req in reqs:
                    wearing = random.random() > 0.1  # 10% chance missing PPE
                    chk = PPECheck(
                        attendance_id=att.id,
                        ppe_item_id=req.ppe_item_id,
                        is_wearing=wearing,
                    )
                    db.session.add(chk)

        db.session.commit()
        total = Attendance.query.count()
        print(f"Demo attendance seeded: {total} records across {days} days.")


if __name__ == '__main__':
    seed_demo_attendance(days=7)
