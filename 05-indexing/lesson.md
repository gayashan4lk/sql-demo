# SQL Indexing Lesson

> **Prerequisites:** You should be comfortable with `SELECT`, `WHERE`, `JOIN`, and `ORDER BY`, and have completed the [Triggers](../04-triggers/lesson.md) lesson. Indexing is about *how* the database finds rows for those queries — nothing new about writing them, just how fast they run.

## Learning Objectives

By the end of this lesson you will be able to:

- Explain what an index is and the B-tree idea behind it
- Read an `EXPLAIN` plan and interpret the `type`, `possible_keys`, `key`, `rows`, and `Extra` columns
- Create single-column, composite, and unique indexes with the `idx_` naming convention
- Recognise that `PRIMARY KEY` and `UNIQUE` constraints already build indexes for you
- Apply the **leftmost-prefix rule** to know which queries a composite index helps
- Spot a **covering index** (`Using index`) and why it is fast
- Recognise what *stops* an index from being used — functions on a column, leading wildcards, type mismatch
- Weigh the cost of indexes on writes, and list, inspect, and drop them

---

## Why This Matters

Imagine the registrar needs the student whose email is `grace.taylor@email.com`. With no help, the database does what you would do with an **unsorted** list of names: start at the top and read every single row until it finds a match — a **full table scan**. With 11 students that is instant. With 11 million it is a disaster.

An **index** is the database's version of the alphabetised tabs in a phone book. Instead of reading every row, it jumps straight to the right place. The query you wrote does not change at all — the database just finds the answer a different, faster way.

Indexing is the single biggest lever you have over query performance. The skill is not memorising syntax (it is one line); it is learning to **read the plan** and tell whether the database is scanning or seeking.

---

## What is an Index?

An index is a **separate, sorted copy of one or more columns**, kept alongside the table, with a pointer from each entry back to the full row. MySQL stores it as a **B-tree**: a balanced tree that lets the engine narrow down to a value in a handful of steps instead of reading everything.

| | No index | With an index |
|---|---|---|
| How a `WHERE email = ...` runs | Reads every row, checks each (**full scan**) | Walks the B-tree straight to the value (**seek**) |
| Cost as the table grows | Linear — doubles when the table doubles | Roughly flat — a few steps even for millions of rows |
| Storage / write cost | None | Extra storage; every write must update the index too |

You already have indexes without knowing it. **Every `PRIMARY KEY` is an index**, and so is **every `UNIQUE` constraint**. In our schema that means `student.student_id`, `student.email`, `course.course_code`, and `enrollment(student_id, course_id)` are *all* already indexed — the database built those the moment the tables were created.

> An index is pure overhead until a query uses it. It speeds up reads and slows down writes. The art is indexing the columns you actually search on, and nothing more.

---

## 1. Reading `EXPLAIN`

`EXPLAIN` shows the **plan** the optimiser chose for a query — without running it. It is the one diagnostic you will use constantly. Put it in front of any `SELECT`:

```sql
EXPLAIN SELECT * FROM student WHERE name = 'Grace Taylor';
```

```text
+----+-------------+---------+------+---------------+------+---------+------+------+-------------+
| id | select_type | table   | type | possible_keys | key  | key_len | ref  | rows | Extra       |
+----+-------------+---------+------+---------------+------+---------+------+------+-------------+
|  1 | SIMPLE      | student | ALL  | NULL          | NULL | NULL    | NULL |   11 | Using where |
+----+-------------+---------+------+---------------+------+---------+------+------+-------------+
```

> **Seeing a tree instead of a table?** On MySQL 8.0.18+ (incl. 9.x) some clients
> render `EXPLAIN` in *tree* format — e.g. `-> Table scan on student (rows=11)`
> with a `-> Filter:` node above it. That's the **same plan**, just drawn
> bottom-up: `Table scan` ≙ `type: ALL` with `key: NULL` (a full scan), and the
> `Filter:` node ≙ `Extra: Using where`. To get the exact table shown here, ask
> for it explicitly:
>
> ```sql
> EXPLAIN FORMAT=TRADITIONAL SELECT * FROM student WHERE name = 'Grace Taylor';
> ```

The columns that matter:

| Column | What it tells you |
|---|---|
| `type` | The access method. Worst-to-best: `ALL` (full scan) → `index` → `range` → `ref` → `eq_ref` → `const`. Seeing **`ALL` is the red flag.** |
| `possible_keys` | Indexes the optimiser *could* use. `NULL` means no index even applies. |
| `key` | The index actually chosen. `NULL` means none was used. |
| `rows` | Estimated rows examined. Lower is better. |
| `Extra` | Notes like `Using where`, `Using index` (covering — great), `Using filesort`, `Using temporary`. |

Above, `name` has no index: `possible_keys` is `NULL`, `key` is `NULL`, `type` is `ALL`, and it expects to examine all 11 rows. That is a full scan.

---

## 2. Creating a Single-Column Index

`name` is searched but not indexed. Let's fix that:

```sql
CREATE INDEX idx_student_name ON student(name);
```

Now re-run the exact same `EXPLAIN`:

```sql
EXPLAIN SELECT * FROM student WHERE name = 'Grace Taylor';
```

```text
+----+-------------+---------+------+------------------+------------------+---------+-------+------+-------+
| id | select_type | table   | type | possible_keys    | key              | key_len | ref   | rows | Extra |
+----+-------------+---------+------+------------------+------------------+---------+-------+------+-------+
|  1 | SIMPLE      | student | ref  | idx_student_name | idx_student_name | 402     | const |    1 | NULL  |
+----+-------------+---------+------+------------------+------------------+---------+-------+------+-------+
```

`type` went from `ALL` to `ref`, `key` is now `idx_student_name`, and `rows` dropped from 11 to 1. The database now seeks straight to Grace instead of reading the whole table.

> **Naming:** use `idx_<table>_<column>` — e.g. `idx_student_name`. Consistent names make `SHOW INDEX` output and `DROP INDEX` statements obvious.

---

## 3. Unique Indexes

A **unique index** does everything a normal index does *and* rejects duplicate values — the index is how the database enforces uniqueness cheaply.

This is exactly why `email` is already fast to search. Look:

```sql
SHOW INDEX FROM student;
```

```text
+---------+------------+------------------+--------------+-------------+
| Table   | Non_unique | Key_name         | Seq_in_index | Column_name |
+---------+------------+------------------+--------------+-------------+
| student |          0 | PRIMARY          |            1 | student_id  |
| student |          0 | email            |            1 | email       |   <- from the UNIQUE constraint
| student |          1 | idx_student_name |            1 | name        |   <- the one we just added
+---------+------------+------------------+--------------+-------------+
```

`Non_unique = 0` marks the unique ones. The `email` index was created automatically by `email VARCHAR(150) NOT NULL UNIQUE`. So `EXPLAIN SELECT * FROM student WHERE email = '...'` already shows `type: const` with no work from you.

When a column *should* be unique but has no constraint yet, you add the protection (and the speed) with one statement:

```sql
CREATE UNIQUE INDEX idx_course_name ON course(course_name);
-- Now two courses can never share a name, AND lookups by course_name are fast.
```

> A `UNIQUE` index will **reject** the `CREATE` itself if the column already contains duplicates. Clean the data first, then add it.

---

## 4. Composite Indexes & the Leftmost-Prefix Rule

A **composite index** covers several columns in order. It is sorted by the first column, then the second within that, like a phone book sorted by last name, then first name.

```sql
CREATE INDEX idx_course_dept_credits ON course(department, credits);
```

The order is everything. A composite index can only be used **left-to-right, with no gaps** — the **leftmost-prefix rule**:

| Query | Uses `idx_course_dept_credits`? |
|---|---|
| `WHERE department = 'Computer Science'` | ✅ Yes — uses the leading column |
| `WHERE department = 'Computer Science' AND credits = 3` | ✅ Yes — uses both columns |
| `WHERE credits = 3` | ❌ No — skips the leading column, so the index cannot be entered |

```sql
EXPLAIN SELECT * FROM course WHERE department = 'Physics';
-- possible_keys / key = idx_course_dept_credits   (leading column → used)

EXPLAIN SELECT * FROM course WHERE credits = 3;
-- possible_keys = NULL, type = ALL                (no leading column → full scan)
```

> Rule of thumb: put the column you filter on **most often, by equality** first. A single composite `(department, credits)` index also serves every `WHERE department = ...` query, so you rarely need a separate index on `department` alone.

---

## 5. Covering Indexes

If an index contains **every column the query needs**, the database answers from the index alone and never touches the table. `Extra` shows **`Using index`**. This is about as fast as it gets.

Our `idx_course_dept_credits` covers `department` and `credits`, so:

```sql
EXPLAIN SELECT department, credits FROM course WHERE department = 'Physics';
```

```text
... | key                     | ... | Extra       |
... | idx_course_dept_credits | ... | Using index |
```

`Using index` = covering. But add a column the index does *not* hold and it must go back to the table:

```sql
EXPLAIN SELECT department, credits, course_name FROM course WHERE department = 'Physics';
-- Extra: Using index condition (or Using where) — course_name forces a row lookup
```

> A covering index is just a normal index that happens to include every column a particular query reads. You do not declare it specially — you design the column list so common queries are covered.

---

## 6. What Stops an Index From Being Used

An index on a column does **not** guarantee it gets used. The query has to be **sargable** (Search-ARGument-able). These common patterns silently defeat an index:

```sql
-- Suppose we index date_of_birth:
CREATE INDEX idx_student_dob ON student(date_of_birth);

-- ❌ Function wraps the column → index unusable, full scan
EXPLAIN SELECT * FROM student WHERE YEAR(date_of_birth) = 2001;

-- ✅ Rewrite as a range on the bare column → index can be used
EXPLAIN SELECT * FROM student
WHERE date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01';
```

| Pattern | Why it kills the index | Fix |
|---|---|---|
| `WHERE YEAR(col) = 2001` | A function on the column hides the stored value | Rewrite as a range on the bare column |
| `WHERE name LIKE '%son'` | A **leading** wildcard means no sorted prefix to seek | A trailing wildcard `'Grace%'` *can* use the index |
| `WHERE student_id = '5'` (string vs INT) | Type mismatch forces a conversion on every row | Compare with the matching type: `= 5` |
| `WHERE a = 1 OR b = 2` (only `a` indexed) | The `OR` branch on `b` needs the whole table anyway | Index both, or split into a `UNION` |

> "Wrapping the column in a function" is the most common cause of a mysteriously slow query. Keep the indexed column **bare** on one side of the comparison.

---

## 7. A Note on Small Tables

Our seed tables are tiny — 11 students, 9 courses, 24 enrollments. With so few rows, the optimiser will often **choose a full scan even when an index exists**, because reading 11 rows is genuinely cheaper than navigating a B-tree. You may see `possible_keys` list your index while `key` stays `NULL`.

**That is correct behaviour, not a broken index.** When you experiment here, read the plan to understand the *decision* — check that your index shows up in `possible_keys` (proof it applies) — and trust that on a production-size table the optimiser would pick it. The reasoning you practise is exactly what scales.

---

## 8. Listing & Dropping Indexes

```sql
-- See every index on a table (PRIMARY, UNIQUE constraints, and ones you added)
SHOW INDEX FROM course;

-- Remove an index by name
DROP INDEX idx_course_dept_credits ON course;
```

Indexes are not free: every `INSERT`, `UPDATE`, and `DELETE` must also update each index on the table, and each index costs storage. Drop indexes you are not using.

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Wrapping the indexed column in a function (`YEAR(col)`, `LOWER(col)`) | Index ignored, full scan | Keep the column bare; rewrite as a range |
| Expecting `WHERE second_col = ...` to use a composite index | Index skipped — leftmost-prefix rule | Put the most-filtered equality column first |
| Leading wildcard `LIKE '%abc'` | Full scan — no sortable prefix | Use a trailing wildcard, or a full-text index |
| Re-indexing a column that a `PRIMARY KEY`/`UNIQUE` already covers | A redundant duplicate index wasting space and write time | Run `SHOW INDEX` first — constraints already build indexes |
| Indexing every column "just in case" | Writes slow down, storage balloons | Index the columns you filter/join/sort on, no more |
| Assuming `EXPLAIN` on tiny data proves the index is unused | Optimiser correctly prefers a scan on small tables | Check `possible_keys`; reason about scale (see §7) |
| Comparing a `VARCHAR`/INT against the wrong type | Implicit conversion disables the index | Match the column's declared type in the comparison |

---

## When to Add an Index / When NOT to

| Add an index when... | Avoid / reconsider when... |
|----------------------|----------------------------|
| The column appears in `WHERE`, `JOIN ... ON`, or `ORDER BY` | The table is write-heavy and rarely queried on that column |
| The column is selective (many distinct values, like `email`) | The column has very few distinct values (e.g. a 3-value status) |
| A query is slow and `EXPLAIN` shows `type: ALL` on a big table | A `PRIMARY KEY`/`UNIQUE` already indexes it |
| A composite `(a, b)` would serve several common queries | You would never query on that column's leading position |

---

## Quick Reference

| Statement | Purpose |
|---|---|
| `EXPLAIN SELECT ...` | Show the query plan (no rows returned) |
| `EXPLAIN FORMAT=JSON SELECT ...` | A detailed plan with cost estimates |
| `EXPLAIN FORMAT=TRADITIONAL SELECT ...` | Force the classic table layout (vs. tree on MySQL 9.x) |
| `CREATE INDEX idx_t_col ON t(col)` | Add a single-column index |
| `CREATE INDEX idx_t_a_b ON t(a, b)` | Add a composite index (order matters) |
| `CREATE UNIQUE INDEX idx_t_col ON t(col)` | Add an index that also enforces uniqueness |
| `SHOW INDEX FROM t` | List every index on a table |
| `DROP INDEX idx_t_col ON t` | Remove an index |

---

## What's Next?

Next you will learn about **transaction processing** — how to group several statements so they all succeed or all fail together. You will use `START TRANSACTION`, `COMMIT`, and `ROLLBACK` to move money between a `student_account` and a `payment` record without ever leaving the data half-updated.
