-- metric_id: auto_reminder_click
-- metric_name: 参赛提醒卡片点击率
-- card_name: Auto reminder click
-- card_id: 3362
-- dashboard: L2 (id=522)
-- business_domain: Daily Challenge
-- owner: ceo, marketing, product, ops
-- definition: 点击用户/展示用户
-- description: 点击用户与展示用户的比例，反映参赛提醒卡片的点击率。
-- evaluation: higher_is_better
-- related_metrics: 
-- source_tables: new_loops_activity.gametok_user, new_loops_activity.kix_web_events, rings_broadcast.pk_activity, rings_broadcast.pk_activity_appointment, rings_broadcast.pk_player_record
-- events_used: challenge_reminder
--
-- [KEY FIELDS]
-- event: challenge_reminder
--   desc: 自动alert推送卡片
--   type: 1=展示, 2=点击
--
-- [SQL]
WITH challenge AS
         (
             SELECT DISTINCT
                 pk_id,
                 fromUnixTimestamp64Milli(activity_start_time, 'Asia/Singapore') AS event_time,
                 toDate(fromUnixTimestamp64Milli(activity_start_time, 'Asia/Singapore')) AS biz_date
             FROM rings_broadcast.pk_activity FINAL
             WHERE title = 'Challenge'
               AND activity_info_id IS NOT NULL
               AND toHour(fromUnixTimestamp64Milli(activity_start_time, 'Asia/Singapore')) IN (17, 21)
               AND toDate(fromUnixTimestamp64Milli(activity_start_time, 'Asia/Singapore')) >= toDate(now('Asia/Singapore') - INTERVAL 15 DAY)
         ),

     book AS
         (
             SELECT DISTINCT
                 t.pk_id,
                 toDate(toTimeZone(t.create_time, 'Asia/Singapore')) AS biz_date,
                 t1.acc_uid AS acc_uid
             FROM (select * from rings_broadcast.pk_activity_appointment  where create_time > now() - interval 30 day) t
                      INNER JOIN
                  (
                      SELECT DISTINCT acc_uid, acc_pid
                      FROM new_loops_activity.gametok_user
                      ) t1
                  ON t.user_id = t1.acc_uid
             WHERE t.status = 'join'
               AND t.create_time >= now() - INTERVAL 16 DAY
         ),

     auto_remind AS
         (
             SELECT DISTINCT
                 toInt32OrNull(pk_id) AS pk_id,
                 user_id, platform,
                 type
             FROM new_loops_activity.kix_web_events
             WHERE event_name = 'challenge_reminder' AND server_time > now() - interval 16 day
               AND type IN (1, 2)
               AND pk_id IS NOT NULL
         ),

     participated AS
         (
             SELECT DISTINCT
                 x.pk_id,
                 x.biz_date,
                 x.acc_uid
             FROM
                 (
                     SELECT
                         t.pk_id,
                         toDate(toTimeZone(t.create_time, 'Asia/Singapore')) AS biz_date,
                         t1.acc_uid AS acc_uid,
                         t.status AS last_status,
                         arrayLast(
                                 s -> s IN ('accepted', 'ready', 'fighting', 'gameover'),
                                 arrayMap(
                                         x -> JSONExtractString(x, 'userStatus'),
                                         arraySort(
                                                 x -> JSONExtractInt(x, 'curTimeMs'),
                                                 JSONExtractArrayRaw(ifNull(t.user_status_log, '[]'))
                                         )
                                 )
                         ) AS stage_final_status
                     FROM (select * from rings_broadcast.pk_player_record where create_time > now() - interval 16 day) t
                              INNER JOIN
                          (
                              SELECT DISTINCT acc_uid, acc_pid
                              FROM new_loops_activity.gametok_user
                              ) t1
                          ON t.player_id = t1.acc_uid
                     WHERE t.pk_id IN
                           (
                               SELECT pk_id
                               FROM challenge
                           )
                       AND toDate(toTimeZone(t.create_time, 'Asia/Singapore')) >= toDate(now('Asia/Singapore') - INTERVAL 16 DAY)
                     ) x
             WHERE x.last_status IN ('fighting', 'gameover')
                OR x.stage_final_status IN ('fighting', 'gameover')
         )

SELECT
    c.biz_date as date, coalesce(platform, 'Android') as platform,
    -- c.pk_id,

    -- countDistinct(b.acc_uid) AS denominator,
    countDistinctIf(b.acc_uid, ar.type = 1) AS denominator,
    countDistinctIf(b.acc_uid, ar.type = 2) AS numerator,
    -- countDistinctIf(b.acc_uid, p.acc_uid > 0) AS participated_uv
ifNull(numerator / nullIf(denominator, 0), 0) AS value
FROM challenge c
         LEFT JOIN book b
                   ON c.pk_id = b.pk_id
         LEFT JOIN auto_remind ar
                   ON b.pk_id = ar.pk_id
                       AND b.acc_uid = ar.user_id
         LEFT JOIN participated p
                   ON b.pk_id = p.pk_id
                       AND b.acc_uid = p.acc_uid

where c.biz_date <= date(now()) and c.biz_date > '2026-03-04'
GROUP BY
    c.biz_date, platform
    -- c.pk_id

ORDER BY
    c.biz_date DESC
    -- c.pk_id
	;
