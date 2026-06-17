-- =============================================================
-- 06 Transactions — Runnable Examples
-- Run schema/reset.sql first. Assumes MySQL 8.0+ with InnoDB (the default).
-- This script is re-runnable: it drops the procedure it creates, and you can
-- restore the seeded balances any time with:  source schema/reset.sql;
-- Pair each block with the prose in lesson.md.
-- =============================================================


-- -------------------------------------------------------------
-- 1. START TRANSACTION / COMMIT — both writes become permanent together
-- -------------------------------------------------------------
START TRANSACTION;
    UPDATE student_account SET balance = balance - 150.00 WHERE student_id = 6;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (6, 150.00, 'Fee', 'Lab fee');
COMMIT;


-- -------------------------------------------------------------
--    ...and ROLLBACK — the work is thrown away
-- -------------------------------------------------------------
START TRANSACTION;
    UPDATE student_account SET balance = balance - 9999.00 WHERE student_id = 6;
ROLLBACK;
-- Balance is untouched by the line above.


-- -------------------------------------------------------------
-- 2. Autocommit — on by default (1)
-- -------------------------------------------------------------
SELECT @@autocommit;


-- -------------------------------------------------------------
-- 3. An atomic charge — prove both moved together
-- -------------------------------------------------------------
SELECT balance FROM student_account WHERE student_id = 6;   -- before

START TRANSACTION;
    UPDATE student_account SET balance = balance - 200.00 WHERE student_id = 6;
    INSERT INTO payment (student_id, amount, payment_type, description)
    VALUES (6, 200.00, 'Fee', 'Late registration fee');
COMMIT;

SELECT balance FROM student_account WHERE student_id = 6;   -- after (200 lower)
SELECT amount, payment_type, description
FROM payment WHERE student_id = 6 ORDER BY payment_id DESC LIMIT 1;


-- -------------------------------------------------------------
-- 4. SAVEPOINT — keep the first change, undo the second
-- -------------------------------------------------------------
START TRANSACTION;
    UPDATE student_account SET balance = balance - 100.00 WHERE student_id = 6;   -- keep
    SAVEPOINT after_fee;

    UPDATE student_account SET balance = balance - 5000.00 WHERE student_id = 6;  -- oops
    ROLLBACK TO after_fee;   -- undo only the 5000 charge
COMMIT;   -- the 100 charge persists


-- -------------------------------------------------------------
-- 5 & 6. Transaction inside a procedure, with a funds guard
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

    -- Any SQL error (including the SIGNAL below) rolls back and re-raises.
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

-- Success path: student 6 has plenty
CALL charge_fee(6, 250.00, 'Library fine');

-- Failure path: student 5 has only 500.00 — this errors and changes nothing
-- (uncomment to see the error)
-- CALL charge_fee(5, 800.00, 'Equipment fee');

-- Valid charge for student 5
CALL charge_fee(5, 200.00, 'Equipment fee');

SELECT student_id, balance FROM student_account WHERE student_id IN (5, 6);


-- -------------------------------------------------------------
-- Cleanup
-- -------------------------------------------------------------
DROP PROCEDURE IF EXISTS charge_fee;
-- Restore the original seeded balances and payments:
--   source schema/reset.sql;
