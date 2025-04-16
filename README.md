# Library Management System - SQL Project

## Introduction

Welcome!

This project demonstrates a comprehensive SQL-based Library Management System. It includes the creation of database schema, implementation of core CRUD operations, data analysis queries, advanced operations with stored procedures, and reporting using CTAS (Create Table As Select). The goal is to showcase SQL proficiency in managing and analyzing data for a library system.

---

## Table Structure

1. **Branch** - Stores branch details and manager information.
2. **Employees** - Employee records linked to branches.
3. **Members** - Library members with registration details.
4. **Books** - Catalog of books with rental and availability info.
5. **Issued_Status** - Tracks books issued to members.
6. **Return_Status** - Records book returns.

---

## CRUD Operations

1. **Create Book Record**
```sql
INSERT INTO books (isbn, book_title, category, rental_price, status, author, publisher)
VALUES ('978-1-60129-456-2', 'To Kill a Mockingbird', 'Classic', 6.00, 'yes', 'Harper Lee', 'J.B. Lippincott & Co.');
```
2. **Update Member Address**
```sql
UPDATE members
SET member_address = '726 New st'
WHERE member_id = 'C101';

```
3. **Delete Issued Book Record**
```sql
DELETE FROM issued_status
WHERE issued_id = 'IS104';
```
4. **Retrieve Books Issued by Employee**
```sql
SELECT issued_id, issued_book_name
FROM issued_status
WHERE issued_emp_id = 'E104';
```
5. **Employees Who Issued More Than One Book**
```sql
SELECT 
    ist.issued_emp_id,
     e.emp_name
FROM issued_status as ist
JOIN
employees as e
ON e.emp_id = ist.issued_emp_id
GROUP BY ist.issued_emp_id, e.emp_name
HAVING COUNT(ist.issued_id) > 1;
```

---

## CTAS - Create Table As Select

6. **Books and Issue Count**
```sql
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
```

16. **Active Members (Last 18 Months)**
```sql
CREATE TABLE active_members
AS 
SELECT 
	m.*,
	ist.issued_date
FROM members AS m
JOIN issued_status AS ist
ON m.member_id = ist.issued_member_id
WHERE issued_date >= CURRENT_DATE - INTERVAL '18 month';
```

19. **Overdue and Fine Calculation**
```sql
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
```

---

## Data Analysis & Findings

7. **Available Classic Books by Rental Price**
```sql
SELECT book_title, rental_price 
FROM books
WHERE category = 'Classic' AND status = 'yes'
ORDER BY rental_price DESC;
```
8. **Rental Income and Stats per Category**
```sql
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
```
9. **New Active Members (Last 1250 Days)**
```sql
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
```
10. **Employees with Branch Manager Info**
```sql
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
ON b.manager_id = e2.emp_id;
```
11. **Popular Books with Rental Price > 6**
```sql
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
ORDER BY times_issued DESC;```
12. **Books Not Yet Returned**
```sql
SELECT 
    DISTINCT ist.issued_book_name
FROM issued_status as ist
LEFT JOIN
return_status as rs
ON ist.issued_id = rs.issued_id
WHERE rs.return_id IS NULL;	
```

---

## Advanced SQL Operations

13. **Overdue Members (30+ Days)**
```sql
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
```

14. **Update Book Status on Return - Procedure**
```sql
CREATE PROCEDURE add_return_records(...)

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
```

18. **Book Issue Procedure**
```sql
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
$$```
- Automatically sets book status to 'no' if available.

17. **Top 3 Employees by Book Issues**
```sql
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
LIMIT 3;
```

15. **Branch Performance Report**
```sql
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
GROUP BY b.branch_id;```
```
---

## Conclusion
This project effectively models a real-world library system using relational databases. It covers data modeling, CRUD functionality, advanced SQL operations, stored procedures, and meaningful business reporting. It is a strong demonstration of SQL skills suitable for data-driven applications in library or inventory domains.

---

Feel free to explore the queries, test with your own data, and extend the system with features like overdue notifications, membership levels, or book reservations.

