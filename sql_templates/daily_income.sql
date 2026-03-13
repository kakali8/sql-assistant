-- metric_id: daily_income
-- metric_name: 总收入
-- card_name: Daily income
-- card_id: 3177
-- dashboard: CEO (id=518)
-- business_domain: Revenue
-- owner: ceo, ops
-- definition: 所有收入汇总
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: loops_billing.topup, new_loops_activity.energy_log, new_loops_activity.gametok_user, new_loops_activity.hab_app_events
-- events_used: 
--
-- [SQL]
WITH
-- device & user mapping
device AS (
    SELECT
        acc_uid,
        acc_pid AS pi
    FROM new_loops_activity.gametok_user
    GROUP BY acc_uid, acc_pid
),

-- IAP Topup
topup AS (
    SELECT
        toDate(toTimeZone(createdOn, 'Asia/Shanghai')) AS date,
        userId,
        sum(toFloat64(price)) AS usd
    FROM loops_billing.topup
    WHERE userId IN (SELECT acc_uid FROM device)
      AND createdOn > now() - INTERVAL 30 DAY
    GROUP BY date, userId
),

-- Ad income
ad AS (
    SELECT
        date,
        'iaa' AS type,
        -- countDistinctIf(pi, pi IS NOT NULL) AS uv,
        sum(energy) / 1000 * 1 AS usd
    FROM (
        SELECT
            toDate(toTimeZone(create_time, 'Asia/Shanghai')) AS date,
            uid,
            energy
        FROM new_loops_activity.energy_log
        WHERE create_time > now() - INTERVAL 30 DAY
          AND source in ('watch_ad', 'watch_ad_outside','watch_by_other_win')
          AND uid IN (SELECT acc_uid FROM device)
    ) a
    LEFT JOIN device b
        ON a.uid = b.acc_uid
    GROUP BY date
),

-- Topup summary
topup_summary AS (
    SELECT
        t1.date AS date,
        'iap' AS type,
        -- countDistinct(pi) AS uv,
        sum(t1.usd) AS value
    FROM topup t1
    LEFT JOIN device t3
        ON t1.userId = t3.acc_uid
    GROUP BY t1.date
)

SELECT *
FROM topup_summary
where date > '2026-01-17'

UNION ALL

SELECT *
FROM ad
where date > '2026-01-17'
order by date
;



















-- WITH
-- -- device & user mapping（先定义）
-- device AS (
--     SELECT
--         acc_uid,
--         acc_pid AS pi
--     FROM new_loops_activity.gametok_user
--     GROUP BY acc_uid, acc_pid
-- ),

-- -- active dates
-- active_users AS (
--     SELECT
--         toDate(toTimeZone(server_time, 'Asia/Shanghai')) AS date
--     FROM new_loops_activity.hab_app_events
--     WHERE user_id IN (SELECT acc_uid FROM device) and server_time > now() - INTERVAL 30 DAY
--     GROUP BY date
-- ),

-- -- IAP Topup
-- topup AS (
--     SELECT
--         toDate(toTimeZone(createdOn, 'Asia/Shanghai')) AS date,
--         userId,
--         sum(toFloat64(price)) AS usd
--     FROM loops_billing.topup
--     WHERE userId IN (SELECT acc_uid FROM device)
--       AND createdOn > now() - INTERVAL 30 DAY
--     GROUP BY date, userId
-- ),

-- -- Energy Topup
-- -- energy_topup AS (
-- --     SELECT
-- --         toDate(toTimeZone(create_time, 'Asia/Shanghai')) AS server_date,
-- --         uid,
-- --         countDistinctIf(id, source IN ('first_topup', 'normal_topup')) AS purchase_times,
-- --         countDistinctIf(id, source IN ('first_topup', 'normal_topup')) * 0.99 AS energy_usd
-- --     FROM new_loops_activity.energy_log
-- --     WHERE create_time > now() - INTERVAL 30 DAY
-- --       AND source IN ('first_topup', 'normal_topup')
-- --       AND uid IN (SELECT acc_uid FROM device)
-- --     GROUP BY server_date, uid
-- -- ),

-- -- Ad income
-- ad AS (
--     SELECT
--         date, 'iaa' as type
--         countDistinct(pi) AS uv,
--         -- sum(energy) AS ad_times,
--         sum(energy) / 1000 * 13 AS usd
--     FROM (
--         SELECT
--             toDate(toTimeZone(create_time, 'Asia/Shanghai')) AS date,
--             uid,
--             energy
--         FROM new_loops_activity.energy_log
--         WHERE create_time > now() - INTERVAL 30 DAY
--           AND source = 'watch_ad'
--           AND uid IN (SELECT acc_uid FROM device)
--     ) a
--     LEFT JOIN device b ON a.uid = b.acc_uid
--     GROUP BY server_date
-- ),

-- -- Topup summary
-- topup_summary AS (
--     SELECT
--         t1.date as date, 'iap' as type
--         countDistinct(pi) AS uv,
--         -- countDistinctIf(pi, t2.uid IS NOT NULL) AS energy_topup_uv,
--         -- countDistinctIf(pi, t1.usd > ifNull(t2.energy_usd, 0)) AS iap_uv,
--         -- sum(ifNull(t2.energy_usd, 0)) AS energy_topup_usd,
--         -- sum(t1.usd) - sum(ifNull(t2.energy_usd, 0)) AS iap_topup_usd,
-- 		sum(t1.usd)
--     FROM topup t1
--     -- LEFT JOIN energy_topup t2
--     --     ON t1.userId = t2.uid
--     --    AND t1.date = t2.server_date
--     LEFT JOIN device t3
--         ON t1.userId = t3.acc_uid
--     GROUP BY t1.date
-- )

-- SELECT *
--     -- t1.date,
--     -- t2.topup_uv,
--   --   t2.iap_uv as iap_tpu,
--   --   t2.energy_topup_uv as energy_tpu,
--   --   t2.iap_topup_usd as iap_topup_usd,
--   --   t2.energy_topup_usd as energy_topup_usd,
--   --   t3.ad_uv as iaa_uv,
--   --   t3.estimate_ad_usd as iaa_usd,
--   --   ifNull(t2.energy_topup_usd, 0)
--   -- + ifNull(t2.iap_topup_usd, 0)
--   -- + ifNull(t3.estimate_ad_usd, 0) AS total_income
-- FROM topup_summary union ad
-- ORDER BY date DESC;

