# SQL Views Lesson

> **Prerequisites:** You should be comfortable with `SELECT`, `WHERE`, `ORDER BY`, and basic functions before starting this lesson.

## Learning Objectives

By the end of this lesson you will be able to:

- Create a view to simplify a query you run often
- Query a view exactly like a regular table
- Use `CREATE OR REPLACE VIEW` to modify an existing view
- Drop a view safely with `IF EXISTS`
- Explain why views with `GROUP BY` or `DISTINCT` are not updatable

---

## Why This Matters

Imagine you work at a university help desk. Every day you run the same query to look up student contact information — `SELECT student_id, name, email FROM student`. Instead of typing that query every morning, you save it as a **view**. Now anyone on the team can run `SELECT * FROM student_contacts` without knowing the underlying query.

Views are also used to **restrict access**. A teaching assistant might see student names and grades through a view, but never see personal email addresses or dates of birth. In real-world databases with dozens of tables and hundreds of columns, views keep things manageable and secure.

---

## What is a View?

A view is a **saved SELECT query** stored as a virtual table. It has no data of its own — it reads from the underlying table every time you query it. Think of it as a "lens" or "shortcut" over your data.

---

## Why Use Views?

- **Simplify queries** — write a complex query once, reuse it like a table
- **Restrict access** — expose only certain columns to users
- **Improve readability** — give meaningful names to derived data

---

## 1. Create a View

```sql
CREATE VIEW student_contacts AS
SELECT student_id, name, email
FROM student;
```

This view hides sensitive fields and exposes only the contact information of each student.

---

## 2. Query a View

Views are queried exactly like regular tables.

```sql
SELECT * FROM student_contacts;
```

---

## 3. View with a WHERE Clause

You can filter rows inside a view.

```sql
CREATE VIEW female_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Female';

SELECT * FROM female_students;
```

---

## 4. View with a Computed Column

Views can include calculated values. This example calculates each student's current age.

```sql
CREATE VIEW student_ages AS
SELECT student_id, name,
       TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
FROM student;

SELECT * FROM student_ages;
```

---

## 5. Create or Replace a View

Updates an existing view without dropping it first.

```sql
CREATE OR REPLACE VIEW student_contacts AS
SELECT student_id, name, email, gender
FROM student;

SELECT * FROM student_contacts;
```

---

## 6. Drop a View

Removes a view. `IF EXISTS` prevents an error if it has already been deleted. This does **not** delete the underlying table data.

```sql
DROP VIEW IF EXISTS female_students;
DROP VIEW IF EXISTS student_ages;
DROP VIEW IF EXISTS student_contacts;
```

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Assuming view data is cached | Slow queries on large tables — MySQL re-runs the SELECT every time you query the view | Understand that views are virtual, not materialized. If performance matters, consider indexing the base table |
| Using `ORDER BY` inside a view definition | MySQL may ignore `ORDER BY` in a view — the result order is unreliable unless the outer query also specifies it | Put `ORDER BY` in the query that reads from the view, not inside the view definition |
| Dropping a view and expecting data loss | Nothing happens to the base table data | Remember: `DROP VIEW` only removes the shortcut, not the underlying data |
| Creating a view with `SELECT *` | If columns are added or removed from the base table, the view may break or return unexpected results | List columns explicitly in the view definition |

---

## When to Use / When NOT to Use

| Use Views When... | Avoid Views When... |
|-------------------|---------------------|
| You repeat the same query often | The underlying query is trivial (a view adds indirection without benefit) |
| You want to hide columns from certain users | You need the results cached for performance (views re-query every time) |
| You want to give a readable name to a complex JOIN or calculation | The view logic changes so frequently that maintaining it becomes overhead |
| You need to present a simplified interface over a complex schema | You are the only user and the raw query is simple enough |

---

## Key Limitations in MySQL

- Views **cannot** use variables or dynamic SQL
- Views with `GROUP BY`, `DISTINCT`, or aggregate functions (`SUM`, `COUNT`, etc.) are **not updatable** — you can `SELECT` from them but not `INSERT`, `UPDATE`, or `DELETE` through them

---

## Quick Reference

| Statement | Purpose |
|---|---|
| `CREATE VIEW` | Save a SELECT query as a virtual table |
| `SELECT * FROM view` | Query a view like a regular table |
| `CREATE OR REPLACE VIEW` | Update a view without dropping it first |
| `DROP VIEW IF EXISTS` | Delete a view (data in base table is untouched) |

---

## What's Next?

In the next lesson you will learn about **updatable views** — views you can `INSERT`, `UPDATE`, and `DELETE` through, writing changes directly to the base table. You will also learn about `WITH CHECK OPTION`, the safety net that prevents rows from silently disappearing from a filtered view.
