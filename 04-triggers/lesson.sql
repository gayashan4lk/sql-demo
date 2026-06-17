-- ============================================================
-- SQL TRIGGERS LESSON
-- Run schema/reset.sql first.
-- ============================================================


-- == ABOUT DELIMITER ==
-- Like procedures, trigger bodies contain many ; characters.
-- Change the delimiter to $$ while defining a trigger, then
-- change it back to ; afterwards.


-- == 1. NEW AND OLD ==
-- NEW = the row after the change  (INSERT, UPDATE)
-- OLD = the row before the change (UPDATE, DELETE)
-- In a BEFORE trigger you may assign to NEW.column.


-- == 2. BEFORE INSERT — NORMALIZE / DERIVE (with validation from section 3) ==

DROP TRIGGER IF EXISTS trg_grade_before_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_before_insert
    BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
    -- Reject out-of-range grades before anything else
    IF NEW.numeric_grade < 0 OR NEW.numeric_grade > 100 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'numeric_grade must be between 0 and 100';
    END IF;

    -- Default the grading date to today if none was provided
    IF NEW.graded_date IS NULL THEN
        SET NEW.graded_date = CURDATE();
    END IF;

    -- Derive the letter grade from the numeric grade
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

-- Enrollment 6 (Clara Davis, CS101) has no grade yet
INSERT INTO grade (enrollment_id, numeric_grade) VALUES (6, 88.00);

SELECT enrollment_id, letter_grade, numeric_grade, graded_date
FROM grade WHERE enrollment_id = 6;


-- == 3. BEFORE INSERT — VALIDATION WITH SIGNAL ==
-- (Validation already built into trg_grade_before_insert above.)
-- This should FAIL:

-- INSERT INTO grade (enrollment_id, numeric_grade) VALUES (10, 150.00);
-- ERROR 1644 (45000): numeric_grade must be between 0 and 100


-- == 4. AFTER INSERT — AUDIT LOGGING ==

DROP TRIGGER IF EXISTS trg_grade_after_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_after_insert
    AFTER INSERT ON grade
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
    VALUES (
        'grade',
        'INSERT',
        NEW.grade_id,
        NULL,
        CONCAT('numeric_grade=', NEW.numeric_grade,
               ', letter_grade=', NEW.letter_grade)
    );
END $$

DELIMITER ;

INSERT INTO grade (enrollment_id, numeric_grade) VALUES (11, 77.00);

SELECT table_name, action, record_id, old_value, new_value
FROM audit_log
WHERE table_name = 'grade'
ORDER BY log_id DESC
LIMIT 1;


-- == 5. AFTER UPDATE — LOG OLD VS NEW ==

DROP TRIGGER IF EXISTS trg_grade_after_update;

DELIMITER $$

CREATE TRIGGER trg_grade_after_update
    AFTER UPDATE ON grade
    FOR EACH ROW
BEGIN
    IF OLD.numeric_grade <> NEW.numeric_grade THEN
        INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
        VALUES (
            'grade',
            'UPDATE',
            NEW.grade_id,
            CONCAT('numeric_grade=', OLD.numeric_grade,
                   ', letter_grade=', OLD.letter_grade),
            CONCAT('numeric_grade=', NEW.numeric_grade,
                   ', letter_grade=', NEW.letter_grade)
        );
    END IF;
END $$

DELIMITER ;

-- Bump Alice's CS101 grade (enrollment 1) from 92.50 to 96.00
UPDATE grade SET numeric_grade = 96.00 WHERE enrollment_id = 1;

-- A no-op update logs nothing
UPDATE grade SET numeric_grade = 96.00 WHERE enrollment_id = 1;

SELECT action, old_value, new_value
FROM audit_log
WHERE table_name = 'grade' AND action = 'UPDATE'
ORDER BY log_id DESC
LIMIT 1;


-- == 6. AFTER DELETE — LOG REMOVALS ==

DROP TRIGGER IF EXISTS trg_grade_after_delete;

DELIMITER $$

CREATE TRIGGER trg_grade_after_delete
    AFTER DELETE ON grade
    FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
    VALUES (
        'grade',
        'DELETE',
        OLD.grade_id,
        CONCAT('numeric_grade=', OLD.numeric_grade,
               ', letter_grade=', OLD.letter_grade),
        NULL
    );
END $$

DELIMITER ;

-- Delete the grade we added for enrollment 6
DELETE FROM grade WHERE enrollment_id = 6;

SELECT action, old_value, new_value
FROM audit_log
WHERE table_name = 'grade' AND action = 'DELETE'
ORDER BY log_id DESC
LIMIT 1;


-- == 7. MANAGING TRIGGERS ==

SHOW TRIGGERS LIKE 'grade'\G
SHOW CREATE TRIGGER trg_grade_after_insert\G


-- == END-TO-END DEMO ==

INSERT INTO grade (enrollment_id, numeric_grade) VALUES (10, 81.00);
UPDATE grade SET numeric_grade = 72.00 WHERE enrollment_id = 10;
DELETE FROM grade WHERE enrollment_id = 10;

SELECT action, old_value, new_value, changed_at
FROM audit_log
WHERE table_name = 'grade'
ORDER BY log_id;


-- == CLEANUP ==

DROP TRIGGER IF EXISTS trg_grade_before_insert;
DROP TRIGGER IF EXISTS trg_grade_after_insert;
DROP TRIGGER IF EXISTS trg_grade_after_update;
DROP TRIGGER IF EXISTS trg_grade_after_delete;
