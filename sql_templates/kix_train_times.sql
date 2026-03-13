-- metric_id: kix_train_times
-- metric_name: 赛前人均游玩次数
-- card_name: KiX train times
-- card_id: 3200
-- dashboard: CEO (id=518)
-- business_domain: Daily Challenge
-- owner: product, ops, marketing
-- definition: 开赛前24h比赛游戏游玩人均次数
-- description: 赛前人均游玩次数的指标
-- evaluation: higher_is_better
-- related_metrics: median_game_seconds, score_zero_user
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.newgame_room_log, rings_broadcast.pk_activity, rings_broadcast.pk_match, rings_broadcast.pk_player_record
-- events_used: 
--
-- [SQL]
WITH
pc AS (
    SELECT DISTINCT
        toDate(
            toDateTime(a.activity_start_time / 1000, 'Asia/Singapore')
            - INTERVAL 21 HOUR
            -- - INTERVAL 30 MINUTE
        ) AS date,
        a.game_id,
        c.name,
        toDateTime(a.activity_start_time / 1000, 'Asia/Singapore') - INTERVAL 21 HOUR
            -- - INTERVAL 30 MINUTE 
			AS activity_start_time
    FROM rings_broadcast.pk_activity a
    LEFT JOIN (
        SELECT app_id, name
        FROM loops_game.game_version_info
    ) c
        ON (toInt64(a.session_id) - 100000) = toInt64(c.app_id)
    WHERE a.title = 'Challenge'
      AND a.activity_info_id IS NOT NULL
      AND a.pk_id IS NOT NULL
),

pc_user AS (
    SELECT DISTINCT
        t.date AS date,
        t.game_id AS game_id,
        t.name AS game_name,
        t2.pk_id AS pk_id,
        t3.acc_pid AS pid,
        t2.create_time AS play_time,
        t2.mode AS mode
    FROM pc t
    INNER JOIN (
        SELECT DISTINCT
            pk_mode_config,
            toDateTime(create_time, 'Asia/Singapore') - INTERVAL 21 HOUR
            -- - INTERVAL 30 MINUTE 
			AS create_time,
            id
        FROM rings_broadcast.pk_match
    ) t1
        ON JSONExtractInt(t1.pk_mode_config, 'gameId') = t.game_id
    LEFT JOIN (
        SELECT DISTINCT
            player_id,
            pk_id,
            toDateTime(create_time, 'Asia/Singapore') - INTERVAL 17 HOUR
            -- - INTERVAL 30 MINUTE 
			AS create_time,
            mode
        FROM rings_broadcast.pk_player_record
    ) t2
        ON t1.id = t2.pk_id
    INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid
        FROM new_loops_activity.gametok_user
    ) t3
        ON t2.player_id = t3.acc_uid
    WHERE t1.create_time >= (t.activity_start_time - INTERVAL 24 HOUR)
      AND t1.create_time <  t.activity_start_time
      AND t2.create_time >= (t.activity_start_time - INTERVAL 24 HOUR)
      AND t2.create_time <  t.activity_start_time
)
select * from(
SELECT
    date,
    game_id,name as game_name,
	'normal' as mode,
	sum(train_times) as  numerator,
	count(distinct acc_pid) as denominator, 
    sum(train_times) /count(distinct acc_pid) AS  value
FROM
(
    SELECT
        toDate(toTimeZone(s1.enter_time, 'Asia/Singapore')- INTERVAL 21 HOUR
            )+1 AS date,
        s1.game_id AS game_id,name,
        s2.acc_pid AS acc_pid,
        count(distinct s1.room_id) AS train_times
    FROM new_loops_activity.newgame_room_log s1
    INNER JOIN new_loops_activity.gametok_user s2
        ON s1.uid = s2.acc_uid
    inner JOIN pc
        ON pc.game_id = s1.game_id
    WHERE  s1.enter_time- INTERVAL 21 HOUR >= (pc.activity_start_time - INTERVAL 24 HOUR)
      AND s1.enter_time - INTERVAL 21 HOUR <  pc.activity_start_time
    GROUP BY
        date,
        game_id,
        acc_pid,name
)
GROUP BY
    date,
    game_id,mode,name
	union all
SELECT 
    date,
    game_id,
    game_name,
    mode,
    --COUNT(DISTINCT pk_id) AS pk_cnt,
    COUNT(DISTINCT pk_id, pid) AS numerator,
    COUNT(DISTINCT pid) AS denominator,
    ROUND( numerator/ denominator, 2) AS value
FROM pc_user
GROUP BY date, game_id,game_name,mode)
ORDER BY date DESC, game_name, mode DESC;
