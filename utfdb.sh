#!/bin/ksh
this_script=$0
pid=$$

(( $# != 1 )) && { print "usage is $this_script oracle_sid"; exit; }


typeset -u ORACLE_SID=$1

O12_HOME=/u01/app/oracle/product/12.1.0.2
O18_HOME=/u01/app/oracle/product/18.0.0.0

# Environment
ORAENV_ASK=NO
. oraenv

# Connection to sys
cnxsys='/ as sysdba'

print "O12_HOME    iz $O12_HOME"
print "O18_HOME    iz $O18_HOME"
print "ORACLE_HOME iz $ORACLE_HOME"
print "ORACLE_SID  iz $ORACLE_SID"


########################################################################################
# Make sure SYS SYSTEM and UNDOTBS1 tablespaces have at least one extensible file
(( cnt=$($O12_HOME/bin/sqlplus -s $cnxsys <<!
set pages 0
set feedback off
set heading on
select count(1)
from dba_data_files
where tablespace_name in ('SYSTEM','SYSAUX','UNDOTBS1')
  and autoextensible = 'NO'
/
!)
))

if (( cnt > 0 ))
then
  print "$this_script : some datafiles are not autoextensible"
  $O12_HOME/bin/sqlplus -s $cnxsys <<!
set lines 200
set pages 0
set feedback off
set heading off
select 'alter database datafile '||''''||file_name||''' autoextend on next 32M;'
  from dba_data_files
 where tablespace_name in ('SYSTEM','SYSAUX','UNDOTBS1')
   and autoextensible = 'NO'
/
!
fi
(( cnt > 0 )) && { print "use generared alter database datafile command to fix, exit."; exit; }
########################################################################################

# Recommanded actions before upgrade
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
set serveroutput on
set lines 240
set pages 0
set timing on
spool prep.$ORACLE_SID
purge DBA_RECYCLEBIN;
SELECT * FROM v\$backup WHERE status !='NOT ACTIVE';
SELECT * FROM v\$recover_file;
create pfile='/tmp/pfile$ORACLE_SID.ora' from spfile;
execute DBMS_PREUP.INVALID_OBJECTS;
EXECUTE DBMS_STATS.GATHER_DICTIONARY_STATS;
EXECUTE SYS.UTL_RECOMP.RECOMP_PARALLEL(DBMS_STATS.DEFAULT_DEGREE);
spool off
!

# Save password file
cp -p $ORACLE_HOME/dbs/orapw$ORACLE_SID /tmp/orapwd${ORACLE_SID}_$$

# preupgrade tool report
# Pre-upgrade report on db
stage_dir=/u01/app/oracle/cfgtoollogs/$ORACLE_SID/preupgrade
preupgrade_log=$stage_dir/preupgrade.log
preupgrade_fixups_sql=$stage_dir/preupgrade_fixups.sql
postupgrade_fixups_sql=$stage_dir/postupgrade_fixups.sql
$O18_HOME/jdk/bin/java -jar $O18_HOME/rdbms/admin/preupgrade.jar TERMINAL TEXT

# Resize SYSTEM SYSAUX UNDOTBS1
for ts in SYSTEM SYSAUX UNDOTBS1
do
  if [[ $(grep $ts $preupgrade_log) ]]
  then
    (( reqsize=$(grep $ts $preupgrade_log | awk '{ print $4}') ))
    #print "reqsize is $reqsize"
    (( reqsize = reqsize + 100 ))
    $O12_HOME/bin/sqlplus -s $cnxsys <<!
    set lines 200
    set feedback off
    set heading off
    select 'alter database datafile '||''''||file_name||''' resize '||$reqsize||'M;'
      from dba_data_files 
     where tablespace_name='$ts' 
     order by bytes 
     fetch first 1 rows only
/
!
  fi 
done

# Check on tablesspace
for ts in SYSTEM SYSAUX UNDOTBS1
do
   [[ $(grep $ts $preupgrade_log) ]] && {  print "fix $ts size, exit."; exit; }
done

# Full datadump export for meta-data
$O12_HOME/bin/sqlplus -s $cnxsys <<!
create or replace directory TMPDIR as '/tmp';
grant read,write on directory TMPDIR to public;
exit
!

# data pump parameter file
cmdfile="/tmp/cmdfile_$pid.dp"
logfile="${ORACLE_SID}_META_$pid.lst"
dumpfile="${ORACLE_SID}_META_${pid}_%u.dmp"
cat <<! > $cmdfile
job_name=${ORACLE_SID}_META
flashback_time=systimestamp
directory=TMPDIR
dumpfile=$dumpfile
full=Y
parallel=4
logfile=$logfile
reuse_dumpfiles=Y
content=MetaData_Only
logtime=all
keep_master=no
!

# exports meta data for the whole database
$O12_HOME/bin/expdp \'/  as sysdba\' parfile=$cmdfile


# make sure flashback is acrivated and a guaranteed savepoint activated
$O12_HOME/bin/sqlplus -s $cnxsys <<!
alter database flashback on;
create restore point DB_UPGRADE guarantee flashback database;
exit
!

# Run prupgrade fixup script
print "$preupgrade_fixups_sql is run ..."
$O12_HOME/bin/sqlplus -s $cnxsys <<!
set lines 200
set pages 1000
set timing on
spool preupgrade_fixups.$ORACLE_SID
@$preupgrade_fixups_sql
spool off
exit
!

# Invalid objects before upgrade
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
set serveroutput on
set lines 240
set pages 1000
set timing on
column "INVALID_CNT" format 99999
spool invalid_objects_before.$ORACLE_SID
select count(1) "INVALID_CNT"
from dba_objects
where status = 'INVALID';

select owner, object_type, object_name, status
from dba_objects
where status = 'INVALID'
order by 1, 2, 3;
spool off
!


# Shutdown instance
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
shutdown immediate;
exit
!

# Copy ORACLE_HOME/dbs files
cp -p $O12_HOME/dbs/*${ORACLE_SID}* $O18_HOME/dbs


# Oracle 18 binaries are used now

# Change environnment
export ORACLE_HOME=$O18_HOME
export PATH=$ORACLE_HOME/bin:$PATH


$O18_HOME/bin/sqlplus -s $cnxsys <<!
startup upgrade;
exit
!


## Start upgrade tool
$O18_HOME/bin/dbupgrade

# Upgrade TIMEZONE
#shutdown immediate;
$O18_HOME/bin/sqlplus -s $cnxsys <<!
set lines 200
set pages 1000
SET SERVEROUT ON SIZE UNLIM
spool timezone_file.$ORACLE_SID
startup upgrade;
select * from v\$timezone_file;
DECLARE
l_tz_version PLS_INTEGER;
BEGIN
l_tz_version := DBMS_DST.get_latest_timezone_version;
DBMS_OUTPUT.put_line('l_tz_version=' || l_tz_version);
DBMS_DST.begin_upgrade(l_tz_version);
END;
/
spool off
exit
!

# Upgrade TIMEZONE
$O18_HOME/bin/sqlplus -s $cnxsys <<!
set lines 200
set pages 1000
SET SERVEROUT ON SIZE UNLIM
spool timezone_file.$ORACLE_SID
shutdown immediate;
startup upgrade;
DECLARE
l_failures PLS_INTEGER;
BEGIN
DBMS_DST.upgrade_database(l_failures);
DBMS_OUTPUT.put_line('DBMS_DST.upgrade_database : l_failures=' || l_failures);
DBMS_DST.end_upgrade(l_failures);
DBMS_OUTPUT.put_line('DBMS_DST.end_upgrade : l_failures=' || l_failures);
END;
/
spool off
exit
!

$O18_HOME/bin/sqlplus -s $cnxsys <<!
set lines 100
set pages 60
COLUMN property_name FORMAT A30
COLUMN property_value FORMAT A20
spool properties.$ORACLE_SID
SELECT property_name, property_value
FROM   database_properties
WHERE  property_name LIKE 'DST_%'
ORDER BY property_name;
spool off
exit
!

# Run postupgrade script
print "$preupgrade_fixups_sql is run ..."
$O18_HOME/bin/sqlplus -s $cnxsys <<!
set lines 200
set pages 1000
set timing on
spool postupgrade_fixups.$ORACLE_SID
@$postupgrade_fixups_sql
spool off
exit
!

# Post upgrade additonal steps
$O18_HOME/bin/sqlplus -s $cnxsys <<!
drop restore point DB_UPGRADE;
create pfile='/tmp/spfile${ORACLE_SID}_18_$$' from spfile;
alter system set compatible='18.7.0.0.0' scope=spfile;
shutdown immediate;
startup;
@?/rdbms/admin/utlrp.sql
exit
!

# Invalid objects after upgrade
$O18_HOME/bin/sqlplus -s $cnxsys <<! 
set serveroutput on
set lines 240
set pages 1000
set timing on
column "INVALID_CNT" format 99999
spool invalid_objects_after.$ORACLE_SID
select count(1) "INVALID_CNT"
from dba_objects
where status = 'INVALID';

select owner, object_type, object_name, status
from dba_objects
where status = 'INVALID'
order by 1, 2, 3;
spool off
!

# Statistics
$O18_HOME/bin/sqlplus -s $cnxsys <<! 
set serveroutput on
set lines 240
set pages 1000
set timing on
spool statistics_refresh.$ORACLE_SID

EXEC DBMS_STATS.GATHER_DICTIONARY_STATS;
execute dbms_stats.gather_fixed_objects_stats;
execute dbms_stats.gather_database_stats(degree=>DBMS_STATS.DEFAULT_DEGREE, cascade=>DBMS_STATS.AUTO_CASCADE, options=>'GATHER AUTO', no_invalidate=>False);
spool off
exit
!

# upgrade crs config
srvctl upgrade database -db $ORACLE_SID -oraclehome $O18_HOME
srvctl config database -db $ORACLE_SID
