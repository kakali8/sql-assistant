-- metric_id: dnu_paly_rate_d0
-- metric_name: 新用户进来第一天玩游戏率
-- card_name: dnu_paly_rate_d0
-- card_id: 3276
-- dashboard: CEO (id=518)
-- business_domain: PK
-- owner: product
-- definition: 新用户进来第一天玩游戏率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.newgame_room_log
-- events_used: 
--
-- [SQL]
with

new_user as (
select distinct acc_pid as pid, date(min(register_time1)) as date
from new_loops_activity.gametok_user
group by acc_pid
)

,day0_play_by_user as (
SELECT pi as pid, date(enter_time) as date,
sum(greatest(
    toFloat64(ifNull(duration_by_ranking, 0)),
    toFloat64(ifNull(duration_by_compute, 0)),
    toFloat64(ifNull(duration_by_end, 0))
)) / 60.0 
 as duration_min
    FROM new_loops_activity.newgame_room_log
group by date, pid
having duration_min <= 180
order by date desc, duration_min desc
)





SELECT
  nu.date as date,
  count(nu.pid) as denominator,
  count(distinct d0.pid) as numerator,
  COALESCE(count(distinct d0.pid) / NULLIF(count(distinct nu.pid), 0), 0) as value
  -- AVG(COALESCE(d0.duration_min, 0)) AS new_user_avg_play_minute_day0
FROM new_user nu
LEFT JOIN day0_play_by_user d0
  ON nu.pid = d0.pid
 AND nu.date = d0.date
GROUP BY nu.date
order by nu.date desc
limit 30;
