-- metric_id: minisite_invitation_impression_to_click
-- metric_name: Minisite 邀请曝光 → 点击漏斗
-- card_name: Minisite Invitation Impression to Click
-- card_id: 3224
-- dashboard: CEO (id=518)
-- business_domain: Viral
-- owner: ops, marketing
-- definition: Minisite邀请/分享展示 → 点击
-- description: Minisite邀请/分享展示与点击之间的转化情况
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.hab_app_events, new_loops_activity.link_click_log, new_loops_activity.link_getlink_log, new_loops_activity.link_kol_log, new_loops_activity.link_kol_users, new_loops_activity.link_report_invite_log
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
s1 AS (
    SELECT
        toDate(toTimeZone(create_time, 'Asia/Singapore')) AS date,
        -- source,
        countDistinct(uid) AS get_link_uv,
        count() AS get_link_pv
    FROM new_loops_activity.link_getlink_log
	where create_time > now() - interval 30 day and uid in (
select uid from new_loops_activity.link_kol_users
	)
	and create_time > '2026-01-17 21:00:00'
    GROUP BY date
),
s2 AS (
    SELECT
        toDate(toTimeZone(create_time, 'Asia/Singapore')) AS date,
        -- source,
        countDistinct(uid) AS click_link_uv,
        count() AS click_link_pv
    FROM new_loops_activity.link_click_log
	where create_time > now() - interval 30 day and uid in (
select uid from new_loops_activity.link_kol_users
	)
	and create_time > '2026-01-17 21:00:00'
    GROUP BY date
),
s3 AS (
SELECT
    toDate(toTimeZone(a.create_time, 'Asia/Singapore')) AS date,
    -- a.source,

    countDistinct(toUInt64(b.invite_log_id)) AS invited_uv,
    countDistinctIf(toUInt64(b.invite_log_id), b.is_task_done = 1) AS invite_success_uv

FROM new_loops_activity.link_report_invite_log AS a
LEFT JOIN
(
    SELECT
        toUInt64(invite_log_id) AS invite_log_id,
        is_task_done
    FROM new_loops_activity.link_kol_log
    WHERE invite_log_id IS NOT NULL
) AS b
    ON toUInt64(a.id) = b.invite_log_id

WHERE a.create_time > now() - INTERVAL 30 DAY
and create_time > '2026-01-17 21:00:00'
  AND b.invite_log_id IS NOT NULL
  and a.result in ('SUCCESS')
    GROUP BY date
),

dau as (
SELECT 
    toDate(
        toTimeZone(server_time,'Asia/Singapore')
    ) AS date
FROM new_loops_activity.hab_app_events
WHERE event_name IN ('loading_page','session_start')
  AND server_time > now() - INTERVAL 30 DAY and server_time > '2026-01-17 21:00:00'
  group by 1
)

SELECT
    t1.date as date,
    -- s1.source,
	 s2.click_link_uv as numerator,
    s1.get_link_uv as denominator,
	COALESCE(1.0*click_link_uv/ NULLIF(get_link_uv, 0), 0)  as value
FROM 
dau t1 left join s1 on t1.date = s1.date
LEFT JOIN s2
    ON t1.date = s2.date
   -- AND s1.source = s2.source
LEFT JOIN s3
    ON t1.date = s3.date
   -- AND s1.source = s3.source
ORDER BY t1.date DESC;
