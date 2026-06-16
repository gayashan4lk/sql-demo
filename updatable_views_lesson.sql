-- 1. Setup — Create an Updatable View

CREATE VIEW student_emails AS
SELECT student_id, name, email
FROM student;

SELECT * FROM student_emails;

-- 2. UPDATE Through a View
UPDATE student_emails
SET email='alice.new@email.com'
WHERE student_id = 1;

SELECT * FROM student WHERE student_id=1;

-- 3. DELETE Through a View
DELETE FROM student_emails 
WHERE student_id = 1;

-- Verify the row is gone from the base table
SELECT * FROM student WHERE student_id = 1;

-- 4. INSERT Through a View
INSERT INTO student_emails (name, email)
VALUES ('Test Student', 'teststudent@email.com');
-- This will FAIL because date_of_birth and gender are NOT NULL with no default

-- 5. WITH CHECK OPTION
-- Without CHECK OPTION (dangerous)
CREATE VIEW female_students_unsafe AS
SELECT student_id, name, gender
FROM student
WHERE gender = 'Female';

UPDATE female_students_unsafe
SET gender = 'Male'
WHERE student_id = 12;

SELECT * FROM female_students_unsafe;

-- With CHECK OPTION (safe)
CREATE VIEW female_students_safe AS
SELECT student_id, name, gender
FROM student
WHERE gender = 'Female'
WITH CHECK OPTION;

SELECT * FROM female_students_safe;

UPDATE female_students_safe
SET gender = 'Male'
WHERE student_id = 9;

-- 6. Non-Updatable View — Contrast

CREATE VIEW gender_count AS
SELECT gender, COUNT(*) AS total
FROM student
GROUP BY gender;

SELECT * FROM gender_count;

-- This will ERROR: View 'gender_count' is not updatable
UPDATE gender_count SET total = 10 WHERE gender = 'Male';
