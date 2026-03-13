-- metric_id: swipe_failed_times_(p50)
-- metric_name: 用户swipe失败次数中位数
-- card_name: Swipe Failed Times (P50)
-- card_id: 3320
-- dashboard: L2 (id=522)
-- business_domain: Monitoring
-- owner: backend, server
-- definition: 每天活跃用户中滑动失败次数的中位数
-- description: 用户swipe失败次数中位数
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.hab_app_events
-- events_used: new_user_swipe
--
-- [KEY FIELDS]
-- event: new_user_swipe
--   desc: 用户滑动屏幕 （ 不再只针对新用户，i改为针对所有进入swipe&play模式的用户 ）
--   type: 1=swipe in teach_swipe_view, 2=swipe in normal swipe view 1031修改&新增, 3=swipe页面无导航栏 0822
--   status: 1=成功, 0=不成功
--
-- [SQL]
SELECT
    date,
    platform,
    quantileTDigest(0.5)(times) AS value
FROM
(
    SELECT
        toDate(toTimeZone(server_time, 'Asia/Singapore')) AS date,
        platform,
        device_id,
        countDistinct(event_time) AS times
    FROM new_loops_activity.hab_app_events
    WHERE event_name = 'new_user_swipe'
      AND server_time > now() - INTERVAL 14 DAY
      AND status = 0
    GROUP BY date, platform, device_id
)
GROUP BY date, platform
ORDER BY date;
