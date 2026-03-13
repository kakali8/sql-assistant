-- metric_id: pk_ready_to_start
-- metric_name: PK成功开玩率
-- card_name: PK ready to start
-- card_id: 3233
-- dashboard: L2 (id=522)
-- business_domain: PK
-- owner: ops, product
-- definition: PK 准备 → 成功开玩
-- description: 关注重点: 开玩率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_activity, rings_broadcast.pk_match, rings_broadcast.pk_player_record
-- events_used: 
--
-- [SQL]
WITH pk AS (
    SELECT DISTINCT
        id AS pk_id,
        toDate(toDateTime(create_time, 'Asia/Singapore')) AS date
    FROM rings_broadcast.pk_match FINAL
    WHERE id NOT IN (
        SELECT pk_id
        FROM rings_broadcast.pk_activity FINAL
        WHERE title = 'Challenge'
    )
),

participated AS (
    SELECT
        pk_id,
        date,
        acc_pid,
        status AS last_status,
        arrayMap(
            x -> JSONExtractString(x, 'userStatus'),
            arraySort(
                x -> JSONExtractInt(x, 'curTimeMs'),
                JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
            )
        ) AS statuses,
        arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
        arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
    FROM
    (
        SELECT
            pk_id,
            toDate(toDateTime(create_time, 'Asia/Singapore')) AS date,
            t1.acc_pid AS acc_pid,
            t.status,
            user_status_log
        FROM rings_broadcast.pk_player_record AS t
        INNER JOIN (
            SELECT DISTINCT acc_uid, acc_pid
            FROM new_loops_activity.gametok_user
        ) AS t1
            ON t.player_id = t1.acc_uid
    ) sub
)

SELECT
    m1.date as date,
    -- countDistinct(m1.pk_id) AS no_of_pk,

    /* 参与 UV / PV */
    -- countDistinct(m2.acc_pid) AS pk_uv,
    -- countDistinct((m2.pk_id, m2.acc_pid)) AS denominator

    /* ✅ accepted：进入PK（按最终状态）UV / PV */
    -- countDistinctIf(m2.acc_pid, (m2.last_status IN ('accepted','ready','fighting','gameover'))
    --     OR (m2.stage_final_status IN ('accepted','ready','fighting','gameover'))) AS enter_pk_uv,
    -- countDistinctIf((m2.pk_id, m2.acc_pid), (m2.last_status IN ('accepted','ready','fighting','gameover'))
    --     OR (m2.stage_final_status IN ('accepted','ready','fighting','gameover'))) AS denominator,


    /* ✅ ready：准备状态（按最终状态）UV / PV */
    -- countDistinctIf(m2.acc_pid, (m2.last_status IN ('ready','fighting','gameover'))
    --     OR (m2.stage_final_status IN ('ready','fighting','gameover'))) AS ready_pk_uv,
    countDistinctIf((m2.pk_id, m2.acc_pid), (m2.last_status IN ('ready','fighting','gameover'))
        OR (m2.stage_final_status IN ('ready','fighting','gameover'))) AS denominator,

    /* 已开始 UV / PV */
    -- countDistinctIf(
    --     m2.acc_pid,
    --     (m2.last_status IN ('fighting','gameover'))
    --     OR (m2.stage_final_status IN ('fighting','gameover'))
    -- ) AS pk_started_uv,
    countDistinctIf(
        (m2.pk_id, m2.acc_pid),
        (m2.last_status IN ('fighting','gameover'))
        OR (m2.stage_final_status IN ('fighting','gameover'))
    ) AS numerator,

    /* 完成 UV / PV */
    -- countDistinctIf(
    --     m2.acc_pid,
    --     (m2.last_status = 'gameover')
    --     OR (m2.last_status = 'fighting' AND NOT m2.has_disconnect)
    -- ) AS finish_pk_uv,
    -- countDistinctIf(
    --     (m2.pk_id, m2.acc_pid),
    --     (m2.last_status = 'gameover')
    --     OR (m2.last_status = 'fighting' AND NOT m2.has_disconnect)
    -- ) AS finish_pk_pv

	numerator/denominator as value

FROM pk AS m1
LEFT JOIN participated AS m2
    ON m1.pk_id = m2.pk_id
WHERE m1.date > '2026-01-17'
  AND m1.date <= toDate(now('Asia/Singapore'))
GROUP BY m1.date
ORDER BY m1.date;











-- WITH pk AS (
--     SELECT DISTINCT
--         id as pk_id,
--         toDate(
--             toDateTime(create_time, 'Asia/Singapore')
--         ) AS date
--     FROM rings_broadcast.pk_match final
--     WHERE id not in (
-- select pk_id FROM rings_broadcast.pk_activity final
--     WHERE title = 'Challenge'
-- 	)
-- ),
-- participated AS (
--     select 
-- 	pk_id,date,acc_pid,status AS last_status,
-- 	arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
--     arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
-- 	from
-- 	(SELECT 
-- 	    pk_id,
-- 		toDate(
--             toDateTime(create_time, 'Asia/Singapore')
--         ) AS date,
--         t1.acc_pid AS acc_pid,
--         t.status,arrayMap(
--                     x -> JSONExtractString(x, 'userStatus'),
--                     arraySort(
--                             x -> JSONExtractInt(x, 'curTimeMs'),
--                             JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
--                     )
--             ) as statuses
--     FROM rings_broadcast.pk_player_record t
--     INNER JOIN (
--         SELECT DISTINCT acc_uid, acc_pid 
--         FROM new_loops_activity.gametok_user
--     ) t1 
--         ON t.player_id = t1.acc_uid)
-- )

-- SELECT 
--     date,
--     COUNT(DISTINCT pk_id) AS pk_times,
--     COUNT(DISTINCT m2.acc_pid) AS pk_uv,
-- 	COUNT(DISTINCT case when m2.last_status in ('fighting','gameover') or m2.stage_final_status in ('fighting','gameover')
--         THEN m2.acc_pid END) AS pk_started_uv,
--    COUNT(DISTINCT CASE
--     WHEN m2.last_status = 'gameover' 
--          OR (m2.last_status = 'fighting' AND m2.stage_final_status NOT IN ('disconnect'))
--     THEN m2.acc_pid 
-- END) AS finish_pk_uv

-- FROM pk AS m1
-- LEFT JOIN participated AS m2
--     ON   m1.pk_id=m2.pk_id
-- WHERE m1.date > '2026-01-17'
-- and m1.date <=toDate(now('Asia/Singapore'))
-- GROUP BY m1.date
-- ORDER BY m1.date DESC;






