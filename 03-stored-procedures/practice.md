# SQL Stored Procedures — Practice Problems

> **Setup:** Run `schema/reset.sql` before starting. This lesson uses the `student`, `course`, and `enrollment` tables.

Try writing the SQL yourself before checking the hint or solution. Remember the `DELIMITER $$` ... `END $$` ... `DELIMITER ;` pattern for every procedure.

---

## Problem 1 — Find Student by ID (Easy)

Create a procedure called `find_student_by_id` that accepts a student ID and returns that student's `name`, `email`, `date_of_birth`, and `gender`.

**Your task:**
1. Create the procedure with an `IN` parameter `p_student_id INT`
2. Call it with student_id = 3
3. Call it with student_id = 8

**Expected:** First call returns Clara Davis's row. Second call returns Henry Brown's row.

<details>
<summary>Hint</summary>

Use `CREATE PROCEDURE ... (IN p_student_id INT)` with a simple `SELECT ... FROM student WHERE student_id = p_student_id` inside the body. Don't forget `DELIMITER $$` before and `DELIMITER ;` after.

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS find_student_by_id;

DELIMITER $$

CREATE PROCEDURE find_student_by_id(IN p_student_id INT)
BEGIN
    SELECT name, email, date_of_birth, gender
    FROM student
    WHERE student_id = p_student_id;
END $$

DELIMITER ;

CALL find_student_by_id(3);
CALL find_student_by_id(8);
```

**What you practiced:** Creating a basic stored procedure with an `IN` parameter and calling it with different values.

</details>

---

## Problem 2 — Department Course Count (Easy)

Create a procedure called `count_department_courses` that accepts a department name and returns the number of courses in that department through an `OUT` parameter.

**Your task:**
1. Create the procedure with `IN p_department VARCHAR(100)` and `OUT p_total INT`
2. Call it for `'Computer Science'` and display the result
3. Call it for `'Physics'` and display the result

**Expected:** Computer Science = 3, Physics = 2.

<details>
<summary>Hint</summary>

Use `SELECT COUNT(*) INTO p_total FROM course WHERE department = p_department`. The caller reads the result with `CALL count_department_courses('Computer Science', @total); SELECT @total;`.

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS count_department_courses;

DELIMITER $$

CREATE PROCEDURE count_department_courses(
    IN p_department VARCHAR(100),
    OUT p_total INT
)
BEGIN
    SELECT COUNT(*) INTO p_total
    FROM course
    WHERE department = p_department;
END $$

DELIMITER ;

CALL count_department_courses('Computer Science', @total);
SELECT @total AS cs_courses;

CALL count_department_courses('Physics', @total);
SELECT @total AS physics_courses;
```

**What you practiced:** Using an `OUT` parameter with `SELECT ... INTO` to return a computed value to the caller.

</details>

---

## Problem 3 — Enrollment Status Report (Medium)

Create a procedure called `student_course_status` that accepts a student ID and a course code, and returns a human-readable status message through an `OUT` parameter.

- If the student is enrolled in that course, return: `'<student_name> is <status> in <course_name>'`
- If the student is not enrolled, return: `'Not enrolled in <course_code>'`

**Your task:**
1. Create the procedure with `IN p_student_id INT`, `IN p_course_code VARCHAR(10)`, and `OUT p_result VARCHAR(255)`
2. Call it for student 1 and course `'CS101'`
3. Call it for student 1 and course `'PHY201'`

**Expected:**
- First call: `'Alice Johnson is Completed in Introduction to Computer Science'`
- Second call: `'Not enrolled in PHY201'`

<details>
<summary>Hint</summary>

You need to JOIN `student`, `enrollment`, and `course` tables. Use `LEFT JOIN` or a two-step approach: first find the course_id from the course_code, then look up the enrollment. Use `IF v_status IS NULL` to detect "not enrolled". Use `CONCAT()` to build the message string.

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS student_course_status;

DELIMITER $$

CREATE PROCEDURE student_course_status(
    IN p_student_id INT,
    IN p_course_code VARCHAR(10),
    OUT p_result VARCHAR(255)
)
BEGIN
    DECLARE v_student_name VARCHAR(100);
    DECLARE v_course_name VARCHAR(150);
    DECLARE v_course_id INT;
    DECLARE v_status VARCHAR(20);

    SELECT name INTO v_student_name
    FROM student
    WHERE student_id = p_student_id;

    SELECT course_id, course_name
    INTO v_course_id, v_course_name
    FROM course
    WHERE course_code = p_course_code;

    SELECT status INTO v_status
    FROM enrollment
    WHERE student_id = p_student_id
      AND course_id = v_course_id;

    IF v_status IS NULL THEN
        SET p_result = CONCAT('Not enrolled in ', p_course_code);
    ELSE
        SET p_result = CONCAT(v_student_name, ' is ', v_status,
                              ' in ', v_course_name);
    END IF;
END $$

DELIMITER ;

CALL student_course_status(1, 'CS101', @result);
SELECT @result;

CALL student_course_status(1, 'PHY201', @result);
SELECT @result;
```

**What you practiced:** Combining JOINs (multi-table lookups), variables, `IF/ELSE`, and `CONCAT` to build a meaningful output message inside a single procedure.

</details>

---

## Problem 4 — Course Capacity Checker (Medium)

Create a procedure called `check_capacity` that accepts a course ID and returns a result set with the course name, max enrollment, current enrollment count (Active only), and spots available.

If the course does not exist, raise an error using `SIGNAL`.

**Your task:**
1. Create the procedure with `IN p_course_id INT`
2. Call it for course_id = 1 (CS101)
3. Call it for course_id = 999 (should raise an error)

**Expected:**
- Course 1: `Introduction to Computer Science`, max = 30, current = 4, available = 26
- Course 999: Error — `'Course not found'`

<details>
<summary>Hint</summary>

DECLARE four variables: `v_course_name`, `v_max`, `v_current`, `v_available`. Use `SELECT ... INTO` from `course` to get the name and max. Then count Active enrollments. Use `SET` to compute availability. Before computing, check if the course was found (if `v_course_name IS NULL`, SIGNAL an error).

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS check_capacity;

DELIMITER $$

CREATE PROCEDURE check_capacity(IN p_course_id INT)
BEGIN
    DECLARE v_course_name VARCHAR(150);
    DECLARE v_max INT;
    DECLARE v_current INT;
    DECLARE v_available INT;

    SELECT course_name, max_enrollment
    INTO v_course_name, v_max
    FROM course
    WHERE course_id = p_course_id;

    IF v_course_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Course not found';
    END IF;

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

CALL check_capacity(1);
CALL check_capacity(999);
```

**What you practiced:** Input validation with `SIGNAL`, multiple `DECLARE` variables, `SELECT ... INTO`, and arithmetic inside a procedure.

</details>

---

## Problem 5 — Safe Email Update (Hard)

Create a procedure called `update_student_email` that accepts a student ID and a new email address. The procedure must validate all of the following before making any changes:

1. The student must exist
2. The new email must contain `'@'`
3. The new email must not already be used by another student

If any check fails, raise an error with a descriptive message using `SIGNAL`. If all checks pass, update the student's email.

**Your task:**
1. Create the procedure with `IN p_student_id INT` and `IN p_new_email VARCHAR(150)`
2. Call it to update student 1's email to `'alice.new@email.com'` (should succeed)
3. Call it with student_id = 999 (should fail: student not found)
4. Call it with email `'bademail'` (should fail: invalid email)
5. Call it to set student 2's email to `'alice.new@email.com'` (should fail: email already in use)

**Expected:** First call succeeds and updates the email. Calls 3–5 each fail with a different error message.

<details>
<summary>Hint</summary>

Use `INSTR(p_new_email, '@') = 0` to check if the email is missing the `@` symbol. Use `SELECT COUNT(*) INTO v_count FROM student WHERE email = p_new_email AND student_id != p_student_id` to check for duplicates (exclude the current student). Order the checks: student exists → email valid → email unique → UPDATE.

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS update_student_email;

DELIMITER $$

CREATE PROCEDURE update_student_email(
    IN p_student_id INT,
    IN p_new_email VARCHAR(150)
)
BEGIN
    DECLARE v_student_exists INT;
    DECLARE v_email_duplicate INT;

    -- Check 1: Student must exist
    SELECT COUNT(*) INTO v_student_exists
    FROM student
    WHERE student_id = p_student_id;

    IF v_student_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student not found';
    END IF;

    -- Check 2: Email must contain @
    IF INSTR(p_new_email, '@') = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid email: must contain @';
    END IF;

    -- Check 3: Email must not be used by another student
    SELECT COUNT(*) INTO v_email_duplicate
    FROM student
    WHERE email = p_new_email
      AND student_id != p_student_id;

    IF v_email_duplicate > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Email already in use by another student';
    END IF;

    -- All checks passed — update the email
    UPDATE student
    SET email = p_new_email
    WHERE student_id = p_student_id;

    SELECT 'Email updated successfully' AS result;
END $$

DELIMITER ;

-- Should succeed
CALL update_student_email(1, 'alice.new@email.com');

-- Should fail: student not found
CALL update_student_email(999, 'test@email.com');

-- Should fail: invalid email
CALL update_student_email(2, 'bademail');

-- Should fail: email already in use
CALL update_student_email(2, 'alice.new@email.com');
```

**What you practiced:** Building a production-style validation procedure with multiple guard clauses, meaningful error messages, and a final `UPDATE` — the exact pattern used in real applications to protect data integrity.

</details>

---

## Bonus: Explain It

*No SQL to write — answer in your own words.*

Your team is debating where to put enrollment validation logic. Developer A says: "Put it in a stored procedure in the database." Developer B says: "Put it in the application code (Python/Java/etc.)."

1. Give one advantage and one disadvantage of **each** approach.
2. If you have both a web app **and** a mobile app connecting to the same database, which approach better ensures consistent behavior? Why?

<details>
<summary>Answer</summary>

**Stored procedure approach:**
- Advantage: Logic is enforced for all clients — no matter how many apps connect, they all call the same procedure and get the same validation.
- Disadvantage: Harder to test, debug, and version-control. You cannot step through a stored procedure with a debugger the way you can with application code.

**Application code approach:**
- Advantage: Richer language features (string manipulation, HTTP calls, better testing frameworks), easier to deploy changes, and easier to read for developers who do not know SQL.
- Disadvantage: If multiple applications connect to the same database, each one must duplicate the validation logic. If one app has a bug, it can bypass the rules.

**With multiple clients (web + mobile):** The stored procedure approach better ensures consistency, because the validation lives in the database — the one place all clients share. Both apps call `CALL enroll_student(...)` and the procedure enforces the same rules regardless of which app triggered it.

</details>

---

## Cleanup

Remove all practice procedures and reset any modified data:

```sql
DROP PROCEDURE IF EXISTS find_student_by_id;
DROP PROCEDURE IF EXISTS count_department_courses;
DROP PROCEDURE IF EXISTS student_course_status;
DROP PROCEDURE IF EXISTS check_capacity;
DROP PROCEDURE IF EXISTS update_student_email;

-- Reset modified student data (Problem 5 may have changed Alice's email)
-- Or simply re-run: source schema/reset.sql;
UPDATE student SET email = 'alice.johnson@email.com' WHERE student_id = 1;
```
