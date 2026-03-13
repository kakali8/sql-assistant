-- metric_id: finish_kix_challenge_rate
-- metric_name: 赛事完成率
-- card_name: Finish kix challenge rate
-- card_id: 3198
-- dashboard: CEO (id=518)
-- business_domain: Daily Challenge
-- owner: product, ops, marketing
-- definition: 完成结算人数 / 开赛人数
-- description: 赛事完成率是指完成结算人数与开赛人数的比率，反映赛事的参与情况。
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, rings_broadcast.pk_activity, rings_broadcast.pk_activity_appointment, rings_broadcast.pk_player_record
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
WITH challenge AS (
    SELECT DISTINCT
        pk_id,
        toDateTime(activity_start_time / 1000, 'Asia/Singapore') AS event_time,
        toDate(
            toDateTime(activity_start_time / 1000, 'Asia/Singapore')
            - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
        ) AS biz_date
    FROM rings_broadcast.pk_activity final
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL 
),
participated AS (
    select 
	pk_id,biz_date,acc_pid,status AS last_status,
	arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
    arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
	from
	(SELECT 
	    pk_id,
		toDate(
            toDateTime(create_time, 'Asia/Singapore')
            - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
        ) AS biz_date,
        t1.acc_pid AS acc_pid,
        t.status,arrayMap(
                    x -> JSONExtractString(x, 'userStatus'),
                    arraySort(
                            x -> JSONExtractInt(x, 'curTimeMs'),
                            JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
                    )
            ) as statuses
    FROM rings_broadcast.pk_player_record t
    INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid 
        FROM new_loops_activity.gametok_user
    ) t1 
        ON t.player_id = t1.acc_uid)
),
hab_events AS (
    SELECT 
        toDate(
            toTimeZone(server_time,'Asia/Singapore')
            - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
        ) AS biz_date,
        device_id,
        event_name
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 60 DAY
),
book AS ( 
SELECT  pk_id,
		toDate(
            toDateTime(create_time, 'Asia/Singapore')
            - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
        ) AS biz_date,
        t1.acc_pid AS acc_pid
		FROM rings_broadcast.pk_activity_appointment t 
INNER JOIN
( SELECT DISTINCT acc_uid, acc_pid FROM new_loops_activity.gametok_user ) t1 
ON t.user_id = t1.acc_uid where t.status='join' )
SELECT 
    m1.biz_date as date,
    COUNT(DISTINCT case when m2.last_status in ('fighting','gameover') or m2.stage_final_status in ('fighting','gameover')
        THEN m2.acc_pid END)  AS denominator,
	 COUNT(DISTINCT CASE
    WHEN m2.last_status = 'gameover' 
         OR (m2.last_status = 'fighting' AND m2.stage_final_status NOT IN ('disconnect'))
    THEN m2.acc_pid 
END) as numerator,
COALESCE(numerator / NULLIF(denominator, 0), 0) AS value
FROM challenge AS m1
LEFT JOIN participated AS m2
    ON   m1.pk_id=m2.pk_id
LEFT JOIN hab_events h1
    ON m2.acc_pid = h1.device_id
   AND h1.biz_date = m2.biz_date+1
left join book m3 
on   m1.pk_id=m3.pk_id
WHERE m1.biz_date > '2026-01-17'
and m1.biz_date <=toDate(now('Asia/Singapore'))
GROUP BY m1.biz_date
ORDER BY m1.biz_date DESC;
