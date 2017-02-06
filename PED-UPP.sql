/* Calculate PED and UPP with these component measures */

SELECT
    event_date
    , market
    , COUNT(it_id) AS n_pickups
    , COUNT(DISTINCT(expert_id)) AS n_experts
    , SUM(n_units)::INT AS total_units
FROM (
    SELECT
        it_id
        , event_date
        , market
        , expert_id
        , COUNT(itoi_id) AS n_units
    FROM (
        SELECT
            itoi.id AS itoi_id
            , it.id AS it_id
            , DATE(convert_to_local(cb.start_time, ec.id)) AS event_date
            , CONCAT_WS('-', ec.id, ec.market) AS market
            , sb.expert_id
        FROM prod_tables.snp_inventory_transfers AS it
        INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
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
    ) AS inv_trans_items
    WHERE event_date  > DATE('2016-09-25')
    GROUP BY it_id, expert_id, event_date, market
) AS pickup_units
GROUP BY event_date, market
ORDER BY event_date, market;
