-- Cancellations

/* % of Same-Day Order Cancellations */ --XXX

SELECT
    order_created_date_local
    , market
    , COUNT(*)
FROM (
    SELECT
        order_created_date_local
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , order_status
        , DATE(convert_to_local(canceled_ts_utc, ec.id)) AS canceled_date
    FROM d3.f_order_master AS ord
    INNER JOIN d3.d_expert AS ex
    ON ord.expert_id = ex.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS order_data
WHERE order_created_date_local > DATE('2016-09-25')
AND order_created_date_local = canceled_date -- IE: Same-Day
GROUP BY order_created_date_local, market
ORDER BY order_created_date_local, market;

--

/* % of Same-Day Visit Cancellations */ -- XXX
-- NOTE: Assumption here is that visit_updated_ts ~= visit_canceled_ts

SELECT
    visit_created_date_local
    , market
    , SUM(CASE visit_status WHEN 'canceled' THEN 1 ELSE 0 END)
    AS n_same_day_canceled_visits
FROM (
    SELECT
        visit_created_date_local
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , visit_status
        , DATE(convert_to_local(visit_updated_ts_utc, ec.id)) AS visit_canceled_date
    FROM d3.f_visit AS vis
    INNER JOIN d3.d_expert AS ex
    ON vis.expert_id = ex.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS visit_data
WHERE visit_canceled_date = visit_created_date_local -- IE: Same Day
AND visit_created_date_local > DATE('2016-09-25')
GROUP BY visit_created_date_local, market
ORDER BY visit_created_date_local, market

/* % of Same-Day (Order-Visit) Cancellations */

SELECT
    event_date
    , market
    , same_day_cancelations / total_visits::FLOAT
FROM (
    SELECT
        event_date
        , market
        , SUM(CASE same_day_visits.visit_status WHEN 'canceled' THEN 1 ELSE 0 END)
        AS visit_order_cancellations
    FROM (
        SELECT
            CONCAT_WS('-', ec.id, ec.market) AS market
            , vis.visit_start_date_local AS event_date
            , vis.visit_id
            , vis.visit_status
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order_master AS ord
        ON vis.order_id = ord.order_id
        INNER JOIN d3.d_expert AS ex
        ON vis.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE ord.order_created_date_local = vis.visit_end_date_local -- Same-Day
    ) AS same_day_visits
    WHERE event_date > DATE('2016-09-25')
    GROUP BY event_date, market
) AS _
ORDER BY event_date, market
LIMIT 10;

-- All Together

WITH order_cancellations
AS (
    SELECT
        order_created_date_local
        , market
        , COUNT(*) AS cancelled_orders
    FROM (
        SELECT
            order_created_date_local
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , order_status
            , DATE(convert_to_local(canceled_ts_utc, ec.id)) AS canceled_date
        FROM d3.f_order_master AS ord
        INNER JOIN d3.d_expert AS ex
        ON ord.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
    ) AS order_data
    WHERE order_created_date_local > DATE('2016-09-25')
    AND order_created_date_local = canceled_date -- IE: Same Day
    GROUP BY order_created_date_local, market
),
visit_cancellations
AS (
    SELECT
        visit_created_date_local
        , market
        , SUM(CASE visit_status WHEN 'canceled' THEN 1 ELSE 0 END)
        AS canceled_visits
    FROM (
        SELECT
            visit_created_date_local
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , visit_status
            , DATE(convert_to_local(visit_updated_ts_utc, ec.id)) AS visit_canceled_date
        FROM d3.f_visit AS vis
        INNER JOIN d3.d_expert AS ex
        ON vis.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
    ) AS visit_data
    WHERE visit_canceled_date = visit_created_date_local -- IE: Same Day
    AND visit_created_date_local > DATE('2016-09-25')
    GROUP BY visit_created_date_local, market
),
visit_order_cancellations
AS (
    SELECT
        event_date
        , market
        , SUM(CASE same_day_visits.visit_status WHEN 'canceled' THEN 1 ELSE 0 END)
        AS visit_order_cancellations
    FROM (
        SELECT
            CONCAT_WS('-', ec.id, ec.market) AS market
            , vis.visit_start_date_local AS event_date
            , vis.visit_id
            , vis.visit_status
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order_master AS ord
        ON vis.order_id = ord.order_id
        INNER JOIN d3.d_expert AS ex
        ON vis.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE ord.order_created_date_local = vis.visit_end_date_local -- Same-Day
    ) AS same_day_visits
    WHERE event_date > DATE('2016-09-25')
    GROUP BY event_date, market
)

SELECT
    voc.event_date
    , voc.market
    , voc.visit_order_cancellations
    , vc.canceled_visits
    , oc.cancelled_orders
FROM visit_order_cancellations AS voc
INNER JOIN visit_cancellations AS vc
ON voc.event_date = vc.visit_created_date_local
AND voc.market = vc.market
INNER JOIN order_cancellations AS oc
ON voc.event_date = oc.order_created_date_local
AND voc.market = oc.market
ORDER BY voc.event_date, voc.market
LIMIT 10;
