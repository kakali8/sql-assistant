-- metric_id: normal_ad_popup_get_energy
-- metric_name: 普通广告弹窗energy获取
-- card_name: Normal Ad Popup Get Energy
-- card_id: 3358
-- dashboard: L2 (id=522)
-- business_domain: Revenue
-- owner: product
-- definition: 普通弹窗中看广告获得energy的情况
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, new_loops_activity.kix_web_events
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
            toDate(toTimeZone(e.server_time,'Asia/Singapore')) AS dt_sg,
            e.type,
            e.s_ts,
            u.register_time1,
            (u.acc_uid IS NOT NULL
                AND e.server_time >= u.register_time1
                AND dateDiff('day',u.register_time1,e.server_time) < 7) AS is_new_user
        FROM new_loops_activity.kix_web_events e
        LEFT JOIN new_user u
            ON e.user_id = u.acc_uid
        WHERE e.event_name = 'monetization_popup'
          AND e.server_time > start_ts
          AND e.s_ts IS NOT NULL
          AND e.type IN (1,2)
          AND e.number = 1
    ),

    first_popup AS
    (
        SELECT
            user_id,
            min(server_time) AS first_time
        FROM base
        WHERE is_new_user
        GROUP BY user_id
    ),

    base_seg AS
    (
        SELECT
            b.*,
            multiIf(
                b.is_new_user AND b.server_time = f.first_time,
                'new_user_first',
                'others'
            ) AS segment
        FROM base b
        LEFT JOIN first_popup f
            ON b.user_id = f.user_id
    ),

    /* energy 按用户 + 日期聚合 */
    energy_day AS
    (
        SELECT
            uid AS user_id,
            toDate(toTimeZone(create_time,'Asia/Singapore')) AS dt_sg,
            count() AS energy
        FROM new_loops_activity.energy_log
        WHERE source IN ('watch_by_other_win')
          AND create_time > start_ts
        GROUP BY uid, dt_sg
    )

SELECT
    bs.dt_sg as date,
    -- bs.segment,

    -- uniqExactIf(bs.s_ts, bs.type = 1) AS denominator,
    -- uniqExactIf(bs.s_ts, bs.type = 2) AS numerator,

    -- uniqExactIf(bs.user_id, bs.type = 1) AS show_uv,
    uniqExactIf(bs.user_id, bs.type = 2) AS denominator,

    -- sumIf(ed.energy, bs.type = 2) AS energy,
    uniqExactIf(ed.user_id, bs.type = 2) AS numerator,

    -- ifNull(click_uv / nullIf(show_uv,0),0) AS ctr,
    -- ifNull(energy_uv / nullIf(click_uv,0),0) AS click_to_energy,
    -- ifNull(energy_uv / nullIf(show_uv,0),0) AS show_to_energy

	numerator/denominator as value

FROM base_seg bs
LEFT JOIN energy_day ed
    ON bs.user_id = ed.user_id
   AND bs.dt_sg = ed.dt_sg

where segment not in ('new_user_first')

GROUP BY
    bs.dt_sg


ORDER BY
    bs.dt_sg DESC
;
