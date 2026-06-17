# SQL Transactions Lesson

> **Prerequisites:** You should be comfortable with `INSERT`, `UPDATE`, and `SELECT`, and have completed the [Indexing](../05-indexing/lesson.md) lesson. The payoff at the end wraps a transaction inside a stored procedure, so it reuses `DELIMITER`, `BEGIN...END`, `DECLARE`, and `SIGNAL` from the [Stored Procedures](../03-stored-procedures/lesson.md) lesson.

## Learning Objectives

By the end of this lesson you will be able to:

- Explain what a transaction is and the four ACID properties
- Use `START TRANSACTION`, `COMMIT`, and `ROLLBACK` to group statements
- Describe `autocommit` and how it changes single-statement behaviour
- Undo part of a transaction with `SAVEPOINT` and `ROLLBACK TO`
- Make a multi-step money operation atomic — both writes happen or neither does
- Roll back automatically inside a procedure with `DECLARE EXIT HANDLER FOR SQLEXCEPTION`
- Enforce a business rule atomically by combining `SIGNAL` with rollback
- Know that only transactional engines (InnoDB) honour any of this

---

## Why This Matters

Charging a student's tuition is not one action — it is **two writes that must agree**:

1. Subtract the fee from `student_account.balance`
2. Insert a row into `payment` recording it

Run them as two separate statements and you are one crash away from disaster. If the server dies
between them, you have either **taken money with no record** of it, or **recorded a payment that was
never deducted**. The books no longer balance, and no single statement is to blame.

A **transaction** binds those writes into one unit: the database guarantees that **all of them
happen, or none of them do**. There is no halfway. That guarantee — applied to money, inventory,
seat reservations, anything where partial work is corruption — is what transactions buy you.

---

## What is a Transaction? (ACID)

A transaction is a group of statements treated as a single, indivisible operation. The guarantees
are summarised by **ACID**:

| Property | Meaning | In our money example |
|---|---|---|
| **A**tomicity | All statements succeed, or all are undone | The deduction and the `payment` insert both happen, or neither does |
| **C**onsistency | The database moves from one valid state to another | Total money in the system stays correct; no orphaned charge |
| **I**solation | Concurrent transactions do not see each other's half-done work | Another query never sees the balance deducted *before* the payment is recorded |
| **D**urability | Once committed, the change survives a crash | After `COMMIT`, a power failure cannot lose the charge |

> Transactions only work on a **transactional storage engine**. MySQL's default, **InnoDB**, is
> transactional. The older **MyISAM** engine silently ignores `START TRANSACTION` / `ROLLBACK` — the
> statements run and commit immediately. All tables in this course are InnoDB.

---

## 1. START TRANSACTION / COMMIT / ROLLBACK

Three statements drive everything:

- **`START TRANSACTION`** (or `BEGIN`) — open a transaction; nothing is permanent yet
- **`COMMIT`** — make every change since the start permanent
- **`ROLLBACK`** — discard every change since the start, as if none happened

```sql
START TRANSACTION;
    UPDATE student_account SET balance = balance - 150.00 WHERE student_id = 6;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (6, 150.00, 'Fee', 'Lab fee');
COMMIT;
-- Both writes are now permanent.
```

The same shape with `ROLLBACK` throws the work away:

```sql
START TRANSACTION;
    UPDATE student_account SET balance = balance - 9999.00 WHERE student_id = 6;
    -- "Wait, that's wrong."
ROLLBACK;
-- The balance is untouched — the UPDATE never really happened.
```

---

## 2. Autocommit

By default MySQL runs in **autocommit** mode: every standalone statement is its own transaction that
commits the instant it finishes.

```sql
SELECT @@autocommit;   -- 1 means autocommit is ON (the default)
```

That is why a plain `UPDATE` you run on its own is permanent immediately — there is nothing to roll
back. `START TRANSACTION` **temporarily suspends** autocommit: from that point, nothing is permanent
until you `COMMIT` (or you discard it with `ROLLBACK`). After the transaction ends, autocommit
resumes.

```sql
-- This single statement is already its own committed transaction:
UPDATE student_account SET balance = balance + 0 WHERE student_id = 6;

-- To group statements, you must open a transaction explicitly:
START TRANSACTION;
    -- ... multiple statements, all pending ...
COMMIT;
```

> You can turn autocommit off for a session with `SET autocommit = 0;`, after which every statement
> begins a transaction you must `COMMIT` yourself. Prefer explicit `START TRANSACTION` blocks — they
> are clearer and scoped to exactly the work you mean to group.

---

## 3. An Atomic Charge (full example)

Here is the real pattern: charge a fee and record it as one unit, proving both moved together.

```sql
-- Before
SELECT balance FROM student_account WHERE student_id = 6;   -- e.g. 3000.00

START TRANSACTION;
    UPDATE student_account SET balance = balance - 200.00 WHERE student_id = 6;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (6, 200.00, 'Fee', 'Late registration fee');
COMMIT;

-- After
SELECT balance FROM student_account WHERE student_id = 6;   -- 2800.00
SELECT amount, payment_type, description
FROM payment WHERE student_id = 6 ORDER BY payment_id DESC LIMIT 1;
```

Until `COMMIT` runs, another connection sees the **old** balance and **no** new payment row. The
moment it commits, it sees **both**. There is no instant where one exists without the other.

---

## 4. SAVEPOINT — partial rollback

A `SAVEPOINT` is a named marker inside a transaction. `ROLLBACK TO` rewinds to that marker, undoing
the work after it while **keeping** the work before it. The transaction stays open.

```sql
START TRANSACTION;
    UPDATE student_account SET balance = balance - 100.00 WHERE student_id = 6;  -- keep this
    SAVEPOINT after_fee;

    UPDATE student_account SET balance = balance - 5000.00 WHERE student_id = 6; -- oops
    ROLLBACK TO after_fee;   -- undo only the 5000 charge

COMMIT;   -- the 100 charge persists; the 5000 charge never happened
```

> `ROLLBACK TO sp` does **not** end the transaction — you still must `COMMIT` or `ROLLBACK`. A plain
> `ROLLBACK` (no `TO`) discards the whole thing, savepoints and all.

---

## 5. Transactions in Stored Procedures

In real systems a transaction lives inside a procedure the application calls. The challenge is error
handling: if any statement fails partway through, you must roll back — not leave half the work
committed. MySQL's tool for this is a **handler**:

```sql
DROP PROCEDURE IF EXISTS charge_fee;

DELIMITER $$

CREATE PROCEDURE charge_fee(
    IN p_student_id  INT,
    IN p_amount      DECIMAL(10,2),
    IN p_description VARCHAR(255)
)
BEGIN
    -- If ANY statement below raises an error, undo everything and re-raise it.
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

CALL charge_fee(6, 250.00, 'Library fine');   -- both writes commit together
```

`DECLARE EXIT HANDLER FOR SQLEXCEPTION` registers a block that fires on any SQL error. It calls
`ROLLBACK` (discarding the partial transaction) and `RESIGNAL` (re-throwing the original error so the
caller still learns it failed). This is the backbone pattern behind the
[Enrollment Pipeline challenge](../challenges/challenge-02-enrollment-pipeline.md).

---

## 6. Enforcing a Rule Atomically

The handler catches *unexpected* errors. To reject a charge by a *business rule* — "no overdrafts" —
check the balance yourself and `SIGNAL` if it fails. The `EXIT HANDLER` then rolls everything back,
so a rejected charge leaves all tables exactly as they were.

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
        -- Read the current balance
        SELECT balance INTO v_balance
        FROM student_account
        WHERE student_id = p_student_id;

        -- Business rule: reject if it would overdraw the account
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

-- Student 5 has only 500.00:
CALL charge_fee(5, 800.00, 'Equipment fee');  -- ERROR 1644: Insufficient funds — nothing changes
CALL charge_fee(5, 200.00, 'Equipment fee');  -- Succeeds — balance 500 -> 300, payment recorded
```

When the `SIGNAL` fires, control jumps to the handler, `ROLLBACK` undoes the (still-uncommitted)
work, and the caller gets the error. The student's balance never moves and no `payment` row is left
behind. That is atomicity protecting a rule.

---

## 7. A Word on Isolation

Everything above assumes you are the only one touching the data. In production, many transactions run
at once, and they can interfere: one reads a balance another is midway through changing, two charges
race and overwrite each other. How strictly the database keeps concurrent transactions apart is its
**isolation level**, and the locks it uses to enforce it can themselves collide as **deadlocks**.
That is the subject of the next lesson — for now, just know that the `I` in ACID is doing quiet work
on your behalf.

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Running DDL inside a transaction (`CREATE`/`ALTER`/`DROP`/`TRUNCATE`) | An **implicit commit** fires — your transaction ends early and cannot be rolled back | Keep DDL out of transactions; only DML (`INSERT`/`UPDATE`/`DELETE`) is transactional |
| Using a MyISAM table | `START TRANSACTION`/`ROLLBACK` are silently ignored; changes commit immediately | Use InnoDB (the default) for anything that needs transactions |
| Catching the error but forgetting `ROLLBACK` in the handler | Partial work stays uncommitted, holding locks, or commits on the next statement | Always `ROLLBACK` (and usually `RESIGNAL`) inside `EXIT HANDLER FOR SQLEXCEPTION` |
| Forgetting to `COMMIT` | Work is invisible to others and locks are held until the session ends or rolls back | End every `START TRANSACTION` with a `COMMIT` or `ROLLBACK` |
| Expecting a single statement to need a transaction | A lone `UPDATE` already commits under autocommit | Only group **multiple** statements that must succeed together |
| `SIGNAL` with no handler around the transaction | The error stops the procedure but partial writes may linger | Pair business-rule `SIGNAL`s with an `EXIT HANDLER` that rolls back |
| Holding a transaction open during slow work | Locks are held the whole time, blocking others | Keep transactions short; do slow work before `START TRANSACTION` |

---

## When to Use / When NOT to

| Use a transaction when... | A transaction is unnecessary / harmful when... |
|---------------------------|-----------------------------------------------|
| Two or more writes must all succeed or all fail (charge + record) | A single statement already does the whole job (it is atomic by itself) |
| Money, inventory, or seat counts must never go half-updated | You are only reading data (no writes to protect) |
| You need to validate, then write, with no gap an error could exploit | The work is a long batch that would hold locks for minutes |
| A procedure must guarantee an invariant across several tables | You are running DDL, which auto-commits anyway |

---

## Quick Reference

| Statement | Purpose |
|---|---|
| `START TRANSACTION` / `BEGIN` | Open a transaction (suspends autocommit) |
| `COMMIT` | Make all changes since the start permanent |
| `ROLLBACK` | Discard all changes since the start |
| `SAVEPOINT name` | Mark a point you can partially roll back to |
| `ROLLBACK TO name` | Undo work after the savepoint; transaction stays open |
| `RELEASE SAVEPOINT name` | Forget a savepoint without rolling back |
| `SET autocommit = 0\|1` | Turn automatic per-statement commit off / on |
| `DECLARE EXIT HANDLER FOR SQLEXCEPTION BEGIN ROLLBACK; RESIGNAL; END` | Auto-rollback on any error inside a procedure |
| `SELECT @@autocommit` | Check whether autocommit is on |

---

## What's Next?

Next you will learn about **concurrency control** — what happens when many transactions run at once.
You will see the read phenomena isolation levels prevent (dirty reads, non-repeatable reads, phantom
reads), set the level with `SET TRANSACTION ISOLATION LEVEL`, take explicit locks with
`SELECT ... FOR UPDATE`, and understand how deadlocks arise and how the database resolves them.
