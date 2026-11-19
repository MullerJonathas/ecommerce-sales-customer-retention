-- 1. Faturamento mensal e ticket médio por categoria de produto
WITH sales_by_category AS (
    SELECT
        strftime('%Y-%m', o.order_purchase_timestamp) AS year_month,
        COALESCE(ct.product_category_name_english, p.product_category_name, 'unknown') AS category,
        oi.order_id,
        oi.price
    FROM order_items oi
    JOIN orders o
        ON oi.order_id = o.order_id
    JOIN products p
        ON oi.product_id = p.product_id
    LEFT JOIN category_translation ct
        ON p.product_category_name = ct.product_category_name
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp IS NOT NULL
)
SELECT
    year_month,
    category,
    COUNT(DISTINCT order_id) AS total_orders,
    ROUND(SUM(price), 2) AS total_revenue,
    ROUND(SUM(price) * 1.0 / COUNT(DISTINCT order_id), 2) AS avg_order_value_in_category,
    ROUND(AVG(price), 2) AS avg_item_price
FROM sales_by_category
GROUP BY year_month, category
ORDER BY year_month DESC, total_revenue DESC;


-- 2. Estados com maior tempo de entrega e maior taxa de cancelamento
WITH order_metrics AS (
    SELECT
        c.customer_state,
        o.order_id,
        o.order_status,
        CASE
            WHEN o.order_status = 'delivered'
             AND o.order_purchase_timestamp IS NOT NULL
             AND o.order_delivered_customer_date IS NOT NULL
            THEN julianday(o.order_delivered_customer_date) - julianday(o.order_purchase_timestamp)
        END AS delivery_days
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE c.customer_state IS NOT NULL
)
SELECT
    customer_state,
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) AS canceled_orders,
    ROUND(
        100.0 * SUM(CASE WHEN order_status = 'canceled' THEN 1 ELSE 0 END) / COUNT(*),
        2
    ) AS cancel_rate_pct,
    ROUND(AVG(delivery_days), 2) AS avg_delivery_days
FROM order_metrics
GROUP BY customer_state
ORDER BY avg_delivery_days DESC, cancel_rate_pct DESC;


-- 3. Porcentagem de clientes que compram mais de uma vez (taxa de retenção)
WITH customer_orders AS (
    SELECT
        c.customer_unique_id,
        COUNT(DISTINCT o.order_id) AS orders_count
    FROM orders o
    JOIN customers c
        ON o.customer_id = c.customer_id
    WHERE o.order_status != 'canceled'
    GROUP BY c.customer_unique_id
)
SELECT
    COUNT(*) AS total_unique_customers,
    SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) AS repeat_customers,
    ROUND(
        100.0 * SUM(CASE WHEN orders_count > 1 THEN 1 ELSE 0 END) * 1.0 / COUNT(*),
        2
    ) AS repeat_purchase_rate_pct
FROM customer_orders;


-- 4. Métodos de pagamento que geram maior valor médio de pedido
WITH order_payment_totals AS (
    SELECT
        op.payment_type,
        op.order_id,
        SUM(op.payment_value) AS order_payment_total
    FROM order_payments op
    JOIN orders o
        ON op.order_id = o.order_id
    WHERE o.order_status != 'canceled'
    GROUP BY op.payment_type, op.order_id
)
SELECT
    payment_type,
    COUNT(*) AS orders_count,
    ROUND(SUM(order_payment_total), 2) AS total_paid_value,
    ROUND(AVG(order_payment_total), 2) AS avg_order_value
FROM order_payment_totals
GROUP BY payment_type
ORDER BY avg_order_value DESC;