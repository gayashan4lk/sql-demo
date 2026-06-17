# Challenge 3 — University Admin Dashboard (Capstone)

> **Attempt after completing:** All lessons (Views through Concurrency)

## Scenario

Build the database backend for a university admin dashboard. This capstone ties together every concept you have learned: views, stored procedures, triggers, indexing, transactions, and concurrency.

---

## Tasks

### Task 1: Views Layer

Create these views:

1. **`v_student_transcript`** — student name, course code, course name, letter grade, numeric grade, credits. Include only completed enrollments that have a grade.

2. **`v_department_summary`** — department name, number of courses, total enrolled students (Active only), average numeric grade across all graded enrollments in that department.

3. **`v_at_risk_students`** — student name, email, course code, letter grade. Show only students who received a `D` or `F` in any course.

### Task 2: Stored Procedures

1. **`sp_calculate_gpa(p_student_id INT)`** — calculate and return a student's GPA as a DECIMAL. Use this scale: A=4.0, B=3.0, C=2.0, D=1.0, F=0.0. Weight by credits.

2. **`sp_generate_grade_report(p_course_id INT)`** — return all students enrolled in the course with their letter grade, numeric grade, and status. Include students who have not been graded yet (show `NULL` for grade).

### Task 3: Triggers

Create a trigger that fires when a grade is inserted or updated. If the student's GPA (calculated using your `sp_calculate_gpa` logic) drops below 2.0, insert a row into a new `probation_alert` table:

```sql
CREATE TABLE probation_alert (
    alert_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    gpa DECIMAL(3,2) NOT NULL,
    alert_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (student_id) REFERENCES student(student_id)
);
```

### Task 4: Indexing

1. Identify which columns are queried most in your views and procedures
2. Add indexes to those columns
3. Use `EXPLAIN` on at least 3 of your queries to show the difference before and after indexing
4. Document which indexes helped and which did not

### Task 5: End-of-Semester Transaction

Create a procedure `sp_end_of_semester(p_course_id INT)` that:
1. Checks that every `Active` enrollment for the course has a grade recorded — if any are missing, ROLLBACK with an error
2. Marks all `Active` enrollments for the course as `Completed`
3. Logs the action to `audit_log` (one row per updated enrollment)
4. COMMITs only if all steps succeed

### Task 6: Concurrency Experiment

1. Open two MySQL client sessions
2. In both sessions, start a transaction
3. Have both try to run `sp_end_of_semester` for the same course simultaneously
4. Document what happens: Do both succeed? Does one block? Is there a deadlock?
5. Explain how you would fix or prevent the issue you observed

---

## Self-Assessment Checklist

- [ ] `v_student_transcript` correctly joins student, enrollment, course, and grade
- [ ] `v_department_summary` aggregates across departments with accurate counts and averages
- [ ] `v_at_risk_students` shows only D and F grades
- [ ] `sp_calculate_gpa` correctly weights by credits
- [ ] `sp_generate_grade_report` includes students without grades (LEFT JOIN)
- [ ] The probation trigger fires on both INSERT and UPDATE of grades
- [ ] The probation trigger correctly calculates GPA and only alerts below 2.0
- [ ] At least 3 EXPLAIN outputs show the impact of your indexes
- [ ] `sp_end_of_semester` rejects if any Active enrollment is ungraded
- [ ] `sp_end_of_semester` is fully transactional (all or nothing)
- [ ] The concurrency experiment is documented with observations
- [ ] You can explain what locking strategy would prevent the concurrency issue
