# SQL Indexing — Practice Problems

> **Setup:** Run `schema/reset.sql` before starting. These problems use the `student` and `course` tables (the Bonus also reasons about `enrollment`). Run the **Cleanup** block at the end to drop every index you add, or re-run `schema/reset.sql` any time the schema drifts.

Try the SQL yourself before checking the hint or solution. Use `EXPLAIN` to inspect the plan, follow the `idx_<table>_<column(s)>` naming convention, and run `SHOW INDEX FROM <table>` whenever you want to see what already exists.

> These problems assume **MySQL 8.0+**. The seed tables are tiny, so the optimiser may **choose a full scan even after you add an index** — that is correct (see §7 of the lesson). Judge your answer by whether the index shows up in `possible_keys`, not only by whether `key` is filled in.

---

## Problem 1 — Index a Searched Column (Easy)

The registrar frequently looks students up by `name`, but that column has no index.

**Your task:**
1. Run `EXPLAIN` on `SELECT * FROM student WHERE name = 'Henry Brown';` and note the `type` and `possible_keys`
2. Create an index called `idx_student_name` on `student(name)`
3. Re-run the same `EXPLAIN` and compare

**Expected:** Before, `possible_keys` is `NULL` and `type` is `ALL`. After, `idx_student_name` appears in `possible_keys` (and on a real-sized table would be chosen as `key`).

<details>
<summary>Hint</summary>

The syntax is `CREATE INDEX idx_student_name ON student(name);`. Run the *exact same* `EXPLAIN SELECT ...` before and after so the only thing that changed is the index.

</details>

<details>
<summary>Solution</summary>

```sql
-- Before: full scan, no index applies
EXPLAIN SELECT * FROM student WHERE name = 'Henry Brown';

-- Add the index
CREATE INDEX idx_student_name ON student(name);

-- After: idx_student_name now appears in possible_keys
EXPLAIN SELECT * FROM student WHERE name = 'Henry Brown';
```

**What you practiced:** Turning a full table scan into an indexed lookup, and using `EXPLAIN` before/after to prove the change.

</details>

---

## Problem 2 — Discover Indexes You Already Have (Easy)

Before adding an index, a good engineer checks what already exists. Some columns are already indexed by their constraints.

**Your task:**
1. Run `SHOW INDEX FROM student` and identify which columns are already indexed and which are unique
2. Run `EXPLAIN` on `SELECT * FROM student WHERE email = 'eva.martinez@email.com';` and explain why it is already fast even though you never created an index on `email`
3. Then add a plain index `idx_course_department` on `course(department)` and `EXPLAIN SELECT * FROM course WHERE department = 'Mathematics';`

**Expected:** `SHOW INDEX` lists `PRIMARY` (on `student_id`) and a unique index on `email`, both with `Non_unique = 0`. The email query uses that unique index (`type` `const`/`ref`). The department query picks up `idx_course_department` in `possible_keys`.

<details>
<summary>Hint</summary>

`email VARCHAR(150) NOT NULL UNIQUE` in the schema automatically created an index — a `UNIQUE` constraint *is* an index. In `SHOW INDEX` output, `Non_unique = 0` marks the unique ones.

</details>

<details>
<summary>Solution</summary>

```sql
-- 1. See what already exists
SHOW INDEX FROM student;
-- PRIMARY on student_id (Non_unique 0), and a unique index on email (Non_unique 0)

-- 2. email is already indexed by its UNIQUE constraint → already fast
EXPLAIN SELECT * FROM student WHERE email = 'eva.martinez@email.com';

-- 3. department has no constraint, so add a plain index
CREATE INDEX idx_course_department ON course(department);
EXPLAIN SELECT * FROM course WHERE department = 'Mathematics';
```

**What you practiced:** Reading `SHOW INDEX` to avoid creating redundant indexes, and understanding that `PRIMARY KEY` and `UNIQUE` constraints build indexes for free.

</details>

---

## Problem 3 — Composite Index & Leftmost Prefix (Medium)

Courses are often filtered by department, sometimes also by credit count. One composite index can serve both — but only if the column order is right.

**Your task:**
1. Create a composite index `idx_course_dept_credits` on `course(department, credits)`
2. Run `EXPLAIN` on three queries and record which use the index:
   - `WHERE department = 'Computer Science'`
   - `WHERE department = 'Computer Science' AND credits = 3`
   - `WHERE credits = 3`
3. Explain the result of the third query

**Expected:** Queries 1 and 2 can use `idx_course_dept_credits`. Query 3 cannot — it skips the leading column `department`, so the leftmost-prefix rule blocks the index (`possible_keys` is `NULL`).

<details>
<summary>Hint</summary>

A composite index is sorted by its first column, then the second within that. You can only enter it from the **left**. `credits` alone is like trying to find a phone-book entry by first name only.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE INDEX idx_course_dept_credits ON course(department, credits);

-- ✅ leading column → index applies
EXPLAIN SELECT * FROM course WHERE department = 'Computer Science';

-- ✅ both columns → index applies
EXPLAIN SELECT * FROM course WHERE department = 'Computer Science' AND credits = 3;

-- ❌ skips the leading column → possible_keys = NULL, full scan
EXPLAIN SELECT * FROM course WHERE credits = 3;
```

**What you practiced:** The leftmost-prefix rule — a composite `(a, b)` index helps `a` and `a + b`, but never `b` alone.

</details>

---

## Problem 4 — Build a Covering Index (Medium)

A covering index holds every column a query needs, so the database answers from the index alone — `Extra` shows `Using index`.

**Your task:**
1. Keep `idx_course_dept_credits` from Problem 3 (or recreate it)
2. Run `EXPLAIN SELECT department, credits FROM course WHERE department = 'English';` and confirm `Extra` shows `Using index`
3. Run `EXPLAIN SELECT department, credits, course_name FROM course WHERE department = 'English';` and explain why `Extra` changes

**Expected:** The first query is covered (`Using index`). The second adds `course_name`, which is not in the index, so the engine must look up the full row and `Using index` disappears.

<details>
<summary>Hint</summary>

A covering index is not a special declaration — it is just an index that happens to contain all the columns the `SELECT` reads. Add a column the index does not hold and the trick breaks.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE INDEX idx_course_dept_credits ON course(department, credits);  -- if not already present

-- ✅ both selected columns are in the index → Using index (covering)
EXPLAIN SELECT department, credits FROM course WHERE department = 'English';

-- ❌ course_name is NOT in the index → row lookup, no longer covering
EXPLAIN SELECT department, credits, course_name FROM course WHERE department = 'English';
```

**What you practiced:** Recognising a covering index from `Using index` in `Extra`, and seeing how adding an un-indexed column to the `SELECT` defeats it.

</details>

---

## Problem 5 — Make a Query Sargable (Hard)

The office wants all students born in 2001. The obvious query wraps the column in a function, which disables any index.

**Your task:**
1. Create an index `idx_student_dob` on `student(date_of_birth)`
2. Run `EXPLAIN SELECT * FROM student WHERE YEAR(date_of_birth) = 2001;` and confirm the index is **not** used
3. Rewrite the query as a date **range** that returns the same students but lets the index apply, and `EXPLAIN` it
4. Confirm both queries return the same rows

**Expected:** The `YEAR(...)` version shows `possible_keys = NULL` (a function hides the column). The range version `date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01'` keeps the column bare, so `idx_student_dob` appears in `possible_keys`. Both return the students born in 2001 (Alice Johnson, Eva Martinez, James Thomas).

<details>
<summary>Hint</summary>

The index stores raw `date_of_birth` values, not `YEAR(date_of_birth)`. Compare the **bare** column against a half-open range `[2001-01-01, 2002-01-01)` instead of computing a function on every row.

</details>

<details>
<summary>Solution</summary>

```sql
CREATE INDEX idx_student_dob ON student(date_of_birth);

-- ❌ function on the column → index unusable
EXPLAIN SELECT * FROM student WHERE YEAR(date_of_birth) = 2001;

-- ✅ range on the bare column → index can be used, same result
EXPLAIN SELECT * FROM student
WHERE date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01';

-- Confirm identical results
SELECT name, date_of_birth FROM student WHERE YEAR(date_of_birth) = 2001;
SELECT name, date_of_birth FROM student
WHERE date_of_birth >= '2001-01-01' AND date_of_birth < '2002-01-01';
```

**What you practiced:** Sargability — keeping the indexed column bare and rewriting a function filter as a range so the optimiser can use the index.

</details>

---

## Bonus — Read the Plan

No SQL to write — just interpret this `EXPLAIN` row for a query on a large `enrollment` table:

```text
| type | possible_keys           | key  | rows   | Extra       |
| ALL  | idx_enrollment_status   | NULL | 480000 | Using where |
```

**Questions:**
1. Is the index being used? How can you tell?
2. The index *applies* (it is in `possible_keys`) but was not chosen. Give one plausible reason.
3. What would you check next to decide whether this is a problem?

<details>
<summary>Answer</summary>

1. **No.** `key` is `NULL` and `type` is `ALL`, so the engine is doing a full table scan of ~480,000 rows.
2. The optimiser judged the index **not selective enough** — `status` has only a few distinct values (`Active`/`Dropped`/`Completed`), so a query matching, say, `status = 'Active'` may hit a large fraction of the table. Scanning can be cheaper than millions of index-then-row lookups. (On tiny tables the same thing happens for a different reason: there are too few rows to bother.)
3. Check **how many rows actually match** (`SELECT COUNT(*) ... WHERE status = 'Active'`). If it is a small fraction, the index should help and a composite index leading with a more selective column might be the fix. If it is most of the table, the scan is correct and an index will not help.

**What you practiced:** Reading a plan to tell scan from seek, and reasoning about index *selectivity* rather than assuming "indexed column = index used."

</details>

---

## Cleanup

Drop every index added in these problems to restore the original schema:

```sql
DROP INDEX idx_student_name        ON student;
DROP INDEX idx_student_dob         ON student;
DROP INDEX idx_course_department   ON course;
DROP INDEX idx_course_dept_credits ON course;

-- Or simply re-run the full schema to restore the original state:
--   source schema/reset.sql;
```
