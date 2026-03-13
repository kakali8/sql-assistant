-- metric_id: normal_popup_click
-- metric_name: 普通商业化弹窗点击
-- card_name: Normal Popup Click
-- card_id: 3359
-- dashboard: L2 (id=522)
-- business_domain: Revenue
-- owner: product
-- definition: 各类型普通商业化弹窗点击率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.kix_web_events
-- events_used: monetization_popup
--
-- [KEY FIELDS]
-- event: monetization_popup
--   desc: 普通商业化弹窗
--   raw_notes: type 1-展示 2-点击 status 1-pk结束退出 2-单机游戏模式结束退出 status_user 用户分层 1-tier 1 2-tier 2 3-tier 3 number 弹窗种类 1-ad 2-invite 3-充值coins 4-充值energy second_diff:<float> 记录rebate数量,可以为小数
--
-- [SQL]
WITH
    toDateTime('2026-02-28 16:00:00') AS start_ts,

    new_user AS
        (
            SELECT
                acc_uid,
                register_time1
            FROM new_loops_activity.gametok_user
        ),

    base AS
        (
            SELECT
                e.user_id,
                e.server_time,
                toDate(toTimeZone(e.server_time, 'Asia/Singapore')) AS dt_sg,
                e.number AS popup_kind,
                e.type,
                e.s_ts,
                u.register_time1,
                (u.acc_uid IS NOT NULL
                    AND e.server_time >= u.register_time1
                    AND dateDiff('day', u.register_time1, e.server_time) < 7) AS is_new_user
            FROM new_loops_activity.kix_web_events e
                     LEFT JOIN new_user u
                               ON e.user_id = u.acc_uid
            WHERE e.event_name = 'monetization_popup'
              AND e.server_time > start_ts
              AND e.s_ts IS NOT NULL
              AND e.type IN (1, 2)
        ),

    first_popup AS
        (
            SELECT
                user_id,
                min(server_time) AS first_time
            FROM base
            WHERE is_new_user
            GROUP BY user_id
        )

SELECT
    b.dt_sg as date,
    -- b.popup_kind,
    multiIf(
            b.popup_kind = 1, 'ad',
            b.popup_kind = 2, 'invite',
            b.popup_kind = 3, 'coins',
            b.popup_kind = 4, 'energy',
            'others'
    ) AS popup_type,

    multiIf(
            b.is_new_user AND b.server_time = f.first_time,
            'new_user_first',
            'others'
    ) AS segment,

    uniqExactIf(b.s_ts, b.type = 1) AS denominator,
    uniqExactIf(b.s_ts, b.type = 2) AS numerator,
    ifNull(numerator / nullIf(denominator, 0), 0) AS value
FROM base b
         LEFT JOIN first_popup f
                   ON b.user_id = f.user_id
GROUP BY
    b.dt_sg,
    -- b.popup_kind,
    popup_type,
    segment
ORDER BY
    b.dt_sg desc,
    -- b.popup_kind,
    segment;
