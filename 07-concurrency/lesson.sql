-- =============================================================
-- 07 Concurrency Control — Runnable Examples
-- Run schema/reset.sql first. Assumes MySQL 8.0+ with InnoDB (the default).
--
-- ⚠ TWO SESSIONS REQUIRED.
-- Concurrency phenomena only appear when two transactions overlap, so you
-- CANNOT reproduce them by piping this file through a single client. Open two
-- MySQL clients — Session A and Session B — and run the numbered steps in the
-- order shown, switching windows at each step. Lines are prefixed [A] or [B].
--
-- Restore the seeded balances any time with:  source schema/reset.sql;
-- =============================================================


-- -------------------------------------------------------------
-- 0. Inspect / set the isolation level (run in either session)
-- -------------------------------------------------------------
SELECT @@transaction_isolation;          -- default: REPEATABLE-READ


-- -------------------------------------------------------------
-- 1. Non-repeatable read under READ COMMITTED
--    Run A-step then B-step then A-step, in order.
-- -------------------------------------------------------------
-- [A] (1)
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5;   -- 500.00

-- [B] (2)
START TRANSACTION;
UPDATE student_account SET balance = 400 WHERE student_id = 5;
COMMIT;

-- [A] (3)
SELECT balance FROM student_account WHERE student_id = 5;   -- 400.00  ← changed mid-transaction
COMMIT;

-- Now repeat steps (1)-(3) with BOTH sessions at REPEATABLE READ:
--   SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Step (3) will still read 500.00 — A sees a consistent snapshot.
-- (reset.sql to restore balance to 500 before re-trying)


-- -------------------------------------------------------------
-- 2. Lost update — the bug (READ COMMITTED or REPEATABLE READ)
--    Reset balance to 500 first: source schema/reset.sql;
-- -------------------------------------------------------------
-- [A] (1)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5;   -- 500

-- [B] (2)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5;   -- 500

-- [A] (3)
UPDATE student_account SET balance = 500 - 100 WHERE student_id = 5;
COMMIT;                                                     -- balance 400

-- [B] (4)
UPDATE student_account SET balance = 500 - 50 WHERE student_id = 5;
COMMIT;                                                     -- balance 450  ← A's 100 charge lost


-- -------------------------------------------------------------
-- 3. Lost update — the fix with SELECT ... FOR UPDATE
--    Reset balance to 500 first: source schema/reset.sql;
-- -------------------------------------------------------------
-- [A] (1)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5 FOR UPDATE;   -- 500, row locked

-- [B] (2)  -- this BLOCKS until A commits
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5 FOR UPDATE;   -- waits...

-- [A] (3)
UPDATE student_account SET balance = balance - 100 WHERE student_id = 5;
COMMIT;                                                     -- balance 400, lock released

-- [B] (4)  -- now unblocks and sees 400
UPDATE student_account SET balance = balance - 50 WHERE student_id = 5;
COMMIT;                                                     -- balance 350  ← correct


-- -------------------------------------------------------------
-- 4. Deadlock — lock two rows in opposite order
--    Reset first: source schema/reset.sql;
-- -------------------------------------------------------------
-- [A] (1)
START TRANSACTION;
UPDATE student_account SET balance = balance - 1 WHERE student_id = 5;   -- locks row 5

-- [B] (2)
START TRANSACTION;
UPDATE student_account SET balance = balance - 1 WHERE student_id = 6;   -- locks row 6

-- [A] (3)  -- wants row 6 → waits for B
UPDATE student_account SET balance = balance - 1 WHERE student_id = 6;

-- [B] (4)  -- wants row 5 → cycle → one session is aborted:
UPDATE student_account SET balance = balance - 1 WHERE student_id = 5;
-- ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction

-- The victim must retry its whole transaction. Inspect details:
SHOW ENGINE INNODB STATUS;

-- COMMIT or ROLLBACK both sessions to clean up.


-- -------------------------------------------------------------
-- 5. Optimistic locking — no locks, check-and-set
--    Reset first: source schema/reset.sql;
-- -------------------------------------------------------------
-- Read balance = 500 (no lock), then only write if it is still 500:
UPDATE student_account SET balance = 400 WHERE student_id = 5 AND balance = 500;
SELECT ROW_COUNT();   -- 1 = succeeded; 0 = someone changed it first → re-read and retry


-- -------------------------------------------------------------
-- Cleanup — restore the default isolation level and seed data
-- -------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Restore original balances:
--   source schema/reset.sql;
