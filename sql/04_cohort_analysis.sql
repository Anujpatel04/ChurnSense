-- ============================================================================
-- COHORT ANALYSIS
-- Big-Tech-Grade User Retention & Churn Prediction System
-- ============================================================================
-- Purpose: Analyze customer retention by cohorts
-- Key Question: How do different customer cohorts retain over time?
-- ============================================================================

-- ============================================================================
-- 1. MONTHLY ACQUISITION COHORT RETENTION
-- ============================================================================

WITH customer_cohorts AS (
    SELECT 
        "Customer ID" as customer_id,
        DATE(MIN(InvoiceDate), 'start of month') as cohort_month,
        MIN(InvoiceDate) as first_purchase
    FROM transactions_clean
    GROUP BY "Customer ID"
),

customer_activity AS (
    SELECT 
        "Customer ID" as customer_id,
        DATE(InvoiceDate, 'start of month') as activity_month
    FROM transactions_clean
    GROUP BY "Customer ID", DATE(InvoiceDate, 'start of month')
),

cohort_retention AS (
    SELECT 
        cc.cohort_month,
        ca.activity_month,
        -- Months since cohort start
        (CAST(strftime('%Y', ca.activity_month) AS INTEGER) - CAST(strftime('%Y', cc.cohort_month) AS INTEGER)) * 12 +
        (CAST(strftime('%m', ca.activity_month) AS INTEGER) - CAST(strftime('%m', cc.cohort_month) AS INTEGER)) as months_since_join,
        COUNT(DISTINCT cc.customer_id) as active_customers
    FROM customer_cohorts cc
    JOIN customer_activity ca ON cc.customer_id = ca.customer_id
    GROUP BY cc.cohort_month, ca.activity_month
),

cohort_sizes AS (
    SELECT 
        cohort_month,
        COUNT(DISTINCT customer_id) as cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
)

SELECT 
    cr.cohort_month,
    cs.cohort_size,
    cr.months_since_join,
    cr.active_customers,
    ROUND(100.0 * cr.active_customers / cs.cohort_size, 2) as retention_rate_pct
FROM cohort_retention cr
JOIN cohort_sizes cs ON cr.cohort_month = cs.cohort_month
WHERE cr.months_since_join <= 12  -- First year retention
ORDER BY cr.cohort_month, cr.months_since_join;


-- ============================================================================
-- 2. COHORT CHURN CURVES
-- ============================================================================
-- Survival analysis style: When do customers churn relative to joining?

WITH customer_lifetime AS (
    SELECT 
        "Customer ID" as customer_id,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase,
        DATE(MIN(InvoiceDate), 'start of month') as cohort_month,
        JULIANDAY(MAX(InvoiceDate)) - JULIANDAY(MIN(InvoiceDate)) as customer_lifetime_days
    FROM transactions_clean
    GROUP BY "Customer ID"
),

lifetime_buckets AS (
    SELECT 
        cohort_month,
        CASE 
            WHEN customer_lifetime_days <= 7 THEN '0-7 days'
            WHEN customer_lifetime_days <= 30 THEN '8-30 days'
            WHEN customer_lifetime_days <= 60 THEN '31-60 days'
            WHEN customer_lifetime_days <= 90 THEN '61-90 days'
            WHEN customer_lifetime_days <= 180 THEN '91-180 days'
            WHEN customer_lifetime_days <= 365 THEN '181-365 days'
            ELSE '365+ days'
        END as lifetime_bucket,
        COUNT(*) as customers
    FROM customer_lifetime
    WHERE last_purchase <= DATE('2011-10-10')  -- Completed lifetimes only
    GROUP BY cohort_month, lifetime_bucket
)

SELECT 
    lifetime_bucket,
    SUM(customers) as total_customers,
    ROUND(100.0 * SUM(customers) / (SELECT SUM(customers) FROM lifetime_buckets), 2) as pct_of_churned
FROM lifetime_buckets
GROUP BY lifetime_bucket
ORDER BY 
    CASE lifetime_bucket
        WHEN '0-7 days' THEN 1
        WHEN '8-30 days' THEN 2
        WHEN '31-60 days' THEN 3
        WHEN '61-90 days' THEN 4
        WHEN '91-180 days' THEN 5
        WHEN '181-365 days' THEN 6
        ELSE 7
    END;


-- ============================================================================
-- 3. COHORT VALUE ANALYSIS
-- ============================================================================
-- Compare customer value across cohorts

WITH customer_value AS (
    SELECT 
        "Customer ID" as customer_id,
        DATE(MIN(InvoiceDate), 'start of month') as cohort_month,
        SUM(Quantity * Price) as total_revenue,
        COUNT(DISTINCT Invoice) as total_orders,
        AVG(Quantity * Price) as avg_transaction_value
    FROM transactions_clean
    GROUP BY "Customer ID"
)

SELECT 
    cohort_month,
    COUNT(*) as cohort_size,
    ROUND(AVG(total_revenue), 2) as avg_customer_revenue,
    ROUND(SUM(total_revenue), 2) as total_cohort_revenue,
    ROUND(AVG(total_orders), 2) as avg_orders_per_customer,
    ROUND(AVG(avg_transaction_value), 2) as avg_transaction_value
FROM customer_value
GROUP BY cohort_month
ORDER BY cohort_month;


-- ============================================================================
-- 4. FIRST-TIME VS REPEAT CUSTOMER CHURN
-- ============================================================================

WITH customer_orders AS (
    SELECT 
        "Customer ID" as customer_id,
        COUNT(DISTINCT Invoice) as order_count,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    GROUP BY "Customer ID"
),

customer_type_churn AS (
    SELECT 
        CASE 
            WHEN order_count = 1 THEN 'One-time'
            WHEN order_count <= 3 THEN 'Low-repeat (2-3)'
            WHEN order_count <= 5 THEN 'Medium-repeat (4-5)'
            ELSE 'High-repeat (6+)'
        END as customer_type,
        COUNT(*) as customers,
        SUM(CASE WHEN last_purchase <= DATE('2011-08-10') THEN 1 ELSE 0 END) as churned
    FROM customer_orders
    GROUP BY customer_type
)

SELECT 
    customer_type,
    customers,
    churned,
    customers - churned as active,
    ROUND(100.0 * churned / customers, 2) as churn_rate_pct
FROM customer_type_churn
ORDER BY 
    CASE customer_type
        WHEN 'One-time' THEN 1
        WHEN 'Low-repeat (2-3)' THEN 2
        WHEN 'Medium-repeat (4-5)' THEN 3
        ELSE 4
    END;


-- ============================================================================
-- 5. SEASONAL COHORT ANALYSIS
-- ============================================================================
-- Do customers acquired in certain seasons have better retention?

WITH customer_seasons AS (
    SELECT 
        "Customer ID" as customer_id,
        MIN(InvoiceDate) as first_purchase,
        CASE 
            WHEN CAST(strftime('%m', MIN(InvoiceDate)) AS INTEGER) IN (12, 1, 2) THEN 'Winter'
            WHEN CAST(strftime('%m', MIN(InvoiceDate)) AS INTEGER) IN (3, 4, 5) THEN 'Spring'
            WHEN CAST(strftime('%m', MIN(InvoiceDate)) AS INTEGER) IN (6, 7, 8) THEN 'Summer'
            ELSE 'Fall'
        END as acquisition_season,
        MAX(InvoiceDate) as last_purchase,
        COUNT(DISTINCT Invoice) as total_orders
    FROM transactions_clean
    GROUP BY "Customer ID"
),

seasonal_churn AS (
    SELECT 
        acquisition_season,
        COUNT(*) as customers,
        AVG(total_orders) as avg_orders,
        SUM(CASE WHEN last_purchase <= DATE('2011-08-10') THEN 1 ELSE 0 END) as churned
    FROM customer_seasons
    WHERE first_purchase <= DATE('2011-06-10')  -- Enough time to observe behavior
    GROUP BY acquisition_season
)

SELECT 
    acquisition_season,
    customers,
    ROUND(avg_orders, 2) as avg_orders,
    churned,
    ROUND(100.0 * churned / customers, 2) as churn_rate_pct
FROM seasonal_churn
ORDER BY 
    CASE acquisition_season
        WHEN 'Winter' THEN 1
        WHEN 'Spring' THEN 2
        WHEN 'Summer' THEN 3
        ELSE 4
    END;


-- ============================================================================
-- 6. TIME-TO-SECOND-PURCHASE ANALYSIS
-- ============================================================================
-- Critical metric: How quickly do customers make a second purchase?

WITH customer_purchases AS (
    SELECT 
        "Customer ID" as customer_id,
        InvoiceDate,
        Invoice,
        ROW_NUMBER() OVER (PARTITION BY "Customer ID" ORDER BY InvoiceDate, Invoice) as purchase_rank
    FROM transactions_clean
    GROUP BY "Customer ID", InvoiceDate, Invoice
),

first_two_purchases AS (
    SELECT 
        customer_id,
        MAX(CASE WHEN purchase_rank = 1 THEN InvoiceDate END) as first_purchase,
        MAX(CASE WHEN purchase_rank = 2 THEN InvoiceDate END) as second_purchase
    FROM customer_purchases
    WHERE purchase_rank <= 2
    GROUP BY customer_id
),

time_to_second AS (
    SELECT 
        customer_id,
        first_purchase,
        second_purchase,
        CASE 
            WHEN second_purchase IS NULL THEN 'No second purchase'
            WHEN JULIANDAY(second_purchase) - JULIANDAY(first_purchase) <= 7 THEN '0-7 days'
            WHEN JULIANDAY(second_purchase) - JULIANDAY(first_purchase) <= 14 THEN '8-14 days'
            WHEN JULIANDAY(second_purchase) - JULIANDAY(first_purchase) <= 30 THEN '15-30 days'
            WHEN JULIANDAY(second_purchase) - JULIANDAY(first_purchase) <= 60 THEN '31-60 days'
            ELSE '60+ days'
        END as time_to_second_bucket
    FROM first_two_purchases
    WHERE first_purchase <= DATE('2011-06-10')
),

-- Get last purchase for churn status
customer_last AS (
    SELECT 
        "Customer ID" as customer_id,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    GROUP BY "Customer ID"
)

SELECT 
    tts.time_to_second_bucket,
    COUNT(*) as customers,
    SUM(CASE WHEN cl.last_purchase <= DATE('2011-08-10') THEN 1 ELSE 0 END) as churned,
    ROUND(100.0 * SUM(CASE WHEN cl.last_purchase <= DATE('2011-08-10') THEN 1 ELSE 0 END) / COUNT(*), 2) as churn_rate_pct
FROM time_to_second tts
JOIN customer_last cl ON tts.customer_id = cl.customer_id
GROUP BY tts.time_to_second_bucket
ORDER BY 
    CASE tts.time_to_second_bucket
        WHEN '0-7 days' THEN 1
        WHEN '8-14 days' THEN 2
        WHEN '15-30 days' THEN 3
        WHEN '31-60 days' THEN 4
        WHEN '60+ days' THEN 5
        ELSE 6
    END;
