# SQL Triggers Lesson

> **Prerequisites:** You should be comfortable with `INSERT`, `UPDATE`, `DELETE`, and have completed the [Stored Procedures](../03-stored-procedures/lesson.md) lesson — triggers reuse `DELIMITER`, `BEGIN...END`, `IF`, and `SIGNAL` from that lesson.

## Learning Objectives

By the end of this lesson you will be able to:

- Explain what a trigger is and how it differs from a stored procedure
- Write the `CREATE TRIGGER` syntax with the correct timing and event
- Use the `NEW` and `OLD` pseudo-rows, and know which is available for each event
- Normalize and derive column values with a `BEFORE INSERT` trigger
- Reject invalid data with `SIGNAL` inside a `BEFORE` trigger
- Build an audit trail with `AFTER INSERT`, `AFTER UPDATE`, and `AFTER DELETE` triggers
- Log a change only when a value actually changed
- List, inspect, and drop triggers

---

## Why This Matters

A stored procedure only runs when someone remembers to `CALL` it. But some rules must hold **no matter how the data is changed** — whether it came from a web app, a bulk import, an admin running raw SQL, or another procedure.

That is what a **trigger** does. A trigger is a block of SQL that the database fires **automatically** whenever a row is inserted, updated, or deleted in a table. No one calls it. It cannot be forgotten or bypassed.

Triggers shine for three jobs:

- **Audit trails** — automatically record who changed what and when, in a separate `audit_log` table.
- **Derived columns** — keep a calculated value in sync (for example, deriving a letter grade from a numeric grade) so the application never has to.
- **Enforcing invariants** — reject changes that would violate a business rule, even if the application forgot to check.

---

## What is a Trigger?

A trigger is a **named block of SQL bound to a table and an event**. You define it once; the database runs it every time that event happens.

| | Stored Procedure | Trigger |
|---|---|---|
| How it runs | You `CALL` it explicitly | Fires automatically on a table event |
| Can it be skipped? | Yes — if no one calls it | No — fires for every matching change |
| Takes parameters? | Yes | No — it reads the changing row instead |
| Bound to a table? | No | Yes — always tied to one table |

A trigger has three defining parts: **timing** (`BEFORE` or `AFTER`), **event** (`INSERT`, `UPDATE`, or `DELETE`), and the **table** it watches.

---

## Trigger Anatomy and DELIMITER

The full syntax:

```sql
CREATE TRIGGER trigger_name
    { BEFORE | AFTER } { INSERT | UPDATE | DELETE }
    ON table_name
    FOR EACH ROW
BEGIN
    -- statements that run for each affected row
END
```

`FOR EACH ROW` means the body runs **once per affected row**. An `UPDATE` that touches 10 rows fires the trigger 10 times.

Just like stored procedures, a trigger body contains many `;` characters, so you must change the statement terminator with `DELIMITER` while defining it:

```sql
DELIMITER $$

CREATE TRIGGER example_trigger
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
    -- ...
END $$

DELIMITER ;
```

We use the `trg_` prefix for trigger names throughout this lesson (for example, `trg_grade_before_insert`).

---

## New Tables in This Lesson

This lesson uses two tables created by `schema/reset.sql`:

- **`grade`** — one row per graded enrollment (`enrollment_id`, `letter_grade`, `numeric_grade`, `graded_date`).
- **`audit_log`** — a standalone log of changes (`table_name`, `action`, `record_id`, `old_value`, `new_value`, `changed_by`, `changed_at`). The `changed_by` and `changed_at` columns fill themselves with defaults (`CURRENT_USER()` and `CURRENT_TIMESTAMP`), so our triggers only need to supply the first five columns.

---

## 1. NEW and OLD — The Pseudo-Rows

Inside a trigger you access the row being changed through two special pseudo-rows:

- **`NEW`** — the row as it will be **after** the change. Holds the incoming values.
- **`OLD`** — the row as it was **before** the change. Holds the existing values.

Which one is available depends on the event:

| Event | `NEW` available? | `OLD` available? |
|-------|:---:|:---:|
| `INSERT` | ✅ (the new row) | ❌ (nothing existed before) |
| `UPDATE` | ✅ (incoming values) | ✅ (existing values) |
| `DELETE` | ❌ (nothing remains) | ✅ (the row being removed) |

You read a column with `NEW.numeric_grade` or `OLD.numeric_grade`. In a **`BEFORE`** trigger you can also **assign** to `NEW.column` to change the value before it is written. You cannot assign to `OLD`, and you cannot assign to `NEW` in an `AFTER` trigger (the row is already saved by then).

---

## 2. BEFORE INSERT — Normalize and Derive Data

A `BEFORE INSERT` trigger runs just before a new row is written, giving you a chance to fill in or fix values. Here we default the grading date to today when it is missing, and derive the letter grade from the numeric grade.

```sql
DROP TRIGGER IF EXISTS trg_grade_before_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_before_insert
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
    -- Default the grading date to today if none was provided
    IF NEW.graded_date IS NULL THEN
        SET NEW.graded_date = CURDATE();
    END IF;

    -- Derive the letter grade from the numeric grade
    IF NEW.numeric_grade >= 90 THEN
        SET NEW.letter_grade = 'A';
    ELSEIF NEW.numeric_grade >= 80 THEN
        SET NEW.letter_grade = 'B';
    ELSEIF NEW.numeric_grade >= 70 THEN
        SET NEW.letter_grade = 'C';
    ELSEIF NEW.numeric_grade >= 60 THEN
        SET NEW.letter_grade = 'D';
    ELSE
        SET NEW.letter_grade = 'F';
    END IF;
END $$

DELIMITER ;
```

Now insert a grade for an ungraded enrollment, supplying **only** the numeric grade:

```sql
-- Enrollment 6 (Clara Davis, CS101) has no grade yet
INSERT INTO grade (enrollment_id, numeric_grade)
VALUES (6, 88.00);

SELECT enrollment_id, letter_grade, numeric_grade, graded_date
FROM grade
WHERE enrollment_id = 6;
-- letter_grade = 'B' (derived), graded_date = today (defaulted)
```

The trigger filled in `letter_grade` and `graded_date` for us. Assigning to `NEW.*` like this is **only allowed in a `BEFORE` trigger**.

---

## 3. BEFORE INSERT — Validation with SIGNAL

A `BEFORE` trigger can also **reject** a bad row. `SIGNAL SQLSTATE '45000'` (the same custom-error mechanism from the Stored Procedures lesson) raises an error and aborts the `INSERT` so the invalid row never lands.

We will add this check to the same `BEFORE INSERT` trigger. A numeric grade must be between 0 and 100:

```sql
DROP TRIGGER IF EXISTS trg_grade_before_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_before_insert
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
    -- Reject out-of-range grades before anything else
    IF NEW.numeric_grade < 0 OR NEW.numeric_grade > 100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'numeric_grade must be between 0 and 100';
    END IF;

    IF NEW.graded_date IS NULL THEN
        SET NEW.graded_date = CURDATE();
    END IF;

    IF NEW.numeric_grade >= 90 THEN
        SET NEW.letter_grade = 'A';
    ELSEIF NEW.numeric_grade >= 80 THEN
        SET NEW.letter_grade = 'B';
    ELSEIF NEW.numeric_grade >= 70 THEN
        SET NEW.letter_grade = 'C';
    ELSEIF NEW.numeric_grade >= 60 THEN
        SET NEW.letter_grade = 'D';
    ELSE
        SET NEW.letter_grade = 'F';
    END IF;
END $$

DELIMITER ;
```

```sql
-- Enrollment 10 (Eva Martinez, CS101) has no grade yet — this should fail
INSERT INTO grade (enrollment_id, numeric_grade)
VALUES (10, 150.00);
-- ERROR 1644 (45000): numeric_grade must be between 0 and 100
```

Because the trigger fires **before** the write, the bad row is rejected and the table is never touched.

---

## 4. AFTER INSERT — Audit Logging

An `AFTER INSERT` trigger runs once the row is safely written. This is the right place to log the change, because the row now exists and has its final `grade_id`.

```sql
DROP TRIGGER IF EXISTS trg_grade_after_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_after_insert
    AFTER INSERT ON grade
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
    VALUES (
        'grade',
        'INSERT',
        NEW.grade_id,
        NULL,
        CONCAT('numeric_grade=', NEW.numeric_grade,
               ', letter_grade=', NEW.letter_grade)
    );
END $$

DELIMITER ;
```

```sql
-- Enrollment 11 (Eva Martinez, CS301) has no grade yet
INSERT INTO grade (enrollment_id, numeric_grade)
VALUES (11, 77.00);

SELECT table_name, action, record_id, old_value, new_value
FROM audit_log
WHERE table_name = 'grade'
ORDER BY log_id DESC
LIMIT 1;
-- action = 'INSERT', new_value = 'numeric_grade=77.00, letter_grade=C'
```

Note two things:

- We did **not** supply `changed_by` or `changed_at` — those columns have defaults (`CURRENT_USER()` and `CURRENT_TIMESTAMP`) that fill themselves in.
- In an `AFTER` trigger you can **read** `NEW.*` but you **cannot assign** to it — the row is already written. (That is why deriving values belongs in the `BEFORE` trigger.)

When you insert a grade now, **both** triggers fire in order: `BEFORE INSERT` normalizes the row, then `AFTER INSERT` logs it.

---

## 5. AFTER UPDATE — Log Old vs. New

On an `UPDATE`, both `OLD` and `NEW` are available, so you can record exactly what changed. We also guard the log with an `IF` so we only write a row when the grade **actually** changed — an `UPDATE` that sets a column to its current value should not clutter the audit log.

```sql
DROP TRIGGER IF EXISTS trg_grade_after_update;

DELIMITER $$

CREATE TRIGGER trg_grade_after_update
    AFTER UPDATE ON grade
    FOR EACH ROW
BEGIN
    IF OLD.numeric_grade <> NEW.numeric_grade THEN
        INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
        VALUES (
            'grade',
            'UPDATE',
            NEW.grade_id,
            CONCAT('numeric_grade=', OLD.numeric_grade,
                   ', letter_grade=', OLD.letter_grade),
            CONCAT('numeric_grade=', NEW.numeric_grade,
                   ', letter_grade=', NEW.letter_grade)
        );
    END IF;
END $$

DELIMITER ;
```

```sql
-- Bump Alice's CS101 grade (enrollment 1) from 92.50 to 96.00
UPDATE grade SET numeric_grade = 96.00 WHERE enrollment_id = 1;

SELECT action, old_value, new_value
FROM audit_log
WHERE table_name = 'grade' AND action = 'UPDATE'
ORDER BY log_id DESC
LIMIT 1;
-- old_value = 'numeric_grade=92.50, letter_grade=A'
-- new_value = 'numeric_grade=96.00, letter_grade=A'

-- A no-op update logs nothing
UPDATE grade SET numeric_grade = 96.00 WHERE enrollment_id = 1;
-- (no new audit row — OLD and NEW are equal)
```

> Notice the `letter_grade` did not change to match the new numeric grade. The `BEFORE INSERT` trigger only fires on inserts. Keeping derived columns in sync on updates is exactly what Practice Problem 4 asks you to build.

---

## 6. AFTER DELETE — Log Removals

On a `DELETE`, only `OLD` is available (there is no new row). Record what was removed so the deletion is never silent.

```sql
DROP TRIGGER IF EXISTS trg_grade_after_delete;

DELIMITER $$

CREATE TRIGGER trg_grade_after_delete
    AFTER DELETE ON grade
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
    VALUES (
        'grade',
        'DELETE',
        OLD.grade_id,
        CONCAT('numeric_grade=', OLD.numeric_grade,
               ', letter_grade=', OLD.letter_grade),
        NULL
    );
END $$

DELIMITER ;
```

```sql
-- Delete the grade we added for enrollment 6
DELETE FROM grade WHERE enrollment_id = 6;

SELECT action, old_value, new_value
FROM audit_log
WHERE table_name = 'grade' AND action = 'DELETE'
ORDER BY log_id DESC
LIMIT 1;
-- action = 'DELETE', old_value = 'numeric_grade=88.00, letter_grade=B', new_value = NULL
```

---

## 7. Managing Triggers

```sql
-- List all triggers in the database
SHOW TRIGGERS\G

-- List only triggers on the grade table
SHOW TRIGGERS LIKE 'grade'\G

-- See the full definition of one trigger
SHOW CREATE TRIGGER trg_grade_after_insert\G

-- Remove a trigger
DROP TRIGGER IF EXISTS trg_grade_after_insert;
```

The `\G` suffix formats output vertically (mysql CLI only). For most of MySQL history a table could have only **one** trigger per timing-and-event combination (one `BEFORE INSERT`, one `AFTER UPDATE`, and so on) — which is why our `BEFORE INSERT` example does both validation and derivation in a single trigger rather than two. MySQL 8 lets you define multiple and order them with `FOLLOWS`/`PRECEDES`, but keeping one trigger per event is the simplest mental model.

---

## End-to-End Demo

With all five triggers in place, watch them work together:

```sql
-- INSERT: BEFORE derives letter + date, AFTER logs it
INSERT INTO grade (enrollment_id, numeric_grade) VALUES (10, 81.00);
-- letter_grade auto-set to 'B', graded_date set to today, audit INSERT row written

-- UPDATE: AFTER logs the change
UPDATE grade SET numeric_grade = 72.00 WHERE enrollment_id = 10;
-- audit UPDATE row written (old 81.00 → new 72.00)

-- DELETE: AFTER logs the removal
DELETE FROM grade WHERE enrollment_id = 10;
-- audit DELETE row written

-- See the whole trail
SELECT action, old_value, new_value, changed_at
FROM audit_log
WHERE table_name = 'grade'
ORDER BY log_id;
```

Nobody called a procedure. Every change logged itself.

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Assigning `NEW.col` in an `AFTER` trigger | Error: "Updating of NEW row is not allowed in after trigger" | Do all `NEW.*` assignments in a `BEFORE` trigger |
| Using `OLD` in an `INSERT` trigger (or `NEW` in a `DELETE` trigger) | Error or `NULL` — that pseudo-row does not exist for the event | Match the pseudo-row to the event (see the NEW/OLD table) |
| Forgetting `FOR EACH ROW` | Syntax error | MySQL triggers are always row-level — always include `FOR EACH ROW` |
| Forgetting `DELIMITER` | Syntax error at the first `;` in the body | Wrap with `DELIMITER $$` ... `END $$` then `DELIMITER ;` |
| Expecting a trigger to fire on `TRUNCATE` | Rows vanish with **no** trigger and **no** audit rows | `TRUNCATE` bypasses `DELETE` triggers; use `DELETE` if you need them |
| A trigger that modifies its own table | "Can't update table ... already used by the statement that invoked this trigger" / risk of loops | Have a trigger modify *other* tables (like `audit_log`), not the table it is on |
| Assuming one fire per statement | The body runs once **per row**, not once per statement | Write the body for a single row; let `FOR EACH ROW` repeat it |

---

## When to Use / When NOT to Use

| Use Triggers When... | Avoid Triggers When... |
|----------------------|------------------------|
| You need an audit trail that no client can bypass | The logic is heavy or slow — it runs on every single row change |
| You must keep a derived column in sync (numeric → letter grade) | The work involves external calls (HTTP, files, email) — keep that in the app |
| A rule must hold regardless of which app or admin makes the change | The logic should be obvious to application developers reading the codebase |
| The action is a small, fast side effect (log a row, set a default) | You need to easily turn the behavior on and off per request |
| You want the database itself to guarantee an invariant | Debugging matters — triggers run invisibly and are hard to step through |

---

## Quick Reference

| Statement | Purpose |
|---|---|
| `CREATE TRIGGER name BEFORE\|AFTER INSERT\|UPDATE\|DELETE ON tbl FOR EACH ROW BEGIN...END` | Define a trigger |
| `NEW.column` | The incoming value (available in `INSERT` and `UPDATE`) |
| `OLD.column` | The previous value (available in `UPDATE` and `DELETE`) |
| `SET NEW.column = value` | Change a value before it is written (`BEFORE` triggers only) |
| `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'` | Reject the change with a custom error |
| `SHOW TRIGGERS [LIKE 'tbl']` | List triggers |
| `SHOW CREATE TRIGGER name` | View a trigger's definition |
| `DROP TRIGGER IF EXISTS name` | Remove a trigger safely |

---

## What's Next?

Next you will learn about **indexing** — how the database finds rows fast. You will see why a query on an un-indexed column scans every row, how an index turns that into a quick lookup, and how to read `EXPLAIN` to tell whether your query is using one.
