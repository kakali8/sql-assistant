-- metric_id: daily_tournament_reward_uv
-- metric_name: 
-- card_name: Daily Tournament reward uv
-- card_id: 3371
-- dashboard: CEO (id=518)
-- business_domain: 
-- owner: 
-- definition: 
-- evaluation: 
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_tour, rings_broadcast.pk_tour_reward_log
-- events_used: 
--
-- [SQL]
select 
   toDate(toDateTime(toInt64(t1.create_time) / 1000)) as date,
   country,
   COALESCE(count(distinct acc_pid),0) AS value
from rings_broadcast.pk_tour_reward_log t1
INNER JOIN rings_broadcast.pk_tour t3 
ON t1.tour_id = t3.id 
  INNER JOIN new_loops_activity.gametok_user u
        ON t1.user_id = u.acc_uid
WHERE t1.create_time >= toUnixTimestamp(today() - 30) * 1000 
and tour_type= 'Daily'
group by date,country
order by date desc
