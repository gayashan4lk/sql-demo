# SQL Updatable Views — Practice Problems

Use your `student` table to solve each problem. Try writing the SQL yourself before checking the hint or solution.

---

## Problem 1 — UPDATE Through a View (Easy)

Create an updatable view called `student_names` that shows `student_id`, `name`, and `gender` from the `student` table.

Then use the view to **update the name** of the student with `student_id = 2` to `'Robert Smith'`.

Finally, verify the change by querying the base `student` table directly.

**Expected:** The name change should be visible in both the view and the base table.

<details>
<summary>Hint</summary>

Create the view with a simple `SELECT` — no `GROUP BY`, no aggregates. Then run `UPDATE <view_name> SET name = ... WHERE ...`. Check with `SELECT * FROM student WHERE student_id = 2`.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW student_names AS
SELECT student_id, name, gender
FROM student;

UPDATE student_names
SET name = 'Robert Smith'
WHERE student_id = 2;

-- Verify in the base table
SELECT * FROM student WHERE student_id = 2;
```

</details>

---

## Problem 2 — DELETE Through a View (Easy)

Create an updatable view called `male_students_view` that shows `student_id`, `name`, and `date_of_birth` for all male students.

Then use the view to **delete the student with `student_id = 4`**.

Verify the row is gone from both the view and the base `student` table.

**Expected:** The student should no longer appear in either the view or the base table.

<details>
<summary>Hint</summary>

Use `DELETE FROM <view_name> WHERE student_id = 4`. Then run `SELECT * FROM student` to confirm the row is removed from the base table too.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW male_students_view AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Male';

DELETE FROM male_students_view
WHERE student_id = 4;

-- Verify in the view
SELECT * FROM male_students_view;

-- Verify in the base table
SELECT * FROM student WHERE student_id = 4;
```

</details>

---

## Problem 3 — WITH CHECK OPTION (Medium)

Create a view called `young_students` that shows `student_id`, `name`, and `date_of_birth` for students born **after 2000-01-01**, with `WITH CHECK OPTION` enabled.

**Part A:** Try to `UPDATE` a student's `date_of_birth` through the view to `'1995-05-01'` (a date that would take them outside the view's filter). Observe what happens.

**Part B:** Now do a valid `UPDATE` — change a student's `date_of_birth` to `'2001-06-15'` (still within the filter). Confirm it succeeds.

**Expected:** Part A should fail with a CHECK OPTION error. Part B should succeed.

<details>
<summary>Hint</summary>

The `WITH CHECK OPTION` clause goes at the end of the `CREATE VIEW` statement. Any `INSERT` or `UPDATE` that would make the row invisible through the view (i.e., no longer match `WHERE date_of_birth > '2000-01-01'`) will be rejected.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW young_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth > '2000-01-01'
WITH CHECK OPTION;

-- Check who is in the view
SELECT * FROM young_students;

-- Part A: This will FAIL — 1995 violates the WHERE clause
UPDATE young_students
SET date_of_birth = '1995-05-01'
WHERE student_id = 1;

-- Part B: This will SUCCEED — 2001 still satisfies the filter
UPDATE young_students
SET date_of_birth = '2001-06-15'
WHERE student_id = 1;

SELECT * FROM young_students;
```

</details>

---

## Problem 4 — Spot the Updatable View (Hard / Conceptual)

Look at the three views below. **Without running them**, decide: which are updatable and which are not? Write your answer and explain why before expanding the solution.

**View A:**
```sql
CREATE VIEW view_a AS
SELECT student_id, name, email
FROM student
WHERE gender = 'Female';
```

**View B:**
```sql
CREATE VIEW view_b AS
SELECT gender, COUNT(*) AS total
FROM student
GROUP BY gender;
```

**View C:**
```sql
CREATE VIEW view_c AS
SELECT DISTINCT gender
FROM student;
```

<details>
<summary>Hint</summary>

Ask yourself for each view: Can MySQL trace every row in the view back to exactly one row in the base table? Watch for `GROUP BY`, `COUNT`, and `DISTINCT` — these are red flags.

</details>

<details>
<summary>Solution</summary>

| View | Updatable? | Reason |
|---|---|---|
| View A | **Yes** | Simple SELECT from a single table with a WHERE clause — each row maps to exactly one base row |
| View B | **No** | Uses `GROUP BY` and `COUNT(*)` — rows are aggregated, so MySQL can't map them back to individual base rows |
| View C | **No** | Uses `DISTINCT` — multiple base rows may collapse into one view row, so MySQL can't determine which base row to update |

```sql
-- You can confirm View B and C are non-updatable by trying:
UPDATE view_b SET total = 5 WHERE gender = 'Male';    -- ERROR
UPDATE view_c SET gender = 'Other' WHERE gender = 'Male'; -- ERROR
```

</details>

---

## Cleanup

Remove all practice views when you're done:

```sql
DROP VIEW IF EXISTS student_names;
DROP VIEW IF EXISTS male_students_view;
DROP VIEW IF EXISTS young_students;
DROP VIEW IF EXISTS view_a;
DROP VIEW IF EXISTS view_b;
DROP VIEW IF EXISTS view_c;
```
