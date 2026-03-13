-- metric_id: dau
-- metric_name: 日活跃用户数 (DAU)
-- card_name: DAU
-- card_id: 3180
-- dashboard: CEO (id=518)
-- business_domain: Platform Basics
-- owner: ceo, marketing
-- definition: 当日去重活跃用户数
-- description: 表示用户规模是否健康
-- evaluation: higher_is_better
-- related_metrics: new_user, retention(d1)
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events
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
new_user AS (
    SELECT
        register_time1, country, network,
        acc_pid
    FROM new_loops_activity.gametok_user
    WHERE is_guest = 1
    GROUP BY ALL
)

SELECT 
    toDate(
        toTimeZone(server_time,'Asia/Singapore')
    ) AS date,  country, 
	(case when network = 'TikTok SAN' then 'TikTok'
            WHEN network = 'Unattributed' or network like '%Facebook%' or network like '%Instagram%'THEN 'FB'
             else network end) as source,
	count(distinct device_id) as value
FROM new_loops_activity.hab_app_events t1
left join new_user t2  ON t1.device_id = t2.acc_pid 
WHERE event_name IN ('loading_page','session_start')
  AND server_time > now() - INTERVAL 30 DAY and server_time > '2026-01-17 21:00:00'
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
GROUP BY 1,2,3 
-- having date <= '2026-03-05' 
order by date







 --    SELECT
 --        toDate(toTimeZone(server_time, 'Asia/Shanghai')) AS date, count(distinct device_id) as value
 --    FROM new_loops_activity.hab_app_events
 --    WHERE user_id IN (SELECT acc_uid FROM new_loops_activity.gametok_user) and server_time > now() - INTERVAL 30 DAY
	-- and server_time > '2026-01-17 21:00:00' and event_name in ('session_start','loading_page')
 --    GROUP BY date order by date

