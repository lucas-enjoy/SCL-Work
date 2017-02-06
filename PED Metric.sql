-- TODO: Need to restructure as Date | Market | Metric

---
# PED (Pickups / Expert / Day)
---

# ------------------------------------------------------

# BY FIL --- Checked

SELECT avg_pickups.fil, ROUND(AVG(ped), 2) AS fil_ped
FROM (
	SELECT exp_pickups.expert_id, exp_pickups.fil, AVG(exp_pickups.n_pickups) AS ped
	FROM (
		SELECT pickups.expert_id, pickups.order_date, pickups.fil, COUNT(*) AS n_pickups
		FROM (
			SELECT its.expert_id, its.created_at::DATE AS order_date, ils.name AS FIL
			FROM prod_tables.snp_inventory_locations AS ils
			LEFT JOIN prod_tables.snp_inventory_transfers AS its
			ON its.inventory_location_id = ils.id
		) AS pickups
		GROUP BY pickups.expert_id, pickups.order_date, pickups.fil
	) AS exp_pickups
	GROUP BY exp_pickups.expert_id, exp_pickups.fil
) AS avg_pickups
GROUP BY avg_pickups.fil
ORDER BY avg_pickups.fil;

# ------------------------------------------------------

# BY SKU --- Need to Check

SELECT ps.description, daily_pickup_skus.avg_daily_pickups
FROM (
	SELECT exp_skus.sku, ROUND(AVG(exp_skus.daily_pickups), 2) AS avg_daily_pickups
	FROM (
		SELECT pickup_skus.expert_id, pickup_skus.sku, AVG(n_pickups) AS daily_pickups
		FROM (
			SELECT pickups_sku.created_at, pickups_sku.expert_id, pickups_sku.sku, COUNT(*) AS n_pickups
			FROM (
				SELECT pickup_orders.pid, pickup_orders.order_date, pickup_orders.expert_id, oi.sku
				FROM (
					SELECT pics.id AS pid, itoi.order_item_id,  pics.created_at::date AS order_date, pics.expert_id
				    FROM prod_tables.snp_inventory_transfer_order_items AS itoi
				    INNER JOIN prod_tables.snp_inventory_transfers AS pics
				    ON itoi.inventory_transfer_id = pics.id
				) AS pickup_orders
				INNER JOIN prod_tables.snp_order_items AS oi
				ON oi.id = pickup_orders.order_item_id
			) AS pickups_sku
			GROUP BY pickups_sku.created_at, pickups_sku.expert_id, pickups_sku.sku
		) AS pickup_skus
		GROUP BY pickup_skus.expert_id, pickup_skus.sku
	) AS exp_skus
	GROUP BY exp_skus.sku
) AS daily_pickup_skus
INNER JOIN prod_tables.snp_product_specs as ps
ON ps.sku = daily_pickup_skus.sku
LIMIT 10;

# ------------------------------------------------------

# BY WEEK --- CHECKED

SELECT CONCAT_WS(' ', expert_first_name, expert_last_name) AS expert, avg_weekly_pickups
FROM (
	SELECT picks_weeks_exp.expert_id, ROUND(AVG(weekly_pickups), 2) AS avg_weekly_pickups
	FROM (
		SELECT picks_weeks.fiscal_week_in_year, picks_weeks.expert_id, SUM(n_pickups) AS weekly_pickups
		FROM (
		    SELECT fd.fiscal_week_in_year, pics.expert_id, pics.n_pickups
		    FROM (
		        SELECT expert_id, created_at::date, COUNT(created_at::date) AS n_pickups
		        FROM prod_tables.snp_inventory_transfers
		        GROUP BY expert_id, created_at::date
		    ) AS pics
		    INNER JOIN d3.d_fiscal_date AS fd
		    ON fd.fiscal_date = pics.created_at
		) AS picks_weeks
		GROUP BY picks_weeks.fiscal_week_in_year, picks_weeks.expert_id
	) AS picks_weeks_exp
	GROUP BY picks_weeks_exp.expert_id
) AS weekly_pickups
INNER JOIN d3.d_expert as exp
ON exp.expert_id = weekly_pickups.expert_id
LIMIT 10;

# ------------------------------------------------------

# BY REGION --- CHECKED (8 Regions)

SELECT loc_ex_peds.market, ROUND(AVG(loc_ex_peds.ped), 2) AS PED
FROM (
	SELECT ex.current_enjoyment_house_name AS market, ex_peds.expert_id, PED
    FROM (
        SELECT expert_id, AVG(pickups) AS PED
        FROM (
            SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
            FROM prod_tables.snp_inventory_transfers
            GROUP BY expert_id, created_at::date
        ) AS pics
        GROUP BY expert_id
    ) AS ex_peds
    LEFT JOIN production.d3.d_expert AS ex
    ON ex.expert_id = ex_peds.expert_id
) AS loc_ex_peds
GROUP BY market;

# ------------------------------------------------------

# BY EXPERT --- CHECKED

SELECT expert_id, AVG(pickups) as PED
FROM (
	SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
	FROM prod_tables.snp_inventory_transfers
	GROUP BY expert_id, created_at::date
	 ) AS pics
GROUP BY expert_id
) AS avg_pickups;

SELECT CONCAT_WS(' ', expert_first_name, expert_last_name) AS expert, ROUND(PED, 2) AS PED
FROM (
	SELECT expert_id, AVG(pickups) as PED
	FROM (
		SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
		FROM prod_tables.snp_inventory_transfers
		GROUP BY expert_id, created_at::date
		 ) AS pics
	GROUP BY expert_id
	) AS avg_pickups
INNER JOIN d3.d_expert as exp
ON exp.expert_id = avg_pickups.expert_id
LIMIT 10;

# ------------------------------------------------------

# IN AGGREGATE --- CHECKED

SELECT ROUND(AVG(PED), 2) AS avg_ped
FROM (
	SELECT expert_id, AVG(pickups) AS PED
	FROM (
		SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
		FROM prod_tables.snp_inventory_transfers
		GROUP BY expert_id, created_at::date
	) AS pickups
	GROUP BY expert_id
) AS avg_pickups;

# ------------------------------------------------------
