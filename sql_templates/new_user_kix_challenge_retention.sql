-- metric_id: new_user_kix_challenge_retention
-- metric_name: 新用户KiX challenge赛事留存
-- card_name: New user KiX challenge Retention
-- card_id: 3284
-- dashboard: L2 (id=522)
-- business_domain: Daily Challenge
-- owner: marketing
-- definition: 新用户参赛隔日是留存
-- description: 新用户参赛隔日的留存率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log, rings_broadcast.pk_activity, rings_broadcast.pk_activity_appointment, rings_broadcast.pk_player_record
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
-- 全平台新用户
New_user AS (
    SELECT 
        toDate(
            toDateTime(register_time1, 'Asia/Singapore') 
        ) AS date,
        acc_pid,acc_uid,
		COALESCE(
        NULLIF(
            CASE 
                WHEN r.to_uid IS NOT NULL AND k.kol_uid IS NULL THEN 'invite'
                WHEN k.kol_uid IS NOT NULL THEN 'minihub'
                ELSE NULL
            END, ''
        ),
        CASE 
            WHEN u.network = 'TikTok SAN' THEN 'TikTok'
            WHEN u.network = 'Unattributed' THEN 'FB'
            WHEN u.network = 'Organic' THEN 'Organic'
            ELSE 'others'
        END,
        'others'
    ) AS source,country
    FROM new_loops_activity.gametok_user as u
	LEFT JOIN new_loops_activity.link_report_invite_log r
    ON r.to_uid = u.acc_uid
    AND r.source <> 'Default'
    AND r.result = 'SUCCESS'
LEFT JOIN (
    SELECT DISTINCT kol_uid
    FROM new_loops_activity.link_kol_log
) k
    ON r.from_uid = k.kol_uid
),

/* =========================
   challenge 活动
========================= */
challenge AS (
    SELECT DISTINCT
        pk_id,
        toDateTime(activity_start_time / 1000, 'Asia/Singapore') AS event_time,
        toDate(
            toDateTime(activity_start_time / 1000, 'Asia/Singapore')
        ) AS biz_date
    FROM rings_broadcast.pk_activity FINAL
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) in (17,21)
),

/* =========================
   参加 challenge 的新用户
========================= */
participated AS (
    SELECT
        s1.pk_id as pk_id,
        s1.biz_date AS biz_date,
        acc_pid ,
        status AS last_status,
        arrayLast(
            s -> s IN ('accepted','ready','fighting','gameover'),
            statuses
        ) AS stage_final_status,
        arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
    FROM (
        SELECT
            pk_id,
            toDate(
                toDateTime(create_time, 'Asia/Singapore')
            ) AS biz_date,
            t.player_id,
            t.status,
            arrayMap(
                x -> JSONExtractString(x, 'userStatus'),
                arraySort(
                    x -> JSONExtractInt(x, 'curTimeMs'),
                    JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
                )
            ) AS statuses
        FROM rings_broadcast.pk_player_record t
    ) AS s1
    INNER JOIN New_user AS s2
        ON  s1.player_id = s2.acc_uid
	 INNER JOIN challenge c
        ON s1.pk_id = c.pk_id
),

/* =========================
   用户 app 活动
========================= */
hab_events AS (
    SELECT
        toDate(
            toTimeZone(server_time,'Asia/Singapore')
        ) AS biz_date,
        device_id,
        event_name
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 30 DAY
),

/* =========================
   当天预约 challenge 的新用户
========================= */
book AS (
    SELECT
        s1.pk_id as pk_id,
        s1.biz_date AS biz_date,
        acc_pid
    FROM (
        SELECT
            pk_id,
            toDate(
                toDateTime(create_time, 'Asia/Singapore')
            ) AS biz_date,
            t.user_id
        FROM rings_broadcast.pk_activity_appointment t
        WHERE t.status = 'join'
    ) AS s1
	 INNER JOIN New_user AS s2
        ON  s1.user_id = s2.acc_uid
	 INNER JOIN challenge c
        ON s1.pk_id = c.pk_id
)

SELECT
    m4.date as date,source,country,
   COUNT(DISTINCT h1.device_id) as numerator,
    COUNT(DISTINCT m2.acc_pid) AS denominator,
	COALESCE(1.0*numerator/ NULLIF(denominator, 0), 0)  as value
FROM New_user AS m4
LEFT JOIN participated AS m2
    ON m4.acc_pid = m2.acc_pid
	AND m4.date = m2.biz_date
LEFT JOIN hab_events AS h1
    ON m2.acc_pid = h1.device_id
   AND h1.biz_date = m4.date + 1
WHERE m4.date > '2026-01-29'
GROUP BY m4.date,source,country
having m4.date <  toDate(now())
ORDER BY m4.date DESC;
