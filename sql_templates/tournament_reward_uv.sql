-- metric_id: tournament_reward_uv
-- metric_name: Tournament奖励人数
-- card_name: Tournament reward uv
-- card_id: 3351
-- dashboard: CEO (id=518)
-- business_domain: rush hour
-- owner: marketing, ops, product
-- definition: 每天Tournament奖励人数
-- description: Tournament奖励人数的日常统计
-- evaluation: display_only
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
and tour_type= 'RushHour'
group by date,country
order by date desc



