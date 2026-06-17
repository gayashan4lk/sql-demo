# Challenge 1 — Student Audit Trail

> **Attempt after completing:** Views, Stored Procedures, Triggers

## Scenario

The registrar's office needs to track every change to student records. Your job is to build an audit system that combines views for easy data access, a stored procedure for safe updates, and a trigger for automatic logging.

---

## Tasks

### Task 1: Create a Student Overview View

Create a view called `student_overview` that joins `student`, `enrollment`, and `course` to show:
- Student name and email
- Course code and course name
- Enrollment status

This view should show one row per enrollment (a student with 3 courses should appear 3 times).

### Task 2: Create an Email Update Procedure

Create a stored procedure `update_student_email(p_student_id INT, p_new_email VARCHAR(150))` that:
- Validates the new email contains `'@'` (reject if not)
- Checks that the student exists (reject if not)
- Updates the student's email

### Task 3: Create an Audit Trigger

Create a trigger `trg_student_email_audit` that fires `AFTER UPDATE` on the `student` table and:
- Checks if the `email` column actually changed
- If it did, inserts a row into `audit_log` with the old and new email values

### Task 4: Test the Full Pipeline

1. Call your procedure to update a student's email
2. Query `student_overview` to confirm the new email appears
3. Query `audit_log` to confirm the change was logged
4. Try calling the procedure with an invalid email (no `@`) and confirm it is rejected

---

## Self-Assessment Checklist

- [ ] The `student_overview` view correctly joins all three tables
- [ ] The procedure rejects emails without `@`
- [ ] The procedure rejects non-existent student IDs
- [ ] The trigger captures both old and new email values
- [ ] The trigger only fires when the email actually changes (not on every UPDATE)
- [ ] The audit log shows who made the change and when
- [ ] All three components work together end-to-end
