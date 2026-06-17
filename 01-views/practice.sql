-- SOLUTION OF PROBLEM 01

CREATE OR REPLACE VIEW student_directory AS
SELECT name, email 
FROM student
ORDER BY name;

SELECT * FROM student_directory;

-- SOLUTION OF PROBLEM 02

CREATE VIEW male_students AS
SELECT student_id, name, date_of_birth
FROM student
WHERE gender = 'Male';

SELECT * FROM male_students;

-- SOLUTION OF PROBLEM 03

CREATE VIEW student_ages_2 AS
SELECT name, gender, TIMESTAMPDIFF(YEAR, date_of_birth, CURDATE()) AS age
FROM student;

SELECT * FROM student_ages_2 WHERE age >= 25;

-- SOLUTION OF PROBLEM 04

CREATE OR REPLACE VIEW student_directory AS
SELECT name, email, gender
FROM student
ORDER BY name;

SELECT * FROM student_directory;

-- SOLUTION OF PROBLEM 05

CREATE VIEW gender_summary AS
SELECT gender, COUNT(*) AS total
FROM student
GROUP BY gender;

SELECT * FROM gender_summary ORDER BY total DESC LIMIT 1;