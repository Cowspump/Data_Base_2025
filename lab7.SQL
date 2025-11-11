-- ============================
-- LABORATORY WORK 7 - SOLUTIONS
-- Автор: Alikhan
-- ============================

-- ========== Part 2: Creating Basic Views ==========

-- Exercise 2.1: Simple View Creation
-- Создаю view employee_details: показывает имя сотрудника, зарплату, департамент и локацию.
-- Отфильтровываю только тех, кто привязан к департаменту (dept_id IS NOT NULL).
CREATE OR REPLACE VIEW employee_details AS
SELECT
    e.emp_id,
    e.emp_name,
    e.salary,
    e.dept_id,
    d.dept_name,
    d.location
FROM employees e
         JOIN departments d ON e.dept_id = d.dept_id
;
-- Я сделал JOIN, поэтому сотрудники без департамента (например, Tom Brown) не появятся.

-- Тест:
-- SELECT * FROM employee_details;
-- Вопрос в задании: почему Tom Brown не появляется? Потому что у него нет dept_id (мы использовали JOIN).

-- Exercise 2.2: View with Aggregation
-- Создаю dept_statistics: название департамента, число сотрудников, avg/max/min зарплата.
-- Включаю все департаменты через LEFT JOIN / GROUP BY.
CREATE OR REPLACE VIEW dept_statistics AS
SELECT
    d.dept_id,
    d.dept_name,
    COUNT(e.emp_id) AS employee_count,
    ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
    COALESCE(MAX(e.salary),0) AS max_salary,
    COALESCE(MIN(e.salary),0) AS min_salary
FROM departments d
         LEFT JOIN employees e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name
;

-- Тест:
-- SELECT * FROM dept_statistics ORDER BY employee_count DESC;

-- Exercise 2.3: View with Multiple Joins
-- Создаю проектный обзор project_overview: имя проекта, бюджет, департамент, локация и размер команды (count сотрудников в департаменте).
CREATE OR REPLACE VIEW project_overview AS
SELECT
    p.project_id,
    p.project_name,
    p.budget,
    p.dept_id,
    d.dept_name,
    d.location,
    COALESCE(ds.team_size,0) AS team_size
FROM projects p
         LEFT JOIN departments d ON p.dept_id = d.dept_id
         LEFT JOIN (
    SELECT dept_id, COUNT(emp_id) AS team_size
    FROM employees
    GROUP BY dept_id
) ds ON d.dept_id = ds.dept_id
;

-- Exercise 2.4: View with Filtering
-- Создаю high_earners: сотрудники с salary > 55000.
CREATE OR REPLACE VIEW high_earners AS
SELECT emp_id, emp_name, salary, dept_id
FROM employees
WHERE salary > 55000
;

-- Вопрос: видны ли все высокооплачиваемые? Да — если нет ограничения прав, view вернёт строки, удовлетворяющие условию.
-- Но если есть права доступа/фильтры на уровне схемы/ролей, результат может быть ограничен.

-- ========== Part 3: Modifying and Managing Views ==========

-- Exercise 3.1: Replace employee_details to include salary_grade
-- Важно: сохраняем исходный порядок колонок и добавляем новый столбец в конец, чтобы избежать ошибки 42P16.
CREATE OR REPLACE VIEW employee_details AS
SELECT
    e.emp_id,
    e.emp_name,
    e.salary,
    e.dept_id,
    d.dept_name,
    d.location,
    CASE
        WHEN e.salary > 60000 THEN 'High'
        WHEN e.salary > 50000 THEN 'Medium'
        ELSE 'Standard'
        END AS salary_grade
FROM employees e
         JOIN departments d ON e.dept_id = d.dept_id
;

-- Exercise 3.2: Rename a View
-- Переименую high_earners -> top_performers
    ALTER VIEW IF EXISTS high_earners RENAME TO top_performers;

-- Проверка:
-- SELECT * FROM top_performers;

-- Exercise 3.3: Drop a temporary view
CREATE TEMPORARY VIEW temp_view AS
SELECT emp_id, emp_name, salary
FROM employees
WHERE salary < 50000
;
-- Удаляю temp_view
DROP VIEW IF EXISTS temp_view;

-- ========== Part 4: Updatable Views ==========

-- Exercise 4.1: Create an Updatable View employee_salaries
-- Простая updatable view должна быть на одну таблицу, без агрегатов/джойнов.
CREATE OR REPLACE VIEW employee_salaries AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees
        WITH CHECK OPTION
;
-- Комментарий: WITH CHECK OPTION полезен, если хотим предотвратить выход строки из области view.

-- Exercise 4.2: Update John Smith's salary через view
-- Я предполагаю, что сотрудник называется 'John Smith'.
UPDATE employee_salaries
SET salary = 52000
WHERE emp_name = 'John Smith';

-- Проверка:
-- SELECT * FROM employees WHERE emp_name = 'John Smith';
-- Вопрос: обновилась ли underlying table? Да — для простых updatable view обновления отражаются в базовой таблице.

-- Exercise 4.3: Insert через view
INSERT INTO employee_salaries (emp_id, emp_name, dept_id, salary)
VALUES (6, 'Alice Johnson', 102, 58000);
-- Проверка:
-- SELECT * FROM employees WHERE emp_name = 'Alice Johnson';
-- Вопрос: было ли успешно? Да — если emp_id уникален и нет ограничений.

-- Exercise 4.4: View with CHECK OPTION (it_employees)
CREATE OR REPLACE VIEW it_employees AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees
WHERE dept_id = 101
        WITH LOCAL CHECK OPTION
;

-- Попытка вставки сотрудника из другого департамента — должна провалиться:
-- INSERT INTO it_employees (emp_id, emp_name, dept_id, salary) VALUES (7, 'Bob Wilson', 103, 60000);
-- Ожидаемая ошибка: ERROR:  new row for relation "it_employees" violates check option "it_employees"
-- Причина: WITH CHECK OPTION предотвращает нарушение условия view.

-- ========== Part 5: Materialized Views ==========

-- Exercise 5.1: Create dept_summary_mv (WITH DATA)
CREATE MATERIALIZED VIEW dept_summary_mv AS
SELECT
    d.dept_id,
    d.dept_name,
    COALESCE(COUNT(e.emp_id),0) AS total_employees,
    COALESCE(SUM(e.salary),0) AS total_salaries,
    COALESCE(COUNT(p.project_id),0) AS total_projects,
    COALESCE(SUM(p.budget),0) AS total_project_budget
FROM departments d
         LEFT JOIN employees e ON d.dept_id = e.dept_id
         LEFT JOIN projects p ON d.dept_id = p.dept_id
GROUP BY d.dept_id, d.dept_name
WITH DATA
;

-- Тест:
-- SELECT * FROM dept_summary_mv ORDER BY total_employees DESC;

-- Exercise 5.2: Refresh materialized view after inserting Charlie Brown
INSERT INTO employees (emp_id, emp_name, dept_id, salary) VALUES (8, 'Charlie Brown', 101, 54000);

-- Query before refresh:
-- SELECT * FROM dept_summary_mv WHERE dept_id = 101;
-- Затем refresh:
REFRESH MATERIALIZED VIEW dept_summary_mv;
-- Query after refresh:
-- SELECT * FROM dept_summary_mv WHERE dept_id = 101;
-- Разница: до REFRESH материализованный view не показывает Charlie Brown; после REFRESH показывает обновлённые агрегаты.

-- Exercise 5.3: Concurrent Refresh
-- Для CONCURRENTLY требуется уникальный индекс на материализованном view.
CREATE UNIQUE INDEX IF NOT EXISTS dept_summary_mv_dept_id_idx ON dept_summary_mv(dept_id);

-- Теперь можно:
REFRESH MATERIALIZED VIEW CONCURRENTLY dept_summary_mv;
-- Преимущество CONCURRENTLY: обновление не блокирует чтение материализованного view для селектов,
-- но требует уникального индекса и занимает больше ресурсов.

-- Exercise 5.4: Materialized View WITH NO DATA
CREATE MATERIALIZED VIEW project_stats_mv AS
SELECT
    p.project_id,
    p.project_name,
    p.budget,
    p.dept_id,
    d.dept_name,
    COALESCE(cnt.assigned_employees,0) AS assigned_employees
FROM projects p
         LEFT JOIN departments d ON p.dept_id = d.dept_id
         LEFT JOIN (
    SELECT dept_id, COUNT(emp_id) AS assigned_employees
    FROM employees
    GROUP BY dept_id
) cnt ON d.dept_id = cnt.dept_id
WITH NO DATA
;

-- Чтобы заполнить:
-- REFRESH MATERIALIZED VIEW project_stats_mv;

-- ========== Part 6: Database Roles ==========

-- Exercise 6.1: Create Basic Roles
-- Создаю роли: analyst (no login), data_viewer (login), report_user (login).
DO $$
    BEGIN
        -- analyst (no login)
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analyst') THEN
            CREATE ROLE analyst;
        END IF;
        -- data_viewer (login)
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_viewer') THEN
            CREATE ROLE data_viewer LOGIN PASSWORD 'viewer123';
        END IF;
        -- report_user
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'report_user') THEN
            CREATE ROLE report_user LOGIN PASSWORD 'report456';
        END IF;
    END $$;

-- Просмотр ролей:
-- SELECT rolname FROM pg_roles WHERE rolname NOT LIKE 'pg_%';

-- Exercise 6.2: Roles with attributes
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'db_creator') THEN
            CREATE ROLE db_creator LOGIN PASSWORD 'creator789' CREATEDB;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'user_manager') THEN
            CREATE ROLE user_manager LOGIN PASSWORD 'manager101' CREATEROLE;
        END IF;
        -- ВНИМАНИЕ: суперпользователь создаю аккуратно
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'admin_user') THEN
            CREATE ROLE admin_user LOGIN PASSWORD 'admin999' SUPERUSER;
        END IF;
    END $$;

-- Exercise 6.3: Grant Privileges
GRANT SELECT ON employees, departments, projects TO analyst;
GRANT ALL PRIVILEGES ON employee_details TO data_viewer;
GRANT SELECT, INSERT ON employees TO report_user;

-- Exercise 6.4: Create Group Roles and assign members
DO $$
    BEGIN
        -- Create group roles
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hr_team') THEN
            CREATE ROLE hr_team;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_team') THEN
            CREATE ROLE finance_team;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'it_team') THEN
            CREATE ROLE it_team;
        END IF;

        -- Create individual users
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hr_user1') THEN
            CREATE ROLE hr_user1 LOGIN PASSWORD 'hr001';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'hr_user2') THEN
            CREATE ROLE hr_user2 LOGIN PASSWORD 'hr002';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_user1') THEN
            CREATE ROLE finance_user1 LOGIN PASSWORD 'fin001';
        END IF;

        -- Assign membership
        GRANT hr_team TO hr_user1;
        GRANT hr_team TO hr_user2;
        GRANT finance_team TO finance_user1;
    END $$;

-- Privileges for teams
GRANT SELECT, UPDATE ON employees TO hr_team;
GRANT SELECT ON dept_statistics TO finance_team;

-- Exercise 6.5: Revoke Privileges
REVOKE UPDATE ON employees FROM hr_team;
REVOKE hr_team FROM hr_user2;
REVOKE ALL PRIVILEGES ON employee_details FROM data_viewer;

-- Exercise 6.6: Modify Role Attributes
-- Add LOGIN & password to analyst
ALTER ROLE analyst WITH LOGIN PASSWORD 'analyst123';
-- Make user_manager a superuser
ALTER ROLE user_manager WITH SUPERUSER;
-- Remove password from analyst
ALTER ROLE analyst WITH PASSWORD NULL;
-- Add connection limit to data_viewer
ALTER ROLE data_viewer WITH CONNECTION LIMIT 5;

-- ========== Part 7: Advanced Role Management ==========

-- Exercise 7.1: Role Hierarchies
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'read_only') THEN
            CREATE ROLE read_only;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'junior_analyst') THEN
            CREATE ROLE junior_analyst LOGIN PASSWORD 'junior123';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'senior_analyst') THEN
            CREATE ROLE senior_analyst LOGIN PASSWORD 'senior123';
        END IF;

        -- Grant read_only membership
        GRANT read_only TO junior_analyst;
        GRANT read_only TO senior_analyst;
    END $$;

-- Grant SELECT on all tables in public to read_only
GRANT SELECT ON ALL TABLES IN SCHEMA public TO read_only;

-- Give senior_analyst extra privileges on employees
GRANT INSERT, UPDATE ON employees TO senior_analyst;

-- Exercise 7.2: Object Ownership
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'project_manager') THEN
            CREATE ROLE project_manager LOGIN PASSWORD 'pm123';
        END IF;
    END $$;

-- Transfer ownership of view and table (requires current role to be owner or superuser)
-- Привожу команды, которые нужно выполнить суперпользователю/владельцу:
    ALTER VIEW IF EXISTS dept_statistics OWNER TO project_manager;
ALTER TABLE IF EXISTS projects OWNER TO project_manager;

-- Проверка владельцев:
-- SELECT tablename, tableowner FROM pg_tables WHERE schemaname = 'public';

-- Exercise 7.3: Reassign and Drop Roles
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'temp_owner') THEN
            CREATE ROLE temp_owner LOGIN;
        END IF;
        -- create a temp table owned by current role, then change owner to temp_owner
        PERFORM 1; -- placeholder
    END $$;

-- Пример:
CREATE TABLE IF NOT EXISTS temp_table (id INT);
ALTER TABLE temp_table OWNER TO temp_owner;

-- Reassign objects owned by temp_owner to postgres (или другому роли)
REASSIGN OWNED BY temp_owner TO postgres;
-- Drop objects owned by temp_owner (если ещё остались)
DROP OWNED BY temp_owner;
-- Finally drop role
DROP ROLE IF EXISTS temp_owner;

-- Exercise 7.4: Row-Level Security with Views (role-specific views)
-- HR view
CREATE OR REPLACE VIEW hr_employee_view AS
SELECT emp_id, emp_name, dept_id, salary
FROM employees
WHERE dept_id = 102
;

GRANT SELECT ON hr_employee_view TO hr_team;

-- Finance view (limited columns)
CREATE OR REPLACE VIEW finance_employee_view AS
SELECT emp_id, emp_name, salary
FROM employees
;

GRANT SELECT ON finance_employee_view TO finance_team;

-- ========== Part 8: Practical Scenarios ==========

-- Exercise 8.1: Department Dashboard View (dept_dashboard)
CREATE OR REPLACE VIEW dept_dashboard AS
SELECT
    d.dept_id,
    d.dept_name,
    d.location,
    COUNT(e.emp_id) AS employee_count,
    ROUND(COALESCE(AVG(e.salary),0)::numeric,2) AS avg_salary,
    COUNT(DISTINCT p.project_id) FILTER (WHERE p.project_id IS NOT NULL) AS active_projects,
    COALESCE(SUM(p.budget),0) AS total_project_budget,
    ROUND(
            CASE WHEN COUNT(e.emp_id) = 0 THEN 0
                 ELSE COALESCE(SUM(p.budget),0) / NULLIF(COUNT(e.emp_id),0)
                END::numeric, 2) AS budget_per_employee
FROM departments d
         LEFT JOIN employees e ON d.dept_id = e.dept_id
         LEFT JOIN projects p ON d.dept_id = p.dept_id
GROUP BY d.dept_id, d.dept_name, d.location
;

-- Exercise 8.2: Audit View for high value projects
-- Step 1: add created_date column to projects (если нет)
ALTER TABLE projects
    ADD COLUMN IF NOT EXISTS created_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP;

-- Create high_budget_projects view
CREATE OR REPLACE VIEW high_budget_projects AS
SELECT
    p.project_id,
    p.project_name,
    p.budget,
    d.dept_name,
    p.created_date,
    CASE
        WHEN p.budget > 150000 THEN 'Critical Review Required'
        WHEN p.budget > 100000 THEN 'Management Approval Needed'
        ELSE 'Standard Process'
        END AS approval_status
FROM projects p
         LEFT JOIN departments d ON p.dept_id = d.dept_id
WHERE p.budget > 75000
;

-- Exercise 8.3: Create Access Control System (roles levels)
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'viewer_role') THEN
            CREATE ROLE viewer_role;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'entry_role') THEN
            CREATE ROLE entry_role;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'analyst_role') THEN
            CREATE ROLE analyst_role;
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'manager_role') THEN
            CREATE ROLE manager_role;
        END IF;
    END $$;

-- Grant privileges and create hierarchy
GRANT SELECT ON ALL TABLES IN SCHEMA public TO viewer_role;

-- entry_role inherits viewer_role
GRANT viewer_role TO entry_role;
GRANT INSERT ON employees, projects TO entry_role;

-- analyst_role inherits entry_role
GRANT entry_role TO analyst_role;
GRANT UPDATE ON employees, projects TO analyst_role;

-- manager_role inherits analyst_role
GRANT analyst_role TO manager_role;
GRANT DELETE ON employees, projects TO manager_role;

-- Create users and assign to roles
DO $$
    BEGIN
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'alice') THEN
            CREATE ROLE alice LOGIN PASSWORD 'alice123';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'bob') THEN
            CREATE ROLE bob LOGIN PASSWORD 'bob123';
        END IF;
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'charlie') THEN
            CREATE ROLE charlie LOGIN PASSWORD 'charlie123';
        END IF;
    END $$;

GRANT viewer_role TO alice;
GRANT analyst_role TO bob;
GRANT manager_role TO charlie;
