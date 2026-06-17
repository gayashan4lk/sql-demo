# SQL Stored Procedures Lesson

> **Prerequisites:** You should be comfortable with `SELECT`, `INSERT`, `UPDATE`, `DELETE`, basic JOINs, and have completed the [Views](../01-views/lesson.md) and [Updatable Views](../02-updatable-views/lesson.md) lessons.

## Learning Objectives

By the end of this lesson you will be able to:

- Create and call a basic stored procedure
- Use `IN` parameters to pass values into a procedure
- Use `OUT` parameters to return values from a procedure
- Declare and use local variables with `DECLARE` and `SET`
- Write conditional logic with `IF...ELSEIF...ELSE...END IF`
- Query multiple tables (JOINs) inside a procedure
- Handle errors with `SIGNAL SQLSTATE`
- Explain the role of `DELIMITER` when defining procedures

---

## Why This Matters

A university registrar does not type raw SQL every time they need to enroll a student or look up a course roster. Instead, someone builds a **stored procedure** — a named, reusable block of SQL that lives inside the database. The registrar calls `CALL enroll_student(5, 3)` and the procedure handles the validation, the INSERT, and any error messages.

Stored procedures keep the logic in the database where it is **consistent no matter which application connects** — a web app, a command-line tool, or a scheduled job all call the same procedure and get the same behavior. They also **reduce network traffic** (one `CALL` instead of multiple round trips) and **centralize business rules** so they cannot be bypassed by a client application.

---

## What is a Stored Procedure?

A stored procedure is a **named block of SQL statements** saved inside the database. Unlike a view (which saves a single `SELECT`), a procedure can contain `INSERT`, `UPDATE`, `DELETE`, variables, conditionals, and error handling. You define it once and call it by name.

---

## About DELIMITER

Before we write any procedures, you need to understand `DELIMITER`. The MySQL client uses `;` to know when a statement ends. But a procedure body contains many `;` inside it. If you do not change the delimiter, MySQL will think the procedure ends at the first `;` inside the body.

The fix: temporarily change the delimiter to something else (like `$$`), write the full procedure, then change it back.

```sql
-- Without DELIMITER change — this BREAKS:
CREATE PROCEDURE broken_example()
BEGIN
    SELECT 1;    -- MySQL thinks the statement ends here!
    SELECT 2;
END;

-- With DELIMITER change — this WORKS:
DELIMITER $$

CREATE PROCEDURE working_example()
BEGIN
    SELECT 1;    -- Fine — $$ is the terminator now, not ;
    SELECT 2;
END $$

DELIMITER ;
```

Every procedure example in this lesson uses this pattern. You will get used to it quickly.

---

## New Tables in This Lesson

This lesson introduces two new tables from the university schema. Run `schema/reset.sql` to create them.

- **`course`** — course catalog (course_code, course_name, credits, department, max_enrollment)
- **`enrollment`** — links students to courses (student_id, course_id, enrolled_date, status)

---

## 1. Basic Procedure (No Parameters)

The simplest procedure wraps a `SELECT` statement. No inputs, no outputs — just a reusable query.

```sql
DROP PROCEDURE IF EXISTS get_all_courses;

DELIMITER $$

CREATE PROCEDURE get_all_courses()
BEGIN
    SELECT course_id, course_code, course_name, department
    FROM course
    ORDER BY department, course_code;
END $$

DELIMITER ;
```

Call it like this:

```sql
CALL get_all_courses();
```

Every time you `CALL get_all_courses()`, MySQL runs the SELECT inside the body and returns the result set.

---

## 2. IN Parameters — Passing Values In

An `IN` parameter lets the caller pass a value into the procedure. It is the default mode — if you omit `IN`/`OUT`, MySQL assumes `IN`.

```sql
DROP PROCEDURE IF EXISTS get_courses_by_department;

DELIMITER $$

CREATE PROCEDURE get_courses_by_department(IN p_department VARCHAR(100))
BEGIN
    SELECT course_code, course_name, credits
    FROM course
    WHERE department = p_department;
END $$

DELIMITER ;
```

```sql
CALL get_courses_by_department('Computer Science');
CALL get_courses_by_department('Mathematics');
```

**Naming convention:** prefix parameters with `p_` (like `p_department`) and local variables with `v_`. This avoids a common bug where a parameter has the same name as a column — MySQL silently resolves to the column, causing your `WHERE` clause to match every row or zero rows.

---

## 3. Multiple IN Parameters

Procedures can accept more than one input. This procedure JOINs `enrollment` and `course` to show a student's courses filtered by status.

```sql
DROP PROCEDURE IF EXISTS get_student_enrollments;

DELIMITER $$

CREATE PROCEDURE get_student_enrollments(
    IN p_student_id INT,
    IN p_status VARCHAR(20)
)
BEGIN
    SELECT c.course_code, c.course_name, e.enrolled_date, e.status
    FROM enrollment e
    JOIN course c ON e.course_id = c.course_id
    WHERE e.student_id = p_student_id
      AND e.status = p_status;
END $$

DELIMITER ;
```

```sql
-- Alice Johnson's completed courses
CALL get_student_enrollments(1, 'Completed');

-- Eva Martinez's active courses
CALL get_student_enrollments(5, 'Active');
```

---

## 4. OUT Parameters — Returning Values

An `OUT` parameter lets the procedure send a value back to the caller. The caller passes a **session variable** (prefixed with `@`) to receive the result.

```sql
DROP PROCEDURE IF EXISTS count_enrollments;

DELIMITER $$

CREATE PROCEDURE count_enrollments(
    IN p_course_id INT,
    OUT p_count INT
)
BEGIN
    SELECT COUNT(*) INTO p_count
    FROM enrollment
    WHERE course_id = p_course_id
      AND status = 'Active';
END $$

DELIMITER ;
```

```sql
CALL count_enrollments(1, @active_count);
SELECT @active_count AS active_enrollments;
-- Returns 4 (students 3, 5, 7, 10 are Active in CS101)
```

`SELECT ... INTO` assigns a query result to a variable instead of returning it as a result set.

---

## 5. Variables and SET

Local variables are declared with `DECLARE` inside the `BEGIN...END` block. You assign values with `SET` or `SELECT ... INTO`.

**Important rule:** all `DECLARE` statements must come **before** any executable statements (`SET`, `SELECT`, `IF`, etc.) inside a `BEGIN...END` block.

```sql
DROP PROCEDURE IF EXISTS get_course_availability;

DELIMITER $$

CREATE PROCEDURE get_course_availability(IN p_course_id INT)
BEGIN
    DECLARE v_course_name VARCHAR(150);
    DECLARE v_max INT;
    DECLARE v_current INT;
    DECLARE v_available INT;

    SELECT course_name, max_enrollment
    INTO v_course_name, v_max
    FROM course
    WHERE course_id = p_course_id;

    SELECT COUNT(*) INTO v_current
    FROM enrollment
    WHERE course_id = p_course_id
      AND status = 'Active';

    SET v_available = v_max - v_current;

    SELECT v_course_name AS course_name,
           v_max AS max_enrollment,
           v_current AS current_enrolled,
           v_available AS spots_available;
END $$

DELIMITER ;
```

```sql
CALL get_course_availability(1);
-- CS101: max=30, current=4, available=26

CALL get_course_availability(9);
-- Quantum Mechanics: max=20, current=1, available=19
```

---

## 6. IF / ELSEIF / ELSE — Conditional Logic

Procedures can branch based on conditions, just like `if/else` in any programming language.

```sql
DROP PROCEDURE IF EXISTS check_enrollment_status;

DELIMITER $$

CREATE PROCEDURE check_enrollment_status(
    IN p_student_id INT,
    IN p_course_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT status INTO v_status
    FROM enrollment
    WHERE student_id = p_student_id
      AND course_id = p_course_id;

    IF v_status IS NULL THEN
        SET p_message = 'Not enrolled';
    ELSEIF v_status = 'Active' THEN
        SET p_message = 'Currently enrolled';
    ELSEIF v_status = 'Completed' THEN
        SET p_message = 'Course completed';
    ELSEIF v_status = 'Dropped' THEN
        SET p_message = 'Enrollment dropped';
    ELSE
        SET p_message = 'Unknown status';
    END IF;
END $$

DELIMITER ;
```

```sql
-- Alice completed CS101
CALL check_enrollment_status(1, 1, @msg);
SELECT @msg;
-- Returns: 'Course completed'

-- Alice is not enrolled in PHY201 (course_id = 9)
CALL check_enrollment_status(1, 9, @msg);
SELECT @msg;
-- Returns: 'Not enrolled'
```

When `SELECT ... INTO` finds no matching row, the variable stays `NULL`. That is how we detect "not enrolled" — the `IF v_status IS NULL` check.

---

## 7. Error Handling with SIGNAL

`SIGNAL SQLSTATE '45000'` raises a custom error and immediately stops the procedure. Use it to reject invalid input before it causes damage.

This capstone procedure validates everything before enrolling a student:

```sql
DROP PROCEDURE IF EXISTS safe_enroll_student;

DELIMITER $$

CREATE PROCEDURE safe_enroll_student(
    IN p_student_id INT,
    IN p_course_id INT
)
BEGIN
    DECLARE v_student_exists INT;
    DECLARE v_course_exists INT;
    DECLARE v_already_enrolled INT;

    -- Check 1: Does the student exist?
    SELECT COUNT(*) INTO v_student_exists
    FROM student
    WHERE student_id = p_student_id;

    IF v_student_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student not found';
    END IF;

    -- Check 2: Does the course exist?
    SELECT COUNT(*) INTO v_course_exists
    FROM course
    WHERE course_id = p_course_id;

    IF v_course_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Course not found';
    END IF;

    -- Check 3: Is the student already enrolled?
    SELECT COUNT(*) INTO v_already_enrolled
    FROM enrollment
    WHERE student_id = p_student_id
      AND course_id = p_course_id;

    IF v_already_enrolled > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student is already enrolled in this course';
    END IF;

    -- All checks passed — enroll the student
    INSERT INTO enrollment (student_id, course_id)
    VALUES (p_student_id, p_course_id);

    SELECT 'Enrollment successful' AS result;
END $$

DELIMITER ;
```

```sql
-- Daniel Lee (4) is not in CS101 (1) — this should succeed
CALL safe_enroll_student(4, 1);

-- Try again — should fail (already enrolled)
CALL safe_enroll_student(4, 1);
-- ERROR 1644 (45000): Student is already enrolled in this course

-- Non-existent student — should fail
CALL safe_enroll_student(999, 1);
-- ERROR 1644 (45000): Student not found
```

This procedure combines every concept from the lesson: `IN` parameters, `DECLARE`, `SELECT ... INTO`, `IF`, `SIGNAL`, and `INSERT`.

---

## 8. Drop and Manage Procedures

```sql
-- Remove a procedure
DROP PROCEDURE IF EXISTS get_all_courses;

-- See all procedures in your database
SHOW PROCEDURE STATUS WHERE Db = 'sql_demo'\G

-- See the full definition of a procedure
SHOW CREATE PROCEDURE safe_enroll_student\G
```

The `\G` suffix formats the output vertically — easier to read for wide results. (This works in the mysql CLI client, not in all GUI tools.)

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Forgetting `DELIMITER` | Syntax error at the first `;` inside the procedure body | Always wrap: `DELIMITER $$` ... `END $$` then `DELIMITER ;` |
| Parameter named same as a column | `WHERE` clause silently matches wrong values (every row or zero rows) | Prefix parameters with `p_` and local variables with `v_` |
| `DECLARE` after an executable statement | MySQL error: "DECLARE is not allowed here" | All `DECLARE` statements must come first inside `BEGIN...END`, before any `SET`, `SELECT`, or `IF` |
| Using `SELECT` without `INTO` for assignment | Returns a result set to the caller instead of storing the value in a variable | Use `SELECT ... INTO v_variable` when you need to capture a value |
| Forgetting `DROP PROCEDURE IF EXISTS` before re-creating | MySQL error: "procedure already exists" | Always precede `CREATE PROCEDURE` with `DROP PROCEDURE IF EXISTS` during development |
| Wrong number of arguments in `CALL` | MySQL error: "incorrect number of arguments" | Match the exact parameter count and order from the procedure definition |

---

## When to Use / When NOT to Use

| Use Stored Procedures When... | Avoid Stored Procedures When... |
|-------------------------------|--------------------------------|
| You need multi-step logic (validate, then insert, then update) | The operation is a simple single-statement query (a view may be simpler) |
| Multiple applications need the same database logic | Your application handles all validation and you want logic in one place, not split between app and DB |
| You want to reduce network round trips (one `CALL` vs. many statements) | The logic changes very frequently — procedures are harder to version-control than application code |
| You need to enforce business rules at the database level regardless of which client connects | You need complex string manipulation, HTTP calls, or other logic better suited to an application language |
| You want to control access: grant `EXECUTE` on a procedure without giving direct table access | Debugging is critical — stored procedures are harder to step-through debug than application code |

---

## Quick Reference

| Statement | Purpose |
|---|---|
| `DELIMITER $$ ... END $$ DELIMITER ;` | Change and restore the statement terminator for procedure bodies |
| `CREATE PROCEDURE name(params) BEGIN...END` | Define a new stored procedure |
| `CALL name(args)` | Execute a stored procedure |
| `IN param_name TYPE` | Parameter passed into the procedure (read-only inside the body) |
| `OUT param_name TYPE` | Parameter set by the procedure, read by the caller via `@variable` |
| `DECLARE v_name TYPE` | Declare a local variable (must be first in `BEGIN...END`) |
| `SET v_name = value` | Assign a value to a local variable |
| `SELECT ... INTO v_name` | Assign a query result to a variable |
| `IF...THEN...ELSEIF...ELSE...END IF` | Conditional branching |
| `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'` | Raise a custom error to reject invalid operations |
| `DROP PROCEDURE IF EXISTS name` | Remove a procedure safely |
| `SHOW CREATE PROCEDURE name` | View the definition of an existing procedure |

---

## What's Next?

Next you will learn about **triggers** — procedures that fire automatically when data changes. A trigger can run `BEFORE` or `AFTER` an `INSERT`, `UPDATE`, or `DELETE`, letting you enforce rules, log changes to an audit table, or update calculated values — without anyone having to remember to call a procedure.
