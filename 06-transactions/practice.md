# SQL Transactions — Practice Problems

> **Setup:** Run `schema/reset.sql` before starting. These problems use the `student_account` and `payment` tables. Re-run `schema/reset.sql` any time the balances drift — several problems deduct money on purpose.

Try the SQL yourself before checking the hint or solution. Use `SELECT balance ...` before and after to prove what changed. Remember the `DELIMITER $$` ... `END $$` ... `DELIMITER ;` pattern and `DROP PROCEDURE IF EXISTS` before `CREATE PROCEDURE`.

> These problems assume **MySQL 8.0+** with **InnoDB** tables (the default). On a non-transactional engine like MyISAM, `ROLLBACK` does nothing — the tables in this course are all InnoDB.

---

## Problem 1 — Commit a Charge (Easy)

Charge student 6 a `$150` lab fee as one atomic unit: deduct it from their balance **and** record a payment, then make it permanent.

**Your task:**
1. Note student 6's starting balance (`SELECT balance FROM student_account WHERE student_id = 6;`)
2. In a single transaction, subtract `150.00` from the balance and insert a `payment` row (`payment_type = 'Fee'`)
3. `COMMIT`, then confirm both the balance dropped by 150 and the payment exists

**Expected:** The balance is `150.00` lower and a new `Fee` payment of `150.00` appears for student 6.

<details>
<summary>Hint</summary>

Wrap both writes between `START TRANSACTION;` and `COMMIT;`. The `UPDATE` uses `balance = balance - 150.00`; the `INSERT` sets `student_id`, `amount`, `payment_type`, and `description`.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT balance FROM student_account WHERE student_id = 6;   -- e.g. 3000.00

START TRANSACTION;
    UPDATE student_account SET balance = balance - 150.00 WHERE student_id = 6;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (6, 150.00, 'Fee', 'Lab fee');
COMMIT;

SELECT balance FROM student_account WHERE student_id = 6;   -- 150 lower
SELECT amount, payment_type, description
FROM payment WHERE student_id = 6 ORDER BY payment_id DESC LIMIT 1;
```

**What you practiced:** Grouping two dependent writes into one atomic transaction so they commit together.

</details>

---

## Problem 2 — Roll It Back (Easy)

Show that a change *inside* an open transaction is real to you but vanishes on `ROLLBACK`.

**Your task:**
1. `START TRANSACTION` and subtract `500.00` from student 3's balance
2. `SELECT` the balance *before* committing — confirm it shows the lower number
3. `ROLLBACK`, then `SELECT` again — confirm the balance is back to its original value

**Expected:** Within the transaction the balance is `500.00` lower; after `ROLLBACK` it returns exactly to the starting value, as if nothing happened.

<details>
<summary>Hint</summary>

Within an open transaction your own session sees its uncommitted changes. `ROLLBACK` (with no `TO`) discards everything since `START TRANSACTION`.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT balance FROM student_account WHERE student_id = 3;   -- e.g. 800.00

START TRANSACTION;
    UPDATE student_account SET balance = balance - 500.00 WHERE student_id = 3;
    SELECT balance FROM student_account WHERE student_id = 3;   -- 300.00 (uncommitted)
ROLLBACK;

SELECT balance FROM student_account WHERE student_id = 3;   -- back to 800.00
```

**What you practiced:** Seeing uncommitted changes within your own transaction, and using `ROLLBACK` to discard them entirely.

</details>

---

## Problem 3 — Partial Rollback with a SAVEPOINT (Medium)

Apply two charges to student 10, but decide the second one was a mistake — undo only that one while keeping the first.

**Your task:**
1. `START TRANSACTION`, then charge `100.00` (update balance + insert payment)
2. Set a `SAVEPOINT` called `after_first`
3. Charge another `2000.00` (update balance + insert payment)
4. `ROLLBACK TO after_first` to undo the second charge, then `COMMIT`
5. Verify only the `100.00` charge persisted (balance down 100, exactly one new payment)

**Expected:** Student 10's balance is `100.00` lower (not `2100.00`), and only the first payment row remains — the `ROLLBACK TO` erased the second charge and its payment insert.

<details>
<summary>Hint</summary>

`ROLLBACK TO after_first` undoes everything after the savepoint — including the second `INSERT` — but keeps the first charge and leaves the transaction open, so you still need `COMMIT`.

</details>

<details>
<summary>Solution</summary>

```sql
SELECT balance FROM student_account WHERE student_id = 10;   -- e.g. 2500.00

START TRANSACTION;
    UPDATE student_account SET balance = balance - 100.00 WHERE student_id = 10;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (10, 100.00, 'Fee', 'Activity fee');

    SAVEPOINT after_first;

    UPDATE student_account SET balance = balance - 2000.00 WHERE student_id = 10;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (10, 2000.00, 'Tuition', 'Mistaken charge');

    ROLLBACK TO after_first;   -- undo the 2000 charge AND its payment insert
COMMIT;

SELECT balance FROM student_account WHERE student_id = 10;   -- 100 lower only
SELECT amount, description FROM payment WHERE student_id = 10 ORDER BY payment_id;
```

**What you practiced:** Using `SAVEPOINT` and `ROLLBACK TO` to undo part of a transaction while keeping earlier work, then committing the rest.

</details>

---

## Problem 4 — Wrap It Safely in a Procedure (Medium)

Move the charge logic into a reusable procedure that rolls back automatically if anything goes wrong.

**Your task:**
1. Write `charge_fee(p_student_id INT, p_amount DECIMAL(10,2), p_description VARCHAR(255))`
2. Inside it, declare `EXIT HANDLER FOR SQLEXCEPTION` that does `ROLLBACK; RESIGNAL;`
3. In a transaction, deduct the amount from the balance and insert a `Fee` payment, then `COMMIT`
4. `CALL charge_fee(4, 300.00, 'Lab equipment')` and verify the balance and payment both updated

**Expected:** Student 4's balance drops by `300.00` and a matching `Fee` payment is recorded — both committed together by the single `CALL`.

<details>
<summary>Hint</summary>

The handler must be **declared before** the `START TRANSACTION`. `RESIGNAL` re-raises the original error after the rollback so the caller still finds out it failed.

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS charge_fee;

DELIMITER $$

CREATE PROCEDURE charge_fee(
    IN p_student_id  INT,
    IN p_amount      DECIMAL(10,2),
    IN p_description VARCHAR(255)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        UPDATE student_account
        SET balance = balance - p_amount
        WHERE student_id = p_student_id;

        INSERT INTO payment (student_id, amount, payment_type, description)
        VALUES (p_student_id, p_amount, 'Fee', p_description);
    COMMIT;
END $$

DELIMITER ;

CALL charge_fee(4, 300.00, 'Lab equipment');

SELECT balance FROM student_account WHERE student_id = 4;   -- 300 lower
SELECT amount, description FROM payment WHERE student_id = 4 ORDER BY payment_id DESC LIMIT 1;
```

**What you practiced:** Wrapping a transaction in a procedure with `DECLARE EXIT HANDLER FOR SQLEXCEPTION` so any error rolls the whole thing back automatically.

</details>

---

## Problem 5 — Guard the Funds (Hard)

Extend the procedure so it refuses to overdraw an account, and prove a rejected charge leaves everything untouched.

**Your task:**
1. In `charge_fee`, read the current balance with `SELECT ... INTO`
2. If `balance < p_amount`, `SIGNAL SQLSTATE '45000'` with a clear message (the handler rolls back)
3. Otherwise deduct and record the payment, then `COMMIT`
4. Test both paths on student 5 (balance `500.00`): `CALL charge_fee(5, 800.00, ...)` must **fail and change nothing**; `CALL charge_fee(5, 200.00, ...)` must succeed

**Expected:** The `$800` call raises *"Insufficient funds"* and student 5's balance stays `500.00` with no new payment. The `$200` call succeeds, leaving the balance at `300.00` with one new `Fee` payment.

<details>
<summary>Hint</summary>

Do the balance check *inside* the transaction, before the `UPDATE`. When `SIGNAL` fires, the `EXIT HANDLER` catches it, runs `ROLLBACK`, and re-raises — so no partial work survives. Use a local `DECLARE v_balance DECIMAL(10,2);`.

</details>

<details>
<summary>Solution</summary>

```sql
DROP PROCEDURE IF EXISTS charge_fee;

DELIMITER $$

CREATE PROCEDURE charge_fee(
    IN p_student_id  INT,
    IN p_amount      DECIMAL(10,2),
    IN p_description VARCHAR(255)
)
BEGIN
    DECLARE v_balance DECIMAL(10,2);

    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        RESIGNAL;
    END;

    START TRANSACTION;
        SELECT balance INTO v_balance
        FROM student_account
        WHERE student_id = p_student_id;

        IF v_balance < p_amount THEN
            SIGNAL SQLSTATE '45000'
                SET MESSAGE_TEXT = 'Insufficient funds for this charge';
        END IF;

        UPDATE student_account
        SET balance = balance - p_amount
        WHERE student_id = p_student_id;

        INSERT INTO payment (student_id, amount, payment_type, description)
        VALUES (p_student_id, p_amount, 'Fee', p_description);
    COMMIT;
END $$

DELIMITER ;

-- Fails: 800 > 500. Balance stays 500, no payment inserted.
CALL charge_fee(5, 800.00, 'Equipment fee');

-- Succeeds: 200 <= 500. Balance -> 300, payment recorded.
CALL charge_fee(5, 200.00, 'Equipment fee');

SELECT balance FROM student_account WHERE student_id = 5;   -- 300.00
SELECT amount, description FROM payment WHERE student_id = 5 ORDER BY payment_id DESC LIMIT 1;
```

**What you practiced:** Enforcing a business rule atomically — combining `SIGNAL` with an `EXIT HANDLER` so a rejected operation rolls back and leaves every table unchanged.

</details>

---

## Bonus — ACID Check

No SQL to write. Consider this sequence run **without** a transaction, where the server crashes between the two statements:

```sql
UPDATE student_account SET balance = balance - 5000.00 WHERE student_id = 2;  -- runs
-- *** server crashes here ***
INSERT INTO payment (student_id, amount, payment_type, description)
VALUES (2, 5000.00, 'Tuition', 'Fall tuition');                               -- never runs
```

**Questions:**
1. What is the corrupt end state, and which ACID property would have prevented it?
2. If instead both statements had committed, which property guarantees the charge survives a later power failure?
3. Why does wrapping the two statements in `START TRANSACTION ... COMMIT` fix the crash scenario?

<details>
<summary>Answer</summary>

1. Student 2 has been charged `$5000` with **no payment record** — money left the balance but nothing documents it. **Atomicity** prevents this: in a transaction, the deduction and the insert both happen or neither does, so a crash before `COMMIT` leaves *nothing* applied.
2. **Durability** — once a transaction commits, the change is written so that it survives crashes and power loss.
3. The `UPDATE` is no longer permanent on its own. Until `COMMIT` runs, both statements are pending; a crash before `COMMIT` rolls the whole transaction back automatically on restart, so the balance is never deducted without the matching payment.

**What you practiced:** Mapping a real failure to the specific ACID property that prevents it, and seeing why a transaction boundary turns "two risky writes" into one safe unit.

</details>

---

## Cleanup

Remove the practice procedure and restore the original seeded balances:

```sql
DROP PROCEDURE IF EXISTS charge_fee;

-- Re-run the full schema to restore original balances and payment history:
--   source schema/reset.sql;
```
