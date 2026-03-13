-- metric_id: dau_play_rate
-- metric_name: dau中玩游戏的比例
-- card_name: dau_play_rate
-- card_id: 3274
-- dashboard: CEO (id=518)
-- business_domain: PK
-- owner: product
-- definition: dau中玩游戏的比例
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.hab_app_events_local, new_loops_activity.newgame_room_log
-- events_used: 
--
-- [SQL]
with

active_user as (
select distinct device_id as pid, date(event_time) as date
from new_loops_activity.hab_app_events_local
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
  count(distinct nu.pid) as denominator,
  count(distinct d0.pid) as numerator,
  COALESCE(count(distinct d0.pid) / NULLIF(count(distinct nu.pid), 0), 0) as value
  -- AVG(COALESCE(d0.duration_min, 0)) AS dau_avg_play_minute_day0
FROM active_user nu
LEFT JOIN day0_play_by_user d0
  ON nu.pid = d0.pid
 AND nu.date = d0.date
 where nu.date <= date(now())
GROUP BY nu.date
order by nu.date desc

limit 30;



