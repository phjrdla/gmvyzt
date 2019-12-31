#!/usr/bin/ksh
#
# Reports histograms for a specific event for the last n snapshots ...
# Uses dba_hist_event_histogram
#
#set -x
this_script=$0
[[ $# != 3 ]] && { print "Usage is $this_script DB_NAME event_number snapshots, exit."; exit; }

# Reports retention in days
(( repret = 62 ))

typeset -u DB_NAME=$1
typeset -l lowerDB_NAME=$1
(( event_number = $2 ))
(( snapshots = $3 ))

print "DB_NAME is $DB_NAME"
print "event_number is $event_number"
print "snapshots is $snapshots"
print "Report retention is $repret days"

(( snapshots < 0 )) && { print "Snapshots must be >= 0, exit."; exit; }

# Histograms reports location
report_dir="/u01/app/oracle/admin/$DB_NAME/histogram_4_event"
[[ ! -d $report_dir ]] && mkdir -p $report_dir

# Environment
#export ORACLE_SID=$DB_NAME
#ORAENV_ASK=NO
#. oraenv

cnx="dzdba/Qmx0225_$lowerDB_NAME@$DB_NAME"
print "cnx iz $cnx"

$ORACLE_HOME/bin/sqlplus -s $cnx <<!
column report_name new_value report_name noprint
column evt_name    new_value evt_name noprint
column timestamp   new_value loc_time noprint

set termout off

select instance_name, host_name, to_char(sysdate,'DD-MON-YYYY HH24:MI:SS') "timestamp"
  from v\$instance;

select '$report_dir/'||instance_name||'_histogram_4_event_${event_number}_'||to_char(sysdate,'YYYYMMDD_HH24MISS')||'.lst' "report_name"
  from v\$instance;

select name "evt_name"
  from v_\$event_name
 where event# =  $event_number;

set termout on

ttitle "$DB_NAME - &loc_time - Event &evt_name ($event_number) - Histogram"
set linesize 160
set pagesize 60
set echo on
set trimspool on

column BTIME format a17 trunc
column ETIME format a17 trunc
column WAIT_TIME_MS   format 999,999,999,999.999
column WAIT_COUNT     format 999,999,999
column WAIT_TOTAL_SEC format 999,999,999,999,999.999
column event_name     format a30 trunc

clear breaks
clear computes
break on WAIT_TIME_MS skip 1 on WAIT_COUNT on WAIT_TOTAL_SEC on event_name

spool &report_name
select eh.snap_id
      ,to_char(s.BEGIN_INTERVAL_TIME,'DD/MM/DD HH24:MI:SS') BTIME
      ,to_char(s.END_INTERVAL_TIME,'DD/MM/DD HH24:MI:SS') ETIME
      ,eh.event_name
      ,round(eh.WAIT_TIME_MILLI,3) WAIT_TIME_MS
      ,eh.WAIT_COUNT
      ,(eh.WAIT_TIME_MILLI*eh.WAIT_COUNT)/1000 WAIT_TOTAL_SEC
 from dba_hist_event_histogram eh
     ,dba_hist_snapshot s
     ,v_\$event_name en
where eh.snap_id = s.snap_id
  and eh.event_name = en.name
  and en.event# = $event_number
  and eh.WAIT_TIME_MILLI <= 3600*1000*2
  and s.snap_id >= ( select max(snap_id) - $snapshots
                      from dba_hist_snapshot )
order by eh.WAIT_TIME_MILLI, eh.snap_id 
/
spool off
!

#delete reports older then retention (repret in days)
find $report_dir -mtime +$repret -exec ls -l {} \;
find $report_dir -mtime +$repret -exec rm {} \;
