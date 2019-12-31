#!/usr/bin/ksh
#
# Sessions count and details per server
# Sessions count and details per schema
# Uses V$SESSION
#
this_script=$0

[[ $# != 1 ]] && { print "Usage is $this_script db_name"; exit; }

typeset -u DB_NAME=$1
typeset -l lowerDB_NAME=$1

# Any instance DB_NAME runnign?
(( instanceUp = $(ps -ef | grep "pmon_$DB_NAME\$" | grep -v grep | wc -l ) ))
(( instanceUp == 0 )) && { print "No instance $DB_NAME found running, exit."; exit; }

# Environment
export ORACLE_SID=$DB_NAME
ORAENV_ASK=NO
. oraenv

# Session report retention
(( repret = 62 ))

print "Report retention is $repret days"

# Sessions reports location
report_dir="/u01/app/oracle/admin/$DB_NAME/stats_sessions"
[[ ! -d $report_dir ]] && mkdir -p $report_dir 

print "Collecting sessions count for $DB_NAME"

[[ -z $ORACLE_HOME ]] && { print "ORACLE_HOME is not defined, exit."; exit; }

cnx="dzdba/Qmx0225_$lowerDB_NAME@$DB_NAME"

$ORACLE_HOME/bin/sqlplus -s $cnx <<!
whenever sqlerror exit sql.sqlcode
set echo off
set lines 130
set pages 500
column machine    format a30 trunc
column schemaname format a30 trunc
column osuser	  format a30 trunc
column status     format a10 trunc
column sessions   format 99999

column instance_name new_value loc_instance
column host_name     new_value loc_host
column timestamp     new_value loc_time
column report_name   new_value report_name

set termout off
select instance_name, host_name, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') "timestamp"
  from v\$instance;

select '$report_dir/'||instance_name||'_stats_sessions_'||to_char(sysdate,'YYYYMMDD_HH24MISS')||'.lst' "report_name"
  from v\$instance;
set termout on

ttitle "&loc_host / &loc_instance / Sessions Inventory / &loc_time"

spool &report_name
clear breaks
clear computes
break on machine skip 1 on report
compute sum of "sessions" on machine
compute sum of "sessions" on report
select machine,  count(1) "sessions", status, schemaname, osuser
  from v\$session
 group by  machine, schemaname, osuser, status
 order by machine, status, 2 desc;
 
clear breaks
clear computes
break on schemaname skip 1 on report
compute sum of "sessions" on schemaname
compute sum of "sessions" on report
select schemaname,  count(1) "sessions", status, machine, osuser
  from v\$session
 group by  schemaname, machine, osuser, status
 order by schemaname, status, 2 desc;
spool off

exit
!

# Delete reports older then retention (repret in days)
find $report_dir -mtime +$repret -exec ls -l {} \;
find $report_dir -mtime +$repret -exec rm {} \;
