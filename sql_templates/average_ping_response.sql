-- metric_id: average_ping_response
-- metric_name: MTR / API PING P90
-- card_name: Average Ping Response
-- card_id: 3191
-- dashboard: CEO (id=518)
-- business_domain: Monitoring
-- owner: backend
-- definition: 网络链路延迟
-- description: 指标描述
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.hab_cdn_result_download_log
-- events_used: 
--
-- [SQL]
-- SELECT
--     date,
--     country,
--     platform,
-- 	-- count(1),
--     ROUND(AVG(ping_millisecond)) AS avg_ping_response
-- FROM
-- (
--     SELECT
--         DATE(CONVERT_TZ(create_time, '+00:00', '+08:00')) AS date,
--         country,
--         platform,
--         result_log_id,
--         MIN(ping_millisecond) AS ping_millisecond
--     FROM new_loops_activity.hab_cdn_result_download_log
--     WHERE create_time > NOW() - INTERVAL 3 DAY
--       AND response_code = 200
--     GROUP BY
--         date,
--         country,
--         platform,
--         result_log_id
-- ) t1
-- where country is not null
-- GROUP BY
--     date,
--     country,
--     platform
-- ORDER BY
--     date DESC,
--     avg_ping_response DESC;






SELECT
    a.date,
    a.country,
    a.platform,
    -- a.times,
    b.ping_millisecond AS value
FROM
(
    /* 每个 (date,country,platform) 的样本数 N 和 P90 位置 ceil(0.9*N) */
    SELECT
        t.date,
        t.country,
        t.platform,
        COUNT(*) AS times,
        CEIL(COUNT(*) * 0.9) AS p90_pos
    FROM
    (
        /* 先按 result_log_id 去重：取最小 ping */
        SELECT
            DATE(CONVERT_TZ(create_time, '+00:00', '+08:00')) AS date,
            country,
            platform,
            result_log_id,
            MIN(ping_millisecond) AS ping_millisecond
        FROM new_loops_activity.hab_cdn_result_download_log
        WHERE create_time > NOW() - INTERVAL 3 DAY
          AND response_code = 200
          AND ping_millisecond IS NOT NULL
        GROUP BY date, country, platform, result_log_id
    ) t
    GROUP BY t.date, t.country, t.platform
) a
JOIN
(
    /* 给每个分组内按 ping 排序后的样本打行号 rn */
    SELECT
        s.date,
        s.country,
        s.platform,
        s.ping_millisecond,
        @rn := IF(@grp = CONCAT_WS('|', s.date, s.country, s.platform), @rn + 1, 1) AS rn,
        @grp := CONCAT_WS('|', s.date, s.country, s.platform) AS _grp_set
    FROM
    (
        /* 同样的去重明细（每个 result_log_id 一条，ping=min） */
        SELECT
            DATE(CONVERT_TZ(create_time, '+00:00', '+08:00')) AS date,
            country,
            platform,
            result_log_id,
            MIN(ping_millisecond) AS ping_millisecond
        FROM new_loops_activity.hab_cdn_result_download_log
        WHERE create_time > NOW() - INTERVAL 3 DAY
          AND response_code = 200
          AND ping_millisecond IS NOT NULL
        GROUP BY date, country, platform, result_log_id
    ) s
    CROSS JOIN (SELECT @rn := 0, @grp := '') vars
    ORDER BY s.date, s.country, s.platform, s.ping_millisecond
) b
  ON a.date = b.date
 AND a.country = b.country
 AND a.platform = b.platform
 AND b.rn = a.p90_pos
ORDER BY
    a.date DESC,
    value DESC;






