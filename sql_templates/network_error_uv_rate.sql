-- metric_id: network_error_uv_rate
-- metric_name: 网络报错用户比例
-- card_name: Network Error UV rate
-- card_id: 3264
-- dashboard: L2 (id=522)
-- business_domain: Monitoring
-- owner: backend, server
-- definition: 遇到错误的活跃用户比例
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.hab_app_events, new_loops_activity.kix_web_events
-- events_used: loading_page, network_error, session_start
--
-- [KEY FIELDS]
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: network_error
--   desc: 网络错误上报
--   type: 1=图片, 2=普通网络请求
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
--
-- [SQL]
with nw_error as 
(select toDate(toTimeZone(event_time, 'Asia/Singapore')) AS date, platform, 
user_id
-- count(distinct event_time) as value
from new_loops_activity.kix_web_events where event_name = 'network_error' and content not in ('networkState: true | Canceled')
group by 1,2,3),

dau as (
SELECT 
        toDate(toTimeZone(event_time, 'Asia/Singapore')) AS date, platform,
        user_id
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
)

select t1.date, platform, count(distinct t1.user_id) as denominator, count(distinct t2.user_id) as numerator, numerator/denominator as value from dau t1 left join nw_error t2 on t1.date=t2.date and t1.platform=t2.platform and t1.user_id = t2.user_id
group by 1,2 order by 1 desc


