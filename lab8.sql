-- Moldabayev Alikhan
-- lab 8: INDEXES in PostgreSQL

----------------------------------------
-- Part 1: Создание таблиц и вставка тестовых данных
----------------------------------------
-- Создаю таблицы (если их нет)
CREATE TABLE IF NOT EXISTS departments (
    dept_id INT PRIMARY KEY,
    dept_name VARCHAR(50),
    location VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS employees (
    emp_id INT PRIMARY KEY,
    emp_name VARCHAR(100),
    dept_id INT,
    salary DECIMAL(10,2),
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

CREATE TABLE IF NOT EXISTS projects (
    proj_id INT PRIMARY KEY,
    proj_name VARCHAR(100),
    budget DECIMAL(12,2),
    dept_id INT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- Вставляю примеры данных
INSERT INTO departments (dept_id, dept_name, location)
VALUES 
(101, 'IT', 'Building A'),
(102, 'HR', 'Building B'),
(103, 'Operations', 'Building C')
ON CONFLICT DO NOTHING; -- чтобы не вставлять дубли при повторном запуске

INSERT INTO employees (emp_id, emp_name, dept_id, salary)
VALUES
(1, 'John Smith', 101, 50000),
(2, 'Jane Doe', 101, 55000),
(3, 'Mike Johnson', 102, 48000),
(4, 'Sarah Williams', 102, 52000),
(5, 'Tom Brown', 103, 60000)
ON CONFLICT DO NOTHING;

INSERT INTO projects (proj_id, proj_name, budget, dept_id)
VALUES
(201, 'Website Redesign', 75000, 101),
(202, 'Database Migration', 120000, 101),
(203, 'HR System Upgrade', 50000, 102)
ON CONFLICT DO NOTHING;

----------------------------------------
-- Part 2: Простые индексы
----------------------------------------
-- Exercise 2.1: Создаю B-tree индекс на salary
-- Комментарий: добавляю индекс на зарплату, чтобы ускорить фильтрацию/сортировку по salary
CREATE INDEX IF NOT EXISTS emp_salary_idx ON employees(salary);

-- Проверка: показать индексы на таблице employees
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'employees';

-- Exercise 2.2: Индекс на внешнем ключе dept_id
-- Комментарий: индекс на dept_id помогает JOIN'ам и запросам WHERE dept_id = ...
CREATE INDEX IF NOT EXISTS emp_dept_idx ON employees(dept_id);

-- Пример запроса, который будет использовать индекс
SELECT * FROM employees WHERE dept_id = 101;

-- Exercise 2.3: Посмотреть все индексы в публичной схеме
SELECT tablename, indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

----------------------------------------
-- Part 3: Многоколонные индексы
----------------------------------------
-- Exercise 3.1: индекс на (dept_id, salary)
-- Комментарий: индекс для запросов, где сначала фильтр по dept_id, затем по salary
CREATE INDEX IF NOT EXISTS emp_dept_salary_idx ON employees(dept_id, salary);

-- Тестовый запрос, который сможет использовать индекс
SELECT emp_name, salary
FROM employees
WHERE dept_id = 101 AND salary > 52000;

-- Exercise 3.2: индекс с обратным порядком колонок
-- Комментарий: проверяю влияние порядка колонок в композитном индексе
CREATE INDEX IF NOT EXISTS emp_salary_dept_idx ON employees(salary, dept_id);

-- Примеры запросов
SELECT * FROM employees WHERE dept_id = 102 AND salary > 50000;
SELECT * FROM employees WHERE salary > 50000 AND dept_id = 102;

----------------------------------------
-- Part 4: Уникальные индексы
----------------------------------------
-- Exercise 4.1: добавляем email и делаем уникальный индекс
ALTER TABLE employees ADD COLUMN IF NOT EXISTS email VARCHAR(100);

-- Обновляю данные email (только если NULL)
UPDATE employees SET email = 'john.smith@company.com' WHERE emp_id = 1 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'jane.doe@company.com' WHERE emp_id = 2 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'tom.brown@company.com' WHERE emp_id = 5 AND (email IS NULL OR email = '');

-- Создаю уникальный индекс на email
CREATE UNIQUE INDEX IF NOT EXISTS emp_email_unique_idx ON employees(email);

-- Тест: вставка с дублирующим email -> ожидаю ошибку unique violation
-- (строку ниже можно раскомментировать чтобы протестировать)
-- INSERT INTO employees (emp_id, emp_name, dept_id, salary, email)
-- VALUES (6, 'New Employee', 101, 55000, 'john.smith@company.com');

-- Exercise 4.2: UNIQUE constraint на phone (Postgres создаст индекс автоматически)
ALTER TABLE employees ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE employees ADD CONSTRAINT IF NOT EXISTS employees_phone_unique UNIQUE (phone);

-- Посмотреть индексы, относящиеся к phone
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'employees' AND indexname ILIKE '%phone%';

----------------------------------------
-- Part 5: Индексы и сортировка
----------------------------------------
-- Exercise 5.1: Индекс, оптимизированный для ORDER BY salary DESC
CREATE INDEX IF NOT EXISTS emp_salary_desc_idx ON employees(salary DESC);

-- Тест ORDER BY
SELECT emp_name, salary FROM employees ORDER BY salary DESC;

-- Exercise 5.2: Индекс с NULLS FIRST на projects.budget
CREATE INDEX IF NOT EXISTS proj_budget_nulls_first_idx ON projects(budget NULLS FIRST);

SELECT proj_name, budget FROM projects ORDER BY budget NULLS FIRST;

----------------------------------------
-- Part 6: Индексы на выражениях
----------------------------------------
-- Exercise 6.1: индекс для нечувствительных к регистру поисков по имени
CREATE INDEX IF NOT EXISTS emp_name_lower_idx ON employees(LOWER(emp_name));

-- Тест запроса
SELECT * FROM employees WHERE LOWER(emp_name) = 'john smith';

-- Exercise 6.2: индекс на вычисляемом годе найма
ALTER TABLE employees ADD COLUMN IF NOT EXISTS hire_date DATE;

UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5 AND hire_date IS NULL;

-- В Postgres нельзя прямо индексировать результат EXTRACT(...) как простую колонку,
-- но можно создать индекс на выражении. Создам индекс на (date_part('year', hire_date))
CREATE INDEX IF NOT EXISTS emp_hire_year_idx ON employees ((EXTRACT(YEAR FROM hire_date)));

-- Тест запроса
SELECT emp_name, hire_date FROM employees WHERE EXTRACT(YEAR FROM hire_date) = 2020;

----------------------------------------
-- Part 7: Управление индексами
----------------------------------------
-- Exercise 7.1: Переименовать emp_salary_idx в employees_salary_index
-- Комментарий: иногда переименовываю, чтобы имя было понятнее
ALTER INDEX IF EXISTS emp_salary_idx RENAME TO employees_salary_index;

-- Проверка
SELECT indexname FROM pg_indexes WHERE tablename = 'employees';

-- Exercise 7.2: Удалить ненужный индекс emp_salary_dept_idx
DROP INDEX IF EXISTS emp_salary_dept_idx;

-- Exercise 7.3: REINDEX существующего индекса
REINDEX INDEX IF EXISTS employees_salary_index;

----------------------------------------
-- Part 8: Практические сценарии
----------------------------------------
-- Exercise 8.1: Оптимизация частого запроса (WHERE salary > 50000 ORDER BY salary DESC)
-- Комментарий: создаю частичный индекс для salary > 50000, чтобы ускорить частые запросы по этому условию
CREATE INDEX IF NOT EXISTS emp_salary_filter_idx ON employees(salary) WHERE salary > 50000;
-- Для JOIN по dept_id уже есть emp_dept_idx

-- Exercise 8.2: Частичный индекс для проектов с бюджетом > 80000
CREATE INDEX IF NOT EXISTS proj_high_budget_idx ON projects(budget) WHERE budget > 80000;

SELECT proj_name, budget FROM projects WHERE budget > 80000;

-- Exercise 8.3: Использовать EXPLAIN для проверки
EXPLAIN SELECT * FROM employees WHERE salary > 52000;

----------------------------------------
-- Part 9: Сравнение типов индексов
----------------------------------------
-- Exercise 9.1: Создать HASH индекс для dept_name (пример)
CREATE INDEX IF NOT EXISTS dept_name_hash_idx ON departments USING HASH (dept_name);

SELECT * FROM departments WHERE dept_name = 'IT';

-- Exercise 9.2: Создать B-tree и Hash индексы на proj_name
CREATE INDEX IF NOT EXISTS proj_name_btree_idx ON projects(proj_name);
CREATE INDEX IF NOT EXISTS proj_name_hash_idx ON projects USING HASH (proj_name);

-- Тестовые запросы
SELECT * FROM projects WHERE proj_name = 'Website Redesign';
SELECT * FROM projects WHERE proj_name > 'Database';

----------------------------------------
-- Part 10: Очистка и документация
----------------------------------------
-- Exercise 10.1: Список индексов и их размеров
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS index_size
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Exercise 10.2: Удаление лишних индексов (пример)
DROP INDEX IF EXISTS proj_name_hash_idx; -- удаляю hash-индекс, если он не нужен

-- Exercise 10.3: Создание VIEW с документированием индексов по зарплате
CREATE OR REPLACE VIEW index_documentation AS
SELECT 
    tablename,
    indexname,
    indexdef,
    'Improves salary-based queries' AS purpose
FROM pg_indexes
WHERE schemaname = 'public' 
  AND indexname ILIKE '%salary%';

SELECT * FROM index_documentation;
