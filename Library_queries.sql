-- Library System Management SQL Project

-- Create table "Branch"
DROP TABLE IF EXISTS branch;
CREATE TABLE branch
(
            branch_id VARCHAR(10) PRIMARY KEY,
            manager_id VARCHAR(10),
            branch_address VARCHAR(30),
            contact_no VARCHAR(15)
);



-- Create table "Employee"
DROP TABLE IF EXISTS employees;
CREATE TABLE employees
(
            emp_id VARCHAR(10) PRIMARY KEY,
            emp_name VARCHAR(30),
            position VARCHAR(30),
            salary DECIMAL(10,2),
            branch_id VARCHAR(10),
            FOREIGN KEY (branch_id) REFERENCES  branch(branch_id)
);


-- Create table "Members"
DROP TABLE IF EXISTS members;
CREATE TABLE members
(
            member_id VARCHAR(10) PRIMARY KEY,
            member_name VARCHAR(30),
            member_address VARCHAR(30),
            reg_date DATE
);


-- Create table "Books"
DROP TABLE IF EXISTS books;
CREATE TABLE books
(
            isbn VARCHAR(50) PRIMARY KEY,
            book_title VARCHAR(80),
            category VARCHAR(30),
            rental_price DECIMAL(10,2),
            status VARCHAR(10),
            author VARCHAR(30),
            publisher VARCHAR(30)
);


-- Create table "IssueStatus"
DROP TABLE IF EXISTS issued_status;
CREATE TABLE issued_status
(
            issued_id VARCHAR(10) PRIMARY KEY,
            issued_member_id VARCHAR(30),
            issued_book_name VARCHAR(80),
            issued_date DATE,
            issued_book_isbn VARCHAR(50),
            issued_emp_id VARCHAR(10),
            FOREIGN KEY (issued_member_id) REFERENCES members(member_id),
            FOREIGN KEY (issued_emp_id) REFERENCES employees(emp_id),
            FOREIGN KEY (issued_book_isbn) REFERENCES books(isbn) 
);



-- Create table "ReturnStatus"
DROP TABLE IF EXISTS return_status;
CREATE TABLE return_status 
(
	return_id VARCHAR(10),
	issued_id VARCHAR(10),
	return_book_name VARCHAR(50),
	return_date DATE,
	return_book_isbn VARCHAR(50),
	FOREIGN KEY (return_book_isbn) REFERENCES books(isbn)
)

-- Project TASK


-- ### 2. CRUD Operations


-- 1. Create a New Book Record
INSERT INTO books (isbn, book_title, category, rental_price, status, author, publisher)
VALUES ('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.')


-- 2. Update an Existing Member's Address
UPDATE members
SET member_address = '726 New st'
WHERE member_id = 'C101';


-- 3. Delete a Record from the Issued Status Table
DELETE FROM issued_status
WHERE issued_id = 'IS104';


-- 4. Retrieve All Books Issued by a Specific Employee
SELECT issued_id, issued_book_name
FROM issued_status
WHERE issued_emp_id = 'E104';


-- 5. List employees Names Who Have Issued More Than One Book
SELECT 
    ist.issued_emp_id,
     e.emp_name
FROM issued_status as ist
JOIN
employees as e
ON e.emp_id = ist.issued_emp_id
GROUP BY ist.issued_emp_id, e.emp_name
HAVING COUNT(ist.issued_id) > 1


-- ### 3. CTAS (Create Table As Select)

-- 6. Generate new tables based on query results - each book and total book_issued_cnt
CREATE TABLE book_cnts
AS    
SELECT 
    b.isbn,
    b.book_title,
    COUNT(ist.issued_id) as no_issued
FROM books as b
JOIN
issued_status as ist
ON ist.issued_book_isbn = b.isbn
GROUP BY b.isbn, b.book_title;


-- ### 4. Data Analysis & Findings


-- 7. Retrieve All Available Books in the "Classic" Category, Sorted by Rental Price:
SELECT book_title, rental_price 
FROM books
WHERE category = 'Classic' AND status = 'yes'
ORDER BY rental_price DESC;


-- 8: Calculate Total Rental Income, Average Rental Price, and Number of Issued Books per Category:
SELECT
    b.category,
    COUNT(*) AS books_issued,
    SUM(b.rental_price) AS total_income,
    ROUND(AVG(b.rental_price), 1) AS avg_rental_price
FROM books AS b
JOIN issued_status AS ist
  ON ist.issued_book_isbn = b.isbn
GROUP BY b.category
ORDER BY total_income DESC;

-- 9. List Active New Members Who Registered in the Last 1250 Days:
SELECT 
    m.member_id,
    m.member_name,
    m.reg_date,
    COUNT(ist.issued_id) AS books_issued
FROM members AS m
JOIN issued_status AS ist
  ON m.member_id = ist.issued_member_id
WHERE m.reg_date >= CURRENT_DATE - INTERVAL '1250 days'
GROUP BY m.member_id
ORDER BY m.reg_date DESC;


-- 10: List Employees with Their Branch Manager's Name and their branch details:
SELECT 
    e1.*,
    b.manager_id,
    e2.emp_name as manager
FROM employees as e1
JOIN  
branch as b
ON b.branch_id = e1.branch_id
JOIN
employees as e2
ON b.manager_id = e2.emp_id


-- 11.  Retrieve All Books with Rental Price Above a Threshold of 6, 
-- Along with the Number of Times Each Book Has Been Issued, and Sorted by Popularity
SELECT 
    b.isbn,
    b.book_title,
    b.rental_price,
    COUNT(ist.issued_id) AS times_issued
FROM books AS b
LEFT JOIN issued_status AS ist
    ON b.isbn = ist.issued_book_isbn
WHERE b.rental_price > 6.00
GROUP BY b.isbn
ORDER BY times_issued DESC;


-- 12: Retrieve the List of Books Not Yet Returned
SELECT 
    DISTINCT ist.issued_book_name
FROM issued_status as ist
LEFT JOIN
return_status as rs
ON ist.issued_id = rs.issued_id
WHERE rs.return_id IS NULL	


/*
### Advanced SQL Operations

13: Identify Members with Overdue Books (30-day return period)
Display the member's name, book title, issue date, and days overdue.
*/

SELECT 
    ist.issued_member_id,
    m.member_name,
    bk.book_title,
    ist.issued_date,
    CURRENT_DATE - ist.issued_date as over_dues_days
FROM issued_status as ist
JOIN 
members as m
    ON m.member_id = ist.issued_member_id
JOIN 
books as bk
ON bk.isbn = ist.issued_book_isbn
LEFT JOIN 
return_status as rs
ON rs.issued_id = ist.issued_id
WHERE 
    rs.return_date IS NULL
    AND
    (CURRENT_DATE - ist.issued_date) > 30
ORDER BY ist.issued_member_id;


/*
14: Update Book Status on Return
Update the status of books in the books table to "available" when they are returned (based on entries in the return_status table).
*/

CREATE OR REPLACE PROCEDURE add_return_records(p_return_id VARCHAR(10), p_issued_id VARCHAR(10), p_book_quality VARCHAR(10))
LANGUAGE plpgsql
AS $$

DECLARE
    v_isbn VARCHAR(50);
    v_book_name VARCHAR(80);
    
BEGIN

    INSERT INTO return_status(return_id, issued_id, return_date, book_quality)
    VALUES
    (p_return_id, p_issued_id, CURRENT_DATE, p_book_quality);

    SELECT 
        issued_book_isbn,
        issued_book_name
        INTO
        v_isbn,
        v_book_name
    FROM issued_status
    WHERE issued_id = p_issued_id;

    UPDATE books
    SET status = 'yes'
    WHERE isbn = v_isbn;

    RAISE NOTICE 'Thank you for returning the book: %', v_book_name;
    
END;
$$
-- calling function 
CALL add_return_records('RS138', 'IS135', 'Good');


/*
15: Branch Performance Report
Create a performance report for each branch, э
showing the number of books issued, the number of books returned, and the total revenue generated from book rentals.
*/

SELECT * FROM branch;
SELECT * FROM issued_status;
SELECT * FROM employees;
SELECT * FROM books;
SELECT * FROM return_status;

CREATE TABLE performance_report
AS
SELECT 
	b.branch_id,
	COUNT(ist.issued_id) AS number_book_issued,
	COUNT(r.return_id) AS  number_of_book_return,
	SUM(bk.rental_price) AS revenue
FROM books AS bk
JOIN issued_status AS ist
ON ist.issued_book_isbn = bk.isbn
LEFT JOIN return_status AS r
ON r.issued_id = ist.issued_id
JOIN  employees as e
ON e.emp_id = ist.issued_emp_id
JOIN branch as b
ON e.branch_id = b.branch_id
GROUP BY b.branch_id

SELECT * FROM performance_report

/*
16: CTAS: Create a Table of Active Members
Create a new table active_members containing members who have issued at least one book in the last 18 months.
*/

CREATE TABLE active_members
AS 
SELECT 
	m.*,
	ist.issued_date
FROM members AS m
JOIN issued_status AS ist
ON m.member_id = ist.issued_member_id
WHERE issued_date >= CURRENT_DATE - INTERVAL '18 month';

SELECT * FROM active_members;

/*
17: Find Employees with the Most Book Issues Processed
Find the top 3 employees who have processed the most book issues. 
Display the employee name, number of books processed, and their branch.
*/

SELECT 
	e.emp_name,
	e.position,
	COUNT(issued_id) AS books_issued,
	e.branch_id
FROM employees AS e
JOIN issued_status AS ist
ON ist.issued_emp_id = e.emp_id
GROUP BY e.emp_id
ORDER BY books_issued DESC
LIMIT 3


/*
18: Stored Procedure
Create a stored procedure to manage the status of books in a library system.
    Description: Write a stored procedure that updates the status of a book based on its issuance or return. Specifically:
    If a book is issued, the status should change to 'no'.
    If a book is returned, the status should change to 'yes'.
*/

CREATE OR REPLACE PROCEDURE issue_book(p_issued_id VARCHAR(10), p_issued_member_id VARCHAR(30), p_issued_book_isbn VARCHAR(30), p_issued_emp_id VARCHAR(10))
LANGUAGE plpgsql
AS $$

DECLARE
-- all the variabable
    v_status VARCHAR(10);

BEGIN
-- all the code
    -- checking if book is available 'yes'
    SELECT 
        status 
        INTO
        v_status
    FROM books
    WHERE isbn = p_issued_book_isbn;

    IF v_status = 'yes' THEN

        INSERT INTO issued_status(issued_id, issued_member_id, issued_date, issued_book_isbn, issued_emp_id)
        VALUES
        (p_issued_id, p_issued_member_id, CURRENT_DATE, p_issued_book_isbn, p_issued_emp_id);

        UPDATE books
            SET status = 'no'
        WHERE isbn = p_issued_book_isbn;

        RAISE NOTICE 'Book records added successfully for book isbn : %', p_issued_book_isbn;


    ELSE
        RAISE NOTICE 'Sorry to inform you the book you have requested is unavailable book_isbn: %', p_issued_book_isbn;
    END IF;

    
END;
$$

SELECT * FROM books;
-- "978-0-553-29698-2" -- yes
-- "978-0-375-41398-8" -- no

CALL issue_book('IS155', 'C108', '978-0-553-29698-2', 'E104');

CALL issue_book('IS156', 'C108', '978-0-375-41398-8', 'E104');

SELECT * FROM books
WHERE isbn = '978-0-553-29698-2';

SELECT * FROM books
WHERE isbn = '978-0-375-41398-8';



/*
19: Create Table As Select (CTAS)
Create a CTAS (Create Table As Select) query to identify overdue books and calculate fines.

Write a CTAS query to create a new table that lists each member and the books they have issued but not returned within 30 days. The table should include:
    The number of overdue books.
    The total fines, with each day's fine calculated at $0.50.
    The number of books issued by each member.
    The resulting table should show:
    Member ID
    Number of overdue books
    Total fines
*/

CREATE TABLE fines AS
SELECT 
    m.member_id,
    COUNT(*) FILTER (
        WHERE CURRENT_DATE - ist.issued_date > 30
    ) AS overdue_books,
    SUM(
        GREATEST((CURRENT_DATE - ist.issued_date) - 30, 0) * 0.50
    ) AS total_fines,
    COUNT(*) AS total_issued
FROM members AS m
JOIN issued_status AS ist
    ON ist.issued_member_id = m.member_id
LEFT JOIN return_status AS r
    ON ist.issued_id = r.issued_id
WHERE r.issued_id IS NULL
GROUP BY m.member_id;

SELECT * FROM fines;