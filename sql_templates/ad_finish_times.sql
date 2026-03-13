-- metric_id: ad_finish_times
-- metric_name: 看广告获得energy次数
-- card_name: Ad finish times
-- card_id: 3238
-- dashboard: CEO (id=518)
-- business_domain: Revenue
-- owner: product, ops
-- definition: 每日从topup页面或者弹窗观看广告的总次数
-- description: 用户观看广告意愿
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log
-- events_used: 
--
-- [SQL]
select 
	date(create_time) as date, 
	source, 
	count(id) as value
from new_loops_activity.energy_log final 
where source in ('watch_ad', 'watch_ad_outside','watch_by_other_win') 
and date(create_time) > now() - INTERVAL 30 DAY
and uid not in (2387152,2387153,2387161,2387159,2387155,2385442)
group by 1,2
-- having date <= '2026-03-05'
order by 1 desc, 2;
