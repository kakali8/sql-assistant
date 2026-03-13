-- metric_id: ads_popup_rate
-- metric_name: 广告弹窗展示率
-- card_name: Ads popup rate
-- card_id: 3337
-- dashboard: L2 (id=522)
-- business_domain: Revenue
-- owner: ceo, product
-- definition: 活跃用户中看到广告弹窗的比例
-- description: 广告弹窗展示率是指在活跃用户中，看到广告弹窗的用户比例。
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.energy_log, new_loops_activity.gametok_user, new_loops_activity.hab_app_events
-- events_used: loading_page, popup_energy_purchase, popup_out_of_energy, session_start, topup_success
--
-- [KEY FIELDS]
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: popup_energy_purchase
--   desc: 无生命值时触发的充值弹窗
--   status_user: 1=充值过的用户, 2=没有充值过的用户
--   panel: 1=该弹框首次展示, 2=该弹框非首次展示 1219新增 pk_id:<string>
--   bind: 0=coin, 1=energy
-- event: popup_out_of_energy
--   desc: “Energy不足”弹窗相关操作
--   bind: 1=tier1, 2=tier2, 3=tier3 1219新增 pk_id:<string>
--   number: 1=有勾选, 0=未勾选
--   status_user: 1=充值过的用户, 2=没有充值过的用户
--   panel: 1=该弹框首次展示, 2=该弹框非首次展示 1126新增字段
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
--
-- [SQL]
-- 口径：弹窗次数
with prep as (
select toDate(toTimeZone(server_time, 'Asia/Singapore')) as date,
       -- 总弹窗次数
	   -- count(distinct case when event_name in ('popup_out_of_energy', 'popup_energy_purchase') and type = 1 then t1.s_ts end) as popup_times, 
	   -- -- coins兑换energy
    --    count(distinct case when event_name = 'popup_out_of_energy' and type = 1 and status = 1 then t1.s_ts end) as coins_buy_energy_popup,
    --    count(distinct case when event_name = 'popup_out_of_energy' and type = 2 and status = 1 then t1.s_ts end) as coins_buy_energy_click,
    --    -- topup
	   -- count(distinct case when event_name = 'popup_energy_purchase' and type = 1 then t1.s_ts end) as topup_popup,
    --    count(distinct case when event_name = 'popup_energy_purchase' and type = 2 then t1.s_ts end) as topup_click,
	   -- sum(case when event_name = 'topup_success' and type = 2 then amount end) as topup_amount, 
       -- 看广告
	   count(distinct case when event_name = 'popup_out_of_energy' and type = 1 and status = 2 then t1.s_ts end) as ad_popup_times,
	   count(distinct case when event_name = 'popup_out_of_energy' and type = 1 and status = 2 then t2.acc_pid end) as ad_popup_uv,
       count(distinct case when event_name = 'popup_out_of_energy' and type = 2 and status = 2 then t1.s_ts end) as ad_click_times,  -- 可能会出现广告没有填充，导致连续点击数据，不管了
	   count(distinct case when event_name = 'popup_out_of_energy' and type = 2 and status = 2 then t2.acc_pid end) as ad_click_uv
       -- invite
	   -- count(distinct case when event_name = 'popup_out_of_energy' and type = 1 and status = 3 then t1.s_ts end) as invite_popup,
    --    count(distinct case when event_name = 'popup_out_of_energy' and type = 2 and status = 3 then t1.s_ts end) as invite_click
from new_loops_activity.hab_app_events as t1
left join (select acc_uid as id, acc_pid from new_loops_activity.gametok_user group by 1,2) as t2 on t1.user_id = t2.id
where event_name in ('popup_out_of_energy', 'popup_energy_purchase', 'topup_success')
-- and platform = 'Android'			-- platform check
-- and device_id not in (select distinct pi from rings_account.account where country_code in ('SG','HK','CN'))
group by 1

),

-- ad_energy as (
-- select date(create_time) as date, count(id) as ad_energy_times
-- from new_loops_activity.energy_log 
-- where source = 'watch_ad' 
-- group by 1
-- ),

dau as (
    SELECT 
        toDate(toTimeZone(server_time,'Asia/Singapore')) AS date,
        count(distinct device_id) as uv
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 30 DAY
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
group by 1)




select 
	date, 
	-- popup_times, 
	-- -- coins兑换energy
	-- coins_buy_energy_popup / popup_times as coins_buy_energy_rate, 
	-- coins_buy_energy_click / coins_buy_energy_popup as coins_buy_energy_ctr, 
	-- -- topup
	-- topup_popup / popup_times as topup_rate, 
	-- topup_click / topup_popup as topup_ctr, 
	-- topup_amount, 
	-- 看广告
	-- ad_popup / popup_times as ad_rate, 
	-- ad_click / ad_popup as ad_ctr, 
	-- ad_energy_times / ad_click as ad_finish_rate, 
	-- ad_energy_times, 
	-- ad_click,		-- 目前出现了没有click记录，但是有energy获得记录

	-- invite
	-- invite_popup / popup_times as invite_rate, 
	-- invite_click / invite_popup as invite_ctr
	t3.uv as denominator,
	ad_popup_uv as numerator,
	ad_popup_uv / t3.uv as value
	
from prep t1 
-- left join ad_energy t2 on t1.date = t2.date 
left join dau t3 on t1.date = t3.date

where date > today() - interval '30' day		-- 1.22之前出现苹果端弹窗一直触发的问题，1.22解决，固调取1.23及之后的数据
order by date desc





;
