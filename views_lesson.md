# SQL Views Lesson

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
