-- =============================================================
-- 07 Concurrency Control — Practice Solutions
-- Run schema/reset.sql first (and again between problems — balances change).
-- Assumes MySQL 8.0+ with InnoDB (the default).
--
-- ⚠ TWO SESSIONS REQUIRED. Open Session A and Session B and run the [A]/[B]
-- steps in order, switching windows at each step. Piping this file straight
-- through a single client will NOT reproduce the races.
--
-- Restore seeded balances any time with:  source schema/reset.sql;
-- =============================================================


-- -------------------------------------------------------------
-- Problem 1 — Inspect and Change the Isolation Level (Easy)
-- -------------------------------------------------------------
SELECT @@transaction_isolation;                               -- REPEATABLE-READ
SET SESSION TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT @@transaction_isolation;                               -- READ-COMMITTED
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT @@transaction_isolation;                               -- REPEATABLE-READ


-- -------------------------------------------------------------
-- Problem 2 — Non-repeatable read (READ COMMITTED), then prevented
-- -------------------------------------------------------------
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

-- Reset, set both sessions to REPEATABLE READ, repeat → A's step (3) reads 500.
--   source schema/reset.sql;


-- -------------------------------------------------------------
-- Problem 3 — Reproduce a Lost Update (Medium)
-- (reset first: source schema/reset.sql;)
-- -------------------------------------------------------------
-- [A] (1)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5;   -- 500

-- [B] (1)
START TRANSACTION;
SELECT balance FROM student_account WHERE student_id = 5;   -- 500

-- [A] (2)
UPDATE student_account SET balance = 500 - 100 WHERE student_id = 5;
COMMIT;                                                     -- 400

-- [B] (2)
UPDATE student_account SET balance = 500 - 50 WHERE student_id = 5;
COMMIT;                                                     -- 450  ← A's charge lost

SELECT balance FROM student_account WHERE student_id = 5;   -- 450 (should be 350)


-- -------------------------------------------------------------
-- Problem 4 — Prevent the Lost Update with FOR UPDATE (Hard)
-- (reset first: source schema/reset.sql;)
-- -------------------------------------------------------------
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


-- -------------------------------------------------------------
-- Problem 5 — Trigger and Resolve a Deadlock (Hard)
-- (reset first: source schema/reset.sql;)
-- -------------------------------------------------------------
-- [A] (1)
START TRANSACTION;
UPDATE student_account SET balance = balance - 1 WHERE student_id = 5;   -- locks row 5

-- [B] (2)
START TRANSACTION;
UPDATE student_account SET balance = balance - 1 WHERE student_id = 6;   -- locks row 6

-- [A] (3)  -- wants row 6 → waits for B
UPDATE student_account SET balance = balance - 1 WHERE student_id = 6;

-- [B] (4)  -- wants row 5 → cycle → DEADLOCK on one session
UPDATE student_account SET balance = balance - 1 WHERE student_id = 5;
-- ERROR 1213 (40001): Deadlock found when trying to get lock; try restarting transaction

SHOW ENGINE INNODB STATUS;   -- details of the last deadlock
-- COMMIT or ROLLBACK both sessions to clean up.
-- Prevention: lock rows in a consistent order; retry the victim on error 1213.


-- -------------------------------------------------------------
-- Cleanup
-- -------------------------------------------------------------
SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;
-- Restore original balances:
--   source schema/reset.sql;
