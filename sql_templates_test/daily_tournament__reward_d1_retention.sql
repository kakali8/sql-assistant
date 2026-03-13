-- metric_id: daily_tournament__reward_d1_retention
-- metric_name: 
-- card_name: Daily Tournament  reward D1 retention
-- card_id: 3372
-- dashboard: CEO (id=518)
-- business_domain: 
-- owner: 
-- definition: 
-- evaluation: 
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_match, rings_broadcast.pk_player_record, rings_broadcast.pk_tour, rings_broadcast.pk_tour_reward_log
-- events_used: 
--
-- [SQL]
WITH
tournament_user AS (
    SELECT
        toDate(t1.create_time) AS date,
		country,
        u.acc_pid as acc_pid,
        t1.pk_id as pk_id
    FROM rings_broadcast.pk_player_record t1

    INNER JOIN new_loops_activity.gametok_user u
        ON t1.player_id = u.acc_uid

    INNER JOIN rings_broadcast.pk_match t2
        ON t1.pk_id = t2.id and toDate(t1.create_time)=toDate(t2.create_time)

    INNER JOIN rings_broadcast.pk_tour t3
        ON t2.tour_id = t3.id and toDate(t2.create_time)=toDate(t2.create_time)
		 WHERE toDate(t1.create_time) >= today() - 30
		  and tour_type= 'Daily'

),
reward as (select 
   toDate(toDateTime(toInt64(t1.create_time) / 1000)) as date,
   country,
   acc_pid
from rings_broadcast.pk_tour_reward_log t1
INNER JOIN rings_broadcast.pk_tour t3 
ON t1.tour_id = t3.id 
  INNER JOIN new_loops_activity.gametok_user u
        ON t1.user_id = u.acc_uid
where toDate(toDateTime(toInt64(t1.create_time) / 1000)) >= today() - 30
 and tour_type= 'Daily'
)

SELECT
    b1.date,
	country,
    COALESCE(countDistinct(b1.acc_pid),0) AS denominator,
	COALESCE(countDistinct(b2.acc_pid),0) AS numerator,
	COALESCE(1.0*numerator / NULLIF(denominator, 0), 0) as value
FROM reward b1
LEFT JOIN tournament_user b2
    ON b1.acc_pid = b2.acc_pid
   AND b2.date = b1.date + 1
group by b1.date,country
