-- metric_id: viral_new_uv
-- metric_name: Viral 占比
-- card_name: viral new uv
-- card_id: 3207
-- dashboard: CEO (id=518)
-- business_domain: Viral
-- owner: ops, marketing, product, ceo
-- definition: Viral 新增 / 总新增
-- description: Viral 新增用户占总新增用户的比例
-- evaluation: higher_is_better
-- related_metrics: invitation_impression_to_click, click_to_invite_sucess
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
new_user AS (
    SELECT
        register_time1, country, network,acc_uid,
        acc_pid
    FROM new_loops_activity.gametok_user
    WHERE is_guest = 1
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
    count(DISTINCT s5.acc_pid)  AS numerator,
    count(DISTINCT s2.acc_pid) AS denominator,
    count(DISTINCT s5.acc_pid) * 1.0
        / NULLIF(count(DISTINCT s2.acc_pid), 0)  AS value
FROM new_loops_activity.gametok_user AS s2

LEFT JOIN new_loops_activity.link_report_invite_log AS s1
    ON date(s1.create_time) = date(s2.register_time1)
   AND s1.source <> 'Default'
left join new_user as s5 on s1.to_uid=s5.acc_uid
left join energy  as s4
on date(s2.register_time1)=s4.date
LEFT JOIN hab_events h1
    ON s1.to_uid = h1.user_id
   AND h1.date = date(s1.create_time) + 1
GROUP BY date,s4.energy ,s4.reward_uv
ORDER BY date DESC;


