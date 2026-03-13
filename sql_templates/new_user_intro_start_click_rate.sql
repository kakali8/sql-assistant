-- metric_id: new_user_intro_start_click_rate
-- metric_name: 新用户从介绍页->点击start按钮漏斗
-- card_name: New user intro start click rate
-- card_id: 3286
-- dashboard: CEO (id=518)
-- business_domain: User Growth
-- owner: marketing, product
-- definition: 指标定义
-- description: 新用户点击start按钮率
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, new_loops_activity.link_kol_log, new_loops_activity.link_report_invite_log, new_loops_activity.newgame_room_log
-- events_used: game_category_load_complete, game_enter, home_navigation_click, intro_page_load_complete, loading_page, new_user_intro_view, new_user_select_game_category, new_user_swipe, new_user_swipe_view, play_prompt, session_start, teach_swipe_view
--
-- [KEY FIELDS]
-- event: game_category_load_complete
--   desc: 选游戏类别页面加载成功。成功定义是：所有游戏类别选项成功展示
--   raw_notes: amount:<int> 加载成功时间 （毫秒） content:<string> 每种数据通过 ｜ 间隔 格式: packet loss (丢包率%)
-- event: game_enter
--   desc: 进入游戏房，区分是从Game/recommended/开播按钮/Top games/Hot games/New games/Account页面my games/首页右上角search/好友半屏和全屏profile/rooms/好友的全屏profile等渠道打开，以及是自己开房间还是进别人的房间/swipe&play模式
--   status: 1=开房间, 2=进别人房间
--   type: 0926=type=1 改为从continue进入, 1=Game, 2=recommended 0905, 3=开播按钮, 4=Top games, 5=Hot games, 6=New games, 7=Account页面my games, 8=首页右上角search 0905, 9=好友半屏profile, 10=好友全屏profile 0905, 11=rooms, 12=好友的全屏profile等渠道打开 13.WEB交互进来 14.IM交互进来 15. swipe&play模式 （..., 0728=18 Activity 好友邀请加入游戏，点击Join按钮, 0912=type=19: Editor's Choice (从play页面的Editor's Choice点击游戏) ty...
--   status_game: 1=用户在swipe也点击进入游戏的时是击穿的
-- event: home_navigation_click
--   desc: 用户点击跳转至其他 Tab 的操作。
--   type: 1=Explore 改为 swipe (点击swipe, 2=Message 改为 点击inbox, 3=Account 改为 点击me, 4=Home 改为 点击play
-- event: intro_page_load_complete
--   desc: 介绍页面加载成功。成功定义是：视频+可点击的按钮成功展示
--   raw_notes: amount:<int> 加载成功时间 （毫秒） content:<string> 每种数据通过 ｜ 间隔 格式: packet loss (丢包率%)
-- event: loading_page
--   desc: 记录用户在landing page画面出现
--   raw_notes: device_id:为固定参数
-- event: new_user_intro_view
--   desc: 介绍平台页面
--   type: 1=进入这个页面, 2=点击“start play”
-- event: new_user_select_game_category
--   desc: 游戏兴趣便签选择页面
--   type: 1=进入这个页面，content可以不传, 2=选中某个游戏类型兴趣 对应的 content = “game category”, 3=用户点击next，包含所有选中游戏类型标签， 对应的content = [game_category1, …, g..., 4=用户点击skip ，content可以不传
-- event: new_user_swipe
--   desc: 用户滑动屏幕 （ 不再只针对新用户，i改为针对所有进入swipe&play模式的用户 ）
--   type: 1=swipe in teach_swipe_view, 2=swipe in normal swipe view 1031修改&新增, 3=swipe页面无导航栏 0822
--   status: 1=成功, 0=不成功
-- event: new_user_swipe_view
--   desc: 用户进入到swipe的页面
--   raw_notes: 0619 game_id:游戏id 0811 second _diff<int> 毫秒 0822 number:<int> 记录用户在被 Swipe 到时，该游戏在列表中的位置(第几位)
-- event: play_prompt
--   desc: 视频点击play提示
-- event: session_start
--   desc: 记录用户打开 App 的时间及启动来源。
--   type: 1=2：
--   bind: 1=安卓, 2=iOS, 3=WEB
-- event: teach_swipe_view
--   desc: swipe教程页面
--
-- [SQL]
with hab_events AS (
    SELECT 
        toDate(
            toTimeZone(server_time,'Asia/Singapore') 
        ) AS biz_date,
        device_id
    FROM new_loops_activity.hab_app_events
    WHERE event_name IN ('loading_page','session_start')
      AND server_time > now() - INTERVAL 14 DAY
)
select
toDate(now('Asia/Singapore') - INTERVAL 1 DAY) as date,source,country,
COALESCE(count(distinct case when event_name in ('new_user_intro_view') and type = 1 then t2.device_id else null end),0) as denominator,
COALESCE(count(distinct case when event_name in ('new_user_intro_view') and type = 2 then t2.device_id else null end),0) as numerator,
COALESCE(1.0*numerator/ NULLIF(denominator, 0), 0)  as value
from
    (select acc_pid, register_date as acc_date, COALESCE(
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
     where register_time1 > now() - interval 30 day
 )t1
        left join
    (SELECT device_id, toDate(toTimeZone(event_time,'Asia/Singapore')) as server_date, event_name, type
     FROM new_loops_activity.hab_app_events
     WHERE event_name in ('teach_swipe_view', 'new_user_swipe_view','play_prompt','game_enter','new_user_swipe','home_navigation_click','new_user_select_game_category','teach_swipe_view','new_user_intro_view','game_category_load_complete','intro_page_load_complete')
       and server_time > now() - interval 30 day
     group by device_id, server_date, event_name, type)t2
    on t1.acc_pid = t2.device_id and t1.acc_date = t2.server_date
        left join
    (SELECT
         pi as pid,
         toDate(toTimeZone(enter_time,'Asia/Singapore')) as event_date, count(distinct room_id) as games_played
     FROM new_loops_activity.newgame_room_log
     WHERE
         enter_time > now() - interval 30 day
       and greatest(
    coalesce(toFloat64(duration_by_ranking), 0),
    coalesce(toFloat64(duration_by_compute), 0),
    coalesce(toFloat64(duration_by_end), 0)
) > 0

     GROUP BY 1,2
    )t3 on t1.acc_pid = t3.pid and t1.acc_date = t3.event_date
where  acc_date > now() - INTERVAL 7 DAY
group by source,country order by 1 desc
