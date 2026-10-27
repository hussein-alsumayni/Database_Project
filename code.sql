CREATE TABLE membership_type (
    type_code        VARCHAR2(10) PRIMARY KEY,
    type_name        VARCHAR2(50) NOT NULL UNIQUE,
    max_books_allowed INT NOT NULL,
    membership_fee   NUMBER(8,2) NOT NULL,
    CONSTRAINT chk_membership_books CHECK (max_books_allowed > 0),
    CONSTRAINT chk_membership_fee CHECK (membership_fee >= 0)
);
CREATE TABLE member (
    member_id      INT PRIMARY KEY,
    first_name     VARCHAR2(40) NOT NULL,
    middle_name    VARCHAR2(40),
    last_name      VARCHAR2(40) NOT NULL,
    street         VARCHAR2(100) NOT NULL,
    city           VARCHAR2(50) NOT NULL,
    postal_code    VARCHAR2(15) NOT NULL,
    date_of_birth  DATE NOT NULL,
    type_code      VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_member_type
        FOREIGN KEY (type_code) REFERENCES membership_type(type_code)
);
-- Multivalued attribute PhoneNumbers is mapped to a separate table.
CREATE TABLE member_phone (
    member_id    INT NOT NULL,
    phone_number VARCHAR2(25) NOT NULL,
    PRIMARY KEY (member_id, phone_number),
    CONSTRAINT fk_phone_member
        FOREIGN KEY (member_id) REFERENCES member(member_id)
        ON DELETE CASCADE
);
CREATE TABLE branch (
    branch_id   INT PRIMARY KEY,
    branch_name VARCHAR2(80) NOT NULL UNIQUE,
    street      VARCHAR2(100) NOT NULL,
    city        VARCHAR2(50) NOT NULL,
    postal_code VARCHAR2(15) NOT NULL
);
CREATE TABLE staff (
    staff_id   INT PRIMARY KEY,
    first_name VARCHAR2(40) NOT NULL,
    last_name  VARCHAR2(40) NOT NULL,
    hire_date  DATE NOT NULL,
    branch_id  INT NOT NULL,
    CONSTRAINT fk_staff_branch
        FOREIGN KEY (branch_id) REFERENCES branch(branch_id)
);
CREATE TABLE librarian (
    staff_id             INT PRIMARY KEY,
    certification_number VARCHAR2(40) NOT NULL UNIQUE,
    CONSTRAINT fk_librarian_staff
        FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
        ON DELETE CASCADE
);
CREATE TABLE assistant (
    staff_id  INT PRIMARY KEY,
    shift_type VARCHAR2(30) NOT NULL,
    CONSTRAINT fk_assistant_staff
        FOREIGN KEY (staff_id) REFERENCES staff(staff_id)
        ON DELETE CASCADE
);
CREATE TABLE publisher (
    publisher_id INT PRIMARY KEY,
    name         VARCHAR2(100) NOT NULL UNIQUE,
    country      VARCHAR2(60) NOT NULL
);
CREATE TABLE author (
    author_id  INT PRIMARY KEY,
    name       VARCHAR2(100) NOT NULL,
    nationality VARCHAR2(60) NOT NULL
);
CREATE TABLE category (
    category_code VARCHAR2(10) PRIMARY KEY,
    description   VARCHAR2(100) NOT NULL
);
CREATE TABLE book (
    isbn            VARCHAR2(13) PRIMARY KEY,
    title           VARCHAR2(200) NOT NULL,
    publication_year NUMBER(4) NOT NULL,
    num_pages      INT NOT NULL,
    publisher_id   INT NOT NULL,
    category_code  VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_book_publisher
        FOREIGN KEY (publisher_id) REFERENCES publisher(publisher_id),
    CONSTRAINT fk_book_category
        FOREIGN KEY (category_code) REFERENCES category(category_code),
    CONSTRAINT chk_book_year CHECK (publication_year BETWEEN 1450 AND 2100),
    CONSTRAINT chk_book_pages CHECK (num_pages > 0)
);
-- Associative table for the M:N Book--Author relationship.
CREATE TABLE book_author (
    isbn      VARCHAR2(13) NOT NULL,
    author_id INT NOT NULL,
    PRIMARY KEY (isbn, author_id),
    CONSTRAINT fk_book_author_book
        FOREIGN KEY (isbn) REFERENCES book(isbn)
        ON DELETE CASCADE,
    CONSTRAINT fk_book_author_author
        FOREIGN KEY (author_id) REFERENCES author(author_id)
        ON DELETE CASCADE
);
CREATE TABLE copy (
    copy_id        INT PRIMARY KEY,
    isbn           VARCHAR2(13) NOT NULL,
    purchase_date  DATE NOT NULL,
    condition_status VARCHAR2(30) NOT NULL,
    branch_id      INT NOT NULL,
    CONSTRAINT fk_copy_book
        FOREIGN KEY (isbn) REFERENCES book(isbn),
    CONSTRAINT fk_copy_branch
        FOREIGN KEY (branch_id) REFERENCES branch(branch_id),
    CONSTRAINT chk_copy_condition CHECK (condition_status IN ('New','Good','Fair','Damaged'))
);
-- Weak entity: the full key is (branch_id, shelf_number).
CREATE TABLE shelf (
    branch_id    INT NOT NULL,
    shelf_number VARCHAR2(10) NOT NULL,
    section_name VARCHAR2(80) NOT NULL,
    PRIMARY KEY (branch_id, shelf_number),
    CONSTRAINT fk_shelf_branch
        FOREIGN KEY (branch_id) REFERENCES branch(branch_id)
        ON DELETE CASCADE
);
-- Optional Copy--Shelf placement. CopyID is unique, so a copy has at most one shelf.
CREATE TABLE copy_shelf (
    copy_id      INT PRIMARY KEY,
    branch_id    INT NOT NULL,
    shelf_number VARCHAR2(10) NOT NULL,
    CONSTRAINT fk_copy_shelf_copy
        FOREIGN KEY (copy_id) REFERENCES copy(copy_id)
        ON DELETE CASCADE,
    CONSTRAINT fk_copy_shelf_shelf
        FOREIGN KEY (branch_id, shelf_number)
        REFERENCES shelf(branch_id, shelf_number)
);
-- The generated column enforces at most one active borrowing per copy.
CREATE TABLE borrowing (
    loan_id       INT PRIMARY KEY,
    member_id     INT NOT NULL,
    copy_id       INT NOT NULL,
    staff_id      INT NOT NULL,
    borrow_date   DATE NOT NULL,
    due_date      DATE NOT NULL,
    return_date   DATE,
    active_copy_id NUMBER GENERATED ALWAYS AS
        (CASE WHEN return_date IS NULL THEN copy_id ELSE NULL END) VIRTUAL,
    CONSTRAINT fk_borrowing_member
        FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT fk_borrowing_copy
        FOREIGN KEY (copy_id) REFERENCES copy(copy_id),
    CONSTRAINT fk_borrowing_staff
        FOREIGN KEY (staff_id) REFERENCES staff(staff_id),
    CONSTRAINT chk_borrow_dates CHECK (due_date >= borrow_date),
    CONSTRAINT chk_return_date CHECK (return_date IS NULL OR return_date >= borrow_date),
    CONSTRAINT uq_one_active_borrowing UNIQUE (active_copy_id)
);
CREATE TABLE reservation (
    reservation_id   INT PRIMARY KEY,
    member_id        INT NOT NULL,
    isbn             VARCHAR2(13) NOT NULL,
    reservation_date DATE NOT NULL,
    status           VARCHAR2(20) NOT NULL,
    CONSTRAINT fk_reservation_member
        FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT fk_reservation_book
        FOREIGN KEY (isbn) REFERENCES book(isbn),
    CONSTRAINT chk_reservation_status CHECK (status IN ('Waiting','Fulfilled','Cancelled'))
);
CREATE TABLE fine (
    fine_id INT PRIMARY KEY,
    loan_id INT NOT NULL UNIQUE,
    amount  NUMBER(8,2) NOT NULL,
    reason  VARCHAR2(150) NOT NULL,
    CONSTRAINT fk_fine_borrowing
        FOREIGN KEY (loan_id) REFERENCES borrowing(loan_id),
    CONSTRAINT chk_fine_amount CHECK (amount > 0)
);
CREATE TABLE payment (
    payment_id   INT PRIMARY KEY,
    member_id    INT NOT NULL,
    fine_id      INT UNIQUE,
    amount       NUMBER(8,2) NOT NULL,
    payment_date DATE NOT NULL,
    CONSTRAINT fk_payment_member
        FOREIGN KEY (member_id) REFERENCES member(member_id),
    CONSTRAINT fk_payment_fine
        FOREIGN KEY (fine_id) REFERENCES fine(fine_id),
    CONSTRAINT chk_payment_amount CHECK (amount > 0)
);
-- ============================================================
-- 2. SAMPLE DATA: AT LEAST FIVE ROWS PER TABLE
-- ============================================================
ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD';
INSERT ALL
INTO membership_type VALUES ('BASIC','Basic Member',3,0.00)
INTO membership_type VALUES ('STUDENT','Student Member',5,10.00)
INTO membership_type VALUES ('STAFF','Staff Member',10,0.00)
INTO membership_type VALUES ('PREMIUM','Premium Member',12,35.00)
INTO membership_type VALUES ('RESEARCH','Research Member',20,50.00)
SELECT 1 FROM dual;
INSERT ALL
INTO branch VALUES (1,'Main Library','University Avenue','Riyadh','11451')
INTO branch VALUES (2,'Science Library','Science Road','Riyadh','11452')
INTO branch VALUES (3,'Engineering Library','College Street','Jeddah','21442')
INTO branch VALUES (4,'Arts Library','Culture Road','Dammam','32241')
INTO branch VALUES (5,'Medical Library','Hospital Road','Abha','62521')
SELECT 1 FROM dual;
INSERT ALL
INTO member VALUES (1001,'Ahmed','Ali','Hassan','King Road','Riyadh','11451','2001-03-15','STUDENT')
INTO member VALUES (1002,'Sara','Mohammed','Saleh','Olaya Street','Riyadh','11564','1999-07-20','BASIC')
INTO member VALUES (1003,'Omar','Khalid','Nasser','Airport Road','Jeddah','21442','1995-11-02','PREMIUM')
INTO member VALUES (1004,'Noura','Fahad','Abdullah','Corniche Road','Dammam','32241','2000-01-28','STUDENT')
INTO member VALUES (1005,'Khalid','Yousef','Mansour','University Road','Abha','62521','1988-09-10','RESEARCH')
SELECT 1 FROM dual;
INSERT ALL
INTO member_phone VALUES (1001,'0501111111')
INTO member_phone VALUES (1001,'0551111111')
INTO member_phone VALUES (1002,'0502222222')
INTO member_phone VALUES (1003,'0503333333')
INTO member_phone VALUES (1004,'0504444444')
INTO member_phone VALUES (1005,'0505555555')
SELECT 1 FROM dual;
INSERT ALL
INTO staff VALUES (2001,'Maha','Ibrahim','2018-02-10',1)
INTO staff VALUES (2002,'Faisal','Othman','2019-06-15',2)
INTO staff VALUES (2003,'Reem','Saeed','2020-01-20',3)
INTO staff VALUES (2004,'Yasir','Hamad','2017-09-05',4)
INTO staff VALUES (2005,'Lama','Nabil','2021-03-12',5)
INTO staff VALUES (2006,'Huda','Salem','2022-01-18',1)
INTO staff VALUES (2007,'Adel','Rashid','2022-04-22',2)
INTO staff VALUES (2008,'Mona','Tariq','2023-02-14',3)
INTO staff VALUES (2009,'Sami','Nasser','2023-08-30',4)
INTO staff VALUES (2010,'Rana','Kamal','2024-01-08',5)
SELECT 1 FROM dual;
-- Total and disjoint specialization: each staff member belongs to exactly one subtype.
INSERT ALL
INTO librarian VALUES (2001,'LIB-1001')
INTO librarian VALUES (2002,'LIB-1002')
INTO librarian VALUES (2003,'LIB-1003')
INTO librarian VALUES (2004,'LIB-1004')
INTO librarian VALUES (2005,'LIB-1005')
SELECT 1 FROM dual;
INSERT ALL
INTO assistant VALUES (2006,'Morning')
INTO assistant VALUES (2007,'Evening')
INTO assistant VALUES (2008,'Morning')
INTO assistant VALUES (2009,'Night')
INTO assistant VALUES (2010,'Evening')
SELECT 1 FROM dual;
INSERT ALL
INTO publisher VALUES (3001,'Pearson','United Kingdom')
INTO publisher VALUES (3002,'McGraw Hill','United States')
INTO publisher VALUES (3003,'Oxford Press','United Kingdom')
INTO publisher VALUES (3004,'Springer','Germany')
INTO publisher VALUES (3005,'Elsevier','Netherlands')
SELECT 1 FROM dual;
INSERT ALL
INTO author VALUES (4001,'Robert Martin','American')
INTO author VALUES (4002,'Thomas Cormen','American')
INTO author VALUES (4003,'Ian Sommerville','British')
INTO author VALUES (4004,'Andrew Tanenbaum','Dutch-American')
INTO author VALUES (4005,'Silberschatz and Korth','American')
SELECT 1 FROM dual;
INSERT ALL
INTO category VALUES ('CS','Computer Science')
INTO category VALUES ('DB','Database Systems')
INTO category VALUES ('SE','Software Engineering')
INTO category VALUES ('NW','Computer Networks')
INTO category VALUES ('AI','Artificial Intelligence')
SELECT 1 FROM dual;
INSERT ALL
INTO book VALUES ('9780132350884','Clean Code',2008,464,3001,'SE')
INTO book VALUES ('9780262033848','Introduction to Algorithms',2009,1312,3002,'CS')
INTO book VALUES ('9780137035151','Software Engineering',2015,816,3003,'SE')
INTO book VALUES ('9780132126953','Computer Networks',2011,960,3004,'NW')
INTO book VALUES ('9780073523323','Database System Concepts',2019,1376,3005,'DB')
SELECT 1 FROM dual;
INSERT ALL
INTO book_author VALUES ('9780132350884',4001)
INTO book_author VALUES ('9780262033848',4002)
INTO book_author VALUES ('9780137035151',4003)
INTO book_author VALUES ('9780132126953',4004)
INTO book_author VALUES ('9780073523323',4005)
SELECT 1 FROM dual;
INSERT ALL
INTO copy VALUES (5001,'9780132350884','2023-01-10','Good',1)
INTO copy VALUES (5002,'9780262033848','2023-02-12','New',2)
INTO copy VALUES (5003,'9780137035151','2022-09-01','Good',3)
INTO copy VALUES (5004,'9780132126953','2021-05-20','Fair',4)
INTO copy VALUES (5005,'9780073523323','2024-01-15','New',5)
SELECT 1 FROM dual;
INSERT ALL
INTO shelf VALUES (1,'S01','Software')
INTO shelf VALUES (2,'S02','Algorithms')
INTO shelf VALUES (3,'S03','Engineering')
INTO shelf VALUES (4,'S04','Networks')
INTO shelf VALUES (5,'S05','Databases')
SELECT 1 FROM dual;
INSERT ALL
INTO copy_shelf VALUES (5001,1,'S01')
INTO copy_shelf VALUES (5002,2,'S02')
INTO copy_shelf VALUES (5003,3,'S03')
INTO copy_shelf VALUES (5004,4,'S04')
INTO copy_shelf VALUES (5005,5,'S05')
SELECT 1 FROM dual;
INSERT ALL
INTO borrowing (loan_id,member_id,copy_id,staff_id,borrow_date,due_date,return_date) VALUES (6001,1001,5001,2001,'2025-01-05','2025-01-19','2025-01-18')
INTO borrowing (loan_id,member_id,copy_id,staff_id,borrow_date,due_date,return_date) VALUES (6002,1002,5002,2002,'2025-01-10','2025-01-24','2025-01-23')
INTO borrowing (loan_id,member_id,copy_id,staff_id,borrow_date,due_date,return_date) VALUES (6003,1003,5003,2003,'2025-02-01','2025-02-15','2025-02-14')
INTO borrowing (loan_id,member_id,copy_id,staff_id,borrow_date,due_date,return_date) VALUES (6004,1004,5004,2004,'2025-02-10','2025-02-24',NULL)
INTO borrowing (loan_id,member_id,copy_id,staff_id,borrow_date,due_date,return_date) VALUES (6005,1005,5005,2005,'2025-03-01','2025-03-15','2025-03-14')
SELECT 1 FROM dual;
INSERT ALL
INTO reservation VALUES (7001,1001,'9780073523323','2025-03-02','Waiting')
INTO reservation VALUES (7002,1002,'9780132350884','2025-03-03','Fulfilled')
INTO reservation VALUES (7003,1003,'9780262033848','2025-03-04','Waiting')
INTO reservation VALUES (7004,1004,'9780137035151','2025-03-05','Cancelled')
INTO reservation VALUES (7005,1005,'9780132126953','2025-03-06','Waiting')
SELECT 1 FROM dual;
INSERT ALL
INTO fine VALUES (8001,6001,15.00,'Late return')
INTO fine VALUES (8002,6002,10.00,'Late return')
INTO fine VALUES (8003,6003,20.00,'Damaged cover')
INTO fine VALUES (8004,6005,12.00,'Late return')
INTO fine VALUES (8005,6004,25.00,'Overdue borrowing')
SELECT 1 FROM dual;
INSERT ALL
INTO payment VALUES (9001,1001,8001,15.00,'2025-01-20')
INTO payment VALUES (9002,1002,8002,10.00,'2025-01-25')
INTO payment VALUES (9003,1003,8003,20.00,'2025-02-16')
INTO payment VALUES (9004,1005,8004,12.00,'2025-03-16')
INTO payment VALUES (9005,1004,NULL,5.00,'2025-03-20')
SELECT 1 FROM dual;
-- ============================================================
-- 3. VIEW
-- ============================================================
CREATE OR REPLACE VIEW current_borrowings AS
SELECT
    br.loan_id,
    m.first_name || ' ' || m.last_name AS member_name,
    b.title,
    c.copy_id,
    br.borrow_date,
    br.due_date,
    s.first_name || ' ' || s.last_name AS handled_by
FROM borrowing br
JOIN member m ON m.member_id = br.member_id
JOIN copy c ON c.copy_id = br.copy_id
JOIN book b ON b.isbn = c.isbn
JOIN staff s ON s.staff_id = br.staff_id
WHERE br.return_date IS NULL;
-- ============================================================
-- 4. REQUIRED QUERIES
-- ============================================================
-- Query 1: INNER JOIN. Books with their publishers and categories.
SELECT b.isbn, b.title, p.name AS publisher, c.description AS category
FROM book b
INNER JOIN publisher p ON p.publisher_id = b.publisher_id
INNER JOIN category c ON c.category_code = b.category_code;
-- Query 2: LEFT JOIN. All members, including members without borrowings.
SELECT m.member_id, m.first_name, m.last_name, br.loan_id, br.borrow_date
FROM member m
LEFT JOIN borrowing br ON br.member_id = m.member_id
ORDER BY m.member_id;
-- Query 3: RIGHT JOIN. All branches, including branches with no staff.
SELECT s.staff_id, s.first_name, s.last_name, b.branch_id, b.branch_name
FROM staff s
RIGHT JOIN branch b ON b.branch_id = s.branch_id
ORDER BY b.branch_id;
-- Query 4: Oracle supports FULL OUTER JOIN directly.
SELECT p.publisher_id, p.name, b.isbn, b.title
FROM publisher p
FULL OUTER JOIN book b ON b.publisher_id = p.publisher_id;
-- Query 5: M:N relationship. Authors and the books they wrote.
SELECT a.author_id, a.name AS author_name, b.isbn, b.title
FROM author a
INNER JOIN book_author ba ON ba.author_id = a.author_id
INNER JOIN book b ON b.isbn = ba.isbn
ORDER BY a.author_id;
-- Query 6: Non-trivial correlated subquery.
-- Find members who have borrowed more books than the average member.
SELECT m.member_id, m.first_name, m.last_name
FROM member m
WHERE (
    SELECT COUNT(*)
    FROM borrowing br
    WHERE br.member_id = m.member_id
) > (
    SELECT AVG(member_borrow_count)
    FROM (
        SELECT member_id, COUNT(*) AS member_borrow_count
        FROM borrowing
        GROUP BY member_id
    ) borrow_counts
);
-- Query 7: Subquery using EXISTS. Find books that have at least one reservation.
SELECT b.isbn, b.title
FROM book b
WHERE EXISTS (
    SELECT 1
    FROM reservation r
    WHERE r.isbn = b.isbn
);
-- Query 8: Aggregate query. Count physical copies at each branch.
SELECT br.branch_id, br.branch_name, COUNT(c.copy_id) AS number_of_copies
FROM branch br
LEFT JOIN copy c ON c.branch_id = br.branch_id
GROUP BY br.branch_id, br.branch_name
ORDER BY br.branch_id;
-- Query 9: Fine and payment status.
SELECT
    f.fine_id,
    f.amount AS fine_amount,
    COALESCE(SUM(p.amount), 0) AS amount_paid,
    CASE
        WHEN p.payment_id IS NULL THEN 'Unpaid'
        ELSE 'Paid'
    END AS payment_status
FROM fine f
LEFT JOIN payment p ON p.fine_id = f.fine_id
GROUP BY f.fine_id, f.amount, p.payment_id;
-- Query 10: View test.
SELECT * FROM current_borrowings;
-- ============================================================
-- 5. OPTIONAL VALIDATION QUERIES
-- ============================================================
-- Confirm that each table has at least five rows.
SELECT 'membership_type' AS table_name, COUNT(*) AS row_count FROM membership_type
UNION ALL SELECT 'member', COUNT(*) FROM member
UNION ALL SELECT 'member_phone', COUNT(*) FROM member_phone
UNION ALL SELECT 'branch', COUNT(*) FROM branch
UNION ALL SELECT 'staff', COUNT(*) FROM staff
UNION ALL SELECT 'librarian', COUNT(*) FROM librarian
UNION ALL SELECT 'assistant', COUNT(*) FROM assistant
UNION ALL SELECT 'publisher', COUNT(*) FROM publisher
UNION ALL SELECT 'author', COUNT(*) FROM author
UNION ALL SELECT 'category', COUNT(*) FROM category
UNION ALL SELECT 'book', COUNT(*) FROM book
UNION ALL SELECT 'book_author', COUNT(*) FROM book_author
UNION ALL SELECT 'copy', COUNT(*) FROM copy
UNION ALL SELECT 'shelf', COUNT(*) FROM shelf
UNION ALL SELECT 'copy_shelf', COUNT(*) FROM copy_shelf
UNION ALL SELECT 'borrowing', COUNT(*) FROM borrowing
UNION ALL SELECT 'reservation', COUNT(*) FROM reservation
UNION ALL SELECT 'fine', COUNT(*) FROM fine
UNION ALL SELECT 'payment', COUNT(*) FROM payment;
select * from BOOK;
