# SQL Triggers — Practice Problems

> **Setup:** Run `schema/reset.sql` before starting. This lesson uses the `grade`, `audit_log`, `enrollment`, and `student` tables. Re-run `schema/reset.sql` any time the seed data drifts.

Try writing the SQL yourself before checking the hint or solution. Remember the `DELIMITER $$` ... `END $$` ... `DELIMITER ;` pattern, the `trg_` naming convention, and always `DROP TRIGGER IF EXISTS` before `CREATE TRIGGER`.

> These problems assume **MySQL 8.0+**, where a table may have more than one trigger for the same event. For the cleanest results, run one problem at a time, or run the **Cleanup** block at the end before switching problems.

---

## Problem 1 — Default the Grading Date (Easy)

Create a `BEFORE INSERT` trigger called `trg_grade_before_insert_date` that sets `graded_date` to today's date whenever a grade is inserted without one.

**Your task:**
1. Create the trigger on the `grade` table
2. Insert a grade for enrollment 7 supplying only `enrollment_id`, `numeric_grade`, and `letter_grade` (no `graded_date`)
3. Confirm `graded_date` was filled in with today's date

**Expected:** The new row's `graded_date` equals today (`CURDATE()`).

<details>
<summary>Hint</summary>

In a `BEFORE INSERT` trigger you can assign to `NEW.graded_date`. Guard it with `IF NEW.graded_date IS NULL THEN ... END IF` so an explicitly supplied date is respected. Use `CURDATE()` for today.

</details>

<details>
<summary>Solution</summary>

```sql
DROP TRIGGER IF EXISTS trg_grade_before_insert_date;

DELIMITER $$

CREATE TRIGGER trg_grade_before_insert_date
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
    IF NEW.graded_date IS NULL THEN
        SET NEW.graded_date = CURDATE();
    END IF;
END $$

DELIMITER ;

-- Enrollment 7 (Clara Davis, ENG101) has no grade yet
INSERT INTO grade (enrollment_id, numeric_grade, letter_grade)
VALUES (7, 84.00, 'B');

SELECT enrollment_id, numeric_grade, letter_grade, graded_date
FROM grade
WHERE enrollment_id = 7;
```

**What you practiced:** Assigning to `NEW.*` in a `BEFORE INSERT` trigger to fill in a default value — work the database does so the application does not have to.

</details>

---

## Problem 2 — Reject Out-of-Range Grades (Easy)

Create a `BEFORE INSERT` trigger called `trg_grade_validate` that rejects any grade whose `numeric_grade` is below 0 or above 100, using `SIGNAL`.

**Your task:**
1. Create the trigger on the `grade` table
2. Try inserting a grade of `105.00` for enrollment 10 — it should fail
3. Insert a valid grade of `68.00` for enrollment 10 — it should succeed

**Expected:** The first insert raises `'numeric_grade must be between 0 and 100'`; the second succeeds.

<details>
<summary>Hint</summary>

Check `IF NEW.numeric_grade < 0 OR NEW.numeric_grade > 100 THEN` and `SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = '...'`. The `SIGNAL` aborts the insert before the row is written.

</details>

<details>
<summary>Solution</summary>

```sql
DROP TRIGGER IF EXISTS trg_grade_validate;

DELIMITER $$

CREATE TRIGGER trg_grade_validate
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
    IF NEW.numeric_grade < 0 OR NEW.numeric_grade > 100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'numeric_grade must be between 0 and 100';
    END IF;
END $$

DELIMITER ;

-- Should fail
INSERT INTO grade (enrollment_id, numeric_grade, letter_grade)
VALUES (10, 105.00, 'A');

-- Should succeed
INSERT INTO grade (enrollment_id, numeric_grade, letter_grade)
VALUES (10, 68.00, 'D');
```

**What you practiced:** Using `SIGNAL` inside a `BEFORE` trigger to enforce a data-integrity rule that no client can bypass.

</details>

---

## Problem 3 — Audit Grade Changes (Medium)

Create an `AFTER UPDATE` trigger called `trg_grade_after_update_audit` that writes a row to `audit_log` **only when** `numeric_grade` actually changes. Record the old and new numeric grades.

**Your task:**
1. Create the trigger on the `grade` table
2. Update enrollment 2's grade (currently 85.00) to 90.00 — should log a row
3. Update enrollment 2's grade to 90.00 again — should log nothing
4. Query `audit_log` to confirm exactly one new row exists

**Expected:** Exactly one `UPDATE` audit row, with `old_value` mentioning 85.00 and `new_value` mentioning 90.00.

<details>
<summary>Hint</summary>

Guard the `INSERT INTO audit_log` with `IF OLD.numeric_grade <> NEW.numeric_grade THEN ... END IF`. Build the old/new strings with `CONCAT`. Only supply `table_name, action, record_id, old_value, new_value` — `changed_by` and `changed_at` default themselves.

</details>

<details>
<summary>Solution</summary>

```sql
DROP TRIGGER IF EXISTS trg_grade_after_update_audit;

DELIMITER $$

CREATE TRIGGER trg_grade_after_update_audit
    AFTER UPDATE ON grade
    FOR EACH ROW
BEGIN
    IF OLD.numeric_grade <> NEW.numeric_grade THEN
        INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
        VALUES (
            'grade',
            'UPDATE',
            NEW.grade_id,
            CONCAT('numeric_grade=', OLD.numeric_grade),
            CONCAT('numeric_grade=', NEW.numeric_grade)
        );
    END IF;
END $$

DELIMITER ;

-- Logs a row (85.00 -> 90.00)
UPDATE grade SET numeric_grade = 90.00 WHERE enrollment_id = 2;

-- Logs nothing (no real change)
UPDATE grade SET numeric_grade = 90.00 WHERE enrollment_id = 2;

SELECT action, old_value, new_value
FROM audit_log
WHERE table_name = 'grade' AND action = 'UPDATE'
ORDER BY log_id DESC;
```

**What you practiced:** Comparing `OLD` and `NEW` in an `AFTER UPDATE` trigger and logging only genuine changes — the standard way to keep an audit log clean.

</details>

---

## Problem 4 — Keep the Letter Grade in Sync (Medium)

Numeric grades and letter grades can drift apart if only one is updated. Create **two** triggers that keep `letter_grade` derived from `numeric_grade`: one for `BEFORE INSERT` and one for `BEFORE UPDATE`. Use the scale ≥90 = A, ≥80 = B, ≥70 = C, ≥60 = D, else F.

**Your task:**
1. Create `trg_grade_derive_insert` (`BEFORE INSERT`) and `trg_grade_derive_update` (`BEFORE UPDATE`)
2. Insert a grade for enrollment 12 with `numeric_grade = 73.00` and **no** `letter_grade` — expect `C`
3. Update enrollment 12's grade to `numeric_grade = 59.00` — expect the letter to become `F`

**Expected:** After the insert, `letter_grade = 'C'`. After the update, `letter_grade = 'F'`.

<details>
<summary>Hint</summary>

Both triggers contain the same `IF / ELSEIF` ladder assigning `NEW.letter_grade`. Assigning to `NEW.*` is legal in **both** `BEFORE INSERT` and `BEFORE UPDATE`. Because they target different events, both can exist on the same table at once.

</details>

<details>
<summary>Solution</summary>

```sql
DROP TRIGGER IF EXISTS trg_grade_derive_insert;
DROP TRIGGER IF EXISTS trg_grade_derive_update;

DELIMITER $$

CREATE TRIGGER trg_grade_derive_insert
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
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

CREATE TRIGGER trg_grade_derive_update
    BEFORE UPDATE ON grade
    FOR EACH ROW
BEGIN
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

-- Insert: letter derived as 'C'
INSERT INTO grade (enrollment_id, numeric_grade) VALUES (12, 73.00);

-- Update: letter re-derived as 'F'
UPDATE grade SET numeric_grade = 59.00 WHERE enrollment_id = 12;

SELECT enrollment_id, numeric_grade, letter_grade
FROM grade
WHERE enrollment_id = 12;
```

**What you practiced:** Maintaining a derived column on both inserts and updates — and seeing why a `BEFORE INSERT` trigger alone is not enough to keep data consistent over time.

</details>

---

## Problem 5 — Protect Completed Grades (Hard)

A grade for a `Completed` enrollment is final and must not be deleted. Create a `BEFORE DELETE` trigger called `trg_grade_no_delete_completed` that looks up the enrollment's status and raises an error if it is `'Completed'`.

**Your task:**
1. Create the trigger on the `grade` table. Inside it, look up the `status` from `enrollment` using `OLD.enrollment_id`.
2. First insert a grade for the **Active** enrollment 6, then delete it — should **succeed**.
3. Try to delete the grade for enrollment 1 (Alice's CS101, a **Completed** enrollment) — should **fail**.

**Expected:** Deleting the Active enrollment's grade succeeds; deleting the Completed enrollment's grade raises `'Cannot delete a grade for a completed enrollment'`.

<details>
<summary>Hint</summary>

Inside the trigger, `DECLARE v_status VARCHAR(20);` then `SELECT status INTO v_status FROM enrollment WHERE enrollment_id = OLD.enrollment_id;`. If `v_status = 'Completed'`, `SIGNAL`. Remember: in a `DELETE` trigger only `OLD` is available — there is no `NEW`.

</details>

<details>
<summary>Solution</summary>

```sql
DROP TRIGGER IF EXISTS trg_grade_no_delete_completed;

DELIMITER $$

CREATE TRIGGER trg_grade_no_delete_completed
    BEFORE DELETE ON grade
    FOR EACH ROW
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT status INTO v_status
    FROM enrollment
    WHERE enrollment_id = OLD.enrollment_id;

    IF v_status = 'Completed' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Cannot delete a grade for a completed enrollment';
    END IF;
END $$

DELIMITER ;

-- Enrollment 6 is Active — insert a grade, then delete it (succeeds)
INSERT INTO grade (enrollment_id, numeric_grade, letter_grade)
VALUES (6, 70.00, 'C');

DELETE FROM grade WHERE enrollment_id = 6;

-- Enrollment 1 is Completed — this delete should fail
DELETE FROM grade WHERE enrollment_id = 1;
```

**What you practiced:** Combining `OLD`, a cross-table `SELECT ... INTO` lookup, a local variable, and `SIGNAL` in a `BEFORE DELETE` trigger to enforce a business rule the database guarantees on its own.

</details>

---

## Bonus: Explain It

*No SQL to write — answer in your own words.*

1. The same grade-validation check could live in a stored procedure, in application code, or in a trigger. Give one reason a **trigger** enforces it more reliably than the other two.
2. In Problem 3 we only log when the grade actually changed (`OLD.numeric_grade <> NEW.numeric_grade`). Why is that guard worth adding?
3. Name one real **downside** of putting business logic in triggers.

<details>
<summary>Answer</summary>

1. A trigger fires for **every** insert/update/delete on the table, regardless of which client made the change — a web app, a mobile app, a bulk import, or an admin typing raw SQL. A stored procedure only runs if someone remembers to `CALL` it, and application checks can be bypassed by any other client that talks to the database directly. The trigger is the one place the rule cannot be skipped.

2. Without the guard, an `UPDATE` that sets `numeric_grade` to the value it already had would still write an audit row, filling the log with "changes" that changed nothing. Many ORMs and forms re-save every column on every edit, so this happens constantly. The guard keeps the audit trail meaningful.

3. Triggers run **invisibly**. A developer reading the application code sees an ordinary `INSERT` and has no hint that extra logic fired behind it, which makes behavior hard to predict and bugs hard to trace. Triggers are also harder to test and step-through debug than ordinary code, and (if a trigger does slow work) they add hidden cost to every single row change.

</details>

---

## Cleanup

Remove all practice triggers and reset any modified data:

```sql
DROP TRIGGER IF EXISTS trg_grade_before_insert_date;
DROP TRIGGER IF EXISTS trg_grade_validate;
DROP TRIGGER IF EXISTS trg_grade_after_update_audit;
DROP TRIGGER IF EXISTS trg_grade_derive_insert;
DROP TRIGGER IF EXISTS trg_grade_derive_update;
DROP TRIGGER IF EXISTS trg_grade_no_delete_completed;

-- The practice inserts/updates changed grade rows and added audit rows.
-- Re-run the full schema to restore the original seed data:
--   source schema/reset.sql;
```
