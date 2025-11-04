-- =====================================
-- LabWork6 - SQL JOINs (PostgreSQL)
-- Author: Alikhan
-- =====================================

-- =====================================
-- PART 1: Database Setup
-- =====================================

-- Создаю таблицу сотрудников
CREATE TABLE employees (
                           emp_id INT PRIMARY KEY,
                           emp_name VARCHAR(50),
                           dept_id INT,
                           salary DECIMAL(10, 2)
);

-- Создаю таблицу отделов
CREATE TABLE departments (
                             dept_id INT PRIMARY KEY,
                             dept_name VARCHAR(50),
                             location VARCHAR(50)
);

-- Создаю таблицу проектов
CREATE TABLE projects (
                          project_id INT PRIMARY KEY,
                          project_name VARCHAR(50),
                          dept_id INT,
                          budget DECIMAL(10, 2)
);

-- Вставляю тестовые данные
INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES
                                                              (1, 'John Smith', 101, 50000),
                                                              (2, 'Jane Doe', 102, 60000),
                                                              (3, 'Mike Johnson', 101, 55000),
                                                              (4, 'Sarah Williams', 103, 65000),
                                                              (5, 'Tom Brown', NULL, 45000);

INSERT INTO departments (dept_id, dept_name, location) VALUES
                                                           (101, 'IT', 'Building A'),
                                                           (102, 'HR', 'Building B'),
                                                           (103, 'Finance', 'Building C'),
                                                           (104, 'Marketing', 'Building D');

INSERT INTO projects (project_id, project_name, dept_id, budget) VALUES
                                                                     (1, 'Website Redesign', 101, 100000),
                                                                     (2, 'Employee Training', 102, 50000),
                                                                     (3, 'Budget Analysis', 103, 75000),
                                                                     (4, 'Cloud Migration', 101, 150000),
                                                                     (5, 'AI Research', NULL, 200000);

-- =====================================
-- PART 2: CROSS JOIN
-- =====================================

-- Все возможные комбинации сотрудников и отделов
SELECT e.emp_name, d.dept_name
FROM employees e CROSS JOIN departments d;
-- Тут просто перемножаются все строки (N*M)

-- То же самое, но с другим синтаксисом
SELECT e.emp_name, d.dept_name
FROM employees e, departments d;

SELECT e.emp_name, d.dept_name
FROM employees e
         INNER JOIN departments d ON TRUE;
-- Тоже кросс джоин, но с условием TRUE (то есть соединяются все)

-- Практический пример – все пары сотрудник + проект
SELECT e.emp_name, p.project_name
FROM employees e CROSS JOIN projects p;
-- Можно использовать для матрицы занятости (кто на каком проекте потенциально может быть)

-- =====================================
-- PART 3: INNER JOIN
-- =====================================

-- Сотрудники и их отделы
SELECT e.emp_name, d.dept_name, d.location
FROM employees e
         INNER JOIN departments d ON e.dept_id = d.dept_id;
-- Том Браун не попадает, потому что у него dept_id = NULL

-- То же самое, но через USING
SELECT emp_name, dept_name, location
FROM employees
         INNER JOIN departments USING (dept_id);
-- Разница: USING убирает дублирующее поле dept_id

-- NATURAL INNER JOIN
SELECT emp_name, dept_name, location
FROM employees
         NATURAL INNER JOIN departments;
-- NATURAL автоматически соединяет по одинаковым названиям колонок

-- INNER JOIN всех трёх таблиц
SELECT e.emp_name, d.dept_name, p.project_name
FROM employees e
         INNER JOIN departments d ON e.dept_id = d.dept_id
         INNER JOIN projects p ON d.dept_id = p.dept_id;
-- Выводит кто из сотрудников работает в каком отделе и проекте

-- =====================================
-- PART 4: LEFT JOIN
-- =====================================

-- Все сотрудники, включая тех у кого нет отдела
SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
         LEFT JOIN departments d ON e.dept_id = d.dept_id;
-- Том Браун будет с NULL в полях отдела

-- Та же логика, но через USING
SELECT emp_name, dept_id, dept_name
FROM employees
         LEFT JOIN departments USING (dept_id);

-- Сотрудники без отдела
SELECT e.emp_name, e.dept_id
FROM employees e
         LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.dept_id IS NULL;

-- Кол-во сотрудников в каждом отделе (включая пустые)
SELECT d.dept_name, COUNT(e.emp_id) AS employee_count
FROM departments d
         LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
ORDER BY employee_count DESC;

-- =====================================
-- PART 5: RIGHT JOIN
-- =====================================

-- Все отделы с сотрудниками (включая отделы без сотрудников)
SELECT e.emp_name, d.dept_name
FROM employees e
         RIGHT JOIN departments d ON e.dept_id = d.dept_id;

-- То же самое, но через LEFT JOIN (таблицы поменялись местами)
SELECT e.emp_name, d.dept_name
FROM departments d
         LEFT JOIN employees e ON e.dept_id = d.dept_id;

-- Отделы без сотрудников
SELECT d.dept_name, d.location
FROM employees e
         RIGHT JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL;

-- =====================================
-- PART 6: FULL JOIN
-- =====================================

-- Все сотрудники и отделы (в том числе без пары)
SELECT e.emp_name, e.dept_id AS emp_dept, d.dept_id AS dept_dept, d.dept_name
FROM employees e
         FULL JOIN departments d ON e.dept_id = d.dept_id;
-- NULL слева — это отдел без сотрудников, NULL справа — сотрудник без отдела

-- Все отделы и проекты, включая без совпадений
SELECT d.dept_name, p.project_name, p.budget
FROM departments d
         FULL JOIN projects p ON d.dept_id = p.dept_id;

-- Показываю "осиротевшие" записи
SELECT
    CASE
        WHEN e.emp_id IS NULL THEN 'Department without employees'
        WHEN d.dept_id IS NULL THEN 'Employee without department'
        ELSE 'Matched'
        END AS record_status,
    e.emp_name,
    d.dept_name
FROM employees e
         FULL JOIN departments d ON e.dept_id = d.dept_id
WHERE e.emp_id IS NULL OR d.dept_id IS NULL;

-- =====================================
-- PART 7: ON vs WHERE
-- =====================================

-- Фильтр через ON (фильтрует до объединения)
SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
         LEFT JOIN departments d ON e.dept_id = d.dept_id AND d.location = 'Building A';

-- Фильтр через WHERE (фильтрует после объединения)
SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
         LEFT JOIN departments d ON e.dept_id = d.dept_id
WHERE d.location = 'Building A';
-- Разница: второй вариант уберёт сотрудников без отдела

-- То же самое для INNER JOIN (результат одинаковый)
SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
         INNER JOIN departments d ON e.dept_id = d.dept_id AND d.location = 'Building A';

SELECT e.emp_name, d.dept_name, e.salary
FROM employees e
         INNER JOIN departments d ON e.dept_id = d.dept_id
WHERE d.location = 'Building A';
-- Тут разницы нет, потому что INNER JOIN всегда исключает NULL-строки

-- =====================================
-- PART 8: COMPLEX JOINS
-- =====================================

-- Комбинация разных JOIN'ов
SELECT
    d.dept_name,
    e.emp_name,
    e.salary,
    p.project_name,
    p.budget
FROM departments d
         LEFT JOIN employees e ON d.dept_id = e.dept_id
         LEFT JOIN projects p ON d.dept_id = p.dept_id
ORDER BY d.dept_name, e.emp_name;

-- Self Join – показываю кто чей менеджер
ALTER TABLE employees ADD COLUMN manager_id INT;

UPDATE employees SET manager_id = 3 WHERE emp_id IN (1,2,4,5);
UPDATE employees SET manager_id = NULL WHERE emp_id = 3;

SELECT
    e.emp_name AS employee,
    m.emp_name AS manager
FROM employees e
         LEFT JOIN employees m ON e.manager_id = m.emp_id;
-- Если manager_id = NULL, значит у сотрудника нет менеджера

-- Средняя зарплата по отделам выше 50k
SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM departments d
         INNER JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
HAVING AVG(e.salary) > 50000;
