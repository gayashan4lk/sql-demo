# SQL Joins — Practice Problems

> **Setup:** Run `schema/reset.sql` before starting. These problems use the `student`, `course`, `enrollment`, and `grade` tables. Every problem is a read-only `SELECT` — there is nothing to clean up afterwards.

Try the SQL yourself before checking the hint or solution. Use table aliases (`s`, `e`, `c`, `g`), qualify your columns (`e.student_id`, not `student_id`), and give every `JOIN` an `ON`.

> These problems assume **MySQL 8.0+**. The seed data has 11 students, 9 courses, 24 enrollments, and 10 grades (so 14 enrollments are ungraded).

---

## Problem 1 — Match Students to Their Enrollments (Easy)

List each student's name next to the course id they are enrolled in.

**Your task:**
1. `INNER JOIN` `student` to `enrollment` on `student_id`
2. Select the student's `name` and the enrollment's `course_id` and `status`
3. Order by name

**Expected:** One row per enrollment (24 rows), each showing a student name and a course id — students with several enrollments appear several times.

<details>
<summary>Hint</summary>

The linking columns are `student.student_id` and `enrollment.student_id`. Alias the tables (`student AS s`, `enrollment AS e`) so you can write `s.name` and `e.course_id`.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT s.name, e.course_id, e.status
FROM student AS s
INNER JOIN enrollment AS e
    ON s.student_id = e.student_id
ORDER BY s.name;
```

**What you practiced:** A basic two-table `INNER JOIN` with aliases and an `ON` clause.

</details>

---

## Problem 2 — Add Course Names (Easy)

The previous result showed `course_id`, which is not human-readable. Join in the `course` table to show real course names.

**Your task:**
1. Start from the `student → enrollment` join in Problem 1
2. Add a second `JOIN` to `course` on `course_id`
3. Select `name`, `course_code`, `course_name`, and `status`

**Expected:** 24 rows — every enrollment, now showing the student name *and* the course code and name (e.g. `Alice Johnson | CS101 | Introduction to Computer Science`).

<details>
<summary>Hint</summary>

Chain the joins: `... JOIN enrollment e ON ... JOIN course c ON e.course_id = c.course_id`. Each new `JOIN` links to a table already in the query.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT s.name, c.course_code, c.course_name, e.status
FROM student AS s
JOIN enrollment AS e ON s.student_id = e.student_id
JOIN course     AS c ON e.course_id  = c.course_id
ORDER BY s.name, c.course_code;
```

**What you practiced:** Joining three tables through a junction table to turn ids into readable names.

</details>

---

## Problem 3 — Keep Ungraded Enrollments (Medium)

Show every enrollment with its grade, including the ones that have not been graded yet.

**Your task:**
1. `LEFT JOIN` `enrollment` to `grade` on `enrollment_id`
2. Select `enrollment_id`, `student_id`, `status`, and `letter_grade`
3. Confirm ungraded enrollments appear with a `NULL` `letter_grade`

**Expected:** 24 rows. The 10 graded enrollments show a letter; the other 14 show `NULL`. An `INNER JOIN` would have returned only 10.

<details>
<summary>Hint</summary>

Put `enrollment` on the left so it is kept in full: `FROM enrollment e LEFT JOIN grade g ON g.enrollment_id = e.enrollment_id`. The unmatched rows get `NULL` for every `grade` column.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT e.enrollment_id, e.student_id, e.status, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
ORDER BY e.enrollment_id;
```

**What you practiced:** Using a `LEFT JOIN` to keep unmatched rows and produce `NULL`s instead of dropping them.

</details>

---

## Problem 4 — Find the Ungraded Enrollments (Medium)

Now list *only* the enrollments that have no grade yet, with the student and course named.

**Your task:**
1. `LEFT JOIN` `enrollment` to `grade`, then keep only the unmatched rows with `WHERE g.grade_id IS NULL`
2. Join `student` and `course` so you can show `name` and `course_code`
3. Order by student name

**Expected:** 14 rows — every enrollment with no grade, each showing the student name and course code.

<details>
<summary>Hint</summary>

This is the anti-join idiom: `LEFT JOIN grade ... WHERE g.grade_id IS NULL`. Test `IS NULL` on the grade's **primary key** (`grade_id`), which is only `NULL` when there was no match.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT s.name, c.course_code, e.status
FROM enrollment AS e
JOIN      student AS s ON s.student_id = e.student_id
JOIN      course  AS c ON c.course_id  = e.course_id
LEFT JOIN grade   AS g ON g.enrollment_id = e.enrollment_id
WHERE g.grade_id IS NULL
ORDER BY s.name;
```

**What you practiced:** The anti-join pattern — `LEFT JOIN` then `WHERE rightPK IS NULL` — to find rows with no match, combined with extra joins for readable output.

</details>

---

## Problem 5 — Completed Courses with Grades (Hard)

For every **Completed** enrollment, show the student, the course, and the numeric grade, best grades first.

**Your task:**
1. Join all four tables: `student → enrollment → course → grade`
2. Filter to `enrollment.status = 'Completed'`
3. Select `name`, `course_code`, `numeric_grade`; order by `numeric_grade` descending

**Expected:** 10 rows (every Completed enrollment is graded). The top row is the highest numeric grade — `95.00` (Frank Wilson, MATH201), down to `65.00`.

<details>
<summary>Hint</summary>

Use an `INNER JOIN` to `grade` here (you only want graded rows), and put the `status` filter in `WHERE` — it filters the `enrollment` (left-most) table, which is always safe.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT s.name, c.course_code, g.numeric_grade
FROM student AS s
JOIN enrollment AS e ON e.student_id    = s.student_id
JOIN course     AS c ON c.course_id     = e.course_id
JOIN grade      AS g ON g.enrollment_id = e.enrollment_id
WHERE e.status = 'Completed'
ORDER BY g.numeric_grade DESC;
```

**What you practiced:** A four-table join combined with a `WHERE` filter and `ORDER BY` — the shape of most real reporting queries.

</details>

---

## Bonus — Why Did My LEFT JOIN Shrink?

No SQL to write. A student wrote this query expecting **all** students, including those with no Active enrollment:

```sql
SELECT s.name, e.course_id
FROM student AS s
LEFT JOIN enrollment AS e ON e.student_id = s.student_id
WHERE e.status = 'Active';
```

**Questions:**
1. Why does this behave like an `INNER JOIN`, dropping students who have no Active enrollment?
2. How would you rewrite it so students with no Active enrollment still appear (with `NULL` course)?

<details>
<summary>Answer</summary>

1. The `WHERE e.status = 'Active'` tests a column on the **right** (`enrollment`) table. For a student with no matching enrollment, `e.status` is `NULL`, and `NULL = 'Active'` is not true — so the `WHERE` filters that row out. Filtering the right table in `WHERE` collapses a `LEFT JOIN` into an `INNER JOIN`.
2. Move the condition into the `ON` clause so it restricts the *match* rather than the *final result*:

```sql
SELECT s.name, e.course_id
FROM student AS s
LEFT JOIN enrollment AS e
    ON e.student_id = s.student_id
   AND e.status = 'Active';
```

Now every student is kept; only their *Active* enrollments are joined, and students with none show `NULL`.

**What you practiced:** Diagnosing the `ON`-vs-`WHERE` trap — the single most common `LEFT JOIN` bug.

</details>

---

## No Cleanup Needed

Every query here only reads data. If you want to reset anything you changed elsewhere, re-run:

```sql
-- source schema/reset.sql;
```
