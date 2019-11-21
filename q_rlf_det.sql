set lines 240
set pages 60

column group_member format a60 trunc
column "MB" format 999999

select l.group# group_number
      , l.status group_status
      , f.member group_member
      , f.status file_status
      , l.bytes/(1024*1024) "MB"
  from v$log l , v$logfile f
 where l.group# = f.group#
 order by l.group# , f.member;

exit
