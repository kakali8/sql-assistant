-- metric_id: book_kix_challenge_uv
-- metric_name: 赛事预约率
-- card_name: Book kix challenge uv
-- card_id: 3196
-- dashboard: CEO (id=518)
-- business_domain: Daily Challenge
-- owner: product, ops, marketing
-- definition: 预约用户 / DAU
-- description: 赛事预约率是指在日活跃用户中进行赛事预约的用户比例。
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
        toDate(toDateTime(activity_start_time / 1000, 'Asia/Singapore') - INTERVAL 17 HOUR - INTERVAL 30 MINUTE) AS biz_date
    FROM rings_broadcast.pk_activity
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL
),

-- participated AS (
--     SELECT 
--         pk_id,
--         biz_date,
--         acc_pid,
--         status AS last_status,
--         arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
--         arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
--     FROM (
--         SELECT 
--             pk_id,
--             toDate(toDateTime(create_time, 'Asia/Singapore') - INTERVAL 17 HOUR - INTERVAL 30 MINUTE) AS biz_date,
--             t1.acc_pid,
--             t.status,
--             arrayMap(
--                 x -> JSONExtractString(x, 'userStatus'),
--                 arraySort(
--                     x -> JSONExtractInt(x, 'curTimeMs'),
--                     JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
--                 )
--             ) AS statuses
--         FROM (select * from rings_broadcast.pk_player_record where create_time > now() - interval 30 day) t
--         INNER JOIN (
--             SELECT DISTINCT acc_uid, acc_pid
--             FROM new_loops_activity.gametok_user
--         ) t1 ON t.player_id = t1.acc_uid
--     )
-- ),

hab_events AS (
    SELECT 
        toDate(toTimeZone(server_time,'Asia/Singapore') - INTERVAL 17 HOUR - INTERVAL 30 MINUTE) AS biz_date,
        device_id
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 30 DAY
	  AND
  (
    /* ---------- iPhone：client_version > 1.0.2260110 ---------- */
    (
      platform = 'iPhone'
      AND (
            toInt64OrZero(splitByChar('.', ifNull(client_version,''))[1]) > 1
         OR (
              toInt64OrZero(splitByChar('.', ifNull(client_version,''))[1]) = 1
              AND toInt64OrZero(splitByChar('.', ifNull(client_version,''))[2]) > 0
            )
         OR (
              toInt64OrZero(splitByChar('.', ifNull(client_version,''))[1]) = 1
              AND toInt64OrZero(splitByChar('.', ifNull(client_version,''))[2]) = 0
              AND toInt64OrZero(splitByChar('.', ifNull(client_version,''))[3]) > 2260110
            )
      )
    )

    OR

    /* ---------- Android：去掉括号后再比 > 1.31.0 ---------- */
    (
      platform = 'Android'
      AND (
            toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[1]) > 1
         OR (
              toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[1]) = 1
              AND toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[2]) > 31
            )
         OR (
              toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[1]) = 1
              AND toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[2]) = 31
              AND toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[3]) > 0
            )
      )
    )
  )
),

book AS (
    SELECT 
        pk_id,
        toDate(toDateTime(create_time, 'Asia/Singapore') - INTERVAL 17 HOUR - INTERVAL 30 MINUTE) AS biz_date,
        t1.acc_pid
    FROM rings_broadcast.pk_activity_appointment t
    INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid
        FROM new_loops_activity.gametok_user
    ) t1 ON t.user_id = t1.acc_uid
    WHERE t.status = 'join'
)

SELECT 
    c.biz_date AS date,
    ifnull(COUNT(DISTINCT b.acc_pid),0) AS numerator,
    ifnull(COUNT(DISTINCT h2.device_id),0) AS denominator,
	COALESCE(COUNT(DISTINCT b.acc_pid)/ NULLIF(COUNT(DISTINCT h2.device_id), 0), 0)  as value
FROM challenge c
-- LEFT JOIN participated p
--     ON c.pk_id = p.pk_id
LEFT JOIN hab_events h2
    ON h2.biz_date = c.biz_date
LEFT JOIN book b
    ON c.pk_id = b.pk_id
WHERE c.biz_date > '2026-01-17'
  AND c.biz_date <= toDate(now('Asia/Singapore'))
GROUP BY c.biz_date
ORDER BY c.biz_date DESC;





