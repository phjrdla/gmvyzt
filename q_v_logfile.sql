set lines 200
column member format a100 trunc
select *
from v$logfile
order by group#, member;

select *
  from v$log;

