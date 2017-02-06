/* Pickups per Expert per Day (PED) */ -- XXX

SELECT
    event_date
    , market
    , AVG(n_pickups) AS "PED"
FROM (
    SELECT
        event_date
        , market
        , expert_id
        , COUNT(inventory_transfer_id) AS n_pickups
    FROM (
        SELECT
            MIN(id) AS inventory_transfer_id -- removes duplicates
            , event_date
            , market
            , expert_id
            , partner
        FROM (
            SELECT
                it.id
                , DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , sb.expert_id
                , CASE
                    WHEN om.partner_channel = 'Integration' AND om.partner_id = 1 THEN 'ATT.com (Cart)'
                    ELSE 'Other'
                END AS partner
            FROM d3.f_order_master AS om
            INNER JOIN prod_tables.snp_order_items AS oi
            ON om.order_id = oi.order_id
            INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
            ON oi.id = itoi.order_item_id
            INNER JOIN prod_tables.snp_inventory_transfers AS it
            ON it.id = itoi.inventory_transfer_id
            INNER JOIN prod_tables.snp_calendar_blocks AS cb
            ON it.id = cb.event_id
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            WHERE cb.event_type = 'InventoryTransfer'
            AND cb.enabled = 'true'
        ) AS partner_pickups
        WHERE partner = 'ATT.com (Cart)'
        AND event_date  > DATE('2016-09-25')
        GROUP BY event_date, market, expert_id, partner
    ) AS partner_daily_pickups
    GROUP BY event_date, market, expert_id
) AS pickups_by_day_market_expert
-- WHERE n_pickups > 1
GROUP BY event_date, market
ORDER BY event_date, market
LIMIT 10;

/* Units per Pickup */ -- XXX

SELECT *
FROM (
    SELECT
        event_date
        , market
        , AVG(n_units) AS units_per_pickup
    FROM (
        SELECT
            it_id
            , event_date
            , market
            , COUNT(itoi_id) AS n_units
        FROM (
            SELECT
                it.id AS it_id
                , DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , itoi.id AS itoi_id
                , CASE
                    WHEN om.partner_channel = 'Integration' AND om.partner_id = 1 THEN 'ATT.com (Cart)'
                    ELSE 'Other'
                END AS partner
            FROM d3.f_order_master AS om
            INNER JOIN prod_tables.snp_order_items AS oi
            ON om.order_id = oi.order_id
            INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
            ON oi.id = itoi.order_item_id
            INNER JOIN prod_tables.snp_inventory_transfers AS it
            ON it.id = itoi.inventory_transfer_id
            INNER JOIN prod_tables.snp_calendar_blocks AS cb
            ON it.id = cb.event_id
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            WHERE cb.event_type = 'InventoryTransfer'
            AND cb.enabled = 'true'
            AND order_status != 'canceled'
        ) AS inventory_transfers
        WHERE partner = 'ATT.com (Cart)'
        AND event_date > DATE('2016-09-25')
        GROUP BY it_id, event_date, market
    ) AS inv_trans_items
    GROUP BY event_date, market
    ORDER BY event_date, market
) AS _
LIMIT 10;

/* Broken Down into Components */

-- Combined

SELECT
    event_date
    , market
    , COUNT(DISTINCT(expert_id)) AS n_experts
    , COUNT(it_id) AS n_pickups
    , SUM(n_items) AS total_units
FROM (
    SELECT
        it_id
        , event_date
        , expert_id
        , market
        , COUNT(itoi_id) AS n_items
        FROM (
            SELECT
                itoi.id AS itoi_id
                , it.id AS it_id
                , DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
                , CONCAT_WS('-', ec.id, ec.market) AS market
                , sb.expert_id
                , CASE
                    WHEN om.partner_channel = 'Integration' AND om.partner_id = 1 THEN 'ATT.com (Cart)'
                    ELSE 'Other'
                END AS partner
            FROM d3.f_order_master AS om
            INNER JOIN prod_tables.snp_order_items AS oi
            ON om.order_id = oi.order_id
            INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
            ON oi.id = itoi.order_item_id
            INNER JOIN prod_tables.snp_inventory_transfers AS it
            ON it.id = itoi.inventory_transfer_id
            INNER JOIN prod_tables.snp_calendar_blocks AS cb
            ON it.id = cb.event_id
            INNER JOIN prod_tables.snp_scheduled_blocks AS sb
            ON cb.id = sb.calendar_block_id
            INNER JOIN d3.d_expert AS ex
            ON ex.expert_id = sb.expert_id
            INNER JOIN prod_tables.snp_enjoyment_centers AS ec
            ON ex.current_enjoyment_house_id = ec.id
            WHERE cb.event_type = 'InventoryTransfer'
            AND cb.enabled = 'true'
        ) AS partner_pickups
        WHERE partner = 'ATT.com (Cart)'
        AND event_date  > DATE('2016-09-25')
    GROUP BY it_id, expert_id, event_date, market
) AS unit_pickups
GROUP BY event_date, market
ORDER BY event_date, market;
