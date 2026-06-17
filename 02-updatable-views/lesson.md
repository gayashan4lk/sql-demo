# SQL Updatable Views Lesson

> **Prerequisite:** You should be familiar with basic views (`CREATE VIEW`, `SELECT`, `WHERE`, `DROP VIEW`) before starting this lesson.

---

## What is an Updatable View?

A regular view lets you **read** data. An **updatable view** goes further — it lets you run `INSERT`, `UPDATE`, and `DELETE` through the view, and those changes flow through to the underlying base table.

Think of it like editing a document through a window. If the window shows you exactly one document, you can reach through and edit it. If the window is showing a summary or a mashup of multiple documents, there's nothing specific to edit.

---

## Rules — What Makes a View Updatable?

MySQL can only make a view updatable if it can trace every row and column back to **exactly one row and column in a single base table**.

A view is updatable when it:

| Rule | Allowed |
|---|---|
| Selects from a single table | Yes |
| Has a `WHERE` clause | Yes |
| Has `DISTINCT` | **No** |
| Has aggregate functions (`SUM`, `COUNT`, `AVG`, etc.) | **No** |
| Has `GROUP BY` or `HAVING` | **No** |
| Has subqueries in the SELECT list | **No** |
| Has `UNION` or set operations | **No** |

---

## 1. Setup — Create an Updatable View

This view exposes only `student_id`, `name`, and `email`. It qualifies as updatable because it selects from a single table with no aggregates or special clauses.

```sql
CREATE VIEW student_emails AS
SELECT student_id, name, email
FROM student;

SELECT * FROM student_emails;
```

---

## 2. UPDATE Through a View

You can update columns that exist in the view. The change writes through to the `student` base table.

```sql
UPDATE student_emails
SET email = 'alice.new@email.com'
WHERE student_id = 1;

-- Verify the change hit the base table
SELECT * FROM student WHERE student_id = 1;
```

---

## 3. DELETE Through a View

Deleting a row through a view deletes that row from the base table entirely.

```sql
DELETE FROM student_emails
WHERE student_id = 10;

-- Verify the row is gone from the base table
SELECT * FROM student WHERE student_id = 10;
```

---

## 4. INSERT Through a View

You can insert a new row through an updatable view. Columns not included in the view must either allow `NULL` or have a default value in the base table.

```sql
-- This will FAIL because date_of_birth and gender are NOT NULL with no default
INSERT INTO student_emails (name, email)
VALUES ('Test Student', 'test@email.com');
```

To insert through a view successfully, the view must include all `NOT NULL` columns without defaults, or those columns must have defaults defined on the table.

---

## 5. WITH CHECK OPTION

This is the most important concept in updatable views.

**The problem without it:** You can `UPDATE` a row through a filtered view in a way that makes the row disappear from the view — it no longer matches the `WHERE` clause, so it's silently gone from your view.

**WITH CHECK OPTION** prevents this. It ensures that any `INSERT` or `UPDATE` through the view must still satisfy the view's `WHERE` clause — otherwise MySQL throws an error.

### Without CHECK OPTION (dangerous)

```sql
CREATE VIEW female_students_unsafe AS
SELECT student_id, name, gender
FROM student
WHERE gender = 'Female';

-- This succeeds — but Alice disappears from the view afterwards!
UPDATE female_students_unsafe
SET gender = 'Male'
WHERE student_id = 1;

SELECT * FROM female_students_unsafe; -- Alice is gone
SELECT * FROM student WHERE student_id = 1; -- She's now Male in the base table
```

### With CHECK OPTION (safe)

```sql
CREATE VIEW female_students_safe AS
SELECT student_id, name, gender
FROM student
WHERE gender = 'Female'
WITH CHECK OPTION;

-- This will FAIL with an error: CHECK OPTION failed
UPDATE female_students_safe
SET gender = 'Male'
WHERE student_id = 2;
```

MySQL blocks the update because the result would violate the `WHERE gender = 'Female'` condition.

---

## 6. Non-Updatable View — Contrast

A view with `GROUP BY` or aggregate functions is **not updatable**. MySQL cannot trace a calculated value back to a single row in the base table.

```sql
CREATE VIEW gender_count AS
SELECT gender, COUNT(*) AS total
FROM student
GROUP BY gender;

SELECT * FROM gender_count; -- Works fine for reading

-- This will ERROR: View 'gender_count' is not updatable
UPDATE gender_count SET total = 10 WHERE gender = 'Male';
```

---

## Quick Reference

| Operation | Updatable View | Non-Updatable View |
|---|---|---|
| `SELECT` | Yes | Yes |
| `UPDATE` | Yes | No |
| `DELETE` | Yes | No |
| `INSERT` | Yes (with conditions) | No |

---

## Key Takeaways

- An updatable view must map cleanly to a **single base table** with no aggregates, `DISTINCT`, `GROUP BY`, or `UNION`
- Changes through the view write directly to the **base table**
- Always use `WITH CHECK OPTION` on filtered views to prevent rows from silently slipping out of the view after an update
- Columns with `NOT NULL` and no default value cannot be omitted in an `INSERT` through a view
