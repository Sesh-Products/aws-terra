INSERT INTO ${database}.${fact_schema}.fact_pos (
  loc_id, prod_id, trans_date, trans_qty, total_sales
)
SELECT loc_id, prod_id, trans_date, trans_qty, total_sales
FROM ${database}.${backup_schema}.pos_transactions_backup
WHERE (loc_id IS NOT NULL OR prod_id IS NOT NULL)
AND trans_date IS NOT NULL;