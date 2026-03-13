-- metric_id: spend_energy_daily
-- metric_name: energy消耗个数
-- card_name: Spend energy daily
-- card_id: 3244
-- dashboard: CEO (id=518)
-- business_domain: Revenue
-- owner: product, ops
-- definition: 每日energy消耗个数
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, rings_broadcast.pk_invite, rings_broadcast.pk_match
-- events_used: 
--
-- [SQL]
with 
whole as (
select 
	date(create_time) as date,
	abs(sum(energy)) as value
from new_loops_activity.energy_log as t1
where create_time > now() - interval 30 day
and source in ('play_once', 'buy_once')
group by 1
order by 1 desc
)

, pk_energy as (
with 
pk as (
select initiator_id, c.acc_pid as invitor_pid, e.acc_pid as target_pid, a.status as status, a.mode as mode, end_reason, pk_id, a.create_time as pk_time,b.target_id,b.status,b.create_time as accept_time
from rings_broadcast.pk_match a
left join (select distinct acc_uid, acc_pid from new_loops_activity.gametok_user)c on a.initiator_id = c.acc_uid
left join rings_broadcast.pk_invite b on a.initiator_id = b.invitor_id 
left join (select distinct acc_uid, acc_pid from new_loops_activity.gametok_user)e on b.target_id = e.acc_uid
where a.create_time BETWEEN subtractMinutes(b.create_time, 1) AND addMinutes(b.create_time, 1) and b.status = 'accepted'
)


,pk_user as (  -- 参与pk的所有用户
select pk_id, invitor_pid as pid, status, mode, end_reason, pk_time, accept_time
from pk
union distinct
select pk_id, target_pid as pid, status, mode, end_reason, pk_time, accept_time
from pk
)

,energy as (
	SELECT  distinct b.acc_pid as pid, 
			energy,
			a.create_time as energy_consume_time
	FROM new_loops_activity.energy_log a
	left join (select distinct acc_uid, acc_pid from new_loops_activity.gametok_user)b on a.uid = b.acc_uid
	where source in ('buy_once' ,'play_once' )

)



,result_detail as(
SELECT distinct
    p.pk_id,
    toDate(p.pk_time) AS date,
	ifNull(e.energy, 0) as energy,
	p.pid,
	p.pk_time,
	e.energy_consume_time
FROM pk_user p
LEFT JOIN energy e ON p.pid = e.pid
WHERE 
(e.energy_consume_time BETWEEN subtractMinutes(p.pk_time, 1) AND addMinutes(p.pk_time, 1))
)

select * 
from result_detail
)


-- 还没有区分source，等数据库好了就改

select * 
from whole;


