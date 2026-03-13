-- metric_id: from_waiting_to_start_match
-- metric_name: 赛事开玩率
-- card_name: From Waiting to Start Match
-- card_id: 3188
-- dashboard: CEO (id=518)
-- business_domain: Daily Challenge
-- owner: product, ops
-- definition: 进入候场后，最终成功开始比赛的用户 / 次数占比
-- description: 赛事开玩率是指在候场后，成功开始比赛的用户与总次数的比例，反映候场体验的流畅性。
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, rings_broadcast.pk_activity, rings_broadcast.pk_activity_appointment, rings_broadcast.pk_player_record
-- events_used: loading_page, session_start, waiting_room_page
--
-- [KEY FIELDS]
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
-- event: waiting_room_page
--   desc: 候场页面
--   raw_notes: type 1-进入页面 2-点击按钮 status 1-能量值>0 2-能量值=0"
--
-- [SQL]
WITH challenge AS (
    SELECT DISTINCT
        pk_id,
        toDateTime(activity_start_time / 1000, 'Asia/Singapore') AS event_time,
        toDate(
            toDateTime(activity_start_time / 1000, 'Asia/Singapore')
        ) AS biz_date
    FROM rings_broadcast.pk_activity final
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) in (17,21)
),
participated AS (
    select 
	pk_id,biz_date,acc_pid,status AS last_status,
	arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
    arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
	from
	(SELECT 
	    pk_id,
		toDate(
            toDateTime(create_time, 'Asia/Singapore')
        ) AS biz_date,
        t1.acc_pid AS acc_pid,
        t.status,arrayMap(
                    x -> JSONExtractString(x, 'userStatus'),
                    arraySort(
                            x -> JSONExtractInt(x, 'curTimeMs'),
                            JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
                    )
            ) as statuses
    FROM rings_broadcast.pk_player_record t
    INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid 
        FROM new_loops_activity.gametok_user
    ) t1 
        ON t.player_id = t1.acc_uid
		where pk_id in (
select pk_id FROM rings_broadcast.pk_activity 
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) in (17,21)
		)
		)
)
-- hab_events AS (
--     SELECT 
--         toDate(
--             toTimeZone(server_time,'Asia/Singapore')
--         ) AS biz_date,
-- 		-- COUNT(DISTINCT device_id) as dau
--         device_id,
--         event_name
--     FROM new_loops_activity.hab_app_events
--     WHERE event_name IN ('loading_page','session_start')
--       AND server_time > now() - INTERVAL 14 DAY
-- 	-- group by biz_date
-- ),
-- dau AS (
--     SELECT 
--         toDate(
--             toTimeZone(server_time,'Asia/Singapore')
--         ) AS biz_date,
-- 		COUNT(DISTINCT device_id) as dau
--         -- device_id,
--         -- event_name
--     FROM new_loops_activity.hab_app_events
--     WHERE event_name IN ('loading_page','session_start')
--       AND server_time > now() - INTERVAL 14 DAY
-- 	  -- and device_id not in (select acc_pid from new_loops_activity.gametok_user where register_date < '2026-01-18')   -- 排除内部账号
-- 	group by biz_date
-- ),
-- book AS ( 
-- SELECT  pk_id,
-- 		toDate(
--             toDateTime(create_time, 'Asia/Singapore')
--         ) AS biz_date,
--         t1.acc_pid AS acc_pid
-- 		FROM rings_broadcast.pk_activity_appointment t 
-- INNER JOIN
-- ( SELECT DISTINCT acc_uid, acc_pid FROM new_loops_activity.gametok_user ) t1 
-- ON t.user_id = t1.acc_uid where t.status='join' 
-- )
SELECT 
    m1.biz_date as date,
 --    COUNT(DISTINCT m2.acc_pid) AS denominator,
	-- COUNT(DISTINCT case when m2.last_status in ('fighting','gameover') or m2.stage_final_status in ('fighting','gameover')
 --        THEN m2.acc_pid END) AS numerator, numerator/denominator as value
		COUNT(DISTINCT case when m2.last_status in ('fighting','gameover') or m2.stage_final_status in ('fighting','gameover')
        THEN m2.acc_pid END)/COUNT(DISTINCT m2.acc_pid) as value
--    COUNT(DISTINCT CASE
--     WHEN m2.last_status = 'gameover' 
--          OR (m2.last_status = 'fighting' AND m2.stage_final_status NOT IN ('disconnect'))
--     THEN m2.acc_pid 
-- END) AS finish_kix_challenge_uv,

 --    1.0 * COUNT(DISTINCT h1.device_id)
 --    / NULLIF(COUNT(DISTINCT m2.acc_pid),0) AS participate_d1_retention,		-- 当天参与kc玩家，第二天登陆app留存率

	-- 1.0 * COUNT(DISTINCT m2.acc_pid)
 --    / NULLIF(max(h2.dau),0) AS dau_participate_rate,

	-- 1.0 * COUNT(DISTINCT m4.acc_pid)
 --    / NULLIF(COUNT(DISTINCT m2.acc_pid),0) AS repeat_participation_rate

FROM challenge AS m1
LEFT JOIN participated AS m2
    ON   m1.pk_id=m2.pk_id

	
WHERE m1.biz_date > '2026-01-17'
and m1.biz_date <=toDate(now('Asia/Singapore')) 
-- and m2.acc_pid not in (select acc_pid from new_loops_activity.gametok_user where register_date < '2026-01-18')
-- and h1.device_id not in (select acc_pid from new_loops_activity.gametok_user where register_date < '2026-01-18')
-- and m3.acc_pid not in (select acc_pid from new_loops_activity.gametok_user where register_date < '2026-01-18')
GROUP BY m1.biz_date
ORDER BY m1.biz_date;


























-- WITH
-- book AS
-- (
--     SELECT
--         pk_id,
--         user_id
--     FROM rings_broadcast.pk_activity_appointment
--     WHERE create_time > now() - INTERVAL 32 DAY
-- ),

-- enter as (
-- select toDate(toTimeZone(server_time,'Asia/Singapore')) AS date, 
-- 		user_id,
-- from new_loops_activity.hab_app_events where event_name = 'waiting_room_page'
-- ),

-- kc AS
-- (
--     SELECT
--         pk_id,
--         player_id,
--         toDate(toTimeZone(create_time,'Asia/Singapore')) AS date,
--         arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
--         arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect,
--         status AS last_status
--     FROM
--     (
--         SELECT
--             pk_id,
--             player_id,
--             status,
--             create_time,
--             arrayMap(
--                 x -> JSONExtractString(x, 'userStatus'),
--                 arraySort(
--                     x -> JSONExtractInt(x, 'curTimeMs'),
--                     JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
--                 )
--             ) AS statuses
--         FROM rings_broadcast.pk_player_record
--         WHERE _is_deleted = 0
--           AND create_time > now() - INTERVAL 30 DAY
--           AND pk_id IN (
--               SELECT pk_id
--               FROM rings_broadcast.pk_activity
--               WHERE title = 'Challenge' and activity_info_id is not null
--           )
--     )
-- )

-- SELECT
--     t1.date,
--     -- b.pk_id,
--     -- countDistinct(b.user_id) AS booked_uv,
--     -- countDistinctIf(
--     --     b.user_id,
--     --     (k.last_status IN ('fighting','gameover')
--     --      OR k.stage_final_status IN ('fighting','gameover'))
--     -- ) AS joined_uv,
-- 	countDistinctIf(
--         t1.user_id,
--         (t2.last_status IN ('fighting','gameover')
--          OR t2.stage_final_status IN ('fighting','gameover'))
--     )/countDistinct(t1.user_id) as value
-- FROM enter t1
-- LEFT JOIN kc t2
--     ON t1.date=t2.date
--    AND t1.user_id = t2.player_id
--    where date > '2026-01-17'
-- GROUP BY
--     t1.date
-- ORDER BY
--     t1.date;










-- with book as
-- (select pk_id, count(distinct user_id) as booked_uv from rings_broadcast.pk_activity_appointment where create_time > now() - interval 32 day group by pk_id),
-- kc as 
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
--         WHERE _is_deleted = 0 and create_time > now() - interval 30 day
-- 		and pk_id in (select pk_id FROM rings_broadcast.pk_activity WHERE title = 'Challenge')
--         ))

-- select date, t1.pk_id, booked_uv, joined_uv from 
-- (select date, pk_id, count(distinct case when last_status in ('fighting','gameover') or stage_final_status in ('fighting','gameover') then player_id else null end) as joined_uv from kc group by pk_id, date) t1 
-- left join book t2 on t1.pk_id = t2.pk_id
-- order by date desc

