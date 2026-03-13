-- metric_id: new_user_consume_energy_rate
-- metric_name: 消耗energy新用户占新用户率
-- card_name: New user consume energy rate
-- card_id: 3291
-- dashboard: CEO (id=518)
-- business_domain: User Growth
-- owner: marketing, ops
-- definition: 新用户消耗energy率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log
-- events_used: 
--
-- [SQL]
WITH t1 AS (
   select acc_pid, register_date as acc_date, COALESCE(
        NULLIF(
            CASE 
                WHEN r.to_uid IS NOT NULL AND k.kol_uid IS NULL THEN 'invite'
                WHEN k.kol_uid IS NOT NULL THEN 'minihub'
                ELSE NULL
            END, ''
        ),
        CASE 
            WHEN u.network = 'TikTok SAN' THEN 'TikTok'
            WHEN u.network = 'Unattributed' THEN 'FB'
            WHEN u.network = 'Organic' THEN 'Organic'
            ELSE 'others'
        END,
        'others'
    ) AS source,country
     from new_loops_activity.gametok_user u
	 	LEFT JOIN new_loops_activity.link_report_invite_log r
    ON r.to_uid = u.acc_uid
    AND r.source <> 'Default'
    AND r.result = 'SUCCESS'
LEFT JOIN (
    SELECT DISTINCT kol_uid
    FROM new_loops_activity.link_kol_log
) k
    ON r.from_uid = k.kol_uid
-- # where  country_code  in ('TH')
     where register_time1 > now() - interval 30 day
),

t2 AS (
    SELECT
        toDate(m1.create_time) AS acc_date,
        m2.acc_pid
    FROM new_loops_activity.energy_log m1
    INNER JOIN new_loops_activity.gametok_user m2
        ON m1.uid = m2.acc_uid
	where source in ('play_once','buy_once')
)

SELECT
    t1.acc_date as date,source,country,
    COALESCE(countDistinct(t1.acc_pid),0) AS denominator,
    COALESCE(countDistinct(t2.acc_pid),0) AS numerator,
	COALESCE(1.0*numerator/ NULLIF(denominator, 0), 0)  as value
FROM t1
LEFT JOIN t2
    ON t1.acc_pid = t2.acc_pid
   AND t1.acc_date = t2.acc_date
GROUP BY
   1,2,3
ORDER BY acc_date;

