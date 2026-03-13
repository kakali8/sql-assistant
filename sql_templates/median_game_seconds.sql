-- metric_id: median_game_seconds
-- metric_name: Challenge游戏时长中位数
-- card_name: Median game seconds
-- card_id: 3228
-- dashboard: L2 (id=522)
-- business_domain: Daily Challenge
-- owner: product, ops
-- definition: 每日KiX challeng游戏时长
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_activity, rings_broadcast.pk_player_record
-- events_used: 
--
-- [SQL]
WITH
challenge AS
(
    SELECT DISTINCT
        pk_id,
        game_id,
        toDateTime(activity_start_time / 1000, 'Asia/Singapore') AS event_time,
        toDate(
            toDateTime(activity_start_time / 1000, 'Asia/Singapore')
            - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
        ) AS biz_date
    FROM rings_broadcast.pk_activity FINAL
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL
      AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) in (17,21)
),

player_end AS
(
    SELECT
        t.pk_id,
        toDate(
            toDateTime(t.create_time, 'Asia/Singapore')
            - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
        ) AS biz_date,
        u.acc_pid AS acc_pid,

        /* 取 user_status_log 按 curTimeMs 排序后的最后一个 raw item */
        arrayElement(
            arraySort(
                x -> JSONExtractInt(x, 'curTimeMs'),
                JSONExtractArrayRaw(ifNull(t.user_status_log, '[]'))
            ),
            length(JSONExtractArrayRaw(ifNull(t.user_status_log, '[]')))
        ) AS last_raw,

        /* 最后状态与最后时间（毫秒） */
        JSONExtractString(last_raw, 'userStatus') AS final_user_status,
        JSONExtractInt(last_raw, 'curTimeMs')     AS final_curTimeMs,

        /* 把 update_time（Unix秒）和 curTimeMs（Unix毫秒）都转成 timestamp */
        toDateTime(t.update_time, 'Asia/Singapore') AS update_ts,
        toDateTime64(final_curTimeMs / 1000.0, 3, 'Asia/Singapore') AS cur_ts,

        /* 结束时间规则 */
        multiIf(
            final_user_status = 'fighting',  update_ts,
            final_user_status = 'gameover',  toDateTime(cur_ts),     -- 转成 DateTime 便于 dateDiff
            update_ts                                                      -- 兜底：其他状态先用 update
        ) AS end_time
    FROM rings_broadcast.pk_player_record AS t
    INNER JOIN
    (
        SELECT DISTINCT acc_uid, acc_pid
        FROM new_loops_activity.gametok_user
    ) AS u
        ON t.player_id = u.acc_uid
),

dur AS
(
    SELECT
        c.biz_date,
        c.game_id,
        c.pk_id,
        p.acc_pid,
        dateDiff('second', c.event_time, p.end_time) AS play_sec
    FROM challenge AS c
    INNER JOIN player_end AS p
        ON c.pk_id = p.pk_id
    WHERE p.end_time >= c.event_time
)

SELECT
    biz_date as date, t2.name as game_name,
    quantileExact(0.50)(play_sec) AS value
    -- quantileExact(0.90)(play_sec) AS p90_play_sec
FROM dur t1 left join 
(select app_id, name from loops_game.game_version_info) t2 on t1.game_id = t2.app_id
WHERE play_sec >= 0
GROUP BY biz_date,t2.name
ORDER BY biz_date;

