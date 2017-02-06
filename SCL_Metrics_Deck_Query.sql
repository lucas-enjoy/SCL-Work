WITH day_mkt_exp_id AS
(SELECT start_date_local, current_enjoyment_house_name, market, expert_id from (
SELECT
        date(convert_to_local( sh.start_time , a14.enjoyment_center_id::varchar )) AS start_date_local,
        a14.enjoyment_center_id,
        ec.name as current_enjoyment_house_name,
        ec.market,
        sh.expert_id
FROM
        d3.d_expert exp
        join prod.snp_shifts sh
         on exp.expert_id = sh.expert_id
        join d3_staging.d_expert_profile_change a14
         on (sh.expert_id = a14.expert_id and (sh.start_time at time zone 'UTC' at time zone 'America/Los_Angeles')::date between a14.effective_start_date and a14.effective_end_date)
        join  prod_tables.snp_enjoyment_centers ec
                on ec.id=a14.enjoyment_center_id
        --and exp.expert_id=213 --imran
        --and exp.expert_id=73 --victor
        and exp.expert_id not in (113, 139, 355) -- test experts
WHERE exp.expert_type = 'Expert'
        and date( convert_to_local( sh.start_time , exp.current_enjoyment_house_id::varchar ) ) BETWEEN '2016-09-26' and current_date+7 order by 1,2,3,4 ) x
group by 1,2,3,4 order by 1,2,3),
day_mkt_exp AS
(SELECT
        a.start_date_local,
        a.current_enjoyment_house_name,
        a.market,
        count(distinct a.expert_id) experts_shift,
        count(distinct case when b.name='OPUS Ability' then a.expert_id end) as experts_opus,
        count(distinct case when b.name='Sonos Ability' then a.expert_id end) as experts_sonos
FROM
        day_mkt_exp_id a
        LEFT JOIN prod.snp_expert_badges eb
         ON (eb.expert_id = a.expert_id and (date_added at time zone 'UTC' at time zone 'America/Los_Angeles')::date <= start_date_local)
        LEFT JOIN prod_tables.snp_badges b
         ON eb.badge_id = b.id

GROUP by 1,2,3),
experts_lms AS
(select d.fiscal_date as start_date_local, e.ec_name as current_enjoyment_house_name ,e.experts_lms
        from d3.d_fiscal_date d
        cross join d3_staging.experts_from_lms e
        where d.fiscal_date between '2016-09-26' and current_date+7
),
used_time AS
(SELECT
        start_date_local,
        current_enjoyment_house_name,
        sum(used_hours) as used_hours,
        sum(used_hours_pvt) as used_hours_pvt,
        sum(used_hours_nvb) as used_hours_nvb,
        sum(used_hours_pto) as used_hours_pto,
        sum(pickup_duration) as pickup_duration
FROM (SELECT
        date(convert_to_local( sh.start_time , exp.current_enjoyment_house_id::varchar )) AS start_date_local,
        exp.current_enjoyment_house_name,
        exp.expert_id,
        extract(EPOCH from (cb.end_time - cb.start_time) )/(60.0*60.0) AS used_hours,
        case when cb.event_type in ('Pickup','Visit','TravelTime', 'Relay','Reservation','InventoryTransfer') THEN extract(EPOCH from (cb.end_time - cb.start_time) )/(60.0*60.0) END AS used_hours_PVT,
        case when cb.event_type not in ('Pickup','Visit','TravelTime', 'Relay','Reservation','InventoryTransfer') THEN extract(EPOCH from (cb.end_time - cb.start_time) )/(60.0*60.0) END AS used_hours_NVB,
        case when cb.event_type in ('PaidTimeOff','paid_time_off') THEN extract(EPOCH from (cb.end_time - cb.start_time) )/(60.0*60.0) END AS used_hours_PTO,
        case when cb.event_type in ('Pickup','InventoryTransfer') THEN extract(EPOCH from (cb.end_time - cb.start_time) )/(60.0*60.0) END AS pickup_duration

        FROM
                d3.d_expert exp
                INNER JOIN prod.snp_shifts sh
                 ON exp.expert_id = sh.expert_id
                INNER JOIN prod.snp_scheduled_blocks sb
                 ON sh.id = sb.shift_id
                INNER JOIN prod.snp_calendar_blocks cb
                 ON sb.calendar_block_id = cb.id
        WHERE
                cb.enabled<>'f'
                AND exp.expert_type = 'Expert'
                AND date( convert_to_local( sh.start_time , exp.current_enjoyment_house_id::varchar ) ) BETWEEN '2016-09-26' and current_date+7)a GROUP by 1,2),
shift_time AS
(SELECT
        start_date_local,
        current_enjoyment_house_name,
        coalesce(sum(case when shift_hours >= 0 and shift_hours < 1 then 1 end),0) as shift_00_hour,
        coalesce(sum(case when shift_hours >= 1 and shift_hours < 2 then 1 end),0) as shift_01_hour,
        coalesce(sum(case when shift_hours >= 2 and shift_hours < 3 then 1 end),0) as shift_02_hour,
        coalesce(sum(case when shift_hours >= 3 and shift_hours < 4 then 1 end),0) as shift_03_hour,
        coalesce(sum(case when shift_hours >= 4 and shift_hours < 5 then 1 end),0) as shift_04_hour,
        coalesce(sum(case when shift_hours >= 5 and shift_hours < 6 then 1 end),0) as shift_05_hour,
        coalesce(sum(case when shift_hours >= 6 and shift_hours < 7 then 1 end),0) as shift_06_hour,
        coalesce(sum(case when shift_hours >= 7 and shift_hours < 8 then 1 end),0) as shift_07_hour,
        coalesce(sum(case when shift_hours >= 8 and shift_hours < 9 then 1 end),0) as shift_08_hour,
        coalesce(sum(case when shift_hours >= 9 and shift_hours < 10 then 1 end),0) as shift_09_hour,
        coalesce(sum(case when shift_hours >= 10 and shift_hours < 11 then 1 end),0) as shift_10_hour,
        coalesce(sum(case when shift_hours >= 11 and shift_hours < 12 then 1 end),0) as shift_11_hour,
        coalesce(sum(case when shift_hours >= 12 and shift_hours < 13 then 1 end),0) as shift_12_hour,
        coalesce(sum(case when shift_hours >= 13 and shift_hours < 14 then 1 end),0) as shift_13_hour,
        coalesce(sum(case when shift_hours >= 14 then 1 end),0) as shift_14_hour,
        sum(shift_hours) as shift_hours
FROM (SELECT
        date(convert_to_local( sh.start_time , exp.current_enjoyment_house_id::varchar )) AS start_date_local,
        exp.current_enjoyment_house_name,
        exp.expert_id,
        extract(EPOCH from (sh.end_time - sh.start_time) )/(60.0*60.0) AS shift_hours
        FROM
                d3.d_expert exp
                INNER JOIN prod.snp_shifts sh
                 ON exp.expert_id = sh.expert_id
                INNER JOIN day_mkt_exp_id xx
                 ON exp.expert_id = xx.expert_id
                 AND exp.current_enjoyment_house_name = xx.current_enjoyment_house_name
                 AND xx.start_date_local = date(convert_to_local( sh.start_time , exp.current_enjoyment_house_id::varchar ))
        WHERE
                exp.expert_type = 'Expert'
                AND date(sh.start_time) BETWEEN '2016-09-26' and current_date+7 and sh.enabled<>'f' )a GROUP by 1,2),
visits AS (
select o.visit_date_local as start_date_local,
    o.visit_eh as current_enjoyment_house_name,
    count(visit_id) visits,
    count(case when o.partner_channel = 'Integration' and o.partner_id = 1 then visit_id end) as visits_att_cart
    from d3.f_order_master o
    where order_status <> 'canceled' --and o.expert_id not in (204, 328)
    and o.visit_date_local between '2016-09-26' and current_date+7
    group by 1,2
),
orders AS (
select o.order_created_date_pt as start_date_local,
    o.visit_eh as current_enjoyment_house_name,
    count(o.order_id) booked_orders,
    count(case when o.order_status = 'canceled' then order_id end) as cancelations
    from d3.f_order_master o
    where o.order_created_date_pt between '2016-09-26' and current_date+7
    group by 1,2
),
travel as (
select  mkt_tt,
        visit_date_local_tt,
        avg(visit_travel_duration_minutes) avg_visit_tt,
        avg(pickup_visit_travel_duration_minutes) avg_pickup_tt
from prod_tables.tblo_order_travel_times
where visit_date_local_tt between '2016-09-26' and current_date+7
group by 1,2
),
pickups as (
        SELECT
            units_per_pickup.event_date,
            units_per_pickup.market,
            sum(units_per_pickup.n_units) AS num_units_in_pickup,
            COUNT(units_per_pickup.n_units) AS num_pickups
        FROM (
            SELECT
                DATE(convert_to_local(cb.start_time, ec.id)) AS event_date,
                ec.market,
                pickup_units.n_units
            FROM (
                   SELECT it.id AS inventory_transfer_id, COUNT(itoi.id) AS n_units
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
           WHERE units_per_pickup.event_date between DATE('2016-09-25') and date(current_timestamp at time zone 'UTC' at time zone 'America/Los_Angeles')-1
        GROUP BY units_per_pickup.event_date, units_per_pickup.market
        ORDER BY units_per_pickup.event_date desc, units_per_pickup.market
)

SELECT
        a.start_date_local,
        concat(ec.id::varchar,'-',ec.market) as current_enjoyment_house_name,
        w.experts_lms,
        a.experts_shift,
        a.experts_opus,
        x.used_hours,
        y.shift_hours,
        coalesce(z.visits,0) visits,
        x.used_hours_pvt,
        x.used_hours_nvb,
        a.experts_sonos,
        y.shift_00_hour,
        y.shift_01_hour,
        y.shift_02_hour,
        y.shift_03_hour,
        y.shift_04_hour,
        y.shift_05_hour,
        y.shift_06_hour,
        y.shift_07_hour,
        y.shift_08_hour,
        y.shift_09_hour,
        y.shift_10_hour,
        y.shift_11_hour,
        y.shift_12_hour,
        y.shift_13_hour,
        y.shift_14_hour,
        d.fiscal_week_end_date,
        coalesce(z.visits_att_cart,0) visits_att_cart,
        coalesce(zz.booked_orders,0) booked_orders,
        coalesce(zz.cancelations,0) cancelations,
        x.used_hours_PTO,
        d.fiscal_week_offset,
        d.fiscal_day_offset,
        tt.avg_visit_tt,
        tt.avg_pickup_tt,
        x.pickup_duration,
        p.num_pickups,
        p.num_units_in_pickup
FROM day_mkt_exp a
JOIN experts_lms w on a.current_enjoyment_house_name = w.current_enjoyment_house_name
AND a.start_date_local = w.start_date_local
JOIN used_time x on a.current_enjoyment_house_name = x.current_enjoyment_house_name
AND a.start_date_local = x.start_date_local
JOIN shift_time y on a.current_enjoyment_house_name = y.current_enjoyment_house_name
AND a.start_date_local = y.start_date_local
LEFT JOIN visits z on a.current_enjoyment_house_name = z.current_enjoyment_house_name
AND a.start_date_local = z.start_date_local
LEFT JOIN orders zz on a.current_enjoyment_house_name = zz.current_enjoyment_house_name
AND a.start_date_local = zz.start_date_local
LEFT JOIN travel tt on a.market = tt.mkt_tt
and a.start_date_local = tt.visit_date_local_tt
left JOIN pickups p on p.event_date = a.start_date_local
AND a.market = p.market
JOIN prod_tables.snp_enjoyment_centers ec on a.current_enjoyment_house_name = ec.name
JOIN d3.d_fiscal_date d on a.start_date_local = d.fiscal_date
ORDER BY 1,2;
