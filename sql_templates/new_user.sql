-- metric_id: new_user
-- metric_name: 新用户数
-- card_name: New User
-- card_id: 3178
-- dashboard: CEO (id=518)
-- business_domain: User Growth
-- owner: ceo, marketing
-- definition: 新注册用户规模
-- description: 新用户数反映了平台在一定时间内新增注册用户的数量。
-- evaluation: higher_is_better
-- related_metrics: viral_new_uv
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log, rings_broadcast.pk_player_record
-- events_used: 
--
-- [SQL]
WITH
new_user AS (
    SELECT
        register_time1, country, network, 
		(case when network = 'TikTok SAN' then 'TikTok'
             WHEN network = 'Unattributed' or network like '%Facebook%' or network like '%Instagram%'THEN 'FB'
             else network end) as network_type,
        acc_pid, acc_uid
    FROM new_loops_activity.gametok_user
    WHERE register_time1 > today() - 30
      AND is_guest = 1
    GROUP BY ALL
),

-- pk AS (
--     SELECT
--         t1.acc_pid,
--         min(t.create_time) AS first_finish
--     FROM (select * from rings_broadcast.pk_player_record where create_time > now() - interval 30 day)t
--     INNER JOIN (
--         SELECT DISTINCT acc_uid, acc_pid
--         FROM new_loops_activity.gametok_user
--     ) t1
--         ON t.player_id = t1.acc_uid
--     WHERE t.status IN ('fighting', 'gameover')
--       AND t.create_time > now() - INTERVAL 30 DAY
--     GROUP BY t1.acc_pid
-- ),

user_type as (select create_time, to_uid, case when b.log_id  is null then 'invite' else 'minihub' end as type from
(select * from new_loops_activity.link_report_invite_log
   where source <> 'Default'
   and result ='SUCCESS')a left join
(select toUInt64(invite_log_id) as log_id FROM new_loops_activity.link_kol_log group by 1)b on a.id = b.log_id 
)


SELECT 
    toDate(toTimeZone(t1.register_time1, 'Asia/Singapore')) AS date, country, 
	COALESCE(
    NULLIF(type, ''),
    NULLIF(network_type, ''),
    'others'
) AS source,
	-- -- ifNull(network, 'null') as source,
    countDistinct(t1.acc_pid) AS value

FROM new_user t1
left join user_type t2
on t1.acc_uid = t2.to_uid
-- LEFT JOIN pk t2
--     ON t1.acc_pid = t2.acc_pid   -- ✅ 只保留等值 JOIN
	where register_time1 > '2026-01-16 16:00:00'
GROUP BY 1,2,3;












	

