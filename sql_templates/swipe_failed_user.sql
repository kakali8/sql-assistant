-- metric_id: swipe_failed_user
-- metric_name: 用户swipe失败率
-- card_name: Swipe Failed User
-- card_id: 3319
-- dashboard: L2 (id=522)
-- business_domain: Monitoring
-- owner: backend, server
-- definition: 每天活跃用户中滑动失败的比例
-- description: 用户swipe失败率
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.hab_app_events
-- events_used: loading_page, new_user_swipe, session_start
--
-- [KEY FIELDS]
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: new_user_swipe
--   desc: 用户滑动屏幕 （ 不再只针对新用户，i改为针对所有进入swipe&play模式的用户 ）
--   type: 1=swipe in teach_swipe_view, 2=swipe in normal swipe view 1031修改&新增, 3=swipe页面无导航栏 0822
--   status: 1=成功, 0=不成功
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
--
-- [SQL]
with dau as (
SELECT 
        toDate(toTimeZone(event_time, 'Asia/Singapore')) AS date, platform,
        device_id
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 60 DAY
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
  group by 1,2,3
),

swipe as (
select toDate(toTimeZone(server_time, 'Asia/Singapore')) as date, platform, device_id from new_loops_activity.hab_app_events
where event_name = 'new_user_swipe' and server_time > now() - interval 14 day and status = 0 group by 1,2,3)


select t1.date as date, t1.platform as platform, count(distinct t1.device_id) as denominator, count(distinct t2.device_id) as numerator, numerator/denominator as value from dau t1 left join swipe t2 on t1.date = t2.date and t1.device_id = t2.device_id
group by 1,2

