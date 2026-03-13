-- metric_id: kix_challenge_redeem_uv
-- metric_name: KiX challenge redeem人数
-- card_name: KiX Challenge redeem uv
-- card_id: 3203
-- dashboard: CEO (id=518)
-- business_domain: Daily Challenge
-- owner: ops, marketing
-- definition: 每日KiX challenge兑奖人数
-- evaluation: display_only
-- related_metrics: 
-- source_tables: rings_broadcast.pk_activity, rings_broadcast.pk_claim_log, rings_broadcast.pk_reward_log
-- events_used: 
--
-- [SQL]
WITH
reward_user_day AS (
    SELECT
        Date(FROM_UNIXTIME(s1.create_time / 1000)) AS date,
        user_id,s1.pk_id,
        SUM(reward) AS reward_usd
    FROM rings_broadcast.pk_reward_log as s1
	inner join rings_broadcast.pk_activity as s2 
	on s1.pk_id=s2.pk_id and 
	date(FROM_UNIXTIME(activity_start_time / 1000))= Date(FROM_UNIXTIME(s1.create_time / 1000))
    WHERE reward_type = '$'
	and s1.pk_id in (
    select pk_id from rings_broadcast.pk_activity where  activity_info_id is not null and HOUR(FROM_UNIXTIME(activity_start_time / 1000)) IN (9, 13)
	)
	and reward>0
	and activity_info_id is not null
    GROUP BY date, user_id,s1.pk_id
),
redeem_day as (
select Date(FROM_UNIXTIME(create_time/ 1000)) AS date,pk_id,game_id,user_id,
sub_mode,
sum(count) as redeem_value
from rings_broadcast.pk_claim_log
where pk_id in (
     select pk_id from rings_broadcast.pk_activity where  activity_info_id is not null and HOUR(FROM_UNIXTIME(activity_start_time / 1000)) IN (9, 13)
	)
group by Date(FROM_UNIXTIME(create_time/1000)),game_id,user_id,pk_id,
sub_mode
)
SELECT
    r.date,sub_mode as redeem_type,c.game_id as game_id,name as game_name,
    COUNT(DISTINCT c.user_id) AS value
FROM reward_user_day r
LEFT JOIN redeem_day  c
    ON r.date = c.date
   AND r.user_id = c.user_id
   and r.pk_id=c.pk_id
right join loops_game.game_version_info as s1
on c.game_id=s1.app_id
where r.date > '2026-01-16'
GROUP BY r.date,sub_mode,r.pk_id,name
ORDER BY r.date DESC;
