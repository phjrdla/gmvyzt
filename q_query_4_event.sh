#!/usr/bin/ksh
#
# Identified SQL statement related to an event
# note : por event 445 (SQL*NET break/reset event) we look for the previous statement
#
this_script=$0


[[ $# != 2 ]] && { print "Usage is $this_script DB_NAME event_number, exit."; exit; }

typeset -u DB_NAME=$1
typeset -l lowerDB_NAME=$1
(( event_number = $2 ))

# Session report retention
(( repret = 62 ))

print "DB_NAME is $DB_NAME"
print "event_number is $event_number"
print "Report retention is $repret days"

report_dir="/u01/app/oracle/admin/$DB_NAME/query_4_event"
[[ ! -d $report_dir ]] && mkdir -p $report_dir

# Environment
#export ORACLE_SID=$DB_NAME
#ORAENV_ASK=NO
#. oraenv

cnx="dzdba/Qmx0225_$lowerDB_NAME@$DB_NAME"
print "cnx iz $cnx"

$ORACLE_HOME/bin/sqlplus -s $cnx <<!
set long 1000
col piece format 999999
col sql_text 	   format a64 word_wrapped
column sql_id      format a14 trunc
column prev_sql_id format a14 trunc
column sid	   format 99999
column username    format a15 trunc
column schemaname  format a15 trunc
column osuser      format a20 trunc
column machine     format a20 trunc
column program     format a20 trunc
column "Logon"     format a17 trunc
column event       format a30 trunc
column "EXEC_DATE" format a19

column report_name   new_value report_name
column timestamp     new_value loc_time

set termout off
select instance_name, host_name, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') "timestamp"
  from v\$instance;

select '$report_dir/'||instance_name||'_query_4_event_${event_number}_'||to_char(sysdate,'YYYYMMDD_HH24MISS')||'.lst' "report_name"
  from v\$instance;
set termout on

clear breaks
break on sql_id page
ttitle "$DB_NAME - &loc_time - Event $event_number - Queries"
set linesize 215
set pagesize 100
set echo on
set trimspool on
spool &report_name
select sid
      ,username
      ,schemaname
      ,osuser
      ,program
      ,machine
      ,to_char(logon_time, 'DD-MM-YY HH24:MI:SS') "Logon"
      ,case event#
         when 445 then to_char(prev_exec_start,'DD/MM/YYYY HH24:MI:SS')
         else          to_char(sql_exec_start,'DD/MM/YYYY HH24:MI:SS')
      end "EXEC_DATE"
      ,event#
      ,event
      ,sql_id
      ,prev_sql_id
  from v\$session
 where event#=$event_number
 order by sid
/
select sql_id, sql_text
from dba_hist_sqltext
where sql_id in ( select distinct decode(event#, 445, prev_sql_id, sql_id) from v\$session where event#=$event_number )
order by sql_id
/
spool off
!

# Delete reports older then retention (repret in days)
find $report_dir -mtime +$repret -exec ls -l {} \;
find $report_dir -mtime +$repret -exec rm {} \;
