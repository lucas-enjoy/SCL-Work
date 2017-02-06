/* Reschedule Rate */

-- NOTE: fraction of orders that have been rescheduled
-- (have canceled visits, and end on a complete or scheduled visit)

-- Of All Booked Orders, how many have been rescheduled

-- NOTE: We get quite different values depending on how we count

SELECT
    order_date
    , market
    , SUM(simple) AS n_simple
    , SUM(complex) AS n_complex
    , COUNT(*) AS n_orders
FROM (
    SELECT
        orders.order_id
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , order_created_date_local AS order_date
        , visits
        , CASE
            WHEN n_visits > 1
            THEN 1
            ELSE 0
          END
        AS simple
        , CASE
            WHEN 'canceled' = ANY(visits) -- at least one cancelation
            AND visits[n_visits] != 'canceled' -- ends WITH a non-canceled visit
            THEN 1
            ELSE 0
          END
        AS complex
        , n_visits - 1 AS n_reschedules
    FROM (
        SELECT
            order_id
            , ARRAY_AGG(visit_status ORDER BY visit_created_ts_local) AS visits
            , ARRAY_LENGTH(ARRAY_AGG(visit_status), 1) AS n_visits
        FROM d3.f_visit
        GROUP BY order_id
    ) AS vis
    INNER JOIN d3.f_order_master AS orders
    ON vis.order_id = orders.order_id
    INNER JOIN d3.d_expert AS ex
    ON orders.expert_id = ex.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS reschedules
WHERE order_date > DATE('2016-09-25')
GROUP BY order_date, market
ORDER BY order_date, market
LIMIT 10;

--

SELECT
    order_date
    , market
    , SUM(rescheduled) AS n_reschedules
    , COUNT(*) AS n_orders
FROM (
    SELECT
        orders.order_id
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , order_created_date_local AS order_date
        , visits
        , CASE
            WHEN n_visits > 1
            THEN 1
            ELSE 0
        END
        AS rescheduled
        , n_visits - 1 AS n_reschedules
    FROM (
        SELECT
            order_id
            , ARRAY_AGG(visit_status ORDER BY visit_created_ts_local) AS visits
            , ARRAY_LENGTH(ARRAY_AGG(visit_status), 1) AS n_visits
        FROM d3.f_visit
        GROUP BY order_id
    ) AS vis
    INNER JOIN d3.f_order_master AS orders
    ON vis.order_id = orders.order_id
    INNER JOIN d3.d_expert AS ex
    ON orders.expert_id = ex.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS reschedules
WHERE order_date > DATE('2016-09-25')
GROUP BY order_date, market
ORDER BY order_date, market
LIMIT 10;

-- Of All Booked Orders, how many times is an order rescheduled

SELECT
    order_date
    , market
    , AVG(CASE rescheduled WHEN 1 THEN n_reschedules ELSE NULL END) AS avg_number_of_reschedules
FROM (
    SELECT
        orders.order_id
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , order_created_date_local AS order_date
        , visits
        , CASE
            WHEN n_visits > 1
            THEN 1
            ELSE 0
        END
        AS rescheduled
        , n_visits - 1 AS n_reschedules
    FROM (
        SELECT
            order_id
            , ARRAY_AGG(visit_status ORDER BY visit_created_ts_local) AS visits
            , ARRAY_LENGTH(ARRAY_AGG(visit_status), 1) AS n_visits
        FROM d3.f_visit
        GROUP BY order_id
    ) AS vis
    INNER JOIN d3.f_order_master AS orders
    ON vis.order_id = orders.order_id
    INNER JOIN d3.d_expert AS ex
    ON orders.expert_id = ex.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS reschedules
WHERE order_date > DATE('2016-09-25')
GROUP BY order_date, market
ORDER BY order_date, market
LIMIT 10;

-- Breakdown by Customer/Employee reschedules

SELECT
    order_date
    , market
    , AVG(percent_employee) AS emp
    , AVG(percent_customer) AS cust
    , AVG(percent_unknown) AS unk
FROM (
    SELECT
        order_id
        , order_date
        , market
        , (visit_employee / total_visits) AS percent_employee
        , (visit_customer / total_visits) AS percent_customer
        , (visit_unknown / total_visits) AS percent_unknown
    FROM (
        SELECT
            order_id
            , order_date
            , market
            , SUM(CASE created_by WHEN 'Employee' THEN 1 ELSE 0 END) AS visit_employee
            , SUM(CASE created_by WHEN 'Customer' THEN 1 ELSE 0 END) AS visit_customer
            , SUM(CASE created_by WHEN 'Unknown' THEN 1 ELSE 0 END) AS visit_unknown
            , COUNT(*)::FLOAT AS total_visits
        FROM (
            SELECT
                orders.order_id
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , order_created_date_local AS order_date
                , created_by
            FROM (
                SELECT
                    order_id
                    , COALESCE(created_by_type, 'Unknown') AS created_by
                FROM prod_tables.snp_visits
            ) AS vis
            INNER JOIN d3.f_order_master AS orders
            ON vis.order_id = orders.order_id
            INNER JOIN d3.d_expert AS ex
            ON orders.expert_id = ex.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
        ) AS visits
        WHERE order_date > DATE('2016-09-25')
        GROUP BY order_id, order_date, market
    ) AS orders
    WHERE total_visits > 1 -- definition of reschedules
) AS breakdown
GROUP BY order_date, market
ORDER BY order_date, market
LIMIT 10;

-- Combined
-- Rescheduled Orders, AVG n_reschedules, n_emp, n_cust, n_unkn
SELECT
    order_date
    , market
    , SUM(rescheduled) AS n_rescheduled_orders
    , AS avg_reschedules_per_order
    ,
FROM (
    SELECT
        order_id
        , order_date
        , market
        , SUM(CASE created_by WHEN 'Employee' THEN 1 ELSE 0 END) AS visit_employee
        , SUM(CASE created_by WHEN 'Customer' THEN 1 ELSE 0 END) AS visit_customer
        , SUM(CASE created_by WHEN 'Unknown' THEN 1 ELSE 0 END) AS visit_unknown
        , COUNT(visit_status) AS n_visits
        , CASE WHEN COUNT(visit_status) > 1 THEN 1 ELSE 0 END
        AS rescheduled
    FROM (
        SELECT
            orders.order_id
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , order_created_date_local AS order_date
            , COALESCE(created_by_type, 'Unknown') AS created_by
            , status AS visit_status
            , order_status
            , visit_created_date_local
            , DATE(convert_to_local(canceled_ts_utc, ec.id)) AS visit_canceled_date_local
        FROM prod_tables.snp_visits AS vis
        INNER JOIN d3.f_order_master AS orders
        ON vis.order_id = orders.order_id
        INNER JOIN d3.d_expert AS ex
        ON orders.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE order_created_date_local > DATE('2016-09-25')
    ) AS order_visits
    WHERE order_date > DATE('2016-09-25')
    GROUP BY order_id, order_date, market
) AS order_reschedules
GROUP BY order_date, market
ORDER BY order_date, market
LIMIT 10;

--
SELECT
    order_date
    , market
    , SUM(n_rescheduled_visits) AS total_rescheduled_visits
    , SUM(n_same_day_rescheduled_visits) AS total_same_day_rescheduled_visits
    , SUM(n_employee_reschedules) AS total_employee_reschedules
    , SUM(n_customer_reschedules) AS total_customer_reschedules
    , SUM(n_unknown_reschedules) AS total_unknown_reschedules
    , SUM(has_rescheduled_visits) AS n_rescheduled_orders
FROM (
    SELECT
        order_id
        , order_date
        , market
        , COUNT(visit_status) AS n_rescheduled_visits
        , SUM(same_day_reschedule) AS n_same_day_rescheduled_visits
        , SUM(CASE created_by WHEN 'Employee' THEN 1 ELSE 0 END)
        AS n_employee_reschedules
        , SUM(CASE created_by WHEN 'Customer' THEN 1 ELSE 0 END)
        AS n_customer_reschedules
        , SUM(CASE created_by WHEN 'Unknown' THEN 1 ELSE 0 END) A
        S n_unknown_reschedules
        , CASE WHEN COUNT(visit_status) > 1 THEN 1 ELSE 0 END
        AS has_rescheduled_visits
    FROM (
        SELECT
            *,
            CASE
                WHEN order_status != 'canceled'
                AND visit_created_date_local = visit_canceled_date_local
                THEN 1
                ELSE 0
            END AS same_day_reschedule
        FROM (
            SELECT
                orders.order_id
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , order_created_date_local AS order_date
                , COALESCE(created_by_type, 'Unknown') AS created_by
                , status AS visit_status
                , order_status
                , visit_created_date_local
                , DATE(convert_to_local(canceled_ts_utc, ec.id)) AS visit_canceled_date_local
            FROM prod_tables.snp_visits AS vis
            INNER JOIN d3.f_order_master AS orders
            ON vis.order_id = orders.order_id
            INNER JOIN d3.d_expert AS ex
            ON orders.expert_id = ex.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            WHERE order_created_date_local > DATE('2016-09-25')
        ) AS order_visits
    ) AS order_visit_same_days
    GROUP BY order_id, order_date, market
) AS order_visit_reschedules
GROUP BY order_date, market
LIMIT 10;
