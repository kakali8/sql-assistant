-- metric_id: daily_tournament_uv
-- metric_name: 每日Daily Tournament用户数
-- card_name: Daily Tournament uv
-- card_id: 3363
-- dashboard: CEO (id=518)
-- business_domain: Daily tournament
-- owner: ceo, marketing, product, ops
-- definition: 每日Daily Tournament参与人数
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_activity, rings_broadcast.pk_match, rings_broadcast.pk_player_record, rings_broadcast.pk_tour
-- events_used: 
--
-- [SQL]
WITH
tournament_user AS (
    SELECT
        toDate(t1.create_time) AS date,
		country,
        u.acc_pid as acc_pid,
        t1.pk_id as pk_id,
        t3.tour_type as tour_type
    FROM (select * from rings_broadcast.pk_player_record where create_time > now()-interval 30 day) t1

    INNER JOIN new_loops_activity.gametok_user u
        ON t1.player_id = u.acc_uid

    INNER JOIN (select * from rings_broadcast.pk_match where create_time > now()-interval 30 day) t2
        ON t1.pk_id = t2.id

    INNER JOIN (select * from rings_broadcast.pk_tour where create_time > now()-interval 30 day) t3
        ON t2.tour_id = t3.id

    -- LEFT JOIN rings_broadcast.pk_activity a
    --     ON t1.pk_id = a.pk_id
	where tour_type= 'Daily'
)

SELECT
    b1.date as date,
	country,
    countDistinct(b1.acc_pid) AS value
FROM tournament_user b1
LEFT JOIN tournament_user b2
    ON b1.acc_pid = b2.acc_pid
   AND b2.date = b1.date + 1

GROUP BY
     b1.date,country

ORDER BY  b1.date DESC;
