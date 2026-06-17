# SQL Updatable Views — Practice Problems

> **Setup:** Make sure you have run `schema/01_student.sql` (or `schema/reset.sql`) before starting.

Use your `student` table to solve each problem. Try writing the SQL yourself before checking the hint or solution.

---

## Problem 1 — UPDATE Through a View (Easy)

Create an updatable view called `student_names` that shows `student_id`, `name`, and `gender` from the `student` table. Then use the view to update the name of the student with `student_id = 2` to `'Robert Smith'`.

**Your task:**
1. Create the view
2. Update the name through the view
3. Verify the change by querying the base `student` table directly

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

**What you practiced:** Updating data through an updatable view and confirming the change flows to the base table.

</details>

---

## Problem 2 — DELETE Through a View (Easy)

Create an updatable view called `male_students_view` that shows `student_id`, `name`, and `date_of_birth` for all male students. Then use the view to delete the student with `student_id = 4`.

**Your task:**
1. Create the view with a `WHERE` filter for male students
2. Delete the student through the view
3. Verify the row is gone from both the view and the base table

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

**What you practiced:** Deleting through a filtered updatable view and understanding that the row is removed from the base table entirely.

</details>

---

## Problem 3 — WITH CHECK OPTION (Medium)

Create a view called `young_students` that shows `student_id`, `name`, and `date_of_birth` for students born **after 2000-01-01**, with `WITH CHECK OPTION` enabled.

**Your task:**
1. Create the view with `WITH CHECK OPTION`
2. **Part A:** Try to update a student's `date_of_birth` to `'1995-05-01'` (outside the filter) — observe the error
3. **Part B:** Update a student's `date_of_birth` to `'2001-06-15'` (still within the filter) — confirm it succeeds

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

**What you practiced:** Using `WITH CHECK OPTION` to enforce that updates stay within the view's filter.

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

**What you practiced:** Applying the updatability rules by inspecting SQL definitions — a skill you will use when designing views in production.

</details>

---

## Problem 5 — Competing Date-Range Views (Hard)

Create two views over the student table, each with `WITH CHECK OPTION`:

- `pre_2001_students` — shows `student_id`, `name`, `date_of_birth` for students born **on or before 2000-12-31**
- `post_2000_students` — shows `student_id`, `name`, `date_of_birth` for students born **after 2000-12-31**

**Your task:**
1. Create both views with `WITH CHECK OPTION`
2. Pick a student from `post_2000_students` and try to update their `date_of_birth` to `'1999-06-01'` through that view — observe what happens
3. Now update the same student's `date_of_birth` directly on the base `student` table to `'1999-06-01'` — does it succeed?
4. Check both views — which view does the student appear in now?

**Expected:** The update through the view should fail (CHECK OPTION). The direct update on the base table should succeed, moving the student from one view to the other.

<details>
<summary>Hint</summary>

`WITH CHECK OPTION` only enforces the WHERE clause when you write through **that specific view**. Direct writes to the base table bypass all view checks.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW pre_2001_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth <= '2000-12-31'
WITH CHECK OPTION;

CREATE VIEW post_2000_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE date_of_birth > '2000-12-31'
WITH CHECK OPTION;

-- See who is in each view
SELECT * FROM pre_2001_students;
SELECT * FROM post_2000_students;

-- Step 2: This will FAIL — moving the student outside the view's filter
UPDATE post_2000_students
SET date_of_birth = '1999-06-01'
WHERE student_id = 1;

-- Step 3: This SUCCEEDS — base table has no CHECK OPTION
UPDATE student
SET date_of_birth = '1999-06-01'
WHERE student_id = 1;

-- Step 4: The student moved from one view to the other
SELECT * FROM post_2000_students;  -- student_id 1 is gone
SELECT * FROM pre_2001_students;   -- student_id 1 appears here now
```

**What you practiced:** Understanding that `WITH CHECK OPTION` only protects writes through the view itself — direct base table writes are unrestricted.

</details>

---

## Bonus: Explain It

*No SQL to write — answer in your own words.*

A view is defined as `SELECT student_id, name FROM student WHERE gender = 'Female'` **without** `WITH CHECK OPTION`. You insert a row through this view: `INSERT INTO <view> (student_id, name) VALUES (99, 'Test')`. Assume `student_id` is not auto-increment for this scenario and `gender` has a default value of `'Male'`.

Does the insert succeed? Where does the new row end up? Can you see it through the view?

<details>
<summary>Answer</summary>

The insert succeeds because the view is updatable (simple SELECT from one table). The new row is inserted into the `student` base table with `gender = 'Male'` (the default). However, since the view filters on `gender = 'Female'`, the new row is **not visible** through the view — it slipped outside the view's scope. This is exactly the kind of silent mismatch that `WITH CHECK OPTION` prevents.

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
DROP VIEW IF EXISTS pre_2001_students;
DROP VIEW IF EXISTS post_2000_students;
```
