-- metric_id: pk_successful_matching
-- metric_name: 匹配成功率
-- card_name: PK Successful Matching
-- card_id: 3184
-- dashboard: CEO (id=518)
-- business_domain: PK
-- owner: product
-- definition: 成功进入对战的匹配比例
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, rings_broadcast.pk_activity, rings_broadcast.pk_invite, rings_broadcast.pk_match
-- events_used: 
--
-- [SQL]
WITH

pk as (
select toDate(toTimeZone(create_time,'Asia/Singapore')) as date, id, initiator_id, acc_pid, status, mode, end_reason, accept_uv, (toInt64(session_id) - 100000) AS game_id from rings_broadcast.pk_match a
left join (select acc_uid, acc_pid from new_loops_activity.gametok_user)b on a.initiator_id = b.acc_uid
left join (
select pk_id, count(distinct target_id) as total_invite,
                count(distinct case when status = 'accepted' then target_id end) as accept_uv
         from rings_broadcast.pk_invite where create_time > now() - INTERVAL 30 day
         group by pk_id
)c on a.id=c.pk_id
where create_time > now() - INTERVAL 30 day
and id not in (
SELECT pk_id FROM rings_broadcast.pk_activity WHERE title = 'Challenge'
)
),

name as (select app_id, name from loops_game.game_version_info group by 1,2)

SELECT
date, mode, t2.name as game_id, 
countDistinct(id) as denominator, 
count(distinct case when accept_uv > 0 then id else null end) as numerator,
	if(isNaN(count(distinct case when accept_uv > 0 then id else null end)/countDistinct(id)), 0, count(distinct case when accept_uv > 0 then id else null end)/countDistinct(id)) as value
FROM pk t1 left join name t2 on t1.game_id = t2.app_id
WHERE
    acc_pid IN (
        SELECT acc_pid FROM new_loops_activity.gametok_user
    )
	and date > '2026-01-17'
group by date, mode, game_id order by date desc
;





	

