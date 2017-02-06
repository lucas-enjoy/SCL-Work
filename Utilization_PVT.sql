-- Utilization PVT (Visits + Pickups + Travel Time)

SELECT
    shift_date
    , market
    , SUM(pvt) AS total_pvt
    , SUM(shift_mins) AS total_shift_time
    -- , SUM(pvt) / SUM(shift_mins) * 100.0 AS utilization_percent
FROM (
    SELECT
        shift_id
        , shift_date
        , market
        , shift_mins
        , SUM(event_mins) AS pvt
    FROM (
        SELECT
            sh.id AS shift_id
            , DATE(sh.start_time) AS shift_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , EXTRACT(EPOCH FROM (sh.end_time - sh.start_time) )/60.0 AS shift_mins
            , EXTRACT(EPOCH FROM (cb.end_time - cb.start_time) )/60.0 AS event_mins
        FROM prod_tables.snp_shifts AS sh
        INNER JOIN prod_tables.snp_scheduled_blocks AS sb
        ON sh.id = sb.shift_id
        INNER JOIN prod_tables.snp_calendar_blocks AS cb
        ON cb.id = sb.calendar_block_id
        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = sb.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE sh.enabled
        AND cb.enabled
        AND cb.event_type IN ('InventoryTransfer', 'TravelTime', 'Visit') -- IE: PVT
    ) AS shift_events
    GROUP BY shift_id, shift_date, market, shift_mins
) AS shift_breakdown
WHERE shift_date BETWEEN DATE('2016-08-01') AND DATE(CURRENT_TIMESTAMP)
GROUP BY shift_date, market
-- ORDER BY shift_date DESC, market
