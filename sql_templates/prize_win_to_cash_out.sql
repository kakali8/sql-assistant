-- metric_id: prize_win_to_cash_out
-- metric_name: 获奖用户提现率
-- card_name: Prize win to cash out
-- card_id: 3222
-- dashboard: L2 (id=522)
-- business_domain: cash out
-- owner: ops, product
-- definition: 每日获奖用户中选择提现的比例
-- description: 现金兑奖情况
-- evaluation: higher_is_better
-- related_metrics: kix_challenge_redeem_uv
-- source_tables: loops_billing.cashout_log, rings_broadcast.pk_activity, rings_broadcast.pk_claim_log, rings_broadcast.pk_reward_log
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
    select pk_id from rings_broadcast.pk_activity where  activity_info_id is not null and HOUR(FROM_UNIXTIME(activity_start_time / 1000)) in (9,13)
	)
	and reward>0
	and activity_info_id is not null
    GROUP BY date, user_id,s1.pk_id
),
redeem_day as (
select Date(FROM_UNIXTIME(create_time/ 1000)) AS date,pk_id,game_id,user_id,
sub_mode, mode,
sum(count) as redeem_value
from rings_broadcast.pk_claim_log
where pk_id in (
    select pk_id from rings_broadcast.pk_activity where  activity_info_id is not null and HOUR(FROM_UNIXTIME(activity_start_time / 1000)) in (9,13)
	)
group by Date(FROM_UNIXTIME(create_time/1000)),game_id,user_id,pk_id,
sub_mode,mode
),

cashout as (
SELECT
    pk_id,
    user_id, status
FROM loops_billing.cashout_log
group by 1,2,3
)

SELECT
    r.date as date,
	-- c.game_id as game_id,name as game_name,
    COUNT(DISTINCT r.user_id) AS denominator,
    -- SUM(reward_usd) AS reward_usd,
 --    COUNT(DISTINCT CASE WHEN sub_mode='Coin' THEN c.user_id END) AS redeem_coins_uv,
 --    SUM(CASE WHEN sub_mode='Coin' THEN c.redeem_value ELSE 0 END) AS redeem_coins,
 --    COUNT(DISTINCT CASE WHEN sub_mode='Energy' THEN c.user_id END) AS redeem_energy_uv,
 --    SUM(CASE WHEN sub_mode='Energy' THEN c.redeem_value ELSE 0 END) AS redeem_energy,
 --    COUNT(DISTINCT CASE WHEN sub_mode='GiftCard' THEN c.user_id END) AS redeem_giftcard_uv,
	-- SUM(CASE WHEN sub_mode='GiftCard' THEN c.redeem_value ELSE 0 END) AS redeem_giftcard,
    COUNT(DISTINCT CASE WHEN mode > 200 THEN c.user_id END) AS numerator,
-- 	SUM(CASE WHEN mode > 200 THEN c.redeem_value ELSE 0 END) AS cashout_usd,
-- 	count(distinct t2.user_id) AS submitted,
-- COUNT(DISTINCT CASE WHEN status = 'PENDING' THEN t2.user_id END) AS pending,
--     COUNT(DISTINCT CASE WHEN status = 'SUCCESS' THEN t2.user_id END) AS success,
--     COUNT(DISTINCT CASE WHEN status = 'FAILED' THEN t2.user_id END) AS failed
COUNT(DISTINCT CASE WHEN mode > 200 THEN c.user_id END)/COUNT(DISTINCT r.user_id) as value
	
FROM reward_user_day r
LEFT JOIN redeem_day  c
    ON r.date = c.date
   AND r.user_id = c.user_id
   and r.pk_id=c.pk_id
right join loops_game.game_version_info as t1 on c.game_id=t1.app_id
left join cashout t2 on r.pk_id = t2.pk_id and r.user_id = t2.user_id
where r.date > '2026-01-16'
GROUP BY r.date,r.pk_id,name
ORDER BY r.date DESC;




