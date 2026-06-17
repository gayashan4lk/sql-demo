# SQL Views — Practice Problems

> **Setup:** Make sure you have run `schema/01_student.sql` (or `schema/reset.sql`) before starting.

Use your `student` table to solve each problem. Try writing the SQL yourself before checking the hint.

---

## Problem 1 — Basic View (Easy)

Create a view called `student_directory` that shows only the `name` and `email` of all students, ordered alphabetically by name.

**Your task:**
1. Create the view
2. Query it to see all rows

**Expected columns:** `name`, `email`
**Expected rows:** 11 (all students, sorted A–Z by name)

<details>
<summary>Hint</summary>

Use `CREATE VIEW ... AS SELECT ... ORDER BY`.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW student_directory AS
SELECT name, email
FROM student
ORDER BY name;

SELECT * FROM student_directory;
```

**What you practiced:** Creating a basic view with `ORDER BY`.

</details>

---

## Problem 2 — Filtered View (Easy)

Create a view called `male_students` that shows the `student_id`, `name`, and `date_of_birth` of all male students only.

**Your task:**
1. Create the view with a `WHERE` filter
2. Query it to verify only male students appear

**Expected columns:** `student_id`, `name`, `date_of_birth`
**Expected rows:** 6 (male students only)

<details>
<summary>Hint</summary>

Use a `WHERE` clause inside the view definition to filter by gender.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW male_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Male';

SELECT * FROM male_students;
```

**What you practiced:** Filtering rows inside a view definition with `WHERE`.

</details>

---

## Problem 3 — Computed Column (Medium)

Create a view called `student_ages` that shows each student's `name`, `gender`, and their **current age** as a column called `age`. Then query the view to show only students who are **25 or older**.

**Your task:**
1. Create the view with a computed `age` column
2. Query the view with a `WHERE` clause to filter by age

**Expected columns:** `name`, `gender`, `age`

<details>
<summary>Hint</summary>

Use `TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE())` to calculate age. Filter on `age` in the SELECT query against the view, not inside the view definition.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW student_ages AS
SELECT name, gender,
       TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
FROM student;

SELECT * FROM student_ages
WHERE age >= 25;
```

**What you practiced:** Using computed columns in a view and filtering on computed values in the outer query.

</details>

---

## Problem 4 — Update a View (Medium)

You already have the `student_directory` view from Problem 1. Update it (without dropping it first) to also include the `gender` column, and remove the `ORDER BY`.

**Your task:**
1. Use `CREATE OR REPLACE VIEW` to modify the existing view
2. Query it to confirm the new column appears

**Expected columns:** `name`, `email`, `gender`

<details>
<summary>Hint</summary>

Use `CREATE OR REPLACE VIEW` to modify an existing view in place.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE OR REPLACE VIEW student_directory AS
SELECT name, email, gender
FROM student;

SELECT * FROM student_directory;
```

**What you practiced:** Modifying an existing view with `CREATE OR REPLACE VIEW`.

</details>

---

## Problem 5 — Aggregate View (Hard)

Create a view called `gender_summary` that shows the **count of students** for each gender. Then query the view to find which gender has the most students.

**Your task:**
1. Create the view using `COUNT(*)` and `GROUP BY`
2. Query it to see all counts
3. Query it again to find only the gender with the highest count

**Expected columns:** `gender`, `total`

<details>
<summary>Hint</summary>

Use `COUNT(*)` and `GROUP BY gender` inside the view. Query the view with `ORDER BY total DESC LIMIT 1` to find the top result. Remember: this view will not be updatable because it uses an aggregate function.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW gender_summary AS
SELECT gender, COUNT(*) AS total
FROM student
GROUP BY gender;

-- Count per gender
SELECT * FROM gender_summary;

-- Gender with the most students
SELECT * FROM gender_summary
ORDER BY total DESC
LIMIT 1;
```

**What you practiced:** Creating a view with aggregate functions and `GROUP BY`. This view is read-only — you cannot `UPDATE` or `DELETE` through it.

</details>

---

## Problem 6 — Birth Decade View (Hard)

Create a view called `student_birth_decade` that shows each student's `name` and a computed column `decade` that displays the decade they were born in (e.g., `'1990s'`, `'2000s'`). Then query the view to count how many students were born in each decade.

**Your task:**
1. Create the view with a computed `decade` column
2. Query the view to see all rows
3. Query the view using `GROUP BY` to count students per decade

**Expected columns:** `name`, `decade`

<details>
<summary>Hint</summary>

Use `CONCAT(FLOOR(YEAR(date_of_birth) / 10) * 10, 's')` to compute the decade string. For the count query, use `SELECT decade, COUNT(*) ... GROUP BY decade` on the view.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE VIEW student_birth_decade AS
SELECT name,
       CONCAT(FLOOR(YEAR(date_of_birth) / 10) * 10, 's') AS decade
FROM student;

-- See all students with their birth decade
SELECT * FROM student_birth_decade;

-- Count students per decade
SELECT decade, COUNT(*) AS total
FROM student_birth_decade
GROUP BY decade
ORDER BY decade;
```

**What you practiced:** Building creative computed columns using `FLOOR`, `YEAR`, `CONCAT`, and querying a view with aggregation in the outer query.

</details>

---

## Bonus: Explain It

*No SQL to write — answer in your own words.*

Your colleague proposes creating a view for every table in the database, with each view doing `SELECT * FROM <table>`. They say it will "add a layer of abstraction." What would you tell them about why this is or is not a good idea?

<details>
<summary>Answer</summary>

This adds indirection without benefit. Each view would be identical to querying the table directly — it does not simplify anything, hide any columns, or add computed values. It also creates maintenance overhead: if the table schema changes, the `SELECT *` views may return unexpected results. Views are valuable when they simplify, restrict, or transform data — not when they mirror it exactly.

</details>

---

## Cleanup

Once you're done, remove all practice views:

```sql
DROP VIEW IF EXISTS student_directory;
DROP VIEW IF EXISTS male_students;
DROP VIEW IF EXISTS student_ages;
DROP VIEW IF EXISTS gender_summary;
DROP VIEW IF EXISTS student_birth_decade;
```
