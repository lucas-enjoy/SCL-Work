-- Now breakdown by market
-- and compare each before/after

WITH pickup_travel_times
AS (
    SELECT
        pickup_date
        , market
        , AVG(pickup_duration) AS pickup_travel_time
        , AVG(pickup_travel_time_per_visit) AS pickup_travel_time_per_visit
    FROM (
        SELECT
            pickup_durations.inventory_transfer_id
            , pickup_date
            , market
            , pickup_duration
            , pickup_durations.pickup_duration / pickup_durations.n_visits
            AS pickup_travel_time_per_visit
        FROM (
            SELECT
                visits_per_pickup.inventory_transfer_id
                , visits_per_pickup.n_visits
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , (EXTRACT(EPOCH FROM cb.end_time) - EXTRACT(EPOCH FROM cb.start_time))/60
                AS pickup_duration
                , DATE(cb.start_time) AS pickup_date
            FROM (
                    SELECT
                        it.id AS inventory_transfer_id
                        , it.expert_id
                        , it.travel_time_id
                        , COUNT(vis.id) AS n_visits
                    FROM prod_tables.snp_inventory_transfers  AS it
                    INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
                    ON it.id = itoi.inventory_transfer_id
                    INNER JOIN prod_tables.snp_order_items AS oi
                    ON oi.id = itoi.order_item_id
                    INNER JOIN prod_tables.snp_visits AS vis
                    ON vis.order_id = oi.order_id
                    GROUP BY it.id, it.expert_id, it.travel_time_id
            ) AS visits_per_pickup
            INNER JOIN prod_tables.snp_calendar_blocks AS cb
            ON visits_per_pickup.travel_time_id = cb.event_id
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            AND cb.event_type = 'TravelTime'
            AND cb.enabled='true'
        ) AS pickup_durations
    ) AS _
    WHERE pickup_date > DATE('2016-09-25')
    GROUP BY pickup_date, market
),
visit_travel_times
AS (
    SELECT
        visit_date
        , market
        , AVG(visit_duration) AS visit_travel_time
    FROM (
        SELECT
            visit_times.visit_id
            , visit_times.inventory_transfer_id
            , (EXTRACT(EPOCH FROM visit_times.end_time) - EXTRACT(EPOCH FROM visit_times.start_time))/60 AS visit_duration
            , visit_times.expert_id
            , visit_times.visit_date
            , visit_times.market
        FROM (
            SELECT
                vis.id AS visit_id
                , it.id AS inventory_transfer_id
                , cb.start_time
                , cb.end_time
                , vis.expert_id
                , DATE(cb.start_time) AS visit_date
                , CONCAT_WS('-', ec.id, ec.market) AS market
            FROM prod_tables.snp_visits AS vis
            INNER JOIN prod_tables.snp_order_items AS oi
            ON vis.order_id = oi.order_id
            INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
            ON oi.id = itoi.order_item_id
            INNER JOIN prod_tables.snp_inventory_transfers  AS it
            ON it.id = itoi.inventory_transfer_id
            INNER JOIN prod_tables.snp_calendar_blocks AS cb
            ON vis.travel_time_id = cb.event_id
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            AND cb.event_type = 'TravelTime'
            AND cb.enabled = 'true'
        ) AS visit_times
    ) AS _
    WHERE visit_date > DATE('2016-09-25')
    GROUP BY visit_date, market
),
ttt
AS (
    SELECT
        final_total_travel_times.visit_date
        , final_total_travel_times.market
        , AVG(final_total_travel_times.total_travel_time) AS avg_total_travel_time
    FROM (
        SELECT
            total_travel_times.visit_id
            , total_travel_times.visit_date
            , total_travel_times.market
            , MIN(total_travel_time) AS total_travel_time
        FROM (
            SELECT
                complete_visit_times.visit_id
                , complete_visit_times.visit_duration + complete_visit_times.pickup_travel_time_per_visit AS total_travel_time
                , DATE(convert_to_local(complete_visit_times.visit_date, ec.id)) AS visit_date
                , CONCAT_WS('-', ec.id, ec.market) AS market
            FROM (
                SELECT
                    visit_durations.visit_id
                    , visit_durations.inventory_transfer_id
                    , visit_durations.visit_duration
                    , visit_fractions.pickup_travel_time_per_visit
                    , visit_durations.expert_id
                    , visit_durations.visit_date
                FROM (
                    SELECT
                        visit_times.visit_id
                        , visit_times.inventory_transfer_id
                        , (EXTRACT(EPOCH FROM visit_times.end_time) - EXTRACT(EPOCH FROM visit_times.start_time))/60 AS visit_duration
                        , visit_times.expert_id
                        , visit_times.visit_date
                    FROM (
                        SELECT
                            vis.id AS visit_id
                            , it.id AS inventory_transfer_id
                            , cb.start_time
                            , cb.end_time
                            , vis.expert_id
                            , DATE(cb.start_time) AS visit_date
                        FROM prod_tables.snp_visits AS vis
                        INNER JOIN prod_tables.snp_order_items AS oi
                        ON vis.order_id = oi.order_id
                        INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
                        ON oi.id = itoi.order_item_id
                        INNER JOIN prod_tables.snp_inventory_transfers  AS it
                        ON it.id = itoi.inventory_transfer_id
                        INNER JOIN prod_tables.snp_calendar_blocks AS cb
                        ON vis.travel_time_id = cb.event_id
                        INNER JOIN prod_tables.snp_scheduled_blocks AS sb
                        ON cb.id = sb.calendar_block_id
                        AND cb.event_type = 'TravelTime'
                        AND cb.enabled = 'true'
                    ) AS visit_times
                ) AS visit_durations
                INNER JOIN (
                    SELECT
                        pickup_durations.inventory_transfer_id
                        , pickup_durations.pickup_duration / pickup_durations.n_visits
                        AS pickup_travel_time_per_visit
                    FROM (
                        SELECT
                            visits_per_pickup.inventory_transfer_id
                            , visits_per_pickup.n_visits
                            , (EXTRACT(EPOCH FROM cb.end_time) - EXTRACT(EPOCH FROM cb.start_time))/60 AS pickup_duration
                        FROM (
                                SELECT
                                    it.id AS inventory_transfer_id
                                    , it.expert_id
                                    , it.travel_time_id
                                    , COUNT(vis.id) AS n_visits
                                FROM prod_tables.snp_inventory_transfers  AS it
                                INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
                                ON it.id = itoi.inventory_transfer_id
                                INNER JOIN prod_tables.snp_order_items AS oi
                                ON oi.id = itoi.order_item_id
                                INNER JOIN prod_tables.snp_visits AS vis
                                ON vis.order_id = oi.order_id
                                GROUP BY it.id, it.expert_id, it.travel_time_id
                        ) AS visits_per_pickup
                        INNER JOIN prod_tables.snp_calendar_blocks AS cb
                        ON visits_per_pickup.travel_time_id = cb.event_id
                        INNER JOIN prod_tables.snp_scheduled_blocks AS sb
                        ON cb.id = sb.calendar_block_id
                        AND cb.event_type = 'TravelTime'
                        AND cb.enabled='true'
                    ) AS pickup_durations
                ) AS visit_fractions
                ON visit_durations.inventory_transfer_id = visit_fractions.inventory_transfer_id
            ) AS complete_visit_times
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = complete_visit_times.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
        ) AS total_travel_times
        GROUP BY visit_id, visit_date, market
    ) AS final_total_travel_times
    WHERE visit_date > DATE('2016-09-25')
    GROUP BY visit_date, market
    ORDER BY visit_date, market
)
SELECT
    ttt.visit_date
    , ttt.market
    , visit_travel_time
    , pickup_travel_time
    , pickup_travel_time_per_visit
    , avg_total_travel_time
FROM ttt
INNER JOIN visit_travel_times AS vtt
ON ttt.visit_date = vtt.visit_date
AND ttt.market = vtt.market
INNER JOIN pickup_travel_times AS ptt
ON ttt.visit_date = ptt.pickup_date
AND ttt.market = ptt.market
ORDER BY visit_date, market
