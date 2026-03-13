-- metric_id: average_energy_spend_per_active_user
-- metric_name: 人均energy消耗量
-- card_name: Average energy spend per active user
-- card_id: 3262
-- dashboard: L2 (id=522)
-- business_domain: Revenue
-- owner: product, ops
-- definition: 平均每日人均energy消耗
-- evaluation: higher_is_better
-- related_metrics: kix_train_times, new_user_avg_spend_energy
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, new_loops_activity.hab_app_events, rings_broadcast.pk_invite, rings_broadcast.pk_match
-- events_used: loading_page, session_start
--
-- [KEY FIELDS]
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
--
-- [SQL]
with 
whole as (
select 
	date(create_time) as date,
	abs(sum(energy)) as total_energy
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
),

dau as (
SELECT 
        toDate(server_time) AS date,
        count(distinct device_id) as dau
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 60 DAY
	  AND
  (
    /* ---------- iPhone：client_version > 1.0.2260110 ---------- */
    (
      platform = 'iPhone'
      AND (
            toInt64OrZero(splitByChar('.', ifNull(client_version,''))[1]) > 1
         OR (
              toInt64OrZero(splitByChar('.', ifNull(client_version,''))[1]) = 1
              AND toInt64OrZero(splitByChar('.', ifNull(client_version,''))[2]) > 0
            )
         OR (
              toInt64OrZero(splitByChar('.', ifNull(client_version,''))[1]) = 1
              AND toInt64OrZero(splitByChar('.', ifNull(client_version,''))[2]) = 0
              AND toInt64OrZero(splitByChar('.', ifNull(client_version,''))[3]) > 2260110
            )
      )
    )

    OR

    /* ---------- Android：去掉括号后再比 > 1.31.0 ---------- */
    (
      platform = 'Android'
      AND (
            toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[1]) > 1
         OR (
              toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[1]) = 1
              AND toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[2]) > 31
            )
         OR (
              toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[1]) = 1
              AND toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[2]) = 31
              AND toInt64OrZero(splitByChar('.', trimBoth(splitByChar('(', ifNull(client_version,''))[1]))[3]) > 0
            )
      )
    )
  )
  group by toDate(server_time)
)


select t1.date as date, COALESCE(total_energy / NULLIF(dau, 0), 0)  as value
from whole t1 left join dau t2 on t1.date=t2.date ;


