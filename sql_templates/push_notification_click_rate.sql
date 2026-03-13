-- metric_id: push_notification_click_rate
-- metric_name: 推送点击率
-- card_name: Push notification click rate
-- card_id: 3240
-- dashboard: L2 (id=522)
-- business_domain: Engagement
-- owner: product, ops
-- definition: 指标定义
-- description: 每天推送点击情况
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.hab_app_events, new_loops_activity.push_history, rings_broadcast.pk_player_record
-- events_used: push_notification
--
-- [KEY FIELDS]
-- event: push_notification
--   desc: 通知feed
--   status: 1=展示, 2=点击, 3=消息到达客户端
--   number: 1=in-app, 2=out-app (仅Android端有记录)
--   type: 对应 push_history.text_id (推送模板ID, 需 < 100000 排除系统推送)
--
-- [SQL]
WITH
    new_user as (
        select acc_pid, acc_uid
        from new_loops_activity.gametok_user
    ),

    receive_noti as (
        select t1.user_id as user_id, t1.device_id as device_id, t1.event_time as event_time, t1.type as type, t1.number as number, t1.status as status, t2.text_content as text_content, t2.text_pool as text_pool
        from (select user_id, device_id, event_name, event_time, type, number, status from new_loops_activity.hab_app_events
where server_time > now() - interval 30 day and device_id in (select distinct acc_pid from new_user) group by all) as t1
                 left join (select * from new_loops_activity.push_history where create_time > now() - interval 30 day and text_id < 100000 group by all) as t2 on t1.type = t2.text_id and t1.user_id = t2.user_id
        where event_name = 'push_notification'
          and type < 100000
          and type is not null
        group by all
    ),

    click_agg as (
        select toDate(toTimeZone(event_time,'Asia/Singapore')) as date, text_pool, count(1) as click_times
        from receive_noti
        where number = 2 and status = 2 group by 1,2),
    pn_send as (
        select toDate(toTimeZone(create_time,'Asia/Singapore')) as date, text_pool, count(1) as send_times
        from new_loops_activity.push_history where create_time > now() - interval 30 day
--         and task_info like '%"inApp":false%'
                                             group by 1,2
    ),
    participated AS (
        select biz_date, acc_uid from
            (select
                 biz_date,acc_uid,status AS last_status,
                 arrayLast(s -> s IN ('accepted','ready','fighting','gameover'), statuses) AS stage_final_status,
                 arrayExists(s -> s = 'disconnect', statuses) AS has_disconnect
             from
                 (SELECT
                      pk_id,
                      toDate(
                              toDateTime(create_time, 'Asia/Singapore')
                                  - INTERVAL 17 HOUR - INTERVAL 30 MINUTE
                      ) AS biz_date,
                      t1.acc_uid AS acc_uid,
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
                                      ON t.player_id = t1.acc_uid))
        where last_status in ('fighting','gameover') or stage_final_status in ('fighting','gameover')
    ),
    join_after_click as (select a.date, text_pool, count(distinct b.acc_uid) as join_uv from
        (select toDate(toTimeZone(event_time,'Asia/Singapore')) as date, text_pool, user_id
         from receive_noti
         where number = 2 and status = 2)a left join participated b on a.user_id = b.acc_uid and a.date = b.biz_date group by 1,2
    )
select t1.date as date, t1.text_pool as text_pool, t1.send_times as denominator, t2.click_times as numerator, numerator/denominator as value from pn_send t1 left join click_agg t2 on t1.date=t2.date and t1.text_pool=t2.text_pool
left join join_after_click t3 on t1.date=t3.date and t1.text_pool=t3.text_pool
-- where text_pool in ('COMPETITION_2')
;
















-- with
--     new_user as (
--         select acc_pid, acc_uid
--         from new_loops_activity.gametok_user
--     ),

--     noti as (
--         select server_time, t1.user_id as user_id, t1.device_id as device_id, t1.event_time as event_time, t1.type as type, t1.number as number, t1.status as status,  t2.text_pool as text_pool
--         from
--         (select * from new_loops_activity.hab_app_events
--         where server_time > now() - interval 14 day and event_name = 'push_notification' and device_id in (select distinct acc_pid from new_user))t1
--             left join
--         (select user_id, text_id, text_pool from new_loops_activity.push_history where create_time > now() - interval 14 day) t2 on t1.type = t2.text_id and t1.user_id = t2.user_id
--         group by 1,2,3,4,5,6,7,8
--     ),

--     receive_noti as (
--         select toDate(toTimeZone(server_time,'Asia/Singapore')) as date, text_pool, count(1) as receive_times
--         from noti
--         where number = 1 and status = 1
--         group by text_pool, date
--     ),

--     click_noti as (
--         select toDate(toTimeZone(server_time,'Asia/Singapore')) as date, text_pool, count(1) as click_times
--         from noti
--         where number = 1 and status = 2
--         group by text_pool, date
--     )

-- select date, t1.text_pool, 
--  t1.receive_times as denominator, t2.click_times as numerator, 
-- 1.0 * t2.click_times / t1.receive_times as value
-- from receive_noti as t1
--          left join click_noti as t2 on t1.text_pool = t2.text_pool and t1.date = t2.date
-- where text_pool is not null
-- order by date desc
-- ;
