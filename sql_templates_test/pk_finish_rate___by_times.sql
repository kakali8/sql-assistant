-- metric_id: pk_finish_rate___by_times
-- metric_name: 
-- card_name: PK Finish Rate - by times
-- card_id: 3185
-- dashboard: CEO (id=518)
-- business_domain: 
-- owner: 
-- definition: 
-- evaluation: 
-- related_metrics: 
-- source_tables: rings_broadcast.pk_activity, rings_broadcast.pk_match, rings_broadcast.pk_player_record
-- events_used: 
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
)

SELECT
    kc.date as date,
    m.mode as mode,

    countIf(kc.last_status = 'gameover' OR kc.stage_final_status = 'gameover') AS numerator,
    count() AS denominator,
    numerator / denominator AS value
FROM kc
LEFT JOIN m ON kc.pk_id = m.id
LEFT JOIN challenge c ON kc.pk_id = c.pk_id
WHERE c.pk_id IS NULL
GROUP BY
    kc.date, m.mode
ORDER BY
    kc.date DESC;










-- select date, mode, 
-- -- t3.name as game_id, 
-- -- count(distinct player_id) as entered_uv, count(distinct case when last_status in ('fighting','gameover') or stage_final_status in ('fighting','gameover') then player_id else null end) as started_uv,
-- count(case when last_status = 'gameover' or stage_final_status = 'gameover' then player_id else null end) as numerator,
-- count(player_id) as denominator,
-- count(case when last_status = 'gameover' or stage_final_status = 'gameover' then player_id else null end)/count(player_id) as value
-- from
-- (SELECT
--     pk_id,
--     player_id,
-- 	date,
--     arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
--     arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect,
--     status AS last_status
-- FROM
--     (
--         SELECT
--             pk_id,
--             player_id,
--             status,
-- 			toDate(toTimeZone(create_time,'Asia/Singapore')) as date,
--             arrayMap(
--                     x -> JSONExtractString(x, 'userStatus'),
--                     arraySort(
--                             x -> JSONExtractInt(x, 'curTimeMs'),
--                             JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
--                     )
--             ) AS statuses
--         FROM rings_broadcast.pk_player_record
--         WHERE _is_deleted = 0 and create_time > now() - interval 3 day
--         ) group by all) t1 
-- 		left join (select id, mode, cast(session_id as int) - 100000 as game_id from rings_broadcast.pk_match group by 1,2,3)t2 on t1.pk_id = t2.id
-- 		-- left join (select app_id, name from loops_game.game_version_info group by 1,2) t3 on t2.game_id = t3.app_id
-- 		where pk_id not in (select pk_id FROM rings_broadcast.pk_activity WHERE title = 'Challenge')
-- group by date, mode 
-- order by date desc;








