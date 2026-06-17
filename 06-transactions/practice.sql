-- =============================================================
-- 06 Transactions — Practice Solutions
-- Run schema/reset.sql first. Assumes MySQL 8.0+ with InnoDB (the default).
-- Several problems deduct money on purpose; restore seeded balances any time
-- with:  source schema/reset.sql;
-- =============================================================


-- -------------------------------------------------------------
-- Problem 1 — Commit a Charge (Easy)
-- -------------------------------------------------------------
SELECT balance FROM student_account WHERE student_id = 6;   -- before

START TRANSACTION;
    UPDATE student_account SET balance = balance - 150.00 WHERE student_id = 6;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (6, 150.00, 'Fee', 'Lab fee');
COMMIT;

SELECT balance FROM student_account WHERE student_id = 6;   -- 150 lower
SELECT amount, payment_type, description
FROM payment WHERE student_id = 6 ORDER BY payment_id DESC LIMIT 1;


-- -------------------------------------------------------------
-- Problem 2 — Roll It Back (Easy)
-- -------------------------------------------------------------
SELECT balance FROM student_account WHERE student_id = 3;   -- before

START TRANSACTION;
    UPDATE student_account SET balance = balance - 500.00 WHERE student_id = 3;
    SELECT balance FROM student_account WHERE student_id = 3;   -- uncommitted (lower)
ROLLBACK;

SELECT balance FROM student_account WHERE student_id = 3;   -- back to original


-- -------------------------------------------------------------
-- Problem 3 — Partial Rollback with a SAVEPOINT (Medium)
-- -------------------------------------------------------------
SELECT balance FROM student_account WHERE student_id = 10;   -- before

START TRANSACTION;
    UPDATE student_account SET balance = balance - 100.00 WHERE student_id = 10;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (10, 100.00, 'Fee', 'Activity fee');

    SAVEPOINT after_first;

    UPDATE student_account SET balance = balance - 2000.00 WHERE student_id = 10;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (10, 2000.00, 'Tuition', 'Mistaken charge');

    ROLLBACK TO after_first;   -- undo the 2000 charge and its payment insert
COMMIT;

SELECT balance FROM student_account WHERE student_id = 10;   -- 100 lower only
SELECT amount, description FROM payment WHERE student_id = 10 ORDER BY payment_id;


-- -------------------------------------------------------------
-- Problem 4 — Wrap It Safely in a Procedure (Medium)
-- (superseded by Problem 5's funds-guarded version, but shown standalone first)
-- -------------------------------------------------------------
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


-- -------------------------------------------------------------
-- Problem 5 — Guard the Funds (Hard) — final version of charge_fee
-- -------------------------------------------------------------
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

-- Fails: 800 > 500 for student 5. Nothing changes.
-- (uncomment to see the error: ERROR 1644 Insufficient funds for this charge)
-- CALL charge_fee(5, 800.00, 'Equipment fee');

-- Succeeds: 200 <= 500. Balance -> 300, payment recorded.
CALL charge_fee(5, 200.00, 'Equipment fee');

SELECT balance FROM student_account WHERE student_id = 5;   -- 300.00
SELECT amount, description FROM payment WHERE student_id = 5 ORDER BY payment_id DESC LIMIT 1;


-- -------------------------------------------------------------
-- Cleanup
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS charge_fee;
-- Restore original seeded balances and payment history:
--   source schema/reset.sql;
