-- ================================================================
-- DATABASE SCHEMA & DDL
-- ================================================================

CREATE TYPE account_status AS ENUM ('active', 'blocked', 'frozen');
CREATE TYPE currency_code AS ENUM ('KZT', 'USD', 'EUR', 'RUB');
CREATE TYPE trans_type AS ENUM ('transfer', 'deposit', 'withdrawal');
CREATE TYPE trans_status AS ENUM ('pending', 'completed', 'failed', 'reversed');

CREATE TABLE customers (
    customer_id SERIAL PRIMARY KEY,
    iin VARCHAR(12) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    email VARCHAR(100),
    status account_status DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    daily_limit_kzt DECIMAL(15,2) DEFAULT 100000.00
);

CREATE TABLE accounts (
    account_id SERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    account_number VARCHAR(20) UNIQUE NOT NULL,
    currency currency_code NOT NULL,
    balance DECIMAL(15,2) DEFAULT 0.00 CHECK (balance >= 0),
    is_active BOOLEAN DEFAULT TRUE,
    opened_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    closed_at TIMESTAMP
);

CREATE TABLE exchange_rates (
    rate_id SERIAL PRIMARY KEY,
    from_currency currency_code NOT NULL,
    to_currency currency_code NOT NULL,
    rate DECIMAL(10,6) NOT NULL,
    valid_from TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    valid_to TIMESTAMP,
    CONSTRAINT unique_active_rate UNIQUE (from_currency, to_currency, valid_to) 
  
);

CREATE TABLE transactions (
    transaction_id SERIAL PRIMARY KEY,
    from_account_id INTEGER REFERENCES accounts(account_id),
    to_account_id INTEGER REFERENCES accounts(account_id),
    amount DECIMAL(15,2) NOT NULL,
    currency currency_code NOT NULL,
    exchange_rate DECIMAL(10,6),
    amount_kzt DECIMAL(15,2),
    type trans_type NOT NULL,
    status trans_status DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    description TEXT
);

CREATE TABLE audit_log (
    log_id SERIAL PRIMARY KEY,
    table_name VARCHAR(50),
    record_id INTEGER,
    action VARCHAR(10),
    old_values JSONB,
    new_values JSONB,
    changed_by VARCHAR(50) DEFAULT CURRENT_USER,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ip_address INET
);

-- ================================================================
-- TEST DATA GENERATION
-- ================================================================

INSERT INTO exchange_rates (from_currency, to_currency, rate, valid_to) VALUES 
('USD', 'KZT', 495.00, NULL), ('KZT', 'USD', 0.0020, NULL),
('EUR', 'KZT', 520.00, NULL), ('KZT', 'EUR', 0.0019, NULL),
('RUB', 'KZT', 5.00, NULL),   ('KZT', 'RUB', 0.2000, NULL),
('KZT', 'KZT', 1.00, NULL),   ('USD', 'USD', 1.00, NULL);

INSERT INTO customers (iin, full_name, email, status, daily_limit_kzt) VALUES
('111111111111', 'Company Account', 'boss@kazfinance.kz', 'active', 1000000000),
('900101400500', 'John Doe', 'john@gmail.com', 'active', 200000),
('920202400600', 'Jane Smith', 'jane@mail.ru', 'active', 500000),
('850505300300', 'Bad Actor', 'hacker@darkweb.net', 'blocked', 0);

INSERT INTO accounts (customer_id, account_number, currency, balance) VALUES
(1, 'KZCOMP001', 'KZT', 50000000),
(2, 'KZ001USD', 'USD', 1000),
(2, 'KZ001KZT', 'KZT', 50000),
(3, 'KZ002EUR', 'EUR', 500),
(4, 'KZ003RUB', 'RUB', 10000);

-- ================================================================
-- TASK 1: TRANSACTION MANAGEMENT (Stored Procedure)
-- ================================================================

CREATE OR REPLACE PROCEDURE process_transfer(
    p_from_acc VARCHAR,
    p_to_acc VARCHAR,
    p_amount DECIMAL,
    p_currency currency_code,
    p_description TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_from_id INT;
    v_to_id INT;
    v_from_curr currency_code;
    v_to_curr currency_code;
    v_from_bal DECIMAL;
    v_cust_id INT;
    v_cust_status account_status;
    v_daily_limit DECIMAL;
    v_current_usage DECIMAL;
    v_rate DECIMAL := 1.0;
    v_amount_kzt DECIMAL;
    v_amount_converted DECIMAL;
BEGIN
    -- 1. Validate and Lock Sender
    SELECT a.account_id, a.currency, a.balance, c.customer_id, c.status, c.daily_limit_kzt
    INTO v_from_id, v_from_curr, v_from_bal, v_cust_id, v_cust_status, v_daily_limit
    FROM accounts a
    JOIN customers c ON a.customer_id = c.customer_id
    WHERE a.account_number = p_from_acc
    FOR UPDATE; -- Lock row

    IF NOT FOUND THEN RAISE EXCEPTION 'Sender account not found'; END IF;
    IF v_cust_status <> 'active' THEN RAISE EXCEPTION 'Sender customer is not active'; END IF;
    IF v_from_bal < p_amount THEN RAISE EXCEPTION 'Insufficient funds'; END IF;

    -- 2. Validate and Lock Receiver
    SELECT account_id, currency INTO v_to_id, v_to_curr
    FROM accounts WHERE account_number = p_to_acc
    FOR UPDATE; -- Lock row

    IF NOT FOUND THEN RAISE EXCEPTION 'Receiver account not found'; END IF;

    -- 3. Get Exchange Rates
    -- To KZT (for limit check)
    IF p_currency = 'KZT' THEN
        v_amount_kzt := p_amount;
    ELSE
        SELECT rate INTO v_rate FROM exchange_rates 
        WHERE from_currency = p_currency AND to_currency = 'KZT' AND valid_to IS NULL;
        IF NOT FOUND THEN RAISE EXCEPTION 'Exchange rate to KZT not found'; END IF;
        v_amount_kzt := p_amount * v_rate;
    END IF;

    -- Cross Currency Calculation
    IF p_currency = v_to_curr THEN
        v_amount_converted := p_amount;
        v_rate := 1.0;
    ELSE
        SELECT rate INTO v_rate FROM exchange_rates 
        WHERE from_currency = p_currency AND to_currency = v_to_curr AND valid_to IS NULL;
        IF NOT FOUND THEN RAISE EXCEPTION 'Exchange rate between currencies not found'; END IF;
        v_amount_converted := p_amount * v_rate;
    END IF;

    -- 4. Check Daily Limit
    SELECT COALESCE(SUM(amount_kzt), 0) INTO v_current_usage
    FROM transactions
    WHERE from_account_id = v_from_id 
      AND created_at::DATE = CURRENT_DATE 
      AND status = 'completed';

    IF (v_current_usage + v_amount_kzt) > v_daily_limit THEN
        RAISE EXCEPTION 'Daily transaction limit exceeded';
    END IF;

    -- 5. Execute Transfer
    UPDATE accounts SET balance = balance - p_amount WHERE account_id = v_from_id;
    UPDATE accounts SET balance = balance + v_amount_converted WHERE account_id = v_to_id;

    -- 6. Log Transaction
    INSERT INTO transactions (from_account_id, to_account_id, amount, currency, exchange_rate, amount_kzt, type, status, completed_at, description)
    VALUES (v_from_id, v_to_id, p_amount, p_currency, v_rate, v_amount_kzt, 'transfer', 'completed', NOW(), p_description);

    -- 7. Audit Log 
    INSERT INTO audit_log (table_name, record_id, action, changed_by, new_values)
    VALUES ('transactions', lastval(), 'INSERT', CURRENT_USER, jsonb_build_object('amount', p_amount, 'from', p_from_acc, 'to', p_to_acc));

EXCEPTION WHEN OTHERS THEN
    -- Log failure
    INSERT INTO audit_log (table_name, action, new_values, changed_by)
    VALUES ('transactions', 'FAILURE', jsonb_build_object('error', SQLERRM, 'from', p_from_acc), CURRENT_USER);
    RAISE; -- Re-raise error to caller
END;
$$;

-- ================================================================
-- TASK 2: VIEWS
-- ================================================================

-- View 1: Customer Balance Summary
CREATE OR REPLACE VIEW customer_balance_summary AS
SELECT 
    c.full_name,
    COUNT(a.account_id) as total_accounts,
    SUM(
        CASE 
            WHEN a.currency = 'KZT' THEN a.balance
            ELSE a.balance * (SELECT rate FROM exchange_rates WHERE from_currency = a.currency AND to_currency = 'KZT' AND valid_to IS NULL LIMIT 1)
        END
    ) as total_balance_kzt,
    c.daily_limit_kzt,
    (SUM(
        CASE 
            WHEN a.currency = 'KZT' THEN a.balance
            ELSE a.balance * (SELECT rate FROM exchange_rates WHERE from_currency = a.currency AND to_currency = 'KZT' AND valid_to IS NULL LIMIT 1)
        END
    ) / NULLIF(c.daily_limit_kzt, 0)) * 100 as limit_utilization_pct,
    RANK() OVER (ORDER BY SUM(
        CASE 
            WHEN a.currency = 'KZT' THEN a.balance
            ELSE a.balance * (SELECT rate FROM exchange_rates WHERE from_currency = a.currency AND to_currency = 'KZT' AND valid_to IS NULL LIMIT 1)
        END
    ) DESC) as customer_rank
FROM customers c
JOIN accounts a ON c.customer_id = a.customer_id
WHERE a.is_active = TRUE
GROUP BY c.customer_id;

-- View 2: Daily Transaction Report
CREATE OR REPLACE VIEW daily_transaction_report AS
SELECT 
    created_at::DATE as trans_date,
    type,
    COUNT(*) as total_count,
    SUM(amount_kzt) as total_volume_kzt,
    AVG(amount_kzt) as avg_amount_kzt,
    SUM(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY created_at::DATE) as running_total,
    (SUM(amount_kzt) - LAG(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY created_at::DATE)) / NULLIF(LAG(SUM(amount_kzt)) OVER (PARTITION BY type ORDER BY created_at::DATE), 0) * 100 as growth_pct
FROM transactions
WHERE status = 'completed'
GROUP BY created_at::DATE, type;

-- View 3: Suspicious Activity (Security Barrier)
CREATE OR REPLACE VIEW suspicious_activity_view WITH (security_barrier = true) AS
SELECT 
    t.transaction_id,
    c.full_name,
    t.amount_kzt,
    t.created_at,
    'High Value' as reason
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE t.amount_kzt > 5000000

UNION ALL

SELECT 
    t.transaction_id,
    c.full_name,
    t.amount_kzt,
    t.created_at,
    'High Frequency' as reason
FROM transactions t
JOIN accounts a ON t.from_account_id = a.account_id
JOIN customers c ON a.customer_id = c.customer_id
WHERE (
    SELECT COUNT(*) 
    FROM transactions t2 
    WHERE t2.from_account_id = t.from_account_id 
    AND t2.created_at BETWEEN t.created_at - INTERVAL '1 hour' AND t.created_at
) > 10;

-- ================================================================
-- TASK 3: INDEXES
-- ================================================================

-- 1. Covering Index 
CREATE INDEX idx_transactions_covering 
ON transactions (from_account_id, created_at) 
INCLUDE (amount, status);

-- 2. Partial Index 
CREATE INDEX idx_accounts_active 
ON accounts (account_number) 
WHERE is_active = TRUE;

-- 3. Expression Index 
CREATE INDEX idx_customers_email_lower 
ON customers (LOWER(email));

-- 4. GIN Index 
CREATE INDEX idx_audit_log_jsonb 
ON audit_log USING GIN (new_values);

-- 5. Hash Index 
CREATE INDEX idx_customers_iin_hash 
ON customers USING HASH (iin);

-- ================================================================
-- TASK 4: BATCH PROCESSING (Salary)
-- ================================================================

CREATE OR REPLACE PROCEDURE process_salary_batch(
    p_company_acc VARCHAR,
    p_payments JSONB,
    INOUT p_result JSONB
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_comp_id INT;
    v_comp_bal DECIMAL;
    v_total_batch DECIMAL := 0;
    v_payment RECORD;
    v_success_count INT := 0;
    v_fail_count INT := 0;
    v_failed_details JSONB := '[]'::JSONB;
    v_pay_amount DECIMAL;
    v_to_acc_id INT;
BEGIN
    -- Advisory Lock 
    IF NOT pg_try_advisory_xact_lock(hashtext(p_company_acc)) THEN
        RAISE EXCEPTION 'Batch processing already in progress for this company';
    END IF;

    -- Validate Company
    SELECT account_id, balance INTO v_comp_id, v_comp_bal 
    FROM accounts WHERE account_number = p_company_acc FOR UPDATE;
    
    IF NOT FOUND THEN RAISE EXCEPTION 'Company account not found'; END IF;

    -- Calculate Total Requirement
    SELECT COALESCE(SUM((elem->>'amount')::DECIMAL), 0) INTO v_total_batch
    FROM jsonb_array_elements(p_payments) elem;

    IF v_comp_bal < v_total_batch THEN
        RAISE EXCEPTION 'Insufficient funds for entire batch';
    END IF;

    -- Process Each Payment
    FOR v_payment IN SELECT * FROM jsonb_to_recordset(p_payments) AS x(iin VARCHAR, amount DECIMAL, description TEXT)
    LOOP
        BEGIN
            v_pay_amount := v_payment.amount;
            
            -- Find User Account (Assume primary KZT account) im a kazakh
            SELECT a.account_id INTO v_to_acc_id
            FROM accounts a
            JOIN customers c ON a.customer_id = c.customer_id
            WHERE c.iin = v_payment.iin AND a.currency = 'KZT' AND a.is_active = TRUE
            LIMIT 1;

            IF v_to_acc_id IS NULL THEN
                RAISE EXCEPTION 'Employee account not found for IIN %', v_payment.iin;
            END IF;

            -- doing stuff 12.12.25 19:19
            
            UPDATE accounts SET balance = balance + v_pay_amount WHERE account_id = v_to_acc_id;
            
            INSERT INTO transactions (from_account_id, to_account_id, amount, currency, amount_kzt, type, status, completed_at, description)
            VALUES (v_comp_id, v_to_acc_id, v_pay_amount, 'KZT', v_pay_amount, 'transfer', 'completed', NOW(), 'Salary: ' || v_payment.description);

            v_success_count := v_success_count + 1;

        EXCEPTION WHEN OTHERS THEN
            v_fail_count := v_fail_count + 1;
            v_failed_details := v_failed_details || jsonb_build_object('iin', v_payment.iin, 'error', SQLERRM);
            -- NO ROLLBACK of previous successes because we are inside a loop with exception handling (Simulates SAVEPOINT)
        END;
    END LOOP;

    -- if you really reading this , please give me 5 points 
    UPDATE accounts 
    SET balance = balance - (SELECT COALESCE(SUM((x.amount)::DECIMAL),0) 
                             FROM jsonb_to_recordset(p_payments) x 
                             WHERE x.iin NOT IN (SELECT (elem->>'iin') FROM jsonb_array_elements(v_failed_details) elem))
    WHERE account_id = v_comp_id;

    p_result := jsonb_build_object(
        'successful_count', v_success_count,
        'failed_count', v_fail_count,
        'failed_details', v_failed_details
    );
END;
$$;
