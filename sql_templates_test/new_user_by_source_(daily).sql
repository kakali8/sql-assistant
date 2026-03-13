-- metric_id: new_user_by_source_(daily)
-- metric_name: 
-- card_name: New user by source (daily)
-- card_id: 3293
-- dashboard: CEO (id=518)
-- business_domain: 
-- owner: 
-- definition: 
-- evaluation: 
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log
-- events_used: 
--
-- [SQL]
WITH 
New_user AS (
    SELECT 
        toDate(
            toDateTime(register_time1, 'Asia/Singapore') 
        ) AS date,
        acc_pid,acc_uid,
		COALESCE(
        NULLIF(
            CASE 
                WHEN r.to_uid IS NOT NULL AND k.log_id IS NULL THEN 'invite'
                WHEN k.log_id IS NOT NULL THEN 'minisite'
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
    FROM new_loops_activity.gametok_user as u
	LEFT JOIN new_loops_activity.link_report_invite_log r
    ON r.to_uid = u.acc_uid
    AND r.source <> 'Default'
    AND r.result = 'SUCCESS'
LEFT JOIN (
    SELECT DISTINCT toUInt64(invite_log_id) as log_id
    FROM new_loops_activity.link_kol_log
) k
    ON r.id = k.log_id
)
SELECT 
	date, 
    source,
	COUNT(DISTINCT acc_pid) AS new_user
	from New_user 
	group by source,date,country
	order by date desc, source,country
