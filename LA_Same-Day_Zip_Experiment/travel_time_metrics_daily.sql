SELECT
    visit_date
    ,zone
    , MAX(visit_travel_time) AS max_vtt
    , AVG(visit_travel_time) AS avg_vtt
    , stddev_samp(visit_travel_time)  AS std_vtt
    , MAX(pickup_travel_time) AS max_ptt
    , AVG(pickup_travel_time) AS avg_ptt
    , stddev_samp(pickup_travel_time) AS std_ptt
    , MAX(pickup_travel_time_per_visit) AS max_pttpv
    , AVG(pickup_travel_time_per_visit) AS avg_pttpv
    , stddev_samp(pickup_travel_time_per_visit) AS std_pttpv
    , MAX(total_travel_time) AS max_ttt
    , AVG(total_travel_time) AS avg_ttt
    , stddev_samp(total_travel_time) AS std_ttt
FROM (
    SELECT
        total_travel_times.visit_id
        , total_travel_times.visit_date
        , total_travel_times.market
        , total_travel_times.zone
        , total_travel_times.pickup_travel_time
        , total_travel_times.visit_travel_time
        , total_travel_times.pickup_travel_time_per_visit
        , MIN(total_travel_time) AS total_travel_time
    FROM (
        SELECT
            complete_visit_times.visit_id
            , visit_duration AS visit_travel_time
            , pickup_duration AS pickup_travel_time
            , complete_visit_times.pickup_travel_time_per_visit
            , complete_visit_times.visit_duration + complete_visit_times.pickup_travel_time_per_visit AS total_travel_time
            , DATE(convert_to_local(complete_visit_times.visit_date, ec.id)) AS visit_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , complete_visit_times.zone
        FROM (
            SELECT
                visit_durations.visit_id
                , visit_durations.inventory_transfer_id
                , visit_durations.visit_duration
                , visit_fractions.pickup_duration
                , visit_fractions.pickup_travel_time_per_visit
                , visit_durations.expert_id
                , visit_durations.visit_date
                , visit_durations.zone
            FROM (
                SELECT
                    visit_times.visit_id
                    , visit_times.inventory_transfer_id
                    , (EXTRACT(EPOCH FROM visit_times.end_time) - EXTRACT(EPOCH FROM visit_times.start_time))/60 AS visit_duration
                    , visit_times.expert_id
                    , visit_times.visit_date
                    , visit_times.zone
                FROM (
                    SELECT
                        vis.id AS visit_id
                        , it.id AS inventory_transfer_id
                        , cb.start_time
                        , cb.end_time
                        , vis.expert_id
                        , DATE(cb.start_time) AS visit_date
                        , zones.zone
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
                    INNER JOIN d3.d_address AS ad
                    ON vis.meeting_address_id = ad.address_id
                    INNER JOIN d3_staging.la_zips_ab AS zones
                    ON ad.zip = zones.zip
                    AND cb.event_type = 'TravelTime'
                    AND cb.enabled = 'true'
                ) AS visit_times
            ) AS visit_durations
            INNER JOIN (
                SELECT
                    pickup_durations.inventory_transfer_id
                    , pickup_durations.pickup_duration
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
        INNER JOIN d3.d_address AS ad
        ON ad.address_id = ec.address_id
    ) AS total_travel_times
    WHERE market = '4-LA'
    GROUP BY
        total_travel_times.visit_id
        , total_travel_times.visit_date
        , total_travel_times.market
        , total_travel_times.zone
        , total_travel_times.pickup_travel_time
        , total_travel_times.visit_travel_time
        , total_travel_times.pickup_travel_time_per_visit
) AS travel_times
WHERE visit_date > DATE('2016-09-25')
-- ZONE TESTING BEGAN ON DATE('2016-11-10')
GROUP BY zone, visit_date
ORDER BY zone, visit_date
