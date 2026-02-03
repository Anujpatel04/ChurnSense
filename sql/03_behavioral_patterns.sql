WITH customer_rfm AS (
    SELECT 
        "Customer ID" as customer_id,
        JULIANDAY(DATE('2011-10-10')) - JULIANDAY(MAX(InvoiceDate)) as recency_days,
        COUNT(DISTINCT Invoice) as frequency,
        SUM(Quantity * Price) as monetary,
        MIN(InvoiceDate) as first_purchase,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    WHERE InvoiceDate <= DATE('2011-10-10')
    GROUP BY "Customer ID"
),

rfm_scores AS (
    SELECT 
        customer_id,
        recency_days,
        frequency,
        monetary,
        CASE WHEN recency_days > 60 THEN 1 ELSE 0 END as is_churned,
        NTILE(5) OVER (ORDER BY recency_days DESC) as R_score,
        NTILE(5) OVER (ORDER BY frequency) as F_score,
        NTILE(5) OVER (ORDER BY monetary) as M_score
    FROM customer_rfm
    WHERE first_purchase <= DATE('2011-08-10')
)

SELECT 
    R_score,
    F_score,
    M_score,
    COUNT(*) as customers,
    SUM(is_churned) as churned,
    ROUND(100.0 * SUM(is_churned) / COUNT(*), 2) as churn_rate_pct
FROM rfm_scores
GROUP BY R_score, F_score, M_score
HAVING COUNT(*) >= 20
ORDER BY churn_rate_pct DESC
LIMIT 20;


WITH customer_purchase_times AS (
    SELECT 
        "Customer ID" as customer_id,
        AVG(CASE WHEN strftime('%w', InvoiceDate) IN ('0', '6') THEN 1 ELSE 0 END) as weekend_purchase_pct,
        AVG(CAST(strftime('%H', InvoiceDate) AS INTEGER)) as avg_purchase_hour,
        AVG(CASE WHEN CAST(strftime('%H', InvoiceDate) AS INTEGER) < 12 THEN 1 ELSE 0 END) as morning_purchase_pct,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    WHERE InvoiceDate <= DATE('2011-10-10')
    GROUP BY "Customer ID"
),

time_patterns AS (
    SELECT 
        customer_id,
        weekend_purchase_pct,
        avg_purchase_hour,
        morning_purchase_pct,
        CASE 
            WHEN last_purchase <= DATE('2011-08-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM customer_purchase_times
)

SELECT 
    status,
    COUNT(*) as customers,
    ROUND(AVG(weekend_purchase_pct) * 100, 2) as avg_weekend_pct,
    ROUND(AVG(avg_purchase_hour), 2) as avg_purchase_hour,
    ROUND(AVG(morning_purchase_pct) * 100, 2) as avg_morning_pct
FROM time_patterns
GROUP BY status;


WITH customer_baskets AS (
    SELECT 
        "Customer ID" as customer_id,
        Invoice,
        InvoiceDate,
        COUNT(DISTINCT StockCode) as unique_items,
        SUM(Quantity) as total_items,
        SUM(Quantity * Price) as basket_value
    FROM transactions_clean
    WHERE InvoiceDate <= DATE('2011-10-10')
    GROUP BY "Customer ID", Invoice, InvoiceDate
),

customer_basket_metrics AS (
    SELECT 
        customer_id,
        AVG(unique_items) as avg_unique_items,
        AVG(total_items) as avg_total_items,
        AVG(basket_value) as avg_basket_value,
        STDEV(basket_value) as basket_value_std,
        MAX(InvoiceDate) as last_purchase
    FROM customer_baskets
    GROUP BY customer_id
),

basket_churn AS (
    SELECT 
        CASE 
            WHEN last_purchase <= DATE('2011-08-10') THEN 'Churned'
            ELSE 'Active'
        END as status,
        avg_unique_items,
        avg_total_items,
        avg_basket_value,
        basket_value_std
    FROM customer_basket_metrics
)

SELECT 
    status,
    COUNT(*) as customers,
    ROUND(AVG(avg_unique_items), 2) as avg_unique_items_per_basket,
    ROUND(AVG(avg_total_items), 2) as avg_total_items_per_basket,
    ROUND(AVG(avg_basket_value), 2) as avg_basket_value,
    ROUND(AVG(basket_value_std), 2) as basket_value_consistency
FROM basket_churn
GROUP BY status;


WITH customer_seasonality AS (
    SELECT 
        "Customer ID" as customer_id,
        strftime('%m', InvoiceDate) as purchase_month,
        COUNT(DISTINCT Invoice) as monthly_orders,
        MAX(InvoiceDate) OVER (PARTITION BY "Customer ID") as last_purchase
    FROM transactions_clean
    WHERE InvoiceDate <= DATE('2011-10-10')
    GROUP BY "Customer ID", strftime('%m', InvoiceDate)
),

seasonal_patterns AS (
    SELECT 
        customer_id,
        SUM(CASE WHEN purchase_month IN ('10', '11', '12') THEN monthly_orders ELSE 0 END) * 1.0 / 
            SUM(monthly_orders) as q4_concentration,
        COUNT(DISTINCT purchase_month) as active_months,
        CASE 
            WHEN MAX(last_purchase) <= DATE('2011-08-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM customer_seasonality
    GROUP BY customer_id
)

SELECT 
    status,
    COUNT(*) as customers,
    ROUND(AVG(q4_concentration) * 100, 2) as avg_q4_concentration_pct,
    ROUND(AVG(active_months), 2) as avg_active_months
FROM seasonal_patterns
GROUP BY status;


WITH customer_returns AS (
    SELECT 
        "Customer ID" as customer_id,
        COUNT(CASE WHEN Quantity < 0 THEN 1 END) as return_transactions,
        COUNT(*) as total_transactions,
        MAX(InvoiceDate) as last_purchase
    FROM transactions_clean
    GROUP BY "Customer ID"
),

return_patterns AS (
    SELECT 
        customer_id,
        return_transactions,
        total_transactions,
        1.0 * return_transactions / NULLIF(total_transactions, 0) as return_rate,
        CASE 
            WHEN last_purchase <= DATE('2011-08-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM customer_returns
)

SELECT 
    status,
    COUNT(*) as customers,
    ROUND(AVG(return_rate) * 100, 2) as avg_return_rate_pct,
    SUM(CASE WHEN return_transactions > 0 THEN 1 ELSE 0 END) as customers_with_returns,
    ROUND(100.0 * SUM(CASE WHEN return_transactions > 0 THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_with_returns
FROM return_patterns
GROUP BY status;


WITH first_purchases AS (
    SELECT 
        "Customer ID" as customer_id,
        MIN(InvoiceDate) as first_purchase_date,
        MIN(Invoice) as first_invoice
    FROM transactions_clean
    GROUP BY "Customer ID"
),

first_order_details AS (
    SELECT 
        fp.customer_id,
        fp.first_purchase_date,
        COUNT(DISTINCT t.StockCode) as first_order_items,
        SUM(t.Quantity * t.Price) as first_order_value
    FROM first_purchases fp
    JOIN transactions_clean t 
        ON fp.customer_id = t."Customer ID" 
        AND fp.first_invoice = t.Invoice
    GROUP BY fp.customer_id, fp.first_purchase_date
),

first_order_churn AS (
    SELECT 
        fod.*,
        CASE 
            WHEN (
                SELECT MAX(InvoiceDate) 
                FROM transactions_clean t2 
                WHERE t2."Customer ID" = fod.customer_id
            ) <= DATE('2011-08-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM first_order_details fod
    WHERE first_purchase_date <= DATE('2011-08-10')
)

SELECT 
    status,
    COUNT(*) as customers,
    ROUND(AVG(first_order_items), 2) as avg_first_order_items,
    ROUND(AVG(first_order_value), 2) as avg_first_order_value,
    ROUND(MEDIAN(first_order_value), 2) as median_first_order_value
FROM first_order_churn
GROUP BY status;


WITH customer_timeline AS (
    SELECT 
        "Customer ID" as customer_id,
        InvoiceDate,
        Invoice,
        MIN(InvoiceDate) OVER (PARTITION BY "Customer ID") as first_purchase,
        MAX(InvoiceDate) OVER (PARTITION BY "Customer ID") as last_purchase
    FROM transactions_clean
    WHERE InvoiceDate <= DATE('2011-10-10')
),

velocity_periods AS (
    SELECT 
        customer_id,
        first_purchase,
        last_purchase,
        COUNT(DISTINCT CASE 
            WHEN JULIANDAY(InvoiceDate) - JULIANDAY(first_purchase) <= 90 
            THEN Invoice END) as orders_first_90_days,
        COUNT(DISTINCT CASE 
            WHEN JULIANDAY(InvoiceDate) - JULIANDAY(first_purchase) BETWEEN 91 AND 180 
            THEN Invoice END) as orders_next_90_days
    FROM customer_timeline
    GROUP BY customer_id, first_purchase, last_purchase
    HAVING JULIANDAY(last_purchase) - JULIANDAY(first_purchase) >= 180
),

velocity_churn AS (
    SELECT 
        customer_id,
        orders_first_90_days,
        orders_next_90_days,
        orders_next_90_days - orders_first_90_days as velocity_change,
        CASE 
            WHEN last_purchase <= DATE('2011-08-10') THEN 'Churned'
            ELSE 'Active'
        END as status
    FROM velocity_periods
)

SELECT 
    status,
    COUNT(*) as customers,
    ROUND(AVG(orders_first_90_days), 2) as avg_orders_first_90d,
    ROUND(AVG(orders_next_90_days), 2) as avg_orders_next_90d,
    ROUND(AVG(velocity_change), 2) as avg_velocity_change,
    SUM(CASE WHEN velocity_change < 0 THEN 1 ELSE 0 END) as declining_velocity_count,
    ROUND(100.0 * SUM(CASE WHEN velocity_change < 0 THEN 1 ELSE 0 END) / COUNT(*), 2) as pct_declining
FROM velocity_churn
GROUP BY status;
