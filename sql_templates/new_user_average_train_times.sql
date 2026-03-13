-- metric_id: new_user_average_train_times
-- metric_name: 新用户平均练习challenge游戏次数
-- card_name: New User Average Train Times
-- card_id: 3322
-- dashboard: L2 (id=522)
-- business_domain: Daily Challenge
-- owner: marketing, product
-- definition: 指标定义
-- description: 平均各国用户练习次数
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, rings_broadcast.pk_activity
-- events_used: 
--
-- [SQL]
    WITH
New_user AS (
SELECT
    toDate(
    toDateTime(register_time1, 'Asia/Singapore')
    - INTERVAL 21 HOUR
    ) AS date, country,
    acc_pid,
    acc_uid
FROM new_loops_activity.gametok_user where register_time1 > now() - interval 14 day
group by 1,2,3,4),

    challenge AS (
SELECT DISTINCT
    game_id,
--     toDateTime(activity_start_time / 1000, 'Asia/Singapore') AS event_time,
    toDate(
    toDateTime(activity_start_time / 1000, 'Asia/Singapore')
    - INTERVAL 21 HOUR
    ) AS date
FROM rings_broadcast.pk_activity FINAL
WHERE title = 'Challenge' and create_time > now() - interval 14 day
  AND activity_info_id IS NOT NULL AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) in (17,21)
    ),
play as (
    select
        game_id, acc_pid, toDate(
            toDateTime(create_time, 'Asia/Singapore')
                - INTERVAL 21 HOUR
                    ) AS date, sum(abs(energy)) as play_times
    from new_loops_activity.energy_log INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid, country
        FROM new_loops_activity.gametok_user where register_time1 > now() - interval 14 day
        ) t1 on energy_log.uid = t1.acc_uid
    where source in ('play_once','buy_once') and create_time > now() - interval 14 day
    group by 1,2,3
)

SELECT
t1.date as date, country, count(distinct t3.acc_pid) as denominator, sum(play_times) as numerator, numerator/denominator as value
FROM New_user AS t1
left join challenge t2 on t1.date = t2.date - interval 1 day
left join play t3 on t1.date=t3.date and t2.game_id=t3.game_id and t1.acc_pid = t3.acc_pid
    group by 1,2 having denominator > 0 
	-- and date <= '2026-03-05'
;
