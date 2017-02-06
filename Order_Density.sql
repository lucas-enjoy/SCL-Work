-- Order Density by ZIP XXX

SELECT
    zip
    , n_orders / population::FLOAT * 1000 AS orders_per_thousand_people
    , n_orders / landsqmi::FLOAT AS orders_per_sq_mile
FROM (
    SELECT *
    FROM (
        SELECT
            orders_by_zip.zip
            , n_orders
            , REPLACE(zip_pop.population, ',', '')::INT AS population
            , zip_pop.landsqmi::FLOAT
        FROM (
            SELECT ad.zip, COUNT(order_id) AS n_orders
            FROM d3.f_order AS ord
            INNER JOIN d3.d_address AS ad
            ON ord.billing_address_id = ad.address_id
            GROUP BY ad.zip
        ) AS orders_by_zip
        INNER JOIN d3.d_zip_code AS zips
        ON orders_by_zip.zip = zips.zip
        INNER JOIN prod_tables.zip_table AS zip_pop
        ON orders_by_zip.zip = zip_pop.zipcode
    ) AS orders_zip
    WHERE population != 0
    AND landsqmi != 0
) AS densities
LIMIT 10;

-- Order Density by Market TODO

SELECT *
FROM (
    SELECT
        orders_by_zip.zip
        , market
        , n_orders
        , REPLACE(zip_pop.population, ',', '')::FLOAT AS population
        , zip_pop.landsqmi
    FROM (
        SELECT ad.zip, COUNT(order_id) AS n_orders
        FROM d3.f_order AS ord
        INNER JOIN d3.d_address AS ad
        ON ord.billing_address_id = ad.address_id
        GROUP BY ad.zip
    ) AS orders_by_zip
    INNER JOIN d3.d_zip_code AS zips
    ON orders_by_zip.zip = zips.zip
    INNER JOIN prod_tables.zip_table AS zip_pop
    ON orders_by_zip.zip = zip_pop.zipcode
) AS orders_by_zip
LIMIT 10;
