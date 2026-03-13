-- metric_id: tournament_retention
-- metric_name: 参与Tournament用户次日留存
-- card_name: Tournament retention
-- card_id: 3348
-- dashboard: CEO (id=518)
-- business_domain: rush hour
-- owner: marketing, product, ops, ceo
-- definition: 每天Tournament用户隔日是否继续留存
-- description: 参与Tournament用户次日留存率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, rings_broadcast.pk_match, rings_broadcast.pk_player_record, rings_broadcast.pk_tour
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
WITH
tournament_user AS (
    SELECT
        toDate(t1.create_time) AS date,
		country,
        u.acc_pid as acc_pid,
        t1.pk_id as pk_id,
        t3.tour_type as tour_type
    FROM (select * from rings_broadcast.pk_player_record where create_time > now() - interval 30 day) t1

    INNER JOIN new_loops_activity.gametok_user u
        ON t1.player_id = u.acc_uid

    INNER JOIN (select * from rings_broadcast.pk_match where create_time > now() - interval 30 day) t2
        ON t1.pk_id = t2.id 

    INNER JOIN rings_broadcast.pk_tour t3
        ON t2.tour_id = t3.id 
		 WHERE toDate(t1.create_time) >= today() - 30
		 and tour_type= 'RushHour'

),
hab_events AS (
    SELECT
        toDate(toTimeZone(server_time,'Asia/Singapore')) AS server_date,
        device_id,
        user_id,
        event_name
    FROM new_loops_activity.hab_app_events
    WHERE device_id IN (SELECT acc_pid FROM new_loops_activity.gametok_user)
      AND event_name IN ('loading_page', 'session_start')
      AND server_time > now() - INTERVAL 40 DAY
),
open_retention AS (
    SELECT server_date, device_id
    FROM hab_events
    WHERE event_name IN ('loading_page', 'session_start')
)

SELECT
    b1.date as date,
	country,
    COALESCE(countDistinct(b1.acc_pid),0) AS denominator,
	COALESCE(countDistinct(b2.device_id),0) AS numerator,
	COALESCE(1.0*numerator / NULLIF(denominator, 0), 0) as value
FROM tournament_user b1
LEFT JOIN open_retention b2
    ON b1.acc_pid = b2.device_id
   AND b2.server_date = b1.date + 1

GROUP BY
     b1.date,country
-- having date > '2026-03-01'
ORDER BY  b1.date DESC;
