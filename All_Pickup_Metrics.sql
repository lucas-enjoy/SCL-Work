-- Including All Metrics of Relevance

--NOTE: View any column names with:

SELECT column_name
FROM information_schema.columns
WHERE table_schema = '' -- ex. d3
AND table_name = '' -- ex. f_order_master

/* Pickups/Expert (PED) */

SELECT
    exp_pickups.event_date
    , exp_pickups.market
    , AVG(exp_pickups.n_pickups) AS "PED"
FROM (
    SELECT
        pickup_markets.event_date
        , pickup_markets.market
        , pickup_markets.expert_id
        , COUNT(*) AS n_pickups
    FROM (
        SELECT
            pickups.event_date
            , CONCAT_WS('-', pickups.id, pickups.market) AS market
            , pickups.expert_id
            , pickups.event_id
        FROM (
            SELECT
                sb.expert_id
                , cb.event_id
                , ec.id
                , ec.market
                , DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
            FROM prod_tables.snp_calendar_blocks AS cb
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            WHERE cb.event_type = 'InventoryTransfer'
            AND cb.enabled = 'true'
        ) AS pickups
        WHERE pickups.event_date > DATE('2016-09-25')
    ) AS pickup_markets
    GROUP BY pickup_markets.event_date, pickup_markets.market, pickup_markets.expert_id
) AS exp_pickups
GROUP BY exp_pickups.event_date, exp_pickups.market
ORDER BY exp_pickups.event_date, exp_pickups.market;

-- Experimenting // Sanity Check

WITH experts_pickups
AS (
    SELECT
        event_date
        , market
        , COUNT(DISTINCT(expert_id)) AS n_experts
    FROM (
        SELECT
            -- it.id
            DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , it.expert_id
        FROM prod_tables.snp_inventory_transfers AS it
        INNER JOIN prod_tables.snp_calendar_blocks AS cb
        ON it.id = cb.event_id
        INNER JOIN prod_tables.snp_scheduled_blocks AS sb
        ON cb.id = sb.calendar_block_id
        INNER JOIN d3.d_expert AS ex
        ON sb.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE cb.event_type = 'InventoryTransfer'
        AND cb.enabled = 'true'
    ) AS pickups
    WHERE event_date > DATE('2016-09-25')
    GROUP BY event_date, market
    ORDER BY event_date, market
),
pickups AS (
    SELECT
        event_date
        , market
        , COUNT(id) AS n_pickups
    FROM (
        SELECT
            it.id
            ,DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
        FROM prod_tables.snp_inventory_transfers AS it
        INNER JOIN prod_tables.snp_calendar_blocks AS cb
        ON it.id = cb.event_id
        INNER JOIN prod_tables.snp_scheduled_blocks AS sb
        ON cb.id = sb.calendar_block_id
        INNER JOIN d3.d_expert AS ex
        ON sb.expert_id = ex.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE cb.event_type = 'InventoryTransfer'
        AND cb.enabled = 'true'
    ) AS pickups
    WHERE event_date > DATE('2016-09-25')
    GROUP BY event_date, market
    ORDER BY event_date, market
),
ped AS (
    SELECT
        exp_pickups.event_date
        , exp_pickups.market
        , AVG(exp_pickups.n_pickups) AS ped
    FROM (
        SELECT
            pickup_markets.event_date
            , pickup_markets.market
            , pickup_markets.expert_id
            , COUNT(*) AS n_pickups
        FROM (
            SELECT
                pickups.event_date
                , CONCAT_WS('-', pickups.id, pickups.market) AS market
                , pickups.expert_id
                , pickups.event_id
            FROM (
                SELECT
                    sb.expert_id
                    , cb.event_id
                    , ec.id
                    , ec.market
                    , DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
                FROM prod_tables.snp_calendar_blocks AS cb
                INNER JOIN prod_tables.snp_scheduled_blocks AS sb
                ON cb.id = sb.calendar_block_id
                INNER JOIN d3.d_expert AS ex
                ON ex.expert_id = sb.expert_id
                INNER JOIN prod_tables.snp_enjoyment_centers AS ec
                ON ex.current_enjoyment_house_id = ec.id
                WHERE cb.event_type = 'InventoryTransfer'
                AND cb.enabled = 'true'
            ) AS pickups
            WHERE pickups.event_date > DATE('2016-09-25')
        ) AS pickup_markets
        GROUP BY pickup_markets.event_date, pickup_markets.market, pickup_markets.expert_id
    ) AS exp_pickups
    GROUP BY exp_pickups.event_date, exp_pickups.market
    ORDER BY exp_pickups.event_date, exp_pickups.market
)
SELECT
    ped.event_date
    , ped.market
    , ep.n_experts
    , pick.n_pickups
    , ped.ped
    , pick.n_pickups / ep.n_experts::FLOAT AS div
FROM ped
INNER JOIN experts_pickups AS ep
ON ped.event_date = ep.event_date
AND ped.market = ep.market
INNER JOIN pickups AS pick
ON ped.event_date = pick.event_date
AND ped.market = pick.market
LIMIT 10;

/* Units/Pickup (UPP) */

SELECT
    units_per_pickup.event_date
    , units_per_pickup.market
    , AVG(units_per_pickup.n_units) AS units_per_pickup
    , COUNT(units_per_pickup.n_units) AS pickups_per_day
FROM (
    SELECT
        DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , pickup_units.n_units
    FROM (
        SELECT
            it.id AS inventory_transfer_id
            , COUNT(itoi.id) AS n_units
        FROM prod_tables.snp_inventory_transfers  AS it
        LEFT JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
        ON it.id = itoi.inventory_transfer_id
        GROUP BY it.id
    ) AS pickup_units
    INNER JOIN prod_tables.snp_calendar_blocks AS cb
    ON pickup_units.inventory_transfer_id = cb.event_id
    INNER JOIN prod_tables.snp_scheduled_blocks AS sb
    ON cb.id = sb.calendar_block_id
    INNER JOIN d3.d_expert AS ex
    ON ex.expert_id = sb.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
    WHERE cb.event_type = 'InventoryTransfer'
    AND cb.enabled='true'
    ) AS units_per_pickup
WHERE units_per_pickup.event_date > DATE('2016-09-25')
GROUP BY units_per_pickup.event_date, units_per_pickup.market
ORDER BY units_per_pickup.event_date, units_per_pickup.market;

/* Travel Time to Pickup (TTP) */

SELECT
    pickup_travels.event_date
    , pickup_travels.market
    , AVG(duration) AS "TTP"
FROM (
    SELECT
        DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , (EXTRACT(EPOCH FROM cb.end_time) - EXTRACT(EPOCH FROM cb.start_time))/60 AS duration
    FROM prod_tables.snp_inventory_transfers AS its
    INNER JOIN prod_tables.snp_calendar_blocks AS cb
    ON its.travel_time_id = cb.event_id
    INNER JOIN prod_tables.snp_scheduled_blocks AS sb
    ON cb.id = sb.calendar_block_id
    AND cb.event_type = 'TravelTime' AND cb.enabled='true'
    INNER JOIN d3.d_expert AS ex
    ON ex.expert_id = sb.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS pickup_travels
WHERE pickup_travels.event_date > DATE('2016-09-25')
GROUP BY pickup_travels.event_date, pickup_travels.market
ORDER BY pickup_travels.event_date, pickup_travels.market;

/* Duration of Pickup (PD) */

SELECT
    pickups.event_date
    , pickups.market
    , AVG(pickups.duration) AS pickup_duration
FROM (
    SELECT
        DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
        , CONCAT_WS('-', ec.id, ec.market) AS market
        , (EXTRACT(EPOCH FROM cb.end_time) - EXTRACT(EPOCH FROM cb.start_time))/60 AS duration
    FROM prod_tables.snp_calendar_blocks AS cb
    INNER JOIN prod_tables.snp_scheduled_blocks AS sb
    ON cb.id = sb.calendar_block_id
    AND cb.event_type = 'InventoryTransfer'
    AND cb.enabled = 'true'
    INNER JOIN d3.d_expert AS ex
    ON ex.expert_id = sb.expert_id
    INNER JOIN prod_tables.snp_enjoyment_centers AS ec
    ON ex.current_enjoyment_house_id = ec.id
) AS pickups
WHERE pickups.event_date > DATE('2016-09-25')
GROUP BY pickups.event_date, pickups.market
ORDER BY pickups.event_date, pickups.market;

/* Total Travel Time */

SELECT
    final_total_travel_times.visit_date
    , final_total_travel_times.market
    , AVG(final_total_travel_times.total_travel_time)
FROM (
    SELECT
        total_travel_times.visit_id
        , total_travel_times.visit_date
        , total_travel_times.market
        , MIN(total_travel_time) AS total_travel_time -- removes duplicate rows
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
    GROUP BY total_travel_times.visit_id, total_travel_times.visit_date, total_travel_times.market
) AS final_total_travel_times
WHERE visit_date > DATE('2016-09-25')
GROUP BY final_total_travel_times.visit_date, final_total_travel_times.market
ORDER BY final_total_travel_times.visit_date, final_total_travel_times.market;

/* TravelTime Percent of Shift */

SELECT
    shift_date
    , market
    , AVG(travel_fraction) * 100
    AS average_shift_travel_percent --TO make a percentage
FROM (
    SELECT
        shift_id
        , shift_date
        , market
        , SUM(event_duration) / shift_duration AS travel_fraction
    FROM (
        SELECT
            sh.id AS shift_id
            , sh.start_time AS shift_start
            , sh.end_time AS shift_end
            , EXTRACT(EPOCH FROM (sh.end_time - sh.start_time))/60 AS shift_duration
            , cb.start_time AS event_start
            , cb.end_time AS event_end
            , EXTRACT(EPOCH FROM (cb.end_time - cb.start_time))/60 AS event_duration
            , cb.event_type
            , DATE(convert_to_local(sh.start_time, ec.id)) AS shift_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
        FROM prod.snp_shifts AS sh
        INNER JOIN prod.snp_scheduled_blocks AS sb
        ON sh.id = sb.shift_id
        INNER JOIN prod.snp_calendar_blocks AS cb
        ON sb.calendar_block_id = cb.id
        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = sb.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE sh.enabled = 'true'
        AND cb.enabled='true'
        AND cb.event_type = 'TravelTime'
    ) AS shift_times
    WHERE shift_date > DATE('2016-09-25')
    GROUP BY shift_id, shift_date, market, shift_duration
) AS shift_fractions
GROUP BY shift_date, market
ORDER BY shift_date, market;

/* Duration of Pickup per Item */

SELECT
    event_date
    , market
    , AVG(pickup_duration_per_unit) AS avg_pickup_duration_per_unit
FROM (
    SELECT
        event_date
        , market
        , duration/n_units AS pickup_duration_per_unit
    FROM (
        SELECT
            DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , pickup_units.n_units
            , (EXTRACT(EPOCH FROM cb.end_time) - EXTRACT(EPOCH FROM cb.start_time))/60 AS duration
        FROM (
            SELECT
                it.id AS inventory_transfer_id
                , COUNT(itoi.id) AS n_units
            FROM prod_tables.snp_inventory_transfers  AS it
            LEFT JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
            ON it.id = itoi.inventory_transfer_id
            GROUP BY it.id
        ) AS pickup_units

        INNER JOIN prod_tables.snp_calendar_blocks AS cb
        ON pickup_units.inventory_transfer_id = cb.event_id
        INNER JOIN prod_tables.snp_scheduled_blocks AS sb
        ON cb.id = sb.calendar_block_id

        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = sb.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE cb.event_type = 'InventoryTransfer'
        AND cb.enabled='true'
        AND pickup_units.n_units != 0 -- has to exist to avoid div_0 errors
    ) AS pickup_durations
WHERE event_date > DATE('2016-09-25')
) AS pickup_fractions
GROUP BY event_date, market
ORDER BY event_date, market;

/* Percent of Orders That Are Same Day (~26%) */

SELECT COUNT(*) / (SELECT COUNT(*) FROM d3.f_visit AS vis
                   INNER JOIN d3.f_order AS ord
                   ON vis.order_id = ord.order_id
                   WHERE order_status != 'canceled'
                   AND visit_status != 'canceled')
FROM d3.f_visit AS vis
INNER JOIN d3.f_order AS ord
ON vis.order_id = ord.order_id
WHERE ord.order_created_date_local = vis.visit_end_date_local
AND order_status != 'canceled'
AND visit_status != 'canceled';

/* Percent of Orders That Are Same Day By Date and Market */

SELECT
    delivery_date
    , market
    , n_same_day_deliveries / n_deliveries::FLOAT * 100
    AS percent_of_same_day_deliveries
FROM (
    SELECT
        delivery_date
        , same_day_deliveries.market
        , n_same_day_deliveries
        , n_deliveries
    FROM (
        SELECT
            visit_start_date_local AS same_day_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , COUNT(*) AS n_same_day_deliveries
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order AS ord
        ON vis.order_id = ord.order_id
        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = vis.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE ord.order_created_date_local = vis.visit_end_date_local -- definition of same day delivery
        AND order_status != 'canceled'
        AND visit_status != 'canceled'
        GROUP BY visit_start_date_local, CONCAT_WS('-', ec.id, ec.market)
    ) AS same_day_deliveries
    INNER JOIN (
        SELECT
            visit_start_date_local AS delivery_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , COUNT(*) AS n_deliveries
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order AS ord
        ON vis.order_id = ord.order_id
        INNER JOIN d3.d_expert AS ex
        ON ex.expert_id = vis.expert_id
        INNER JOIN prod_tables.snp_enjoyment_centers AS ec
        ON ex.current_enjoyment_house_id = ec.id
        WHERE order_status != 'canceled'
        AND visit_status != 'canceled'
        GROUP BY visit_start_date_local, CONCAT_WS('-', ec.id, ec.market)
    ) AS daily_deliveries
    ON same_day_deliveries.same_day_date = daily_deliveries.delivery_date
    AND same_day_deliveries.market = daily_deliveries.market
) AS daily_market_deliveries
WHERE delivery_date > DATE('2016-09-25')
ORDER BY delivery_date, market;

/* Breakdown of Zero vs. Single vs. Bulk Pickups */

SELECT
    classified_pickups.*
    , n_zero_pickups / total_pickups::FLOAT * 100 AS percent_zero_pickups
    , n_single_pickups / total_pickups::FLOAT * 100 AS percent_single_pickups
    , n_bulk_pickups / total_pickups::FLOAT * 100 AS percent_bulk_pickups
FROM (
    SELECT
        pickup_date
        , market
        , SUM(zero_pickups) AS n_zero_pickups
        , SUM(single_pickups) AS n_single_pickups
        , SUM(bulk_pickups) AS n_bulk_pickups
        , SUM(zero_pickups) + SUM(single_pickups) + SUM(bulk_pickups) AS total_pickups
    FROM (
        SELECT
            pickup_date
            , market
            , CASE WHEN n_units < 1 THEN 1 ELSE 0 END AS zero_pickups
            , CASE WHEN n_units = 1 THEN 1 ELSE 0 END AS single_pickups
            , CASE WHEN n_units > 1 THEN 1 ELSE 0 END AS bulk_pickups
        FROM (
            SELECT
                DATE(convert_to_local(cb.start_time, ec.id)) AS pickup_date
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , pickup_units.n_units
            FROM (
                SELECT
                    it.id AS inventory_transfer_id
                    , COUNT(itoi.id) AS n_units
                FROM prod_tables.snp_inventory_transfers  AS it
                LEFT JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
                ON it.id = itoi.inventory_transfer_id
                GROUP BY it.id
            ) AS pickup_units

            INNER JOIN prod_tables.snp_calendar_blocks AS cb
            ON pickup_units.inventory_transfer_id = cb.event_id
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id

            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            WHERE cb.event_type = 'InventoryTransfer'
            AND cb.enabled='true'
        ) AS daily_pickups
    ) AS cased_pickups
    WHERE pickup_date > DATE('2016-09-25')
    GROUP BY pickup_date, market
    ORDER BY pickup_date, market
) AS classified_pickups
LIMIT 10;

/* Visits per Pickup */

SELECT
    event_date
    , market
    , same_day_cancelations
    , total_visits
    , same_day_cancelations / total_visits::FLOAT AS percent_cancelations
FROM (
    SELECT
        event_date
        , market
        , SUM(CASE same_day_visits.visit_status WHEN 'canceled' THEN 1 ELSE 0 END)
        AS same_day_cancelations
        , COALESCE(COUNT(*), 1) AS total_visits
    FROM (
        SELECT
            CONCAT_WS('-', ec.id, ec.market) AS market
            , vis.visit_start_date_local AS event_date
            , vis.visit_id
            , vis.visit_status
        FROM d3.f_visit AS vis
        INNER JOIN d3.f_order AS ord
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
ORDER BY event_date, market;
