-- metric_id: viral__popup_show_click_rate
-- metric_name: viral弹窗展示->点击漏斗
-- card_name: Viral  popup show click rate
-- card_id: 3260
-- dashboard: CEO (id=518)
-- business_domain: Viral
-- owner: product, ops
-- definition: 展示->点击
-- description: 弹窗是否有吸引力
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.kix_web_events, new_loops_activity.link_click_log, new_loops_activity.link_getlink_log, new_loops_activity.link_kol_users, new_loops_activity.link_report_invite_log
-- events_used: kix_viral
--
-- [KEY FIELDS]
-- event: kix_viral
--   desc: kix的 viral邀新裂变所有场景记录
--   type: 1=S01 Energy_Rescue：没能量弹窗, 2=S02 HQ_After_Share：Challenge赛后分享，用户在结算页点击“关闭”奖状弹窗 -> 触发二次..., 3=S03 HQ_H5_Share ：Challenge赛事预约，swipe置顶推送，点击详情进入H5页, 4=S04 HQ_Room_Invite：Challenge赛前候场，用户进入 HQ 赛事候场室 (Waiting R..., 5=S05 Add_Friend_Invite：Play 页面 -> 进入Add Friends 页面 -> 邀请入口, 6=S06 Game_Room_Invite：游戏室内邀请，游戏内 -> 点击游戏室 -> 点击 Invite (邀请..., 7=S07 Gamification_Task, 9=S09 PK_After_Share: PK结算页分享
--   status: 1=展示, 2=点击
--   number: 0=S07对应的专属奖励, 1=spin
--   bind: 1=tier1, 2=tier2, 3=tier3 260129新增
--
-- [SQL]
select 
toDate(now('Asia/Singapore') - INTERVAL 1 DAY) as date,s1.source,
popup_click_pv as numerator,
popup_show_pv denominator, 
COALESCE(1.0*popup_click_pv/ NULLIF(popup_show_pv, 0), 0)  as value
from
(select 
source,count(distinct acc_pid) as get_link_uv,
count(distinct id) as get_link_pv
from new_loops_activity.link_getlink_log
left join new_loops_activity.gametok_user on  uid=acc_uid
where uid not in (select distinct uid from new_loops_activity.link_kol_users)
and date(create_time)> now() - INTERVAL 7 DAY
group by source) as s1
left join (
select source,
count(distinct acc_pid) as click_link_uv,
count(distinct id) as click_link_pv
from new_loops_activity.link_click_log
left join new_loops_activity.gametok_user on  uid=acc_uid
where uid not in (select distinct uid from new_loops_activity.link_kol_users)
and date(create_time)> now() - INTERVAL 7 DAY
group by source
) as s2 
on  s1.source=s2.source
left join (
select 
source,
count(distinct case when result ='SUCCESS' then acc_pid end) as invite_success_uv,
count(distinct case when result not in ('SUCCESS') then acc_pid end) as invite_fail_uv
from new_loops_activity.link_report_invite_log
left join new_loops_activity.gametok_user on  to_uid=acc_uid
where to_uid not in (select distinct uid from new_loops_activity.link_kol_users)
and date(create_time)> now() - INTERVAL 7 DAY
group by  source
) as s3 
on s1.source=s3.source
left join (
select 
case when type=1 then 'Energy_Rescue'
when type=2 then 'HQ_After_Share'
when type=3 then 'HQ_H5_Share'
when type=4 then 'HQ_Room_Invite'
when type=5 then 'Add_Friend_Invite'
when type=6 then 'Game_Room_Invite'
when type=7 then 'Gamification_Task'
when type=9 then 'PK_After_Share'
end as type,
count(distinct case when status=1 then id end) as popup_show_pv,
count(distinct case when status=1 then device_id end) as popup_show_uv,
count(distinct case when status=2 then id end) as popup_click_pv,
count(distinct case when status=2 then device_id end) as popup_click_uv
from new_loops_activity.kix_web_events
where event_name='kix_viral'
and date(server_time)> now() - INTERVAL 7 DAY
group by type
) as s4 
on  s1.source=type
