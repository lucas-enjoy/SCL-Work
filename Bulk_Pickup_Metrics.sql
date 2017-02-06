-- Bulk Pickup Metrics

/* Pickup Item Histogram */

SELECT
    pickup_items.n_items
    , COUNT(*)
FROM (
    SELECT
        it.id
        , COUNT(itoi.id) AS n_items
    FROM prod_tables.snp_inventory_transfers  AS it
    LEFT JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
    ON it.id = itoi.inventory_transfer_id
    GROUP BY it.id
) AS pickup_items
GROUP BY pickup_items.n_items
ORDER BY pickup_items.n_items;

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

/* Visits associated with Bulk vs. Single Pickups */

SELECT *
FROM

--
