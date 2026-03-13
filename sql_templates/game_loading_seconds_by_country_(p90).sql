-- metric_id: game_loading_seconds_by_country_(p90)
-- metric_name: 不同国家游戏加载时长(P90)
-- card_name: Game loading seconds by country (P90)
-- card_id: 3271
-- dashboard: L2 (id=522)
-- business_domain: Monitoring
-- owner: server
-- definition: 游戏加载时长
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.kix_web_events
-- events_used: game_package_download
--
-- [KEY FIELDS]
-- event: game_package_download
--   desc: 游戏包下载
--   type: 1=阿里云sdk下载方案, 2=IOS 原生下载
--
-- [SQL]
SELECT
    toDate(toTimeZone(server_time, 'Asia/Singapore')) AS date, 
	-- game_id, 
	b.country as country,
    -- platform,
    quantileTDigest(0.9)(
        toFloat64OrNull(substringIndex(ifNull(content, ''), '|', 1))
    )/1000 AS value
FROM 
(select * from new_loops_activity.kix_web_events
WHERE event_name = 'game_package_download'
  AND toTimeZone(server_time, 'Asia/Singapore') >= now() - INTERVAL 14 DAY
  AND toTimeZone(server_time, 'Asia/Singapore') <  now()
  AND toFloat64OrNull(substringIndex(ifNull(content, ''), '|', 1)) IS NOT NULL
  )a 
  left join 
  (select acc_uid, country from new_loops_activity.gametok_user group by 1,2)b on a.user_id = b.acc_uid
GROUP BY 1,2
ORDER BY date;






