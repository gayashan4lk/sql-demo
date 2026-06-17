# SQL Joins Lesson

> **Prerequisites:** You should be comfortable with `SELECT`, `WHERE`, and `ORDER BY`. This is the foundation the rest of the path builds on — Views, Stored Procedures, and Indexing all assume you can join tables.

## Learning Objectives

By the end of this lesson you will be able to:

- Explain why related data is split across tables and how a join recombines it
- Write an `INNER JOIN` using `ON` and table aliases
- Join three or more tables through a junction table
- Use `LEFT JOIN` to keep unmatched rows, and read the `NULL`s it produces
- Find rows that have *no* match with the anti-join pattern (`LEFT JOIN ... WHERE x IS NULL`)
- Use `RIGHT JOIN` and know it is just a mirror of `LEFT JOIN`
- Avoid the classic trap where a condition in `WHERE` silently turns a `LEFT JOIN` into an `INNER JOIN`
- Recognise self-joins and `CROSS JOIN`

---

## Why This Matters

The database does not keep everything in one big table. Instead it **normalises** — each fact lives
in one place. The `enrollment` table records *which student takes which course*, but it does not
store names; it stores **ids**:

```sql
SELECT * FROM enrollment LIMIT 2;
-- enrollment_id | student_id | course_id | enrolled_date | status
--             1 |          1 |         1 | 2025-09-01    | Completed
--             2 |          1 |         4 | 2025-09-01    | Completed
```

That is efficient to store, but useless to read on its own — `student_id = 1` means nothing to a
human. To answer a real question like *"which courses is Alice taking?"* you must **recombine** the
`student` table with the `enrollment` table. That recombination is a **join**. Joins are how you turn
normalised ids back into readable answers, and almost every non-trivial query uses one.

---

## 1. The Tables We'll Join

Four tables, linked by foreign keys:

```
student ──< enrollment >── course
              │
              └──< grade
```

- **`student`** — `student_id` (PK), `name`, `email`, ...
- **`course`** — `course_id` (PK), `course_code`, `course_name`, ...
- **`enrollment`** — a **junction table**: each row links one `student_id` to one `course_id`, plus a
  `status`. This is how a *many-to-many* relationship (many students, many courses) is stored.
- **`grade`** — `grade_id` (PK), `enrollment_id`, `letter_grade`, `numeric_grade`. Not every
  enrollment has one yet.

`<` and `>` point to the "many" side: one student has many enrollments; one course has many
enrollments; one enrollment has at most one grade.

---

## 2. INNER JOIN

An `INNER JOIN` combines rows from two tables wherever a condition matches, and **keeps only the
matches**. Match `student.student_id` to `enrollment.student_id`:

```sql
SELECT s.name, e.course_id, e.status
FROM student AS s
INNER JOIN enrollment AS e
    ON s.student_id = e.student_id;
```

```text
name           | course_id | status
Alice Johnson  |         1 | Completed
Alice Johnson  |         4 | Completed
Alice Johnson  |         6 | Completed
Bob Smith      |         1 | Completed
...
```

Three things to notice:

- **Aliases** (`AS s`, `AS e`) keep the query short. You can write `s.name` instead of
  `student.name`. The `AS` keyword is optional: `student s` works too.
- **`ON`** states *how* the tables relate — here, the shared `student_id`. This is the heart of the
  join.
- **Qualify your columns.** `e.course_id` says *which* table's `course_id` you mean. If a column name
  exists in both tables, an unqualified reference is an "ambiguous column" error.

> Plain `JOIN` means `INNER JOIN` — the `INNER` keyword is optional. We spell it out here for
> clarity; in practice most people write just `JOIN`.

---

## 3. Joining Through a Junction (three tables)

`enrollment` links students to courses but holds only ids. To show student **names** alongside course
**names**, join all three tables in one query — chain a second `JOIN`:

```sql
SELECT s.name, c.course_code, c.course_name, e.status
FROM student AS s
JOIN enrollment AS e ON s.student_id = e.student_id
JOIN course     AS c ON e.course_id  = c.course_id
ORDER BY s.name;
```

```text
name           | course_code | course_name                      | status
Alice Johnson  | CS101       | Introduction to Computer Science | Completed
Alice Johnson  | MATH101     | Calculus I                       | Completed
Alice Johnson  | ENG101      | English Composition              | Completed
Bob Smith      | CS101       | Introduction to Computer Science | Completed
...
```

Each `JOIN` adds one table and one `ON` that links it to a table already in the query. This
`student → enrollment → course` pattern is the workhorse of the whole schema — every later lesson
that touches enrollments uses it.

---

## 4. LEFT JOIN

An `INNER JOIN` drops rows with no match. A **`LEFT JOIN`** keeps **every row from the left table**,
and fills the right table's columns with `NULL` where there is no match.

Not every enrollment has been graded yet, so join `enrollment` to `grade` with a `LEFT JOIN` to list
*all* enrollments — graded or not:

```sql
SELECT e.enrollment_id, e.student_id, e.status, g.letter_grade, g.numeric_grade
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
ORDER BY e.enrollment_id;
```

```text
enrollment_id | student_id | status    | letter_grade | numeric_grade
            1 |          1 | Completed | A            | 92.50
            2 |          1 | Completed | B            | 85.00
            6 |          3 | Active    | NULL         | NULL     ← no grade yet
            7 |          3 | Active    | NULL         | NULL
           10 |          5 | Active    | NULL         | NULL
...
```

The ungraded enrollments still appear; their `grade` columns are `NULL`. An `INNER JOIN` here would
have silently dropped all 14 ungraded enrollments. **`LEFT JOIN` is how you say "keep them anyway."**

> "Left" and "right" refer to the order in the query: the table before `LEFT JOIN` is the left one
> (kept in full); the table after it is the right one (matched, or `NULL`).

---

## 5. Finding Unmatched Rows (anti-join)

Because unmatched rows have `NULL` on the right side, you can **filter for exactly those** — the rows
with no match. This is the **anti-join** idiom: `LEFT JOIN`, then `WHERE <right-table column> IS NULL`.

Find every enrollment that has **no grade yet**:

```sql
SELECT e.enrollment_id, e.student_id, e.course_id, e.status
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
WHERE g.grade_id IS NULL;
```

```text
enrollment_id | student_id | course_id | status
            6 |          3 |         1 | Active
            7 |          3 |         6 | Active
           10 |          5 |         1 | Active
... (14 rows total)
```

Test the `IS NULL` against a column that is **never** `NULL` for a real match — a primary key like
`g.grade_id` is perfect. If the row matched, `grade_id` has a value; if it did not, it is `NULL`.

---

## 6. RIGHT JOIN

A `RIGHT JOIN` keeps every row from the **right** table instead of the left. It is just a mirror
image — `A RIGHT JOIN B` returns the same rows as `B LEFT JOIN A`:

```sql
-- These two are equivalent:
SELECT ... FROM grade AS g RIGHT JOIN enrollment AS e ON g.enrollment_id = e.enrollment_id;
SELECT ... FROM enrollment AS e LEFT JOIN grade AS g ON g.enrollment_id = e.enrollment_id;
```

Most people stick to `LEFT JOIN` and put the table they want to keep on the left — it reads more
naturally. `RIGHT JOIN` is worth recognising but rarely worth writing.

> **MySQL has no `FULL OUTER JOIN`** (keep unmatched rows from *both* sides). If you ever need it,
> emulate it with `LEFT JOIN ... UNION ... RIGHT JOIN ...`. For basic work you will not.

---

## 7. `ON` vs `WHERE` — the classic trap

This is the mistake that catches everyone. Putting a condition on the **right** table in the `WHERE`
clause silently turns your `LEFT JOIN` back into an `INNER JOIN`.

```sql
-- ❌ Looks like a LEFT JOIN, behaves like an INNER JOIN.
-- The WHERE drops every row where g.letter_grade is NULL — i.e. every unmatched row.
SELECT e.enrollment_id, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g ON g.enrollment_id = e.enrollment_id
WHERE g.letter_grade = 'A';

-- ✅ Condition in the ON clause: unmatched enrollments are KEPT (with NULL grade),
--    and only matching grades are restricted to 'A'.
SELECT e.enrollment_id, g.letter_grade
FROM enrollment AS e
LEFT JOIN grade AS g
    ON g.enrollment_id = e.enrollment_id
   AND g.letter_grade = 'A';
```

The rule: a condition that should **restrict the match** goes in `ON`; a condition that should
**filter the final result** goes in `WHERE`. For an `INNER JOIN` it makes no difference — but for a
`LEFT JOIN` it changes everything. (Filtering on the *left* table in `WHERE` is fine and common.)

---

## 8. Joining + Aggregating

Joins combine with `GROUP BY` to answer "how many" questions. Count how many of each student's
enrollments have been graded, keeping students whose count is zero by using a `LEFT JOIN` and
`COUNT(g.grade_id)` (which ignores `NULL`s):

```sql
SELECT s.name,
       COUNT(e.enrollment_id) AS enrollments,
       COUNT(g.grade_id)      AS graded
FROM student AS s
JOIN      enrollment AS e ON e.student_id    = s.student_id
LEFT JOIN grade      AS g ON g.enrollment_id = e.enrollment_id
GROUP BY s.student_id, s.name
ORDER BY s.name;
```

```text
name           | enrollments | graded
Alice Johnson  |           3 |      3
Clara Davis    |           2 |      0
Eva Martinez   |           3 |      0
...
```

`COUNT(g.grade_id)` counts only the non-`NULL` matches, so a student with enrollments but no grades
shows `graded = 0` — exactly what you want.

---

## 9. Self-Joins and CROSS JOIN (briefly)

Two more joins you should recognise:

- **Self-join** — a table joined to *itself*, using two aliases, to relate rows within one table
  (e.g. pairing students who share a `course_id`). The mechanics are identical; only the two aliases
  of the same table are new.
- **`CROSS JOIN`** — every row of one table paired with every row of the other (a *Cartesian
  product*), with **no `ON`**. 11 students × 9 courses = 99 rows. Occasionally useful for generating
  combinations — but usually a `CROSS JOIN` you see is an **accident**: forgetting the `ON` on a
  normal join produces the same explosion of rows.

```sql
SELECT s.name, c.course_code
FROM student AS s
CROSS JOIN course AS c;   -- 99 rows: every student paired with every course
```

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Forgetting the `ON` clause | Accidental `CROSS JOIN` — every row paired with every row | Always give a `JOIN` an `ON` that links the tables |
| Unqualified column in both tables | "Column 'x' in field list is ambiguous" error | Qualify with the alias: `e.course_id` |
| Right-table condition in `WHERE` on a `LEFT JOIN` | Unmatched rows are dropped — it becomes an `INNER JOIN` | Put match conditions in `ON`; keep result filters for the left table |
| Expecting `FULL OUTER JOIN` | Syntax error — MySQL does not support it | Use `LEFT JOIN ... UNION ... RIGHT JOIN` |
| Surprised by duplicate rows | One-to-many joins repeat the "one" side for each "many" match | Expected behaviour; use `GROUP BY`/`DISTINCT` if you need one row |
| Using `INNER JOIN` when you meant "keep all" | Rows with no match silently disappear | Use `LEFT JOIN` when the left side must always appear |

---

## When to Use Which Join

| You want... | Use |
|-------------|-----|
| Only rows that exist in **both** tables | `INNER JOIN` |
| **All** rows of the main table, with matches where they exist | `LEFT JOIN` |
| The mirror of the above (keep the other table in full) | `RIGHT JOIN` |
| Rows in the main table with **no** match in the other | `LEFT JOIN ... WHERE rightPK IS NULL` |
| Every combination of two tables | `CROSS JOIN` |

---

## Quick Reference

| Syntax | Purpose |
|---|---|
| `FROM a JOIN b ON a.id = b.a_id` | Inner join — keep only matches |
| `FROM a LEFT JOIN b ON ...` | Keep all of `a`; `b` columns `NULL` when unmatched |
| `FROM a RIGHT JOIN b ON ...` | Keep all of `b` (mirror of `LEFT`) |
| `FROM a JOIN b ON ... JOIN c ON ...` | Chain three+ tables |
| `FROM a CROSS JOIN b` | Every combination (Cartesian product) |
| `... LEFT JOIN b ON ... WHERE b.pk IS NULL` | Anti-join — rows of `a` with no `b` |
| `FROM t AS x JOIN t AS y ON ...` | Self-join (one table, two aliases) |

---

## What's Next?

Next is **[Views](../01-views/lesson.md)** — saved, named `SELECT` queries you can treat like a
table. Almost every useful view wraps a `JOIN` like the ones above, giving a readable name to the
"student → enrollment → course" query so you never have to retype it. Everything you just learned is
the raw material the rest of this path is built from.
