SELECT * 
FROM production.d3.f_visit as vis
INNER JOIN production.d3.f_order as ord
ON vis.order_id=ord.order_id
LIMIT 10;

# production.d3.f_order_item_master has SKU by order_item

# looks like f_inventory_adjustment is the right view
SELECT inv.transaction_number, COUNT(transaction_number)
FROM production.d3.f_inventory_adjustment AS inv
GROUP BY inv.transaction_number
LIMIT 10;

# prod.snp_calendar_blocks 
# scheduled_blocks
# scheduled_blocks enabled == 't'

# snp_pickups (expert_id, pickup_location_id, travel_time_id)
# snp_pick_up_locations

# This will get
SELECT em.id, em.first_name, em.last_name, num_picks
FROM (
	SELECT ex_id, num_picks
	FROM (
		SELECT pic.expert_id AS ex_id, COUNT(pic.expert_id) AS num_picks
		FROM prod.snp_pickups AS pic
		GROUP BY ex_id
	) AS exp_pic
	INNER JOIN prod.snp_experts AS exp
	ON ex_id=exp.id
) AS top
INNER JOIN prod.snp_employees AS em
ON top.id = em.id
LIMIT 10;


# working 
SELECT ex.id AS exp_id, num_pickups
	FROM (
		SELECT pic.expert_id AS exid, COUNT(pic.expert_id) AS num_pickups
		FROM prod.snp_pickups AS pic
		GROUP BY pic.expert_id
	) AS exem
	INNER JOIN prod.snp_experts AS ex
	ON exid=ex.id
    LIMIT 10;

# counting dates
SELECT created_at::date, COUNT(created_at::date)
FROM prod.snp_pickups
GROUP BY created_at::date
LIMIT 10;

# ------------------------------------------------------

# with region
SELECT loc_ex_peds.loc, ROUND(AVG(loc_ex_peds.ped), 2) AS PED
FROM (
	SELECT ex.current_enjoyment_house_name AS loc, ex_peds.expert_id, PED
    FROM (
        SELECT expert_id, AVG(pickups) AS PED
        FROM 
        (
            SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
            FROM prod.snp_pickups
            GROUP BY expert_id, created_at::date
        ) AS pics
        GROUP BY expert_id
    ) AS ex_peds
    LEFT JOIN production.d3.d_expert AS ex
    ON ex.expert_id = ex_peds.expert_id
) AS loc_ex_peds
GROUP BY loc
LIMIT 10;

# ------------------------------------------------------

# join on expert names
SELECT CONCAT_WS(' ', expert_first_name, expert_last_name) AS expert, 
	ROUND(PED, 2) AS PED
FROM (
	SELECT expert_id, AVG(pickups) as PED
	FROM (
		SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
		FROM prod.snp_pickups
		GROUP BY expert_id, created_at::date
		 ) AS pics
	GROUP BY expert_id
	  ) AS avg_pickups
INNER JOIN d3.d_expert as exp
ON exp.expert_id = avg_pickups.expert_id
LIMIT 10;

# ------------------------------------------------------

# FINALLY - Calculate Average Pickups / Expert / Day OVERALL
SELECT AVG(PED)
FROM (
	SELECT employee_id, PED
	FROM (
		SELECT expert_id, AVG(pickups) AS PED
		FROM (
			SELECT expert_id, created_at::date, COUNT(created_at::date) AS pickups
			FROM prod.snp_pickups
			GROUP BY expert_id, created_at::date
			) AS pickups
		GROUP BY expert_id
		) AS avg_pickups
	INNER JOIN prod.snp_experts AS exp
	ON avg_pickups.expert_id = exp.id
) AS PEDs


