#!/bin/bash

ORACLE_SID=""

while [ $# -ne 0 ]
do
        case $1 in
                -s)   ORACLE_SID=$2
                      shift
                      ;;
            esac
        shift
done

if [ "$ORACLE_SID" = "" ]; then
echo "ORACLE_SID needs to be filled in"
exit 1
fi

export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/18.0.0.0
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$ORACLE_HOME/bin
export ORACLE_SID

sqlplus "/ as sysdba" <<EOF
drop restore point upgrade_$ORACLE_SID;
alter system set compatible='18.7.0.0.0' scope=spfile;
alter system set "_use_cached_asm_free_space"=TRUE scope=spfile;
shutdown immediate
exit
EOF

srvctl upgrade database -d $ORACLE_SID -o /u01/app/oracle/product/18.0.0.0
srvctl config database -d $ORACLE_SID -verbose
srvctl start database -d $ORACLE_SID

grep -i $ORACLE_SID /etc/oratab

sqlplus "/ as sysdba" <<EOF
create pfile='$ORACLE_BASE/admin/$ORACLE_SID/pfile/init${ORACLE_SID}.ora' from spfile;
exec DBMS_STATS.GATHER_FIXED_OBJECTS_STATS;
exec DBMS_STATS.GATHER_DICTIONARY_STATS;
exit
EOF

sqlplus -s "/ as sysdba" <<EOF
set serveroutput on
set heading off
set feed off
set termout off
set echo off
set feedback off
set lines 999
set trimspool on
set pages 0
spool /u01/app/oracle/scripts/upgrade/stats_${ORACLE_SID}.sql
select 'exec dbms_stats.gather_schema_stats('''||username||''',DEGREE=>4);'
from dba_users
where username in (select username from dba_users where oracle_maintained='N' and profile !='PASSWPROF');
spool off
@/u01/app/oracle/scripts/upgrade/stats_${ORACLE_SID}.sql
exit
EOF
