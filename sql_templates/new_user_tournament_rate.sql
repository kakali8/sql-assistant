-- metric_id: new_user_tournament_rate
-- metric_name: 新用户参与Tournamen率
-- card_name: New user tournament rate
-- card_id: 3354
-- dashboard: CEO (id=518)
-- business_domain: rush hour
-- owner: marketing, product, ops, ceo
-- definition: 每日新用户Tournament参与率
-- description: 新用户参与率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log, rings_broadcast.pk_match, rings_broadcast.pk_player_record, rings_broadcast.pk_tour
-- events_used: 
--
-- [SQL]
WITH
/* 新注册用户 */
New_user AS (
    SELECT
        toDate(toDateTime(register_time1, 'Asia/Singapore')) AS date,
		(case when network = 'TikTok SAN' then 'TikTok'
           when network = 'Unattributed' then 'FB'
            when network = 'Organic' then 'Organic' else 'others' end) as network_type,
        acc_pid,
        acc_uid,country
    FROM new_loops_activity.gametok_user
	 WHERE register_time1 > today() - 30
      AND is_guest = 1
),
user_type as (select create_time, to_uid, case when b.log_id  is null then 'invite' else 'minihub' end as type from
(select * from new_loops_activity.link_report_invite_log
   where source <> 'Default'
   and result ='SUCCESS')a left join
(select toUInt64(invite_log_id) as log_id FROM new_loops_activity.link_kol_log group by 1)b on a.id = b.log_id 
),
/* tournament 明细 */
base_tournament AS (
   SELECT
        toDate(t1.create_time) AS date,
        u.acc_pid as acc_pid,
        t1.pk_id as pk_id
    FROM rings_broadcast.pk_player_record t1
    INNER JOIN new_loops_activity.gametok_user u
        ON t1.player_id = u.acc_uid
    INNER JOIN rings_broadcast.pk_match t2
        ON t1.pk_id = t2.id
    INNER JOIN rings_broadcast.pk_tour t3
        ON t2.tour_id = t3.id
	where toDate(t1.create_time)>today() - 30
	 and tour_type= 'RushHour'
)
SELECT
    n.date as date,
   COALESCE(
    NULLIF(type, ''),
    NULLIF(network_type, ''),
    'others'
) AS source,country,
    countDistinct(n.acc_pid) AS denominator,
    countDistinct(b1.acc_pid) AS numerator,
    COALESCE(1.0*numerator / NULLIF(denominator, 0), 0) as value
FROM New_user n
left join user_type t2
on n.acc_uid = t2.to_uid
LEFT JOIN base_tournament b1
    ON n.date = b1.date
   AND n.acc_pid = b1.acc_pid

LEFT JOIN base_tournament b2
    ON b1.acc_pid = b2.acc_pid
   AND b2.date = b1.date + 1

GROUP BY
    n.date,source,country

ORDER BY n.date DESC;
