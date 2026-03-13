-- metric_id: tournament_d1_retention
-- metric_name: Tournament留存
-- card_name: Tournament D1 retention
-- card_id: 3346
-- dashboard: CEO (id=518)
-- business_domain: rush hour
-- owner: marketing, product, ops, ceo
-- definition: 每天Tournament用户隔日是否继续参赛
-- description: 留存率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_match, rings_broadcast.pk_player_record, rings_broadcast.pk_tour
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
    FROM rings_broadcast.pk_player_record t1

    INNER JOIN new_loops_activity.gametok_user u
        ON t1.player_id = u.acc_uid

    INNER JOIN rings_broadcast.pk_match t2
        ON t1.pk_id = t2.id and toDate(t1.create_time)=toDate(t2.create_time)

    INNER JOIN rings_broadcast.pk_tour t3
        ON t2.tour_id = t3.id and toDate(t2.create_time)=toDate(t2.create_time)
		 WHERE toDate(t1.create_time) >= today() - 30
		 and tour_type= 'RushHour'

)

SELECT
    b1.date,
	country,
    COALESCE(countDistinct(b1.acc_pid),0) AS denominator,
	COALESCE(countDistinct(b2.acc_pid),0) AS numerator,
	COALESCE(1.0*numerator / NULLIF(denominator, 0), 0) as value
FROM tournament_user b1
LEFT JOIN tournament_user b2
    ON b1.acc_pid = b2.acc_pid
   AND b2.date = b1.date + 1

GROUP BY
     b1.date,country

ORDER BY  b1.date DESC;
