-- metric_id: viral_reward_uv
-- metric_name: viral奖励用户数
-- card_name: Viral reward uv
-- card_id: 3225
-- dashboard: CEO (id=518)
-- business_domain: Viral
-- owner: ops, product, marketing
-- definition: 指标定义
-- description: viral奖励用户数
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, new_loops_activity.hab_app_events, new_loops_activity.link_report_invite_log
-- events_used: loading_page, session_start
--
-- [KEY FIELDS]
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
--
-- [SQL]
WITH hab_events AS (
    SELECT 
        toDate(server_time) AS date,
        device_id,
        user_id
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 14 DAY
),
energy as (select 
date(s3.create_time) as date,
count(distinct uid) as reward_uv,
ifnull(sum(energy),0) as energy
from new_loops_activity.energy_log as s3
    where s3.source = 'invite_new_user'
	group by date(s3.create_time))

SELECT
    date(s2.register_time1)  AS date,
    s4.reward_uv AS value
FROM new_loops_activity.gametok_user AS s2

LEFT JOIN new_loops_activity.link_report_invite_log AS s1
    ON date(s1.create_time) = date(s2.register_time1)
   AND s1.source <> 'Default'
   and s1.result ='SUCCESS'
left join energy  as s4
on date(s2.register_time1)=s4.date
LEFT JOIN hab_events h1
    ON s1.to_uid = h1.user_id
   AND h1.date = date(s1.create_time) + 1
GROUP BY date,s4.reward_uv
ORDER BY date DESC;
