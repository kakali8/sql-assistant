-- metric_id: prize_impression_to_claim
-- metric_name: 
-- card_name: Prize impression to claim
-- card_id: 3221
-- dashboard: L2 (id=522)
-- business_domain: 
-- owner: 
-- definition: 
-- evaluation: 
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, rings_broadcast.pk_activity
-- events_used: prize_pool
--
-- [KEY FIELDS]
-- event: prize_pool
--   desc: 奖状页相关操作
--   raw_notes: type 1-进入页面 2-点击按钮 status 260106 含义修改 1-冠军 Claim按钮 2-除冠军之外的人 Join按钮 number: 用户本场比赛的名次，如果是围观者传0
--
-- [SQL]
SELECT
    toDate(toTimeZone(server_time, 'Asia/Singapore')) as date, count(distinct case when type = 1 then user_id else null end) as denominator,
    count(distinct case when type = 2 then user_id else null end) as numerator, numerator/denominator as value
FROM new_loops_activity.hab_app_events
WHERE user_id IN (SELECT acc_uid FROM new_loops_activity.gametok_user) and server_time > now() - INTERVAL 30 DAY
  and server_time > '2026-01-17 21:00:00' and event_name in ('prize_pool')
and status = 1
--   and pk_id in (select pk_id from rings_broadcast.pk_activity where  activity_info_id is not null and HOUR(FROM_UNIXTIME(activity_start_time / 1000)) = 9)
group by 1 order by 1;
