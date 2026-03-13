-- metric_id: average_meaningful_battles_per_user
-- metric_name: 人均成功 PK 次数（活跃用户）
-- card_name: Average Meaningful Battles Per User
-- card_id: 3190
-- dashboard: CEO (id=518)
-- business_domain: Platform Basics
-- owner: product, ops
-- definition: 活跃用户在统计周期内，平均成功完成的 PK 场次
-- evaluation: display_only
-- related_metrics: pk_successful_matching, pk_click_to_enter, pk_enter_to_ready, pk_ready_to_start, pk_start_to_finish
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, rings_broadcast.pk_activity, rings_broadcast.pk_match, rings_broadcast.pk_player_record
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
kc AS
(
    SELECT
        pk_id,
        player_id,
        toDate(toTimeZone(create_time,'Asia/Singapore')) AS date,

        arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
        status AS last_status
    FROM
    (
        SELECT
            pk_id,
            player_id,
            status,
            create_time,
            arrayMap(
                x -> JSONExtractString(x, 'userStatus'),
                arraySort(
                    x -> JSONExtractInt(x, 'curTimeMs'),
                    JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
                )
            ) AS statuses
        FROM rings_broadcast.pk_player_record
        WHERE _is_deleted = 0
          AND create_time > now() - INTERVAL 3 DAY
    )
group by 1,2,3,4,5),

m AS
(
    SELECT
        id,
        mode,
        cast(session_id as Int32) - 100000 AS game_id
    FROM rings_broadcast.pk_match
    GROUP BY id, mode, game_id
),

challenge AS
(
    SELECT pk_id
    FROM rings_broadcast.pk_activity
    WHERE title = 'Challenge'
    GROUP BY pk_id
),
dau as 
(SELECT
        toDate(toTimeZone(server_time, 'Asia/Shanghai')) AS date, count(distinct device_id) as uv
    FROM new_loops_activity.hab_app_events
    WHERE user_id IN (SELECT acc_uid FROM new_loops_activity.gametok_user) and server_time > now() - INTERVAL 30 DAY  and event_name in ('session_start','loading_page')
    GROUP BY date order by date)

select t1.date, t1.numerator/t2.uv as value from
(SELECT
    kc.date as date,
    countIf(kc.last_status = 'gameover' OR kc.stage_final_status = 'gameover') AS numerator
FROM kc
LEFT JOIN m ON kc.pk_id = m.id
LEFT JOIN challenge c ON kc.pk_id = c.pk_id
WHERE c.pk_id IS NULL
GROUP BY
    kc.date)t1 left join 
dau t2 on t1.date = t2.date
ORDER BY
    t1.date DESC;

















