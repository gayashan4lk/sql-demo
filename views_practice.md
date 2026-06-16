# SQL Views — Practice Problems

Use your `student` table to solve each problem. Try writing the SQL yourself before checking the hint.

---

## Problem 1 — Basic View (Easy)

Create a view called `student_directory` that shows only the `name` and `email` of all students, ordered alphabetically by name.

**Expected columns:** `name`, `email`

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

</details>

---

## Problem 2 — Filtered View (Easy)

Create a view called `male_students` that shows the `student_id`, `name`, and `date_of_birth` of all male students only.

**Expected columns:** `student_id`, `name`, `date_of_birth`

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

</details>

---

## Problem 3 — Computed Column (Medium)

Create a view called `student_ages` that shows each student's `name`, `gender`, and their **current age** as a column called `age`. Then query the view to show only students who are **25 or older**.

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

</details>

---

## Problem 4 — Update a View (Medium)

You already have the `student_directory` view from Problem 1. Update it (without dropping it first) to also include the `gender` column, and remove the `ORDER BY`.

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

</details>

---

## Problem 5 — Aggregate View (Hard)

Create a view called `gender_summary` that shows the **count of students** for each gender. Then query the view to find which gender has the most students.

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

</details>

---

## Cleanup

Once you're done, remove all practice views:

```sql
DROP VIEW IF EXISTS student_directory;
DROP VIEW IF EXISTS male_students;
DROP VIEW IF EXISTS student_ages;
DROP VIEW IF EXISTS gender_summary;
```
