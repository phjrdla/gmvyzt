set lines 240
set pages 100
select group#, bytes/(1024*1024) "MB"
from v$log
union
select group#, bytes/(1024*1024) "MB"
from v$standby_log
order by 1
/
column member format a100 trunc
select group#, member
from v$logfile
order by 1
/

