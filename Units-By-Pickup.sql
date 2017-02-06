---
# Units / Pickup
---

-- NOTE: We're getting Nulls, from where we have an order that doesn't have SKUs for the items?

# ------------------------------------------------------

# BY EXPERT

SELECT CONCAT_WS(' ', exp.expert_first_name, exp.expert_last_name) AS expert, avg_pickups AS avg_units_per_pickups
FROM (
	SELECT exp_pickups.expert_id, ROUND(AVG(exp_pickups.n_items), 2) AS avg_pickups
	FROM (
		SELECT its.expert_id, order_transfers.inventory_transfer_id, SUM(order_transfers.num_items) AS n_items
		FROM (
			SELECT item_orders.order_id, item_orders.loc, item_orders.num_items, itoi.inventory_transfer_id
			FROM (
			    SELECT oi.order_id, oi.pick_up_location_id AS loc, COUNT(*) AS num_items
				FROM prod_tables.snp_order_items AS oi
				GROUP BY order_id, pick_up_location_id
			) AS item_orders
			INNER JOIN production.prod_tables.snp_inventory_transfer_order_items AS itoi
			ON itoi.order_item_id = item_orders.order_id
		) AS order_transfers
		INNER JOIN production.prod_tables.snp_inventory_transfers AS its
		ON order_transfers.inventory_transfer_id = its.id
		GROUP BY its.expert_id, order_transfers.inventory_transfer_id
	) AS exp_pickups
	GROUP BY exp_pickups.expert_id
) AS avg_exp_pickups
INNER JOIN d3.d_expert as exp
ON exp.expert_id = avg_exp_pickups.expert_id
LIMIT 10;

# ------------------------------------------------------

# BY PRODUCT
SELECT ps.description, ROUND(avg_pickups.avg_num_per_pickup, 2) AS avg_num_per_pickup
FROM (
	SELECT num_skus_pick.sku, AVG(num_items) AS avg_num_per_pickup
	FROM (
		SELECT pick_skus.pid, pick_skus.sku, COUNT(*) AS num_items
		FROM (
			SELECT pic_ois.pid, oi.sku
			FROM (
				SELECT pics.id AS pid, itoi.order_item_id
				FROM prod_tables.snp_inventory_transfer_order_items AS itoi
				INNER JOIN production.prod_tables.snp_inventory_transfers AS pics
				ON itoi.inventory_transfer_id = pics.id
			) AS pic_ois
			INNER JOIN prod_tables.snp_order_items AS oi
			ON oi.id = pic_ois.order_item_id
		) AS pick_skus
		GROUP BY pick_skus.pid, pick_skus.sku
	) AS num_skus_pick
	GROUP BY num_skus_pick.sku
) AS avg_pickups
INNER JOIN prod_tables.snp_product_specs AS ps
ON avg_pickups.sku = ps.sku
LIMIT 10;

# ------------------------------------------------------

# NOTE: Check this --- might want to use order_items.id instead of order_items.order_id

# BY MARKET
SELECT trans_markets.market, ROUND(AVG(trans_markets.n_items), 2) AS units_per_pickup
FROM (
	SELECT market_inv.itid, market_inv.market, SUM(market_inv.num_items) AS n_items
	FROM (
		SELECT centers_inv.itid, centers_inv.num_items, centers.market
		FROM (
			SELECT cover_inv.itid, cover_inv.num_items, cover.enjoyment_center_id
			FROM (
				SELECT zip_inv.itid, zip_inv.num_items, zips.coverage_area_id
				FROM (
					SELECT pickups.itid, pickups.num_items, pickups.loc, ads.zip
					FROM (
						SELECT order_transfers.inventory_transfer_id AS itid, order_transfers.num_items, its.meeting_address_id AS loc
						FROM (
							SELECT item_orders.order_id, item_orders.loc, item_orders.num_items, itoi.inventory_transfer_id
							FROM (
							    SELECT oi.order_id, oi.pick_up_location_id AS loc, COUNT(*) AS num_items
								FROM prod_tables.snp_order_items AS oi
								GROUP BY order_id, pick_up_location_id
							) AS item_orders
							INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
							ON itoi.order_item_id = item_orders.order_id
						) AS order_transfers
						INNER JOIN prod_tables.snp_inventory_transfers AS its
						ON order_transfers.inventory_transfer_id = its.id
					) AS pickups
					INNER JOIN prod_tables.snp_addresses AS ads
					ON ads.id = pickups.loc
				) AS zip_inv
				INNER JOIN prod_tables.snp_zip_codes AS zips
				ON zips.zip = zip_inv.zip
			) AS cover_inv
			INNER JOIN prod_tables.snp_coverage_areas AS cover
			ON cover_inv.coverage_area_id = cover.id
		) AS centers_inv
		INNER JOIN prod_tables.snp_enjoyment_centers AS centers
		ON centers.id = centers_inv.enjoyment_center_id
	) AS market_inv
	GROUP BY market_inv.itid, market_inv.market
) AS trans_markets
GROUP BY trans_markets.market;

# ANOTHER WAY
SELECT market, AVG(market_inv.n_items) AS avg_units_per_pickups
FROM (
	SELECT exp.home_enjoyment_house_name AS market, exp_pickups.inventory_transfer_id, exp_pickups.n_items
	FROM (
		SELECT its.expert_id, order_transfers.inventory_transfer_id, SUM(order_transfers.num_items) AS n_items
		FROM (
			SELECT item_orders.order_id, item_orders.loc, item_orders.num_items, itoi.inventory_transfer_id
			FROM (
			    SELECT oi.order_id, oi.pick_up_location_id AS loc, COUNT(*) AS num_items
				FROM prod_tables.snp_order_items AS oi
				GROUP BY order_id, pick_up_location_id
			) AS item_orders
			INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
			ON itoi.order_item_id = item_orders.order_id
		) AS order_transfers
		INNER JOIN prod_tables.snp_inventory_transfers AS its
		ON order_transfers.inventory_transfer_id = its.id
		GROUP BY its.expert_id, order_transfers.inventory_transfer_id
	) AS exp_pickups
	INNER JOIN d3.d_expert as exp
	ON exp.expert_id = exp_pickups.expert_id
) AS market_inv
GROUP BY market;

# ------------------------------------------------------

# IN AGGREGATE
SELECT ROUND(AVG(final.n_items), 2)
FROM (
	SELECT order_transfers.inventory_transfer_id, SUM(order_transfers.num_items) AS n_items
	FROM (
		SELECT item_orders.order_id, item_orders.loc, item_orders.num_items, itoi.inventory_transfer_id
		FROM (
		    SELECT oi.order_id, oi.pick_up_location_id AS loc, COUNT(*) AS num_items
			FROM prod_tables.snp_order_items AS oi
			GROUP BY order_id, pick_up_location_id
		) AS item_orders
		INNER JOIN prod_tables.snp_inventory_transfer_order_items AS itoi
		ON itoi.order_item_id = item_orders.order_id
	) AS order_transfers
	INNER JOIN prod_tables.snp_inventory_transfers AS its
	ON order_transfers.inventory_transfer_id = its.id
	GROUP BY order_transfers.inventory_transfer_id
) AS final

# ------------------------------------------------------
