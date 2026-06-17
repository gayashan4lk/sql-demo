# Challenge 2 — Enrollment Pipeline

> **Attempt after completing:** Views, Stored Procedures, Triggers, Transactions

## Scenario

Build a complete enrollment system where a student can enroll in a course with capacity checks and payment processing — all in a single atomic transaction. If anything fails, nothing should change.

---

## Tasks

### Task 1: Create the Enrollment Procedure

Create a stored procedure `enroll_student(p_student_id INT, p_course_id INT, p_fee DECIMAL(10,2))` that does all of the following inside a single `TRANSACTION`:

1. **Check capacity** — count current `Active` enrollments for the course. If it equals `max_enrollment`, roll back with an error message
2. **Check duplicate** — verify the student is not already enrolled (any status). If they are, roll back
3. **Check funds** — verify the student's account balance is >= the fee. If not, roll back
4. **Deduct fee** — subtract the fee from `student_account.balance`
5. **Record payment** — insert a row into `payment` with type `'Tuition'`
6. **Create enrollment** — insert a row into `enrollment` with status `'Active'`
7. **COMMIT** if all steps succeed

If any step fails, the entire transaction must `ROLLBACK` — no partial state.

### Task 2: Create an Enrollment Count Trigger

Create a trigger (or a view) that makes it easy to see the current enrollment count for each course. Option A: a view called `course_enrollment_count`. Option B: a column on the course table maintained by triggers.

### Task 3: Create an Enrollment Dashboard View

Create a view called `enrollment_dashboard` showing:
- Course code, course name, department
- Current enrolled count (Active enrollments only)
- Remaining capacity (`max_enrollment - enrolled count`)

### Task 4: Test All Scenarios

1. **Success case** — enroll a student with sufficient funds in a course with capacity. Verify enrollment, payment, and balance all updated
2. **Full course** — try enrolling in a course at max capacity. Verify nothing changed
3. **Insufficient funds** — try enrolling a student with a low balance. Verify nothing changed
4. **Duplicate enrollment** — try enrolling a student in a course they are already in. Verify nothing changed

---

## Self-Assessment Checklist

- [ ] The procedure is wrapped in START TRANSACTION / COMMIT with ROLLBACK on failure
- [ ] Capacity check counts only Active enrollments
- [ ] Duplicate check catches any enrollment status (Active, Dropped, Completed)
- [ ] The fee is deducted from `student_account` and recorded in `payment`
- [ ] A failed enrollment leaves all tables unchanged (atomicity)
- [ ] The `enrollment_dashboard` view shows accurate current counts
- [ ] All four test scenarios produce the expected results
