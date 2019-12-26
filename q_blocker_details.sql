set lines 250

col BLOCKER_SID      heading "BLOCKER|SID"
col BLOCKED_SID      heading "BLOCKED|SID"

col wait_event       heading "WAIT|EVENT"

col wait_event_text  format a30 trunc
col wait_event_text  HEADING "WAITING FOR"

col BLOCKER_USER     format a10 trunc
col BLOCKER_USER     HEADING "BLOCKER|USERNAME"

col BLOCKER_SCHEMA   format a10 trunc
col BLOCKER_SCHEMA   HEADING "BLOCKER|SCHEMANAME"

col BLOCKED_USER     format a10 trunc
col BLOCKED_USER     HEADING "BLOCKED|USERNAME"

col BLOCKED_OBJ_OWN  format a10 trunc
col BLOCKED_OBJ_OWN  HEADING "BLOCKED|OBJECT|OWNER"

col BLOCKED_OBJ_TYP  format a7 trunc
col BLOCKED_OBJ_TYP  HEADING "BLOCKED|OBJECT|TYPE"

col BLOCKED_OBJ_NAM  format a15 trunc
col BLOCKED_OBJ_NAM  HEADING "BLOCKED|OBJECT|NAME"

col LOCK_TYPE        format a15 trunc

col BLOCKED_SQL      format a40 trunc wrap
col BLOCKED_SQL      HEADING "BLOCKED SQL|STATEMENT"

col BLOCKER_SQL      format a40 trunc wrap
col BLOCKER_SQL      HEADING "BLOCKER SQL|STATEMENT"

col blocker_username format a15 trunc
col blocked_username format a15 trunc

col "BLOCKER_SQL_ID" format a14
col "BLOCKER_SQL_ID" HEADING "BLOCKER|SQL_ID"

col "BLOCKED_SQL_ID" format a14
col "BLOCKED_SQL_ID" HEADING "BLOCKED|SQL_ID"

select *
  from v$session_blockers 
/

rem   ,s2.sql_id                    "BLOCKED_SQL_ID"

select sb.blocker_sid
      ,s1.username 	            "BLOCKER_USER"
      ,nvl(ash_view.sql_id, 'None') "BLOCKER_SQL_ID"
      ,sql2.sql_text                "BLOCKER_SQL"
      ,sb.sid                       "BLOCKED_SID"
      ,s2.username                  "BLOCKED_USER"
      ,sql1.sql_text                "BLOCKED_SQL"
      ,dbo.owner                    "BLOCKED_OBJ_OWN"
      ,dbo.object_type              "BLOCKED_OBJ_TYP"
      ,dbo.object_name              "BLOCKED_OBJ_NAM"
      ,sb.wait_event
      ,sb.wait_event_text
      ,decode( lo.locked_mode ,0, 'None'
                              ,1, 'Null'
                              ,2, 'Row-S (SS)'
                              ,3, 'Row-X (SX)'
                              ,4, 'Share'
                              ,5, 'S/Row-X (SSX)'
                              ,6, 'Exclusive') lock_type
 from v$session_blockers sb
     ,v$session s1
     ,( select distinct session_id, sql_id
          from dba_hist_active_sess_history
         where (session_id, snap_id) in ( select session_id, max(snap_id)
                                            from dba_hist_active_sess_history
                                           group by session_id )
      ) ash_view
     ,v$session s2
     ,v$locked_object lo
     ,dba_objects dbo
     ,dba_hist_sqltext  sql1
     ,dba_hist_sqltext  sql2
where sb.blocker_sid  = s1.sid
  and sb.blocker_sid  = ash_view.session_id (+)
  and ash_view.sql_id = sql2.sql_id
  and sb.sid          = s2.sid
  and sb.sid          = lo.session_id
  and lo.object_id    = dbo.object_id (+)
  and s2.sql_id       = sql1.sql_id
/
