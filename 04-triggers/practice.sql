-- SOLUTION OF PROBLEM 01 — Default the Grading Date (Easy)

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

INSERT INTO grade (enrollment_id, numeric_grade, letter_grade)
VALUES (7, 84.00, 'B');

SELECT enrollment_id, numeric_grade, letter_grade, graded_date
FROM grade
WHERE enrollment_id = 7;


-- SOLUTION OF PROBLEM 02 — Reject Out-of-Range Grades (Easy)

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


-- SOLUTION OF PROBLEM 03 — Audit Grade Changes (Medium)

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


-- SOLUTION OF PROBLEM 04 — Keep the Letter Grade in Sync (Medium)

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

INSERT INTO grade (enrollment_id, numeric_grade) VALUES (12, 73.00);

UPDATE grade SET numeric_grade = 59.00 WHERE enrollment_id = 12;

SELECT enrollment_id, numeric_grade, letter_grade
FROM grade
WHERE enrollment_id = 12;


-- SOLUTION OF PROBLEM 05 — Protect Completed Grades (Hard)

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


-- == CLEANUP ==

DROP TRIGGER IF EXISTS trg_grade_before_insert_date;
DROP TRIGGER IF EXISTS trg_grade_validate;
DROP TRIGGER IF EXISTS trg_grade_after_update_audit;
DROP TRIGGER IF EXISTS trg_grade_derive_insert;
DROP TRIGGER IF EXISTS trg_grade_derive_update;
DROP TRIGGER IF EXISTS trg_grade_no_delete_completed;
