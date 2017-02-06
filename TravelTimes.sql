--- 
# TravelTime
---

# ------------------------------------------------------

# BY Product



# ------------------------------------------------------

# BY Market

SELECT market, ROUND(CAST(AVG(enj_travels.duration) AS numeric), 2) as avg_travel_time
FROM (
	SELECT exp_travels.expert_id, exp.current_enjoyment_house_name AS market, duration
	FROM (
		SELECT (EXTRACT(EPOCH FROM end_time) - EXTRACT(EPOCH FROM start_time))/3600 AS duration, travels.expert_id
		FROM (
			SELECT cb.event_id, cb.start_time, cb.end_time, sb.expert_id
			FROM prod_tables.snp_calendar_blocks AS cb
			INNER JOIN prod_tables.snp_scheduled_blocks AS sb
			ON cb.id = sb.calendar_block_id
			WHERE cb.event_type = 'TravelTime' AND cb.enabled='true'
		) AS travels
		INNER JOIN prod_tables.snp_inventory_transfers AS its
		ON its.travel_time_id = travels.event_id
	) AS exp_travels
	INNER JOIN d3.d_expert as exp
	ON exp.expert_id = exp_travels.expert_id
) AS enj_travels
GROUP BY enj_travels.market
;



# ------------------------------------------------------

# BY Expert, HOURS

SELECT CONCAT_WS(' ', expert_first_name, expert_last_name) AS expert, avg_travel_time
FROM (
	SELECT travel_times.expert_id, ROUND(CAST(AVG(travel_times.duration) AS numeric), 2) as avg_travel_time
	FROM (
		SELECT (EXTRACT(EPOCH FROM end_time) - EXTRACT(EPOCH FROM start_time))/3600 AS duration, travels.expert_id
		FROM (
			SELECT cb.event_id, cb.start_time, cb.end_time, sb.expert_id
			FROM prod_tables.snp_calendar_blocks AS cb
			INNER JOIN prod_tables.snp_scheduled_blocks AS sb
			ON cb.id = sb.calendar_block_id
			WHERE cb.event_type = 'TravelTime' AND cb.enabled='true'
		) AS travels
		INNER JOIN prod_tables.snp_inventory_transfers AS its
		ON its.travel_time_id = travels.event_id
	) AS travel_times
	GROUP BY travel_times.expert_id
) AS exp_travels
INNER JOIN d3.d_expert as exp
ON exp.expert_id = exp_travels.expert_id
LIMIT 10;

# ------------------------------------------------------

# IN AGGREGATE

SELECT ROUND(CAST(AVG(duration) AS numeric), 2) AS avg_travel_time
FROM (
	SELECT (EXTRACT(EPOCH FROM end_time) - EXTRACT(EPOCH FROM start_time))/3600 AS duration
	FROM (
		SELECT cb.event_id, cb.start_time, cb.end_time, sb.expert_id
		FROM prod_tables.snp_calendar_blocks AS cb
		INNER JOIN prod_tables.snp_scheduled_blocks AS sb
		ON cb.id = sb.calendar_block_id
		WHERE cb.event_type = 'TravelTime' AND cb.enabled='true'
	) AS travels
	INNER JOIN prod_tables.snp_inventory_transfers AS its
	ON its.travel_time_id = travels.event_id
) AS travel_times;

# ------------------------------------------------------