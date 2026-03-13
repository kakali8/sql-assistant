-- metric_id: network_error
-- metric_name: 网络报错次数
-- card_name: Network Error
-- card_id: 3263
-- dashboard: L2 (id=522)
-- business_domain: Monitoring
-- owner: backend, server
-- definition: 网络报错次数
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.kix_web_events
-- events_used: network_error
--
-- [KEY FIELDS]
-- event: network_error
--   desc: 网络错误上报
--   type: 1=图片, 2=普通网络请求
--
-- [SQL]
select toDate(toTimeZone(event_time, 'Asia/Singapore')) AS date, platform, 
(case when content like '%networkState: false%' then 'no_network' else 'other_issue' end) as error_type,
-- count(distinct user_id)
count(distinct event_time) as value
from new_loops_activity.kix_web_events where event_name = 'network_error' 
-- and content not in ('networkState: true | Canceled')
group by date, platform, error_type having date > '2026-02-02' order by date desc
