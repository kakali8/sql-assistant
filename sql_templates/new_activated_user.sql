-- metric_id: new_activated_user
-- metric_name: 有效新用户占比
-- card_name: new_activated_user
-- card_id: 3182
-- dashboard: CEO (id=518)
-- business_domain: User Growth
-- owner: marketing, ceo
-- definition: 指标定义
-- description: T+1 进入有效对战的新用户比例
-- evaluation: higher_is_better
-- related_metrics: dau
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log, rings_broadcast.pk_activity, rings_broadcast.pk_player_record
-- events_used: 
--
-- [SQL]
WITH
new_user AS (select register_time1, country,acc_pid,acc_uid, COALESCE(
    NULLIF(type, ''),
    NULLIF(network_type, ''),
    'others'
) AS source from
    (SELECT
        register_time1, country, (case when network = 'TikTok SAN' then 'TikTok'
           when network = 'Unattributed' then 'FB'
            when network = 'Organic' then 'Organic' else 'others' end) as network_type,
        acc_pid,acc_uid
    FROM new_loops_activity.gametok_user
    WHERE register_time1 > today() - 30
      AND is_guest = 1)a left join 
    (select create_time, to_uid, case when b.log_id is null then 'invite' else 'minihub' end as type from
(select * from new_loops_activity.link_report_invite_log
   where source <> 'Default'
   and result ='SUCCESS')a left join
(select toUInt64(invite_log_id) as log_id FROM new_loops_activity.link_kol_log group by 1)b on a.id = b.log_id)b on a.acc_uid = b.to_uid
),

pk AS (
select acc_pid, min(biz_date) as first_finish from 
    (select 
	pk_id,biz_date,acc_pid,status AS last_status,
	arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
    arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
	from
	(SELECT 
	    pk_id,
		toDate(
            toDateTime(create_time, 'Asia/Singapore')
        ) AS biz_date,
        t1.acc_pid AS acc_pid,
        t.status,arrayMap(
                    x -> JSONExtractString(x, 'userStatus'),
                    arraySort(
                            x -> JSONExtractInt(x, 'curTimeMs'),
                            JSONExtractArrayRaw(ifNull(user_status_log, '[]'))
                    )
            ) as statuses
    FROM rings_broadcast.pk_player_record t
    INNER JOIN (
        SELECT DISTINCT acc_uid, acc_pid 
        FROM new_loops_activity.gametok_user
    ) t1 
        ON t.player_id = t1.acc_uid
-- 		where pk_id in (
-- select pk_id FROM rings_broadcast.pk_activity 
--     WHERE title = 'Challenge'
--       AND activity_info_id IS NOT NULL AND toHour(toDateTime(activity_start_time / 1000, 'Asia/Singapore')) in (17,21)
-- 		)
		))
	where last_status = 'gameover' 
         OR (last_status = 'fighting' AND stage_final_status NOT IN ('disconnect'))
group by 1)

SELECT
    toDate(toTimeZone(t1.register_time1, 'Asia/Singapore')) AS date, country, 
	source,

    -- ✅ 24h 内完成 PK 的用户
    countDistinctIf(
        t1.acc_pid,
        t2.first_finish >= t1.register_time1
        AND t2.first_finish < addHours(t1.register_time1, 24)
    ) as numerator,
	count(distinct t1.acc_pid) as denominator,
	numerator/denominator AS value

FROM new_user t1
LEFT JOIN pk t2
    ON t1.acc_pid = t2.acc_pid   -- ✅ 只保留等值 JOIN
	where toDate(toTimeZone(t1.register_time1, 'Asia/Singapore')) > '2026-01-17'
GROUP BY 1,2,3;












	

