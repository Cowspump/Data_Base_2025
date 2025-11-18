-- Moldabayev Alikhan
-- lab 8: INDEXES in PostgreSQL


-- 1) Создаём таблицы, если их нет
CREATE TABLE IF NOT EXISTS departments (
                                           dept_id INT PRIMARY KEY,
                                           dept_name VARCHAR(50),
                                           location VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS employees (
                                         emp_id INT PRIMARY KEY,
                                         emp_name VARCHAR(100),
                                         dept_id INT,
                                         salary NUMERIC(12,2),
    -- email, phone, hire_date будут добавлены через ALTER TABLE IF NOT EXISTS ниже
                                         FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

CREATE TABLE IF NOT EXISTS projects (
                                        proj_id INT PRIMARY KEY,
                                        proj_name VARCHAR(100),
                                        budget NUMERIC(14,2),
                                        dept_id INT,
                                        FOREIGN KEY (dept_id) REFERENCES departments(dept_id)
);

-- 2) Вставляем тестовые данные, но безопасно (ON CONFLICT DO NOTHING)
INSERT INTO departments (dept_id, dept_name, location) VALUES
                                                           (101, 'IT', 'Building A'),
                                                           (102, 'HR', 'Building B'),
                                                           (103, 'Operations', 'Building C')
ON CONFLICT (dept_id) DO NOTHING;

INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES
                                                              (1, 'John Smith', 101, 50000),
                                                              (2, 'Jane Doe', 101, 55000),
                                                              (3, 'Mike Johnson', 102, 48000),
                                                              (4, 'Sarah Williams', 102, 52000),
                                                              (5, 'Tom Brown', 103, 60000)
ON CONFLICT (emp_id) DO NOTHING;

INSERT INTO projects (proj_id, proj_name, budget, dept_id) VALUES
                                                               (201, 'Website Redesign', 75000, 101),
                                                               (202, 'Database Migration', 120000, 101),
                                                               (203, 'HR System Upgrade', 50000, 102)
ON CONFLICT (proj_id) DO NOTHING;

-- 3) Добавляем колонки, если ещё не добавлены
ALTER TABLE employees ADD COLUMN IF NOT EXISTS email VARCHAR(100);
ALTER TABLE employees ADD COLUMN IF NOT EXISTS phone VARCHAR(20);
ALTER TABLE employees ADD COLUMN IF NOT EXISTS hire_date DATE;

-- Заполняем email/phone/hire_date безопасно — только если NULL
UPDATE employees SET email = 'john.smith@company.com' WHERE emp_id = 1 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'jane.doe@company.com' WHERE emp_id = 2 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'mike.johnson@company.com' WHERE emp_id = 3 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'sarah.williams@company.com' WHERE emp_id = 4 AND (email IS NULL OR email = '');
UPDATE employees SET email = 'tom.brown@company.com' WHERE emp_id = 5 AND (email IS NULL OR email = '');

UPDATE employees SET hire_date = '2020-01-15' WHERE emp_id = 1 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2019-06-20' WHERE emp_id = 2 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2021-03-10' WHERE emp_id = 3 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2020-11-05' WHERE emp_id = 4 AND hire_date IS NULL;
UPDATE employees SET hire_date = '2018-08-25' WHERE emp_id = 5 AND hire_date IS NULL;

-- 4) Part 2: Basic indexes (use IF NOT EXISTS)
CREATE INDEX IF NOT EXISTS emp_salary_idx ON employees(salary);
CREATE INDEX IF NOT EXISTS emp_dept_idx ON employees(dept_id);

-- 5) View index info example (just a helpful SELECT)
-- SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'employees';

-- 6) Part 3: multicolumn indexes
CREATE INDEX IF NOT EXISTS emp_dept_salary_idx ON employees(dept_id, salary);
CREATE INDEX IF NOT EXISTS emp_salary_dept_idx ON employees(salary, dept_id);

-- 7) Part 4: unique index on email
-- Создаём уникальный индекс безопасно — IF NOT EXISTS поддерживается в PostgreSQL >= 9.5
CREATE UNIQUE INDEX IF NOT EXISTS emp_email_unique_idx ON employees(email);

-- Также добавим UNIQUE constraint на phone (сам PostgreSQL создаст индекс при добавлении CONSTRAINT)
-- Добавим constraint только если его ещё нет
DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_constraint WHERE conname = 'employees_phone_key'
        ) THEN
            ALTER TABLE employees ADD CONSTRAINT employees_phone_key UNIQUE (phone);
        END IF;
    EXCEPTION WHEN duplicate_object THEN
        -- игнорируем
        RAISE NOTICE 'Constraint employees_phone_key already exists or cannot be added';
    END$$;

-- 8) Part 5: index for sorting and NULL handling
CREATE INDEX IF NOT EXISTS emp_salary_desc_idx ON employees (salary DESC);
CREATE INDEX IF NOT EXISTS proj_budget_nulls_first_idx ON projects (budget NULLS FIRST);

-- 9) Part 6: expression index (case-insensitive searches)
CREATE INDEX IF NOT EXISTS emp_name_lower_idx ON employees (LOWER(emp_name));

-- Index on extracted year: better to index expression cast to int
-- NOTE: Using EXTRACT returns double precision; to be safe, cast to int
CREATE INDEX IF NOT EXISTS emp_hire_year_idx ON employees ((EXTRACT(YEAR FROM hire_date)::int));

-- 10) Part 7: rename index safely (переименование только если старый индекс существует и нового нет)
DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'i' AND relname = 'emp_salary_idx')
            AND NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'i' AND relname = 'employees_salary_index') THEN
            EXECUTE 'ALTER INDEX emp_salary_idx RENAME TO employees_salary_index';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Не удалось переименовать индекс (возможно уже переименован)';
    END$$;

-- 11) Drop redundant index if exists
DROP INDEX IF EXISTS emp_salary_dept_idx;

-- 12) REINDEX — безопасно: проверим существование, затем попытаемся
DO $$
    BEGIN
        IF EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'i' AND relname = 'employees_salary_index') THEN
            BEGIN
                EXECUTE 'REINDEX INDEX employees_salary_index';
            EXCEPTION WHEN OTHERS THEN
                RAISE NOTICE 'REINDEX failed or not needed';
            END;
        END IF;
    END$$;

-- 13) Part 8: practical scenario indexes (partial index)
-- Index for WHERE salary > 50000 (partial index)
CREATE INDEX IF NOT EXISTS emp_salary_filter_idx ON employees(salary) WHERE salary > 50000;

-- Index for ORDER BY (we already created emp_salary_desc_idx)

-- Partial index for projects with budget > 80000
CREATE INDEX IF NOT EXISTS proj_high_budget_idx ON projects(budget) WHERE budget > 80000;

-- 14) Part 9: Hash index (only for equality)
-- Hash index creation is allowed; if exists, skip
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'i' AND relname = 'dept_name_hash_idx') THEN
            EXECUTE 'CREATE INDEX dept_name_hash_idx ON departments USING HASH (dept_name)';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Hash index creation skipped or failed';
    END$$;

-- Also create btree and hash for proj_name safely
CREATE INDEX IF NOT EXISTS proj_name_btree_idx ON projects(proj_name);
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_class WHERE relkind = 'i' AND relname = 'proj_name_hash_idx') THEN
            EXECUTE 'CREATE INDEX proj_name_hash_idx ON projects USING HASH (proj_name)';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'proj_name_hash_idx creation skipped or failed';
    END$$;

-- 15) Part 10: listing indexes with sizes (example select)
-- SELECT schemaname, tablename, indexname, pg_size_pretty(pg_relation_size(indexname::regclass)) as index_size
-- FROM pg_indexes WHERE schemaname = 'public' ORDER BY tablename, indexname;

-- 16) Cleanup examples (dropping unnecessary indexes safely)
DROP INDEX IF EXISTS proj_name_hash_idx;

-- 17) Create a documentation view (safe: drop and recreate to ensure definition)
CREATE OR REPLACE VIEW index_documentation AS
SELECT
    tablename,
    indexname,
    indexdef,
    'Improves salary-based queries'::text as purpose
FROM pg_indexes
WHERE schemaname = 'public'
  AND indexname LIKE '%salary%';

-- 18) Example EXPLAIN usage: пользователь может выполнить это вручную, например:
-- EXPLAIN ANALYZE SELECT * FROM employees WHERE salary > 52000;

-- 19) Доп.: демонстрационные запросы (безопасные SELECT для проверки)
SELECT 'indexes_on_employees' AS info, indexname, indexdef FROM pg_indexes WHERE tablename = 'employees';
SELECT 'top_employees' AS info, emp_name, salary FROM employees ORDER BY salary DESC LIMIT 5;
SELECT proj_name, budget FROM projects WHERE budget > 80000;
