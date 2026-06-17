CREATE TABLE student_account (
    account_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL UNIQUE,
    balance DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    FOREIGN KEY (student_id) REFERENCES student(student_id)
);

CREATE TABLE payment (
    payment_id INT AUTO_INCREMENT PRIMARY KEY,
    student_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    payment_date DATE NOT NULL DEFAULT (CURDATE()),
    payment_type ENUM('Tuition', 'Fee', 'Refund') NOT NULL,
    description VARCHAR(255),
    FOREIGN KEY (student_id) REFERENCES student(student_id)
);

-- Each student gets an account with a starting balance
INSERT INTO student_account (student_id, balance) VALUES
    (1,  1500.00),
    (2,  2000.00),
    (3,  800.00),
    (4,  1200.00),
    (5,  500.00),
    (6,  3000.00),
    (7,  1000.00),
    (8,  1750.00),
    (9,  600.00),
    (10, 2500.00),
    (11, 900.00);

-- Some payment history
INSERT INTO payment (student_id, amount, payment_date, payment_type, description) VALUES
    (1,  5000.00, '2025-08-15', 'Tuition', 'Fall 2025 tuition'),
    (1,   150.00, '2025-08-15', 'Fee',     'Student activity fee'),
    (2,  5000.00, '2025-08-20', 'Tuition', 'Fall 2025 tuition'),
    (3,  5000.00, '2025-08-18', 'Tuition', 'Fall 2025 tuition'),
    (4,  5000.00, '2025-08-22', 'Tuition', 'Fall 2025 tuition'),
    (5,  5000.00, '2025-08-25', 'Tuition', 'Fall 2025 tuition'),
    (6,  5000.00, '2025-08-15', 'Tuition', 'Fall 2025 tuition'),
    (8, -1500.00, '2025-10-01', 'Refund',  'Dropped PHY101 refund');
