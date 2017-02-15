SELECT
    order_canceled_hour
    , COUNT(order_id)::FLOAT /
    (SELECT
    COUNT(*)
    FROM d3.f_order_master
    WHERE order_status = 'canceled' ) * 100.0
FROM (
    SELECT
        order_id
        , EXTRACT(HOUR FROM canceled_ts_utc)::INT AS order_canceled_hour
    FROM d3.f_order_master
    WHERE order_status = 'canceled'
) AS _
GROUP BY order_canceled_hour
ORDER BY order_canceled_hour
