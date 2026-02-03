-- ============================================================================
-- CHURN RATE ANALYSIS
-- Big-Tech-Grade User Retention & Churn Prediction System
-- ============================================================================
-- Purpose: Calculate overall and segmented churn rates
-- Definition: Churn = No purchase activity for 60+ consecutive days
-- ============================================================================

-- Note: These queries are designed to be executed against a SQL database
-- or translated to pandas using pandasql. Column names match the cleaned dataset.

-- ============================================================================
-- 1. OVERALL CHURN RATE
-- ============================================================================

-- Calculate churn rate based on 60-day inactivity window
-- Using observation date cutoff to avoid right-censoring

WITH customer_last_purchase AS (
    SELECT 
        "Customer ID" as customer_id,
        MAX(InvoiceDate) as last_purchase_date,
        MIN(InvoiceDate) as first_purchase_date,
        COUNT(DISTINCT Invoice) as total_orders
    FROM transactions_clean
    GROUP BY "Customer ID"
),

churn_labels AS (
    SELECT 
        customer_id,
        last_purchase_date,
        first_purchase_date,
        total_orders,
        -- Observation date: 60 days before data end to allow lookforward
        DATE('2011-12-09') as observation_date,
        -- Churn if last purchase was more than 60 days before observation end
        CASE 
            WHEN last_purchase_date <= DATE('2011-10-10') THEN 1  -- 60 days before Dec 9
            ELSE 0 
        END as is_churned
    FROM customer_last_purchase
    WHERE first_purchase_date <= DATE('2011-10-10')  -- Customer must exist before observation
)

SELECT 
    COUNT(*) as total_customers,
    SUM(is_churned) as churned_customers,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) as churn_rate_pct,
    AVG(total_orders) as avg_orders_per_customer
FROM churn_labels;


-- ============================================================================
-- 2. CHURN RATE BY CUSTOMER TENURE
-- ============================================================================

WITH customer_tenure AS (
    SELECT 
        "Customer ID" as customer_id,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase,
        JULIANDAY(MAX(InvoiceDate)) - JULIANDAY(MIN(InvoiceDate)) as tenure_days
    FROM transactions_clean
    GROUP BY "Customer ID"
),

tenure_buckets AS (
    SELECT 
        customer_id,
        tenure_days,
        CASE 
            WHEN tenure_days <= 30 THEN '0-30 days'
            WHEN tenure_days <= 90 THEN '31-90 days'
            WHEN tenure_days <= 180 THEN '91-180 days'
            WHEN tenure_days <= 365 THEN '181-365 days'
            ELSE '365+ days'
        END as tenure_bucket,
        CASE 
            WHEN last_purchase <= DATE('2011-10-10') THEN 1 
            ELSE 0 
        END as is_churned
    FROM customer_tenure
    WHERE first_purchase <= DATE('2011-10-10')
)

SELECT 
    tenure_bucket,
    COUNT(*) as customers,
    SUM(is_churned) as churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) as churn_rate_pct
FROM tenure_buckets
GROUP BY tenure_bucket
ORDER BY 
    CASE tenure_bucket
        WHEN '0-30 days' THEN 1
        WHEN '31-90 days' THEN 2
        WHEN '91-180 days' THEN 3
        WHEN '181-365 days' THEN 4
        ELSE 5
    END;


-- ============================================================================
-- 3. CHURN RATE BY PURCHASE FREQUENCY
-- ============================================================================

WITH customer_frequency AS (
    SELECT 
        "Customer ID" as customer_id,
        COUNT(DISTINCT Invoice) as order_count,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    GROUP BY "Customer ID"
),

frequency_buckets AS (
    SELECT 
        customer_id,
        order_count,
        CASE 
            WHEN order_count = 1 THEN '1 order'
            WHEN order_count <= 3 THEN '2-3 orders'
            WHEN order_count <= 5 THEN '4-5 orders'
            WHEN order_count <= 10 THEN '6-10 orders'
            ELSE '10+ orders'
        END as frequency_bucket,
        CASE 
            WHEN last_purchase <= DATE('2011-10-10') THEN 1 
            ELSE 0 
        END as is_churned
    FROM customer_frequency
    WHERE first_purchase <= DATE('2011-10-10')
)

SELECT 
    frequency_bucket,
    COUNT(*) as customers,
    SUM(is_churned) as churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) as churn_rate_pct,
    ROUND(AVG(order_count), 2) as avg_orders
FROM frequency_buckets
GROUP BY frequency_bucket
ORDER BY 
    CASE frequency_bucket
        WHEN '1 order' THEN 1
        WHEN '2-3 orders' THEN 2
        WHEN '4-5 orders' THEN 3
        WHEN '6-10 orders' THEN 4
        ELSE 5
    END;


-- ============================================================================
-- 4. CHURN RATE BY MONETARY VALUE (RFM MONETARY)
-- ============================================================================

WITH customer_monetary AS (
    SELECT 
        "Customer ID" as customer_id,
        SUM(Quantity * Price) as total_revenue,
        AVG(Quantity * Price) as avg_order_value,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    GROUP BY "Customer ID"
),

monetary_percentiles AS (
    SELECT 
        customer_id,
        total_revenue,
        NTILE(5) OVER (ORDER BY total_revenue) as monetary_quintile,
        CASE 
            WHEN last_purchase <= DATE('2011-10-10') THEN 1 
            ELSE 0 
        END as is_churned
    FROM customer_monetary
    WHERE first_purchase <= DATE('2011-10-10')
)

SELECT 
    'Q' || monetary_quintile as monetary_segment,
    COUNT(*) as customers,
    SUM(is_churned) as churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) as churn_rate_pct,
    ROUND(AVG(total_revenue), 2) as avg_revenue
FROM monetary_percentiles
GROUP BY monetary_quintile
ORDER BY monetary_quintile;


-- ============================================================================
-- 5. CHURN RATE BY COUNTRY
-- ============================================================================

WITH customer_country AS (
    SELECT 
        "Customer ID" as customer_id,
        Country,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    GROUP BY "Customer ID", Country
),

country_churn AS (
    SELECT 
        Country,
        COUNT(*) as customers,
        SUM(CASE WHEN last_purchase <= DATE('2011-10-10') THEN 1 ELSE 0 END) as churned
    FROM customer_country
    WHERE first_purchase <= DATE('2011-10-10')
    GROUP BY Country
    HAVING COUNT(*) >= 50  -- Only countries with significant sample
)

SELECT 
    Country,
    customers,
    churned,
    ROUND(100.0 * churned / customers, 2) as churn_rate_pct
FROM country_churn
ORDER BY churn_rate_pct DESC;
