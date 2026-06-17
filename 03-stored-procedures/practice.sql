-- SOLUTION OF PROBLEM 01 — Find Student by ID (Easy)

DROP PROCEDURE IF EXISTS find_student_by_id;

DELIMITER $$

CREATE PROCEDURE find_student_by_id(IN p_student_id INT)
BEGIN
    SELECT name, email, date_of_birth, gender
    FROM student
    WHERE student_id = p_student_id;
END $$

DELIMITER ;

CALL find_student_by_id(3);
CALL find_student_by_id(8);


-- SOLUTION OF PROBLEM 02 — Department Course Count (Easy)

DROP PROCEDURE IF EXISTS count_department_courses;

DELIMITER $$

CREATE PROCEDURE count_department_courses(
    IN p_department VARCHAR(100),
    OUT p_total INT
)
BEGIN
    SELECT COUNT(*) INTO p_total
    FROM course
    WHERE department = p_department;
END $$

DELIMITER ;

CALL count_department_courses('Computer Science', @total);
SELECT @total AS cs_courses;

CALL count_department_courses('Physics', @total);
SELECT @total AS physics_courses;


-- SOLUTION OF PROBLEM 03 — Enrollment Status Report (Medium)

DROP PROCEDURE IF EXISTS student_course_status;

DELIMITER $$

CREATE PROCEDURE student_course_status(
    IN p_student_id INT,
    IN p_course_code VARCHAR(10),
    OUT p_result VARCHAR(255)
)
BEGIN
    DECLARE v_student_name VARCHAR(100);
    DECLARE v_course_name VARCHAR(150);
    DECLARE v_course_id INT;
    DECLARE v_status VARCHAR(20);

    SELECT name INTO v_student_name
    FROM student
    WHERE student_id = p_student_id;

    SELECT course_id, course_name
    INTO v_course_id, v_course_name
    FROM course
    WHERE course_code = p_course_code;

    SELECT status INTO v_status
    FROM enrollment
    WHERE student_id = p_student_id
      AND course_id = v_course_id;

    IF v_status IS NULL THEN
        SET p_result = CONCAT('Not enrolled in ', p_course_code);
    ELSE
        SET p_result = CONCAT(v_student_name, ' is ', v_status,
                              ' in ', v_course_name);
    END IF;
END $$

DELIMITER ;

CALL student_course_status(1, 'CS101', @result);
SELECT @result;

CALL student_course_status(1, 'PHY201', @result);
SELECT @result;


-- SOLUTION OF PROBLEM 04 — Course Capacity Checker (Medium)

DROP PROCEDURE IF EXISTS check_capacity;

DELIMITER $$

CREATE PROCEDURE check_capacity(IN p_course_id INT)
BEGIN
    DECLARE v_course_name VARCHAR(150);
    DECLARE v_max INT;
    DECLARE v_current INT;
    DECLARE v_available INT;

    SELECT course_name, max_enrollment
    INTO v_course_name, v_max
    FROM course
    WHERE course_id = p_course_id;

    IF v_course_name IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Course not found';
    END IF;

    SELECT COUNT(*) INTO v_current
    FROM enrollment
    WHERE course_id = p_course_id
      AND status = 'Active';

    SET v_available = v_max - v_current;

    SELECT v_course_name AS course_name,
           v_max AS max_enrollment,
           v_current AS current_enrolled,
           v_available AS spots_available;
END $$

DELIMITER ;

CALL check_capacity(1);
CALL check_capacity(999);


-- SOLUTION OF PROBLEM 05 — Safe Email Update (Hard)

DROP PROCEDURE IF EXISTS update_student_email;

DELIMITER $$

CREATE PROCEDURE update_student_email(
    IN p_student_id INT,
    IN p_new_email VARCHAR(150)
)
BEGIN
    DECLARE v_student_exists INT;
    DECLARE v_email_duplicate INT;

    SELECT COUNT(*) INTO v_student_exists
    FROM student
    WHERE student_id = p_student_id;

    IF v_student_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student not found';
    END IF;

    IF INSTR(p_new_email, '@') = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Invalid email: must contain @';
    END IF;

    SELECT COUNT(*) INTO v_email_duplicate
    FROM student
    WHERE email = p_new_email
      AND student_id != p_student_id;

    IF v_email_duplicate > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Email already in use by another student';
    END IF;

    UPDATE student
    SET email = p_new_email
    WHERE student_id = p_student_id;

    SELECT 'Email updated successfully' AS result;
END $$

DELIMITER ;

CALL update_student_email(1, 'alice.new@email.com');
CALL update_student_email(999, 'test@email.com');
CALL update_student_email(2, 'bademail');
CALL update_student_email(2, 'alice.new@email.com');
