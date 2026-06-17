# SQL Concurrency Control Lesson

> **Prerequisites:** You should have completed the [Transactions](../06-transactions/lesson.md) lesson — concurrency control is entirely about what happens when several of those transactions run **at the same time**. You will reuse `START TRANSACTION`, `COMMIT`, and `ROLLBACK` throughout.

## Learning Objectives

By the end of this lesson you will be able to:

- Explain why two correct transactions can corrupt data when they run concurrently
- Name the three read phenomena: dirty read, non-repeatable read, and phantom read
- Map each phenomenon to the isolation level that prevents it
- Set the isolation level with `SET TRANSACTION ISOLATION LEVEL` and read InnoDB's default
- Reproduce a **lost update** and understand why it happens
- Take explicit row locks with `SELECT ... FOR UPDATE` and `FOR SHARE`
- Recognise a **deadlock**, why it arises, and how InnoDB resolves it
- Choose between pessimistic locking and an optimistic (version-column) strategy

> **You need two sessions.** Every phenomenon below only appears when two transactions overlap. Open **two separate MySQL clients** (call them **Session A** and **Session B**) and run the numbered steps in order, alternating between the windows. Piping a single script straight through will *not* reproduce any of this — the whole point is the interleaving.

---

## Why This Matters

Two registrars process a charge against student 5's account (balance `$500`) at the same moment. Each app does the natural thing — read the balance, subtract a fee, write it back:

```text
Session A: read balance = 500
Session B: read balance = 500
Session A: 500 - 100 = 400, write 400, commit
Session B: 500 - 50  = 450, write 450, commit   <- overwrites A
```

The account was charged `$150` total but the final balance is `$450`, not `$350`. **A's charge vanished.** Neither transaction is buggy on its own; the bug only exists because they overlapped. This is a **lost update**, and it is invisible in single-user testing.

Concurrency control is the set of tools — isolation levels and locks — that the database gives you to make overlapping transactions behave as if they had run one after another.

---

## 1. The Three Read Phenomena

The SQL standard names three ways a transaction can see inconsistent data when others are running. Each is defined by a two-session timeline.

| Phenomenon | What happens | Timeline |
|---|---|---|
| **Dirty read** | You read another transaction's change *before it commits* — and it may roll back | B updates a row; A reads the new value; B rolls back; A acted on data that never existed |
| **Non-repeatable read** | You read the same row twice and get **different values**, because someone committed a change between your reads | A reads balance = 500; B updates it to 400 and commits; A reads again = 400 |
| **Phantom read** | You run the same query twice and get **different rows**, because someone inserted/deleted matching rows | A counts Active enrollments = 5; B inserts one and commits; A counts again = 6 |

> A non-repeatable read is about an existing row *changing*; a phantom is about the *set of rows* changing. Different fixes apply to each.

---

## 2. Isolation Levels

The **isolation level** controls which of these phenomena are allowed. Higher levels prevent more, at the cost of more locking (and so less concurrency). The four standard levels:

| Level | Dirty read | Non-repeatable read | Phantom read |
|---|---|---|---|
| `READ UNCOMMITTED` | ✅ possible | ✅ possible | ✅ possible |
| `READ COMMITTED` | ❌ prevented | ✅ possible | ✅ possible |
| `REPEATABLE READ` *(InnoDB default)* | ❌ prevented | ❌ prevented | ❌ prevented¹ |
| `SERIALIZABLE` | ❌ prevented | ❌ prevented | ❌ prevented |

¹ In the standard, `REPEATABLE READ` still allows phantoms. **InnoDB goes further** — its consistent-snapshot reads plus next-key locking prevent phantoms too at this level, which is one reason it is the sensible default.

> Higher is not automatically better. `SERIALIZABLE` makes plain `SELECT`s take locks and can serialise your whole workload, hurting throughput. Most applications run happily on the default `REPEATABLE READ` (or drop to `READ COMMITTED` for higher concurrency).

---

## 3. Setting the Isolation Level

```sql
-- Inspect the current level
SELECT @@transaction_isolation;          -- e.g. REPEATABLE-READ

-- Change it for your session (affects transactions you start afterwards)
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- Or for the very next transaction only
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
    -- ... runs at SERIALIZABLE ...
COMMIT;
```

`SET SESSION` lasts for your connection; `SET GLOBAL` changes the default for new connections (and needs privileges). Set the level **before** `START TRANSACTION` — you cannot change it mid-transaction.

---

## 4. Seeing a Non-Repeatable Read

Run this in two windows to watch isolation level change the outcome. First under `READ COMMITTED`:

```sql
-- ── Session A ──                          -- ── Session B ──
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT balance FROM student_account         -- (1) 500.00
WHERE student_id = 5;
                                            START TRANSACTION;
                                            UPDATE student_account
                                            SET balance = 400
                                            WHERE student_id = 5;
                                            COMMIT;                 -- (2)
SELECT balance FROM student_account         -- (3) 400.00  ← changed!
WHERE student_id = 5;
COMMIT;
```

A read the same row twice in one transaction and got two different answers — a **non-repeatable read**. Now redo it with both sessions at `REPEATABLE READ` (the default): step (3) still returns **500.00**, because A reads from a consistent snapshot taken when its transaction began. B's committed change is invisible to A until A commits and starts fresh.

---

## 5. The Lost Update Problem

Isolation levels govern what you *read*, but a read-modify-write race can still drop a write. Reproduce the `$500` example:

```sql
-- ── Session A ──                          -- ── Session B ──
START TRANSACTION;                          START TRANSACTION;
SELECT balance FROM student_account         SELECT balance FROM student_account
WHERE student_id = 5;   -- 500              WHERE student_id = 5;   -- 500
UPDATE student_account
SET balance = 500 - 100 WHERE student_id=5;
COMMIT;  -- balance 400
                                            UPDATE student_account
                                            SET balance = 500 - 50 WHERE student_id=5;
                                            COMMIT;  -- balance 450  ← A's charge lost
```

Both computed from the stale `500` they each read. The final `450` reflects only B. The fix is to stop them reading the same row at once — locking.

---

## 6. Pessimistic Locking — `SELECT ... FOR UPDATE`

`SELECT ... FOR UPDATE` reads a row **and locks it** for writing. Any other transaction that tries to `SELECT ... FOR UPDATE` (or `UPDATE`) the same row **blocks** until you commit. This serialises the read-modify-write and kills the lost update:

```sql
-- ── Session A ──                          -- ── Session B ──
START TRANSACTION;
SELECT balance FROM student_account
WHERE student_id = 5
FOR UPDATE;             -- 500, row locked
                                            START TRANSACTION;
                                            SELECT balance FROM student_account
                                            WHERE student_id = 5
                                            FOR UPDATE;   -- BLOCKS, waiting for A
UPDATE student_account
SET balance = balance - 100 WHERE student_id=5;
COMMIT;                 -- releases the lock
                                            -- now unblocks, sees 400
                                            UPDATE student_account
                                            SET balance = balance - 50 WHERE student_id=5;
                                            COMMIT;       -- 350 — correct!
```

The total is now `$150` and the final balance `$350`. Use **`UPDATE ... WHERE`** as the write — letting the engine apply the delta to the *current* value — rather than writing a number you computed from a stale read.

> `FOR SHARE` (formerly `LOCK IN SHARE MODE`) takes a weaker **shared** lock: others may also read-share it, but nobody can modify it until you commit. Use `FOR SHARE` when you must read a row consistently but are not going to change it; use `FOR UPDATE` when you intend to write. Both require an open transaction — a lock with no transaction is released instantly.

---

## 7. Deadlocks

Locks introduce a new risk: two transactions each holding a lock the other needs, waiting forever. InnoDB **detects** this and aborts one of them.

```sql
-- ── Session A ──                          -- ── Session B ──
START TRANSACTION;                          START TRANSACTION;
UPDATE student_account SET balance=balance-1
WHERE student_id = 5;   -- locks row 5
                                            UPDATE student_account SET balance=balance-1
                                            WHERE student_id = 6;   -- locks row 6
UPDATE student_account SET balance=balance-1
WHERE student_id = 6;   -- wants row 6 → waits for B
                                            UPDATE student_account SET balance=balance-1
                                            WHERE student_id = 5;   -- wants row 5 → DEADLOCK
-- One session gets:
-- ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction
```

InnoDB picks a **victim** (usually the one that did less work), rolls it back, and lets the other proceed. The victim's whole transaction is undone, so it must be **retried**.

> Deadlocks are normal, not a bug to eliminate entirely. Two defences: (1) **lock rows in a consistent order** everywhere (e.g. always lowest `student_id` first) so cycles cannot form; (2) **wrap transactions in retry logic** in the application — catch `1213` and run the transaction again. `SHOW ENGINE INNODB STATUS;` shows details of the last deadlock.

---

## 8. Optimistic Locking (the alternative)

Pessimistic locking blocks others up front. **Optimistic** locking assumes conflicts are rare: read freely, then verify nothing changed at write time using a version (or the old value) in the `WHERE` clause.

```sql
-- Read balance = 500 (no lock). At write time, only succeed if it is still 500:
UPDATE student_account
SET balance = 400
WHERE student_id = 5 AND balance = 500;

-- Check the affected-row count: 0 means someone else changed it first → re-read and retry.
SELECT ROW_COUNT();
```

If `ROW_COUNT()` is `0`, the row moved under you — abort and retry. Optimistic locking avoids holding locks (great for low-contention, read-heavy workloads); pessimistic locking is simpler when contention is high.

---

## Common Mistakes and Gotchas

| Mistake | What Happens | How to Avoid |
|---------|-------------|--------------|
| Testing concurrency in one session | The race never appears; bugs ship to production | Always reproduce with two interleaved sessions |
| Expecting a plain `SELECT` to lock | Under snapshot reads it takes no lock; lost updates slip through | Use `SELECT ... FOR UPDATE` when you will write the row |
| Writing a value computed from a stale read | Overwrites a concurrent change (lost update) | Lock first, then `UPDATE ... SET col = col - x` on the live value |
| Locking with no open transaction | The lock releases immediately and protects nothing | `FOR UPDATE`/`FOR SHARE` only hold inside `START TRANSACTION ... COMMIT` |
| Cranking everything to `SERIALIZABLE` | Throughput collapses as plain reads start blocking | Use the default `REPEATABLE READ`; raise the level only where needed |
| Treating a deadlock as a fatal error | Users see random failures | Catch `1213` and **retry** the transaction; lock rows in a consistent order |
| Holding a transaction open during slow work | Locks block everyone else for the duration | Keep transactions short; do slow work before taking locks |

---

## When to Use What

| Situation | Approach |
|-----------|----------|
| Read-modify-write on a hot row (balances, counters, seats) | `SELECT ... FOR UPDATE`, then `UPDATE` the live value |
| Read a row consistently but not modify it | `FOR SHARE` |
| Low contention, read-heavy, want maximum concurrency | Optimistic: version/old-value check in `WHERE` + retry |
| Need to prevent phantoms in a range scan | `REPEATABLE READ` (InnoDB) or `SERIALIZABLE` |
| Want highest concurrency and can tolerate non-repeatable reads | `READ COMMITTED` |

---

## Quick Reference

| Statement | Purpose |
|---|---|
| `SELECT @@transaction_isolation` | Show the current isolation level |
| `SET SESSION TRANSACTION ISOLATION LEVEL <level>` | Set the level for this connection |
| `SET TRANSACTION ISOLATION LEVEL <level>` | Set the level for the next transaction only |
| `SELECT ... FOR UPDATE` | Read and take an exclusive lock (others block on write) |
| `SELECT ... FOR SHARE` | Read and take a shared lock (others may read, not write) |
| `UPDATE t SET c = c - x WHERE ...` | Apply a delta to the live value (avoids lost updates) |
| `WHERE ... AND col = :old_value` | Optimistic check — combine with `ROW_COUNT()` |
| `SHOW ENGINE INNODB STATUS` | Inspect the last deadlock and current locks |

---

## What's Next?

That completes the seven-topic path — Views, Updatable Views, Stored Procedures, Triggers, Indexing, Transactions, and Concurrency Control. The natural next step is the [cross-topic challenges](../README.md#challenges), especially the **University Admin Dashboard** capstone, which ties every topic together: views over the data, procedures and triggers to maintain it, indexes to keep it fast, and transactions with the right isolation to keep it correct under load.
