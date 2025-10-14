-- =====================================
-- LabWork5 — Database Constraints (PostgreSQL)
-- Author: Alikhan
-- =====================================

-- =========================
-- Part 1: CHECK Constraints
-- =========================
CREATE TABLE employees (
    employee_id SERIAL PRIMARY KEY,
    first_name TEXT,
    last_name TEXT,
    age INTEGER CHECK (age BETWEEN 18 AND 65),
    salary NUMERIC CHECK (salary > 0)
);

INSERT INTO employees (first_name, last_name, age, salary)
VALUES ('John', 'Doe', 30, 2000),
       ('Alice', 'Smith', 50, 4000);

CREATE TABLE products_catalog (
    product_id SERIAL PRIMARY KEY,
    product_name TEXT,
    regular_price NUMERIC,
    discount_price NUMERIC,
    CONSTRAINT valid_discount CHECK (
        regular_price > 0 AND
        discount_price > 0 AND
        discount_price < regular_price
    )
);

INSERT INTO products_catalog (product_name, regular_price, discount_price)
VALUES ('Laptop', 2000, 1500),
       ('Headphones', 200, 100);

CREATE TABLE bookings (
    booking_id SERIAL PRIMARY KEY,
    check_in_date DATE,
    check_out_date DATE,
    num_guests INTEGER,
    CHECK (num_guests BETWEEN 1 AND 10),
    CHECK (check_out_date > check_in_date)
);

INSERT INTO bookings (check_in_date, check_out_date, num_guests)
VALUES ('2025-10-10', '2025-10-15', 2),
       ('2025-12-01', '2025-12-05', 5);


-- =========================
-- Part 2: NOT NULL Constraints
-- =========================
CREATE TABLE customers (
    customer_id INTEGER NOT NULL,
    email TEXT NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

INSERT INTO customers VALUES (1, 'john@example.com', '1234567890', '2025-10-01');

CREATE TABLE inventory (
    item_id INTEGER NOT NULL,
    item_name TEXT NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    unit_price NUMERIC NOT NULL CHECK (unit_price > 0),
    last_updated TIMESTAMP NOT NULL
);

INSERT INTO inventory VALUES (1, 'Mouse', 10, 25.5, NOW());


-- =========================
-- Part 3: UNIQUE Constraints
-- =========================
CREATE TABLE users (
    user_id SERIAL PRIMARY KEY,
    username TEXT UNIQUE,
    email TEXT UNIQUE,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (username, email) VALUES ('alikhan', 'alikhan@example.com');
INSERT INTO users (username, email) VALUES ('temir', 'temir@example.com');

CREATE TABLE course_enrollments (
    enrollment_id SERIAL PRIMARY KEY,
    student_id INTEGER,
    course_code TEXT,
    semester TEXT,
    CONSTRAINT unique_student_course UNIQUE (student_id, course_code, semester)
);

INSERT INTO course_enrollments (student_id, course_code, semester)
VALUES (1, 'CS101', 'Fall2025'),
       (1, 'CS102', 'Fall2025');

ALTER TABLE users ADD CONSTRAINT unique_username UNIQUE (username);
ALTER TABLE users ADD CONSTRAINT unique_email UNIQUE (email);


-- =========================
-- Part 4: PRIMARY KEY Constraints
-- =========================
CREATE TABLE departments (
    dept_id INTEGER PRIMARY KEY,
    dept_name TEXT NOT NULL,
    location TEXT
);

INSERT INTO departments VALUES (1, 'HR', 'Almaty'),
                               (2, 'IT', 'Astana'),
                               (3, 'Finance', 'Shymkent');

CREATE TABLE student_courses (
    student_id INTEGER,
    course_id INTEGER,
    enrollment_date DATE,
    grade TEXT,
    PRIMARY KEY (student_id, course_id)
);

INSERT INTO student_courses VALUES (1, 101, '2025-09-01', 'A');
INSERT INTO student_courses VALUES (1, 102, '2025-09-01', 'B');


-- =========================
-- Part 5: FOREIGN KEY Constraints
-- =========================
CREATE TABLE employees_dept (
    emp_id SERIAL PRIMARY KEY,
    emp_name TEXT NOT NULL,
    dept_id INTEGER REFERENCES departments(dept_id),
    hire_date DATE
);

INSERT INTO employees_dept (emp_name, dept_id, hire_date)
VALUES ('John', 1, '2025-01-10'),
       ('Alice', 2, '2025-02-20');

CREATE TABLE authors (
    author_id SERIAL PRIMARY KEY,
    author_name TEXT NOT NULL,
    country TEXT
);

CREATE TABLE publishers (
    publisher_id SERIAL PRIMARY KEY,
    publisher_name TEXT NOT NULL,
    city TEXT
);

CREATE TABLE books (
    book_id SERIAL PRIMARY KEY,
    title TEXT NOT NULL,
    author_id INTEGER REFERENCES authors(author_id),
    publisher_id INTEGER REFERENCES publishers(publisher_id),
    publication_year INTEGER,
    isbn TEXT UNIQUE
);

INSERT INTO authors (author_name, country) VALUES ('Tolstoy', 'Russia'), ('Hemingway', 'USA');
INSERT INTO publishers (publisher_name, city) VALUES ('Penguin', 'London'), ('Vintage', 'New York');
INSERT INTO books (title, author_id, publisher_id, publication_year, isbn)
VALUES ('War and Peace', 1, 1, 1869, '978-1234567890'),
       ('The Old Man and the Sea', 2, 2, 1952, '978-0987654321');

CREATE TABLE categories (
    category_id SERIAL PRIMARY KEY,
    category_name TEXT NOT NULL
);

CREATE TABLE products_fk (
    product_id SERIAL PRIMARY KEY,
    product_name TEXT NOT NULL,
    category_id INTEGER REFERENCES categories(category_id) ON DELETE RESTRICT
);

CREATE TABLE orders (
    order_id SERIAL PRIMARY KEY,
    order_date DATE NOT NULL
);

CREATE TABLE order_items (
    item_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_fk(product_id),
    quantity INTEGER CHECK (quantity > 0)
);

INSERT INTO categories (category_name) VALUES ('Electronics');
INSERT INTO products_fk (product_name, category_id) VALUES ('Laptop', 1);
INSERT INTO orders (order_date) VALUES ('2025-10-10');
INSERT INTO order_items (order_id, product_id, quantity) VALUES (1, 1, 2);
DELETE FROM orders WHERE order_id = 1;


-- =========================
-- Part 6: E-commerce Schema
-- =========================
CREATE TABLE customers_ecom (
    customer_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT UNIQUE NOT NULL,
    phone TEXT,
    registration_date DATE NOT NULL
);

CREATE TABLE products_ecom (
    product_id SERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT,
    price NUMERIC CHECK (price >= 0),
    stock_quantity INTEGER CHECK (stock_quantity >= 0)
);

CREATE TABLE orders_ecom (
    order_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers_ecom(customer_id) ON DELETE CASCADE,
    order_date DATE NOT NULL,
    total_amount NUMERIC CHECK (total_amount >= 0),
    status TEXT CHECK (status IN ('pending', 'processing', 'shipped', 'delivered', 'cancelled'))
);

CREATE TABLE order_details (
    order_detail_id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders_ecom(order_id) ON DELETE CASCADE,
    product_id INTEGER REFERENCES products_ecom(product_id),
    quantity INTEGER CHECK (quantity > 0),
    unit_price NUMERIC CHECK (unit_price > 0)
);

INSERT INTO customers_ecom (name, email, phone, registration_date)
VALUES ('Alikhan', 'ali@example.com', '777777777', '2025-10-01'),
       ('Temirlan', 'temir@example.com', '888888888', '2025-10-02');

INSERT INTO products_ecom (name, description, price, stock_quantity)
VALUES ('Laptop', 'Powerful machine', 2000, 10),
       ('Mouse', 'Wireless mouse', 50, 100);

INSERT INTO orders_ecom (customer_id, order_date, total_amount, status)
VALUES (1, '2025-10-10', 2050, 'pending');

INSERT INTO order_details (order_id, product_id, quantity, unit_price)
VALUES (1, 1, 1, 2000),
       (1, 2, 1, 50);
