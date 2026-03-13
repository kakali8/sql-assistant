-- metric_id: high_balance_user
-- metric_name: 高余额用户
-- card_name: High balance user
-- card_id: 3384
-- dashboard: CEO (id=518)
-- business_domain: Revenue
-- owner: ceo, ops
-- definition: 高能量余额用户列表
-- evaluation: display_only
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.energy_user, rings_broadcast.pk_activity, rings_broadcast.pk_match, rings_broadcast.pk_tour
-- events_used: 
--
-- [SQL]
WITH energy_user AS
         (
             SELECT
                 uid,name,
                 energy
             FROM (select * from new_loops_activity.energy_user final)a left join (select id, name, register_time from rings_account.account final)b on a.uid = b.id where uid not in (2155126,2356671,2342639) and register_time > '2026-01-01 16:00:00'
         ),

     energy AS
         (
             SELECT
                 toDate(toTimeZone(a.create_time, 'Asia/Singapore')) AS date,
                 a.create_time,
                 a.uid,
                 b.pi AS pid,
                 a.from_source,
                 a.game_id,
                 a.pk_id
             FROM new_loops_activity.energy_log AS a
                      LEFT JOIN
                  (
                      SELECT id, pi
                      FROM rings_account.account
                      GROUP BY id, pi
                      ) AS b
                  ON a.uid = b.id
             WHERE a.source IN ('play_once', 'buy_once')
               AND toDate(toTimeZone(a.create_time, 'Asia/Singapore')) = toDate(now('Asia/Singapore'))
         ),

     challenge_game AS
         (
             SELECT DISTINCT
                 game_id,
                 pk_id,
                 toDate(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) AS date
             FROM rings_broadcast.pk_activity FINAL
             WHERE title = 'Challenge'
               AND create_time > now() - INTERVAL 30 DAY
               AND activity_info_id IS NOT NULL
               AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) IN (17, 21)
         ),

     tour_game AS
         (
             SELECT DISTINCT
                 a.game_id,
                 b.id AS pk_id,
                 a.tour_type,
                 toDate(toDateTime(a.tour_start_time / 1000, 'Asia/Singapore')) AS date
             FROM
                 (
                     SELECT *
                     FROM rings_broadcast.pk_tour
                     WHERE toDate(toDateTime(tour_start_time / 1000, 'Asia/Singapore')) >= toDate(now('Asia/Singapore') - INTERVAL 30 DAY)
                     ) a
                     LEFT JOIN
                 (
                     SELECT id, tour_id
                     FROM rings_broadcast.pk_match
                     ) b
                 ON a.id = b.tour_id
         ),

     energy_tagged AS
         (
             SELECT
                 e.uid as uid,
                 e.pid as pid,
                 multiIf(
                         tg.pk_id IS NOT NULL AND tg.tour_type = 'Daily',
                         'daily_tournament',

                         tg.pk_id IS NOT NULL AND tg.tour_type = 'RushHour',
                         'rush_hour',

                         tg.tour_type IS NULL AND cg_game.game_id IS NOT NULL,
                         'kix_challenge_practice',

                         'others'
                 ) AS game_type
             FROM energy e
                      LEFT JOIN tour_game tg
                                ON e.pk_id = tg.pk_id
                                    AND e.date = tg.date
                      LEFT JOIN challenge_game cg_game
                                ON e.game_id = cg_game.game_id
                                    AND e.date = cg_game.date
         )

,adh as (SELECT
    u.uid,u.name,
    u.energy as energy_balance,
    countIf(t.game_type = 'daily_tournament') AS daily_tournament_times,
    countIf(t.game_type = 'rush_hour') AS rush_hour_times,
    countIf(t.game_type = 'kix_challenge_practice') AS kix_challenge_practice_times,
    countIf(t.game_type = 'others') AS others_times,
    countIf(t.uid IS NOT NULL) AS total_energy_cost_times_today
FROM energy_user u
         LEFT JOIN energy_tagged t
                   ON u.uid = t.uid
GROUP BY
    u.uid,u.name,
    u.energy 
HAVING total_energy_cost_times_today > 0
ORDER BY
    u.energy DESC
	,total_energy_cost_times_today DESC
	)

select uid,name,energy_balance 
from adh

