-- metric_id: retention(d1)
-- metric_name: 留存(D1)
-- card_name: Retention(d1)
-- card_id: 3236
-- dashboard: CEO (id=518)
-- business_domain: Platform Basics
-- owner: ceo, product
-- definition: 新用户 D1 留存
-- evaluation: higher_is_better
-- related_metrics: new_activated_user, new_user_challenge_rate, new_user_kix_challenge_retention, new_user_enter_intro_rate, new_user_intro_start_click_rate, dnu_paly_rate_d0
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log, rings_broadcast.pk_player_record
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
hab_events AS (
    SELECT
        toDate(toTimeZone(server_time,'Asia/Singapore')) AS server_date,
        device_id,
        user_id,
        event_name
    FROM new_loops_activity.hab_app_events
    WHERE device_id IN (SELECT acc_pid FROM new_loops_activity.gametok_user)
      AND event_name IN ('loading_page', 'session_start')
      AND server_time > now() - INTERVAL 40 DAY
),

open_retention AS (
    SELECT server_date, device_id
    FROM hab_events
    WHERE event_name IN ('loading_page', 'session_start')
),

new_user AS (
    SELECT *, (case when network = 'TikTok SAN' then 'TikTok'
            WHEN network = 'Unattributed' or network like '%Facebook%' or network like '%Instagram%'THEN 'FB'
             else network end) as network_type
    FROM new_loops_activity.gametok_user
    WHERE register_time1 > today() - 30
      AND is_guest = 1
    GROUP BY ALL
),

user_type as (
select create_time, to_uid, case when b.log_id is null then 'invite' else 'minihub' end as type from
(select * from new_loops_activity.link_report_invite_log
   where source <> 'Default'
   and result ='SUCCESS')a left join
(select toUInt64(invite_log_id) as log_id FROM new_loops_activity.link_kol_log group by 1)b on a.id = b.log_id
),

pk AS (
    SELECT
        t1.acc_pid,
        min(t.create_time) AS first_finish
    FROM rings_broadcast.pk_player_record t
    INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid
        FROM new_loops_activity.gametok_user
    ) t1
        ON t.player_id = t1.acc_uid
    WHERE t.status IN ('fighting', 'gameover')
      AND t.create_time > now() - INTERVAL 30 DAY
    GROUP BY t1.acc_pid
),

main AS (
    SELECT
        toDate(toTimeZone(t1.register_time1, 'Asia/Singapore')) AS register_date,
        country,
        COALESCE(
    NULLIF(type, ''),
    NULLIF(network_type, ''),
    'others'
) AS source,
        t1.acc_pid
    FROM new_user t1
    -- LEFT JOIN pk t2 ON t1.acc_pid = t2.acc_pid
    -- WHERE t2.first_finish >= t1.register_time1
    --   AND t2.first_finish < addHours(t1.register_time1, 24)
	left join 
	user_type t2 on t1.acc_uid = t2.to_uid
    GROUP BY ALL
),

base AS (
    SELECT
        t1.register_date AS date,
        t1.country AS country,
        ifNull(t1.source, 'null') AS source,
        countDistinct(t1.acc_pid) AS cohort_size,
        countDistinct(t2.device_id) AS d1_cnt,
        countDistinct(t3.device_id) AS d3_cnt,
        countDistinct(t4.device_id) AS d7_cnt
    FROM main AS t1
    LEFT JOIN open_retention AS t2
        ON t1.acc_pid = t2.device_id AND t2.server_date = t1.register_date + INTERVAL 1 DAY
    LEFT JOIN open_retention AS t3
        ON t1.acc_pid = t3.device_id AND t3.server_date = t1.register_date + INTERVAL 3 DAY
    LEFT JOIN open_retention AS t4
        ON t1.acc_pid = t4.device_id AND t4.server_date = t1.register_date + INTERVAL 7 DAY
    GROUP BY 1,2,3
)

-- SELECT
--     date,
--     country,
--     source,
--     d1_cnt / cohort_size AS value,
--     'd1' AS day
-- FROM base

-- UNION ALL
-- SELECT
--     date,
--     country,
--     source,
--     d3_cnt / cohort_size AS value,
--     'd3' AS day
-- FROM base

-- UNION ALL
SELECT
    date,
    country,
    source,
	d1_cnt as numerator,
	cohort_size as denominator,
    d1_cnt / cohort_size AS value
    -- 'd7' AS day
FROM base
where date > '2026-01-17'
;

