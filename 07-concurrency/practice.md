# SQL Concurrency Control — Practice Problems

> **Setup:** Run `schema/reset.sql` before starting (and again between problems — several change balances). These problems use the `student_account` table. Student 5 starts at `$500` and student 6 at `$3000`.

> **You need two MySQL sessions.** Open two clients — **Session A** and **Session B** — and run the numbered steps in order, switching windows at each step. A single piped script cannot reproduce a race. These problems assume **MySQL 8.0+** with **InnoDB**.

---

## Problem 1 — Inspect and Change the Isolation Level (Easy)

Get comfortable reading and setting the level before you rely on it.

**Your task:**
1. In Session A, show the current isolation level
2. Change the session level to `READ COMMITTED` and confirm the change
3. Restore it to the InnoDB default, `REPEATABLE READ`

**Expected:** The first query shows `REPEATABLE-READ`; after the `SET`, it shows `READ-COMMITTED`; after restoring, `REPEATABLE-READ` again.

<details>
<summary>Hint</summary>

The system variable is `@@transaction_isolation`. Set the level with `SET SESSION TRANSACTION ISOLATION LEVEL ...`. The variable reports it hyphenated (`READ-COMMITTED`).

</details>

<details>
<summary>Solution</summary>

```sql
SELECT @@transaction_isolation;                               -- REPEATABLE-READ
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT @@transaction_isolation;                               -- READ-COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT @@transaction_isolation;                               -- REPEATABLE-READ
```

**What you practiced:** Reading `@@transaction_isolation` and switching the session isolation level.

</details>

---

## Problem 2 — Observe (and Stop) a Non-Repeatable Read (Medium)

Show that the same `SELECT` inside one transaction can return different values under `READ COMMITTED`, then that `REPEATABLE READ` keeps it stable.

**Your task:**
1. Set **both** sessions to `READ COMMITTED`
2. Session A: `START TRANSACTION`, read student 5's balance
3. Session B: `START TRANSACTION`, update student 5's balance to `400`, `COMMIT`
4. Session A: read student 5's balance again (without committing) — note it changed; then `COMMIT`
5. `source schema/reset.sql`, set both sessions to `REPEATABLE READ`, and repeat — confirm step 4 returns the **original** value

**Expected:** Under `READ COMMITTED`, A's second read returns `400` (a non-repeatable read). Under `REPEATABLE READ`, A's second read still returns `500` — A reads its opening snapshot until it commits.

<details>
<summary>Hint</summary>

The phenomenon depends only on A's reads spanning B's commit. The isolation level you set in A is what decides whether A sees B's committed change mid-transaction.

</details>

<details>
<summary>Solution</summary>

```sql
-- Both sessions:
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- [A] (1)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5;   -- 500

-- [B] (2)
START TRANSACTION;
UPDATE student_account SET balance = 400 WHERE student_id = 5;
COMMIT;

-- [A] (3)
SELECT balance FROM student_account WHERE student_id = 5;   -- 400  ← non-repeatable read
COMMIT;

-- Reset and repeat at REPEATABLE READ:
--   source schema/reset.sql;
-- Both sessions: SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- A's step (3) now returns 500.
```

**What you practiced:** Reproducing a non-repeatable read at `READ COMMITTED` and preventing it at `REPEATABLE READ` via snapshot reads.

</details>

---

## Problem 3 — Reproduce a Lost Update (Medium)

Two concurrent charges, each reading the balance first, can silently drop one charge.

**Your task:**
1. `source schema/reset.sql` so student 5 is back to `500`
2. Session A and Session B each `START TRANSACTION` and read student 5's balance (both see `500`)
3. Session A: `UPDATE` the balance to `500 - 100`, `COMMIT`
4. Session B: `UPDATE` the balance to `500 - 50`, `COMMIT`
5. Read the final balance and explain why it is wrong

**Expected:** The final balance is `450`, not `350`. Both sessions computed from the stale `500`; B's write overwrote A's, so A's `$100` charge is lost.

<details>
<summary>Hint</summary>

The bug is writing a **literal** computed from a value you read earlier (`500 - 50`). Both transactions read `500` before either wrote, so the second commit wins.

</details>

<details>
<summary>Solution</summary>

```sql
-- [A] (1)                                  -- [B] (1)
START TRANSACTION;                          START TRANSACTION;
SELECT balance FROM student_account         SELECT balance FROM student_account
WHERE student_id = 5;   -- 500              WHERE student_id = 5;   -- 500

-- [A] (2)
UPDATE student_account SET balance = 500 - 100 WHERE student_id = 5;
COMMIT;                                     -- 400

-- [B] (2)
UPDATE student_account SET balance = 500 - 50 WHERE student_id = 5;
COMMIT;                                     -- 450  ← A's charge lost

SELECT balance FROM student_account WHERE student_id = 5;   -- 450 (should be 350)
```

**What you practiced:** Reproducing a lost update — a read-modify-write race that isolation level alone does not prevent.

</details>

---

## Problem 4 — Prevent the Lost Update with FOR UPDATE (Hard)

Use row locking so the two charges serialise and the total is correct.

**Your task:**
1. `source schema/reset.sql` so student 5 is back to `500`
2. Session A: `START TRANSACTION`, then `SELECT ... FOR UPDATE` student 5's row
3. Session B: `START TRANSACTION`, then `SELECT ... FOR UPDATE` the same row — confirm it **blocks**
4. Session A: `UPDATE balance = balance - 100`, `COMMIT` — Session B now unblocks
5. Session B: `UPDATE balance = balance - 50`, `COMMIT`
6. Verify the final balance is `350`

**Expected:** B's `SELECT ... FOR UPDATE` waits until A commits. Because B's `UPDATE` uses `balance - 50` on the **live** value (now `400`), the final balance is `350` — both charges applied.

<details>
<summary>Hint</summary>

Two things matter: lock the row with `FOR UPDATE` so B waits, **and** write with `SET balance = balance - 50` (a delta on the current value) rather than a number you read earlier.

</details>

<details>
<summary>Solution</summary>

```sql
-- [A] (1)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5 FOR UPDATE;   -- 500, locked

-- [B] (2)  -- BLOCKS until A commits
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5 FOR UPDATE;   -- waiting...

-- [A] (3)
UPDATE student_account SET balance = balance - 100 WHERE student_id = 5;
COMMIT;                                                     -- 400, lock released

-- [B] (4)  -- unblocks, sees 400
UPDATE student_account SET balance = balance - 50 WHERE student_id = 5;
COMMIT;                                                     -- 350

SELECT balance FROM student_account WHERE student_id = 5;   -- 350 ✓
```

**What you practiced:** Preventing a lost update with pessimistic locking (`SELECT ... FOR UPDATE`) plus a delta `UPDATE`.

</details>

---

## Problem 5 — Trigger and Resolve a Deadlock (Hard)

Make two transactions lock the same two rows in opposite order, observe InnoDB abort one, and reason about the fix.

**Your task:**
1. `source schema/reset.sql`
2. Session A: `START TRANSACTION`, `UPDATE` student 5's row (locks it)
3. Session B: `START TRANSACTION`, `UPDATE` student 6's row (locks it)
4. Session A: `UPDATE` student 6's row — it waits for B
5. Session B: `UPDATE` student 5's row — completes the cycle; one session gets `ERROR 1213`
6. Explain which session was the victim and how you would prevent this in real code

**Expected:** One session receives `ERROR 1213 (40001): Deadlock found ...` and is rolled back; the other proceeds. The fix is to always lock rows in a consistent order (e.g. lowest `student_id` first) and to retry the victim transaction.

<details>
<summary>Hint</summary>

A deadlock needs a **cycle**: A holds 5 and wants 6 while B holds 6 and wants 5. InnoDB detects the cycle immediately and rolls back the cheaper transaction with error `1213`.

</details>

<details>
<summary>Solution</summary>

```sql
-- [A] (1)
START TRANSACTION;
UPDATE student_account SET balance = balance - 1 WHERE student_id = 5;   -- locks row 5

-- [B] (2)
START TRANSACTION;
UPDATE student_account SET balance = balance - 1 WHERE student_id = 6;   -- locks row 6

-- [A] (3)  -- wants row 6 → waits
UPDATE student_account SET balance = balance - 1 WHERE student_id = 6;

-- [B] (4)  -- wants row 5 → cycle → DEADLOCK
UPDATE student_account SET balance = balance - 1 WHERE student_id = 5;
-- ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction

-- Inspect: SHOW ENGINE INNODB STATUS;
-- COMMIT/ROLLBACK both sessions to clean up.
```

**Prevention:** order lock acquisition consistently (always touch student 5 before student 6) so no cycle can form, and wrap the transaction in application retry logic that re-runs it on error `1213`.

**What you practiced:** Producing a real deadlock, seeing InnoDB pick a victim, and the two standard defences — consistent lock ordering and retry.

</details>

---

## Bonus — Which Phenomena Can Occur?

No SQL to write. For each isolation level, say whether a **dirty read**, **non-repeatable read**, and **phantom read** are possible, and give a one-line reason for the trickiest one.

1. `READ UNCOMMITTED`
2. `READ COMMITTED`
3. `REPEATABLE READ` (InnoDB)

<details>
<summary>Answer</summary>

1. **`READ UNCOMMITTED`** — all three possible. You can even read another transaction's uncommitted (dirty) data, which may later roll back.
2. **`READ COMMITTED`** — dirty read prevented; non-repeatable read and phantom read still possible. Each statement sees the latest *committed* data, so the same row can change between two reads in one transaction.
3. **`REPEATABLE READ` (InnoDB)** — all three prevented. Each transaction reads from a consistent snapshot taken at its start, and InnoDB's next-key locking blocks the inserts that would cause phantoms — going beyond what the SQL standard requires at this level.

**What you practiced:** Mapping isolation levels to the read phenomena they allow, including InnoDB's stronger-than-standard `REPEATABLE READ`.

</details>

---

## Cleanup

Restore the default isolation level (if you changed it) and the seeded balances:

```sql
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- Re-run the full schema to restore original balances:
--   source schema/reset.sql;
```
