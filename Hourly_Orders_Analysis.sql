-- Hourly Orders Analysis

/* Give us the running total percent of orders by hour of day */

SELECT order_hour, SUM(percent_of_orders) OVER (ROWS UNBOUNDED PRECEDING)
FROM(
    SELECT
        order_hour,
        (Count(*)/(SELECT COUNT(*) FROM d3.f_order)::FLOAT) * 100 AS percent_of_orders
    FROM (
        SELECT
            EXTRACT(HOUR FROM order_created_ts_local) AS order_hour
        FROM d3.f_order
    ) AS orders
    GROUP BY order_hour
    ORDER BY order_hour
) AS _

/* Of just the same-day deliveries */

SELECT order_hour, SUM(percent_of_orders) OVER (ROWS UNBOUNDED PRECEDING)
FROM (
    SELECT
        orders.order_hour,
        COUNT(*) / (SELECT COUNT(*)
             FROM d3.f_visit AS vis
             INNER JOIN d3.f_order AS ord
             ON vis.order_id = ord.order_id
             WHERE ord.order_created_date_local = vis.visit_end_date_local
             AND order_status != 'canceled')::FLOAT AS percent_of_orders

    FROM (
        SELECT
            EXTRACT(HOUR FROM order_created_ts_local) AS order_hour
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order AS ord
        ON vis.order_id = ord.order_id
        WHERE ord.order_created_date_local = vis.visit_start_date_local
        AND order_status != 'canceled'
    ) AS orders
    GROUP BY orders.order_hour
    ORDER BY orders.order_hour
) AS _

/* Broken Down by Market */

-- Histogram Style

SELECT
    order_hours.market
    , order_hour
    , COUNT(*) / total_orders.total_market_orders::FLOAT * 100 AS percent_of_orders
FROM (
    SELECT
        EXTRACT(HOUR FROM ord.order_created_ts_local) AS order_hour
        , CONCAT_WS('-', ec.id, ec.market) AS market
    FROM d3.f_visit AS vis
    INNER JOIN d3.f_order AS ord
    ON vis.order_id = ord.order_id
    INNER JOIN d3.d_expert AS ex
    ON ex.expert_id = vis.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
    WHERE ord.order_created_date_local = vis.visit_start_date_local
    AND order_status != 'canceled'
    AND visit_status != 'canceled'
) AS order_hours
INNER JOIN (
    SELECT
        CONCAT_WS('-', ec.id, ec.market) AS market
        , COUNT(*) AS total_market_orders
    FROM d3.f_visit AS vis
    INNER JOIN d3.f_order AS ord
    ON vis.order_id = ord.order_id
    INNER JOIN d3.d_expert AS ex
    ON ex.expert_id = vis.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
    WHERE ord.order_created_date_local = vis.visit_start_date_local
    AND order_status != 'canceled'
    AND visit_status != 'canceled'
    GROUP BY CONCAT_WS('-', ec.id, ec.market)
) AS total_orders
ON order_hours.market = total_orders.market
GROUP BY order_hours.market, order_hour, total_orders.total_market_orders
ORDER BY order_hours.market, order_hour;

-- AS A RUNNING SUM

SELECT
    market
    , order_hour
    , SUM(percent_of_orders) OVER (PARTITION BY market ORDER BY order_hour)
FROM (
    SELECT
        order_hours.market
        , order_hour
        , COUNT(*) / total_orders.total_market_orders::FLOAT * 100 AS percent_of_orders
    FROM (
        SELECT
            EXTRACT(HOUR FROM ord.order_created_ts_local) AS order_hour
            , CONCAT_WS('-', ec.id, ec.market) AS market
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order AS ord
        ON vis.order_id = ord.order_id
        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = vis.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE ord.order_created_date_local = vis.visit_start_date_local
        AND order_status != 'canceled'
        AND visit_status != 'canceled'
    ) AS order_hours
    INNER JOIN (
        SELECT
            CONCAT_WS('-', ec.id, ec.market) AS market
            , COUNT(*) AS total_market_orders
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order AS ord
        ON vis.order_id = ord.order_id
        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = vis.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE ord.order_created_date_local = vis.visit_start_date_local
        AND order_status != 'canceled'
        AND visit_status != 'canceled'
        GROUP BY CONCAT_WS('-', ec.id, ec.market)
    ) AS total_orders
    ON order_hours.market = total_orders.market
    GROUP BY order_hours.market, order_hour, total_orders.total_market_orders
    ORDER BY order_hours.market, order_hour
) AS _;
