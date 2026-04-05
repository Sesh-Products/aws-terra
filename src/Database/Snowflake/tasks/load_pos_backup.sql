INSERT INTO ${database}.${backup_schema}.pos_transactions_backup (
  loc_id, prod_id, store_code, city_id, state_id, county_id,
  address, keys_used, product_upc, trans_date, trans_qty, total_sales
)
WITH stg_data AS (
  SELECT * FROM ${database}.${schema}.${stream_name}
  WHERE METADATA$ACTION = 'INSERT'
),
child_ids AS (
  SELECT
    s.*,
    dc.city_id,
    dst.state_id,
    dco.county_id
  FROM stg_data s
  LEFT JOIN ${database}.${dim_schema}.dim_city dc
    ON  s.CITY IS NOT NULL
    AND UPPER(TRIM(s.CITY))     = UPPER(TRIM(dc.city_name))
    AND (s.POSTAL_CODE IS NULL OR TRIM(s.POSTAL_CODE) = TRIM(dc.postal_code))
  LEFT JOIN ${database}.${dim_schema}.dim_state dst
    ON  s.STATE IS NOT NULL
    AND UPPER(TRIM(s.STATE))    = UPPER(TRIM(dst.state_name))
  LEFT JOIN ${database}.${dim_schema}.dim_county dco
    ON  s.COUNTY IS NOT NULL
    AND UPPER(TRIM(s.COUNTY))   = UPPER(TRIM(dco.county_name))
),
loc_matched AS (
  SELECT
    c.*,
    dl.loc_id,
    TRIM(
      IFF(c.STORE_CODE IS NOT NULL,                            'STORE_CODE ',  '') ||
      IFF(c.city_id IS NOT NULL AND c.POSTAL_CODE IS NOT NULL, 'CITY+POSTAL ', '') ||
      IFF(c.city_id IS NOT NULL AND c.POSTAL_CODE IS NULL,     'CITY_ONLY ',   '') ||
      IFF(c.state_id   IS NOT NULL,                            'STATE ',       '') ||
      IFF(c.county_id  IS NOT NULL,                            'COUNTY ',      '') ||
      IFF(c.ADDRESS    IS NOT NULL,                            'ADDRESS ',     '') ||
      IFF(c.STORE_NAME IS NOT NULL,                            'STORE_NAME ',  '')
    ) AS keys_used
  FROM child_ids c
  LEFT JOIN ${database}.${dim_schema}.dim_location dl
    ON (
      (
        dl.store_code::STRING = c.STORE_CODE::STRING
        AND (c.city_id   IS NULL OR dl.city_id   = c.city_id)
        AND (c.state_id  IS NULL OR dl.state_id  = c.state_id)
        AND (c.county_id IS NULL OR dl.county_id = c.county_id)
        AND (c.ADDRESS   IS NULL OR UPPER(TRIM(dl.address)) = UPPER(TRIM(c.ADDRESS)))
      )
      OR
      (
        c.STORE_NAME IS NOT NULL
        AND UPPER(TRIM(dl.loc_name)) = UPPER(TRIM(c.STORE_NAME))
      )
    )
)
SELECT
  loc_id,
  prod_id,
  STORE_CODE,
  city_id,
  state_id,
  county_id,
  ADDRESS,
  keys_used,
  product_upc,
  TRY_CAST(week_ending AS DATE) AS trans_date,
  eq_units::NUMBER(18,2)        AS trans_qty,
  sales::NUMBER(18,4)           AS total_sales
FROM loc_matched