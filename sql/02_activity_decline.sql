WITH customer_timeline AS (
    SELECT 
        "Customer ID" as customer_id,
        InvoiceDate,
        Invoice,
        MAX(InvoiceDate) OVER (PARTITION BY "Customer ID") as last_purchase_date
    FROM transactions_clean
),

activity_windows AS (
    SELECT 
        customer_id,
        Invoice,
        InvoiceDate,
        last_purchase_date,
        JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) as days_before_last,
        CASE 
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 30 THEN 'Last 30 days'
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 60 THEN '31-60 days before'
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 90 THEN '61-90 days before'
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 120 THEN '91-120 days before'
            ELSE '120+ days before'
        END as time_window
    FROM customer_timeline
),

churned_customers AS (
    SELECT DISTINCT customer_id
    FROM activity_windows
    WHERE last_purchase_date <= DATE('2011-10-10')
)

SELECT 
    aw.time_window,
    COUNT(DISTINCT aw.customer_id) as unique_customers,
    COUNT(DISTINCT aw.Invoice) as total_orders,
    ROUND(1.0 * COUNT(DISTINCT aw.Invoice) / COUNT(DISTINCT aw.customer_id), 2) as orders_per_customer
FROM activity_windows aw
INNER JOIN churned_customers cc ON aw.customer_id = cc.customer_id
GROUP BY aw.time_window
ORDER BY 
    CASE aw.time_window
        WHEN '120+ days before' THEN 1
        WHEN '91-120 days before' THEN 2
        WHEN '61-90 days before' THEN 3
        WHEN '31-60 days before' THEN 4
        WHEN 'Last 30 days' THEN 5
    END;


WITH customer_revenue_timeline AS (
    SELECT 
        "Customer ID" as customer_id,
        InvoiceDate,
        SUM(Quantity * Price) as daily_revenue,
        MAX(InvoiceDate) OVER (PARTITION BY "Customer ID") as last_purchase_date
    FROM transactions_clean
    GROUP BY "Customer ID", InvoiceDate
),

revenue_windows AS (
    SELECT 
        customer_id,
        daily_revenue,
        CASE 
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 30 THEN 'Last 30 days'
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 60 THEN '31-60 days before'
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 90 THEN '61-90 days before'
            ELSE '90+ days before'
        END as time_window
    FROM customer_revenue_timeline
    WHERE last_purchase_date <= DATE('2011-10-10')
)

SELECT 
    time_window,
    COUNT(*) as purchase_days,
    ROUND(SUM(daily_revenue), 2) as total_revenue,
    ROUND(AVG(daily_revenue), 2) as avg_daily_revenue,
    ROUND(MEDIAN(daily_revenue), 2) as median_daily_revenue
FROM revenue_windows
GROUP BY time_window
ORDER BY 
    CASE time_window
        WHEN '90+ days before' THEN 1
        WHEN '61-90 days before' THEN 2
        WHEN '31-60 days before' THEN 3
        WHEN 'Last 30 days' THEN 4
    END;


WITH customer_orders AS (
    SELECT 
        "Customer ID" as customer_id,
        DATE(InvoiceDate) as order_date,
        ROW_NUMBER() OVER (PARTITION BY "Customer ID" ORDER BY InvoiceDate) as order_rank
    FROM transactions_clean
    GROUP BY "Customer ID", DATE(InvoiceDate)
),

purchase_gaps AS (
    SELECT 
        c1.customer_id,
        c1.order_date as current_order,
        c2.order_date as next_order,
        JULIANDAY(c2.order_date) - JULIANDAY(c1.order_date) as days_between_orders,
        c1.order_rank
    FROM customer_orders c1
    LEFT JOIN customer_orders c2 
        ON c1.customer_id = c2.customer_id 
        AND c1.order_rank = c2.order_rank - 1
    WHERE c2.order_date IS NOT NULL
),

customer_status AS (
    SELECT 
        "Customer ID" as customer_id,
        CASE 
            WHEN MAX(InvoiceDate) <= DATE('2011-10-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM transactions_clean
    GROUP BY "Customer ID"
)

SELECT 
    cs.status,
    ROUND(AVG(pg.days_between_orders), 2) as avg_days_between_orders,
    ROUND(MEDIAN(pg.days_between_orders), 2) as median_days_between_orders,
    MIN(pg.days_between_orders) as min_gap,
    MAX(pg.days_between_orders) as max_gap,
    COUNT(*) as total_gaps
FROM purchase_gaps pg
JOIN customer_status cs ON pg.customer_id = cs.customer_id
GROUP BY cs.status;


WITH customer_orders_ranked AS (
    SELECT 
        "Customer ID" as customer_id,
        Invoice,
        InvoiceDate,
        SUM(Quantity * Price) as order_value,
        ROW_NUMBER() OVER (PARTITION BY "Customer ID" ORDER BY InvoiceDate DESC) as recency_rank,
        COUNT(*) OVER (PARTITION BY "Customer ID") as total_orders
    FROM transactions_clean
    GROUP BY "Customer ID", Invoice, InvoiceDate
),

last_vs_historical AS (
    SELECT 
        customer_id,
        AVG(CASE WHEN recency_rank <= 3 THEN order_value END) as avg_last_3_orders,
        AVG(CASE WHEN recency_rank > 3 THEN order_value END) as avg_historical_orders,
        total_orders
    FROM customer_orders_ranked
    WHERE total_orders >= 6
    GROUP BY customer_id, total_orders
),

customer_churn_status AS (
    SELECT 
        "Customer ID" as customer_id,
        CASE 
            WHEN MAX(InvoiceDate) <= DATE('2011-10-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM transactions_clean
    GROUP BY "Customer ID"
)

SELECT 
    ccs.status,
    COUNT(*) as customers,
    ROUND(AVG(lvh.avg_last_3_orders), 2) as avg_last_3_orders,
    ROUND(AVG(lvh.avg_historical_orders), 2) as avg_historical_orders,
    ROUND(100.0 * (AVG(lvh.avg_last_3_orders) - AVG(lvh.avg_historical_orders)) / AVG(lvh.avg_historical_orders), 2) as pct_change
FROM last_vs_historical lvh
JOIN customer_churn_status ccs ON lvh.customer_id = ccs.customer_id
GROUP BY ccs.status;


WITH customer_products AS (
    SELECT 
        "Customer ID" as customer_id,
        StockCode,
        InvoiceDate,
        MAX(InvoiceDate) OVER (PARTITION BY "Customer ID") as last_purchase_date
    FROM transactions_clean
),

product_timing AS (
    SELECT 
        customer_id,
        StockCode,
        CASE 
            WHEN JULIANDAY(last_purchase_date) - JULIANDAY(InvoiceDate) <= 60 THEN 'Last 60 days'
            ELSE 'Historical'
        END as period
    FROM customer_products
    WHERE last_purchase_date <= DATE('2011-10-10')
),

product_diversity AS (
    SELECT 
        customer_id,
        period,
        COUNT(DISTINCT StockCode) as unique_products
    FROM product_timing
    GROUP BY customer_id, period
)

SELECT 
    period,
    COUNT(DISTINCT customer_id) as customers,
    ROUND(AVG(unique_products), 2) as avg_unique_products,
    ROUND(MEDIAN(unique_products), 2) as median_unique_products
FROM product_diversity
GROUP BY period;
