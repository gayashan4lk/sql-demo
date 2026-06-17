-- ============================================================
-- SQL STORED PROCEDURES LESSON
-- Run schema/reset.sql first.
-- ============================================================


-- == ABOUT DELIMITER ==
-- MySQL uses ; as the statement terminator, but procedure bodies
-- contain many ; inside them. We change the delimiter to $$ so
-- MySQL waits for the full procedure before executing.


-- == 1. BASIC PROCEDURE (NO PARAMETERS) ==

DROP PROCEDURE IF EXISTS get_all_courses;

DELIMITER $$

CREATE PROCEDURE get_all_courses()
BEGIN
    SELECT course_id, course_code, course_name, department
    FROM course
    ORDER BY department, course_code;
END $$

DELIMITER ;

CALL get_all_courses();


-- == 2. IN PARAMETERS ==

DROP PROCEDURE IF EXISTS get_courses_by_department;

DELIMITER $$

CREATE PROCEDURE get_courses_by_department(IN p_department VARCHAR(100))
BEGIN
    SELECT course_code, course_name, credits
    FROM course
    WHERE department = p_department;
END $$

DELIMITER ;

CALL get_courses_by_department('Computer Science');
CALL get_courses_by_department('Mathematics');


-- == 3. MULTIPLE IN PARAMETERS ==

DROP PROCEDURE IF EXISTS get_student_enrollments;

DELIMITER $$

CREATE PROCEDURE get_student_enrollments(
    IN p_student_id INT,
    IN p_status VARCHAR(20)
)
BEGIN
    SELECT c.course_code, c.course_name, e.enrolled_date, e.status
    FROM enrollment e
    JOIN course c ON e.course_id = c.course_id
    WHERE e.student_id = p_student_id
      AND e.status = p_status;
END $$

DELIMITER ;

CALL get_student_enrollments(1, 'Completed');
CALL get_student_enrollments(5, 'Active');


-- == 4. OUT PARAMETERS ==

DROP PROCEDURE IF EXISTS count_enrollments;

DELIMITER $$

CREATE PROCEDURE count_enrollments(
    IN p_course_id INT,
    OUT p_count INT
)
BEGIN
    SELECT COUNT(*) INTO p_count
    FROM enrollment
    WHERE course_id = p_course_id
      AND status = 'Active';
END $$

DELIMITER ;

CALL count_enrollments(1, @active_count);
SELECT @active_count AS active_enrollments;


-- == 5. VARIABLES AND SET ==

DROP PROCEDURE IF EXISTS get_course_availability;

DELIMITER $$

CREATE PROCEDURE get_course_availability(IN p_course_id INT)
BEGIN
    DECLARE v_course_name VARCHAR(150);
    DECLARE v_max INT;
    DECLARE v_current INT;
    DECLARE v_available INT;

    SELECT course_name, max_enrollment
    INTO v_course_name, v_max
    FROM course
    WHERE course_id = p_course_id;

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

CALL get_course_availability(1);
CALL get_course_availability(9);


-- == 6. IF / ELSEIF / ELSE ==

DROP PROCEDURE IF EXISTS check_enrollment_status;

DELIMITER $$

CREATE PROCEDURE check_enrollment_status(
    IN p_student_id INT,
    IN p_course_id INT,
    OUT p_message VARCHAR(255)
)
BEGIN
    DECLARE v_status VARCHAR(20);

    SELECT status INTO v_status
    FROM enrollment
    WHERE student_id = p_student_id
      AND course_id = p_course_id;

    IF v_status IS NULL THEN
        SET p_message = 'Not enrolled';
    ELSEIF v_status = 'Active' THEN
        SET p_message = 'Currently enrolled';
    ELSEIF v_status = 'Completed' THEN
        SET p_message = 'Course completed';
    ELSEIF v_status = 'Dropped' THEN
        SET p_message = 'Enrollment dropped';
    ELSE
        SET p_message = 'Unknown status';
    END IF;
END $$

DELIMITER ;

CALL check_enrollment_status(1, 1, @msg);
SELECT @msg;

CALL check_enrollment_status(1, 9, @msg);
SELECT @msg;


-- == 7. ERROR HANDLING WITH SIGNAL ==

DROP PROCEDURE IF EXISTS safe_enroll_student;

DELIMITER $$

CREATE PROCEDURE safe_enroll_student(
    IN p_student_id INT,
    IN p_course_id INT
)
BEGIN
    DECLARE v_student_exists INT;
    DECLARE v_course_exists INT;
    DECLARE v_already_enrolled INT;

    SELECT COUNT(*) INTO v_student_exists
    FROM student WHERE student_id = p_student_id;

    IF v_student_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student not found';
    END IF;

    SELECT COUNT(*) INTO v_course_exists
    FROM course WHERE course_id = p_course_id;

    IF v_course_exists = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Course not found';
    END IF;

    SELECT COUNT(*) INTO v_already_enrolled
    FROM enrollment
    WHERE student_id = p_student_id AND course_id = p_course_id;

    IF v_already_enrolled > 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Student is already enrolled in this course';
    END IF;

    INSERT INTO enrollment (student_id, course_id)
    VALUES (p_student_id, p_course_id);

    SELECT 'Enrollment successful' AS result;
END $$

DELIMITER ;

CALL safe_enroll_student(4, 1);
CALL safe_enroll_student(4, 1);
CALL safe_enroll_student(999, 1);


-- == 8. DROP AND MANAGE PROCEDURES ==

SHOW PROCEDURE STATUS WHERE Db = 'sql_demo'\G
SHOW CREATE PROCEDURE safe_enroll_student\G


-- == CLEANUP ==

DROP PROCEDURE IF EXISTS get_all_courses;
DROP PROCEDURE IF EXISTS get_courses_by_department;
DROP PROCEDURE IF EXISTS get_student_enrollments;
DROP PROCEDURE IF EXISTS count_enrollments;
DROP PROCEDURE IF EXISTS get_course_availability;
DROP PROCEDURE IF EXISTS check_enrollment_status;
DROP PROCEDURE IF EXISTS safe_enroll_student;
