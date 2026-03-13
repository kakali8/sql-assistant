-- metric_id: cash_out_error
-- metric_name: 提现失败原因
-- card_name: Cash out error
-- card_id: 3237
-- dashboard: L2 (id=522)
-- business_domain: cash out
-- owner: ops
-- definition: 指标定义
-- description: Cash out失败原因
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: loops_billing.cashout_log
-- events_used: 
--
-- [SQL]
SELECT
  date(convert_tz(create_time, '+00:00', '+08:00')) as date, payment_method, error_code as type, count(distinct id) as value
FROM loops_billing.cashout_log
where status in ('FAIL')
and create_time > '2026-01-17 16:00:00'
group by 1,2,3






