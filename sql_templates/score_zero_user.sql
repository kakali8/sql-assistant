-- metric_id: score_zero_user
-- metric_name: 零分用户占比
-- card_name: Score zero user
-- card_id: 3230
-- dashboard: L2 (id=522)
-- business_domain: Daily Challenge
-- owner: product, ops
-- definition: 每日KiX challeng游戏分数
-- description: 零分占比
-- evaluation: lower_is_better
-- related_metrics: 
-- source_tables: rings_broadcast.pk_activity, rings_broadcast.pk_reward_log
-- events_used: 
--
-- [SQL]
WITH
score AS (
    SELECT
        pk_Id,
        user_id,
        score
    FROM rings_broadcast.pk_reward_log
    WHERE pk_Id IN (
        SELECT pk_id
        FROM rings_broadcast.pk_activity
        WHERE activity_info_id IS NOT NULL
          AND  toHour(toDateTime(activity_start_time / 1000)) in (9,13)
    ) and create_time > now() - interval 30 day
),
challenge AS (
SELECT
    pk_id,
    game_id,
    event_time,
    toDate(event_time) AS date
FROM
(
    SELECT
        pk_id,
        game_id,
        fromUnixTimestamp64Milli(activity_start_time, 'Asia/Singapore') AS event_time
    FROM rings_broadcast.pk_activity FINAL
    WHERE title = 'Challenge'
      AND activity_info_id IS NOT NULL
      AND toHour(toDateTime(activity_start_time / 1000))in (9,13)
)
where event_time < now()
and event_time > now() - interval 30 day
-- ORDER BY event_time DESC
-- LIMIT 1
),
game_score as (
SELECT
        date, user_id,
        score
FROM challenge t1
LEFT JOIN score t2
    ON t1.pk_id = t2.pk_Id
	where date > '2026-01-17'
	group by 1,2,3
)

SELECT
    date,
    -- cnt AS player_cnt,
    if(cnt = 0, 0, zero_cnt / cnt) AS value
    -- if(total = 0 OR cnt = 0, 0, 1 - 2 * weighted_sum / (cnt * total)) AS gini
FROM
(
    SELECT
        date,
        arraySort(groupArray(score)) AS scores,
        length(scores) AS cnt,
        countEqual(scores, 0) AS zero_cnt,
        arraySum(scores) AS total,
        arraySum(
            arrayMap(
                (x, i) -> x * (length(scores) - i + 0.5),
                scores,
                arrayEnumerate(scores)
            )
        ) AS weighted_sum
    FROM game_score
    GROUP BY date
)
ORDER BY date;









	

