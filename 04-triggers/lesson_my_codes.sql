-- ============================================
-- 2. BEFORE INSERT — Normalize and Derive Data
-- ============================================

DROP TRIGGER IF EXISTS trg_grade_before_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_before_insert
	BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
	IF NEW.graded_date IS NULL THEN
		SET NEW.graded_date = CURDATE();
	END IF;
	
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

INSERT INTO grade (enrollment_id, numeric_grade)
VALUES (6, 88.00);

-- ============================================
-- 3. BEFORE INSERT — Validation with SIGNAL
-- ============================================

DROP TRIGGER IF EXISTS trg_grade_before_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_before_insert
	BEFORE INSERT ON grade
    FOR EACH ROW
BEGIN
	IF NEW.numeric_grade < 0 OR NEW.numeric_grade > 100 THEN
		SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'numeric_grade must be between 0 and 100.';
	END IF;

	IF NEW.graded_date IS NULL THEN
		SET NEW.graded_date = CURDATE();
	END IF;
	
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

INSERT INTO grade (enrollment_id, numeric_grade)
VALUES (10, 135);

-- ============================================
-- 4. AFTER INSERT — Audit Logging
-- ============================================

DROP TRIGGER IF EXISTS trg_grade_after_insert;

DELIMITER $$

CREATE TRIGGER trg_grade_after_insert
	AFTER INSERT ON grade
    FOR EACH ROW
BEGIN
	INSERT INTO audit_log(table_name, action, record_id, old_value, new_value)
    VALUES ('grade', 'INSERT', NEW.grade_id, NULL,
    CONCAT('numeric_grade=', NEW.numeric_grade, ', letter_grade=', NEW.letter_grade)
    );
END $$

DELIMITER ;

INSERT INTO grade (enrollment_id, numeric_grade)
VALUES (11, 77.00);

SELECT table_name, action, record_id, old_value, new_value
FROM audit_log
WHERE table_name = 'grade'
ORDER BY log_id DESC
LIMIT 1;

-- ============================================
-- 5. AFTER UPDATE — Log Old vs. New
-- ============================================

DROP TRIGGER IF EXISTS trg_grade_after_update;

DELIMITER $$

CREATE TRIGGER trg_grade_after_update
	AFTER UPDATE ON grade
    FOR EACH ROW
BEGIN
	IF OLD.numeric_grade <> NEW.numeric_grade THEN
		INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
		VALUES ('grade', 'UPDATE', NEW.grade_id, 
        CONCAT('numeric_grade=', OLD.numeric_grade, ', letter_grade=', OLD.letter_grade),
		CONCAT('numeric_grade=', NEW.numeric_grade, ', letter_grade=', NEW.letter_grade)
		);
	END IF;
END $$

DELIMITER ;

UPDATE grade SET numeric_grade = 96.00 WHERE enrollment_id = 1;

-- ============================================
-- 6. AFTER DELETE — Log Removals
-- ============================================

DROP TRIGGER IF EXISTS trg_grade_after_delete;

DELIMITER $$

CREATE TRIGGER trg_grade_after_delete
	AFTER DELETE ON grade
    FOR EACH ROW
BEGIN
	INSERT INTO audit_log (table_name, action, record_id, old_value, new_value)
	VALUES ('grade', 'DELETE', OLD.grade_id, 
	CONCAT('numeric_grade=', OLD.numeric_grade, ', letter_grade=', OLD.letter_grade),
	NULL
	);
END $$

DELIMITER ;

DELETE FROM grade WHERE enrollment_id = 4;

-- ============================================
-- 7. Managing Triggers
-- ============================================

SHOW TRIGGERS;

SHOW TRIGGERS LIKE 'grade';

SHOW CREATE TRIGGER trg_grade_before_insert;

DROP TRIGGER IF EXISTS trg_grade_before_insert;
DROP TRIGGER IF EXISTS trg_grade_after_insert;
DROP TRIGGER IF EXISTS trg_grade_after_update;
DROP TRIGGER IF EXISTS trg_grade_after_delete;