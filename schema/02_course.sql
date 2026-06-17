CREATE TABLE course (
    course_id INT AUTO_INCREMENT PRIMARY KEY,
    course_code VARCHAR(10) NOT NULL UNIQUE,
    course_name VARCHAR(150) NOT NULL,
    credits INT NOT NULL DEFAULT 3,
    department VARCHAR(100) NOT NULL,
    max_enrollment INT NOT NULL DEFAULT 30
);

INSERT INTO course (course_code, course_name, credits, department, max_enrollment) VALUES
    ('CS101',   'Introduction to Computer Science', 3, 'Computer Science', 30),
    ('CS201',   'Data Structures and Algorithms',   3, 'Computer Science', 25),
    ('CS301',   'Database Systems',                 3, 'Computer Science', 25),
    ('MATH101', 'Calculus I',                       4, 'Mathematics',      35),
    ('MATH201', 'Linear Algebra',                   3, 'Mathematics',      30),
    ('ENG101',  'English Composition',              3, 'English',          40),
    ('ENG201',  'Creative Writing',                 3, 'English',          20),
    ('PHY101',  'Physics I',                        4, 'Physics',          30),
    ('PHY201',  'Quantum Mechanics',                3, 'Physics',          20);
