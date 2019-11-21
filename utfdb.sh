#!/usr/bin/ksh
this_script=$0
this_script=$0
cat <<!
This script attempts to perform an upgrade to 18c
several ancillary activities are performed before the proper upgrade database action
!

[[ $# == 0 ]] && {  print "script usage: $(basename $0) [-h] [-a Oracle 12c home] [-b Oracle 18c home] [-c RMAN catalog sid] -d DB to upgrade sid [-g Register with CRS Y/N]"; exit; }


# process number, to name files uniquely
pid=$$

# For temporay files
TMPDIR='/tmp'
[[ ! -d $TMPDIR ]] && { print "Directory $TMPDIR not found, exit."; exit; }

# log and error files
log=$TMPDIR/${this_script}_$pid.log
err=$TMPDIR/${this_script}_$pid.err

typeset -u ORACLE_SID
typeset -u RMANCAT_SID
typeset -u REGWGRID

while getopts "h:?a:?b:?c:?d:g:?" OPTION
do
  case "$OPTION" in
    a)
      O12_HOME=$OPTARG
      ;;
    b)
      O18_HOME=$OPTARG
      ;;
    c)
      RMANCAT_SID=$OPTARG
      ;;
    d)
      export ORACLE_SID=$OPTARG
      ;;
    g)
      REGWGRID=$OPTARG
      ;;
    h)
      print "script usage: $(basename $0) [-h] [-a Oracle 12c home] [-b Oracle 18c home] [-c RMAN catalog sid] -d DB to upgrade sid [-g Register with CRS Y/N]" 
      print "Exemple :  $(basename $0) -a /u01/app/oracle/product/12.1.0.2 -b /u01/app/oracle/product/18.0.0.0 -c RMANCAT -d BELREG -g Y" 
      print "Exemple :  $(basename $0) -d BELREG -g Y" 
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

########################################################################################
# A spfile alias must be present
typeset -u answer
answer=''
while [[ -z "$answer" ]]
do
  spfile="+DATA/$ORACLE_SID/spfile$ORACLE_SID.ora"
  read answer?"Is spfile $spfile in place?(Y/N)?" 
done 
[[ $answer != 'Y' ]] && { print "Exit $0"; exit; }

########################################################################################
# Default values
[[ -z $O12_HOME ]] && O12_HOME=/u01/app/oracle/product/12.1.0.2
[[ -z $O18_HOME ]] && O18_HOME=/u01/app/oracle/product/18.0.0.0

print "O12_HOME iz $O12_HOME"
print "O18_HOME iz $O18_HOME"
print "ORACLE_SID iz $ORACLE_SID"
print "RMANCAT_SID iz $RMANCAT_SID"
print "REGWGRID iz $REGWGRID"

# Environment
#ORAENV_ASK=NO
#. oraenv

# Connection to sys
cnxsys='/ as sysdba'
print "Connects to db with $cnx"

print "Check Oracle 18c listener is started"
rec=$(ps -ef | grep -i tnslsnr | grep -v grep)
print $rec  
[[ $rec != *18.0.0* ]] && { print 'Listener 18c is not started, exit.'; exit; }

########################################################################################
print "\nMake sure SYS SYSTEM and UNDOTBS1 tablespaces have at least one extensible file"
(( cnt=$($O12_HOME/bin/sqlplus -s $cnxsys <<! 
set pages 0
set timing off
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
whenever sqlerror exit SQL.SQLCODE
set lines 200
set timing off
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
print "\nCleanup underscored paramaters"
cmdfile=$TMPDIR/sql_$pid.cmd
$O12_HOME/bin/sqlplus -s $cnxsys <<!
whenever sqlerror exit SQL.SQLCODE
set lines 200
set pages 0
set feedback off
set heading off
set timing off
spool $cmdfile
select 'alter system reset "'||name||'" scope=spfile;'
  from v\$spparameter 
 where substr(name,1,1) = '_'
   and isspecified='TRUE';
spool off
!

if [[ -s $cmdfile ]]
then
  cat $cmdfile
  $O12_HOME/bin/sqlplus -s $cnxsys <<!
@$cmdfile
exit
!
else
  print 'no underscored paremeters to remove'
fi

########################################################################################
print "\nA bunch of recommanded actions before upgrade"
$O12_HOME/bin/sqlplus -s $cnxsys <<!
whenever sqlerror continue
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

########################################################################################
print "\nSave password file"
cp -p $ORACLE_HOME/dbs/orapw$ORACLE_SID /tmp/orapwd${ORACLE_SID}_$$

########################################################################################
print "\nGenerate a report on db with preupgrade tool"
stage_dir=/u01/app/oracle/cfgtoollogs/$ORACLE_SID/preupgrade
preupgrade_log=$stage_dir/preupgrade.log
preupgrade_fixups_sql=$stage_dir/preupgrade_fixups.sql
postupgrade_fixups_sql=$stage_dir/postupgrade_fixups.sql
$O18_HOME/jdk/bin/java -jar $O18_HOME/rdbms/admin/preupgrade.jar TERMINAL TEXT

# Display preupgrade tool log
view $preupgrade_log

# Decide if upgrade process should go on ....
typeset -u answer
answer=''
while [[ -z "$answer" ]]
do
  read answer?"Proceed with the upgrade (Y/N)?" 
done 
[[ $answer != 'Y' ]] && { print "Exit $0"; exit; }

########################################################################################
print "\nResize SYSTEM SYSAUX UNDOTBS1 if needed"
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

########################################################################################
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
create or replace directory TMPDIR as '$TMPDIR';
grant read,write on directory TMPDIR to public;
exit
!

# data pump parameter file
cmdfile="$TMPDIR/cmdfile_$pid.dp"
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

print '\nFull database metadata dump created'
$O12_HOME/bin/expdp \'/  as sysdba\' parfile=$cmdfile 

########################################################################################
print '\nmake sure flashback is activated and a guaranteed savepoint created'
print '\nCreate restore point DB_UPGRADE'
$O12_HOME/bin/sqlplus -s $cnxsys <<!  
alter database flashback on;
create restore point DB_UPGRADE guarantee flashback database;
exit
!

########################################################################################
print '\nRun prupgrade fixup script'
print "$preupgrade_fixups_sql is run ..."
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
whenever sqlerror exit SQL.SQLCODE
set lines 200
set pages 1000
set timing on
spool preupgrade_fixups.$ORACLE_SID
@$preupgrade_fixups_sql
spool off
exit
!

########################################################################################
print '\nInvalid objects before upgrade'
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
whenever sqlerror exit SQL.SQLCODE
set lines 240
set pages 1000
set timing on
column owner       format a30 trunc
column status      format a10 trunc
column object_name format a30 trunc
column object_type format a30 trunc

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

# Decide if upgrade process should go on ....
answer=''
while [[ -z "$answer" ]]
do
  read answer?"Proceed with the upgrade (Y/N)?" 
done 
[[ $answer != 'Y' ]] && { print "Exit $0"; exit; }

########################################################################################
print '\nOracle 12c instance is stopped'
$O12_HOME/bin/sqlplus -s $cnxsys <<! 
shutdown immediate;
exit
!

########################################################################################
print '\nCopy ORACLE_HOME/dbs files to 18c ORACLE_HOME'
cp -p $O12_HOME/dbs/*${ORACLE_SID}* $O18_HOME/dbs 

# Oracle 18 binaries are used now
print "$O18_HOME binaries are now used" 

# Change environnment
export ORACLE_HOME=$O18_HOME
export PATH=$ORACLE_HOME/bin:$PATH

########################################################################################
print '\nOracle 18c instance is started in upgrade mode'
$O18_HOME/bin/sqlplus -s $cnxsys <<!
whenever sqlerror exit SQL.SQLCODE
startup upgrade;
exit
!

########################################################################################
print "\nUpgrade to 18c beginth ...."
$O18_HOME/bin/dbupgrade 

# Decide if upgrade process should go on ....
typeset -u answer
answer=''
while [[ -z "$answer" ]]
do
  read answer?"Proceed with the upgrade (Y/N)?" 
done 
[[ $answer != 'Y' ]] && { print "Exit $0"; exit; }

########################################################################################
print '\nUpgrade TIMEZONE step 1'
$O18_HOME/bin/sqlplus -s $cnxsys <<! 
whenever sqlerror exit SQL.SQLCODE
set lines 200
set pages 1000
SET SERVEROUT ON SIZE UNLIM
spool timezone_file_1.$ORACLE_SID
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
print '\nUpgrade TIMEZONE, step 2'
$O18_HOME/bin/sqlplus -s $cnxsys <<! 
whenever sqlerror exit SQL.SQLCODE
set lines 200
set pages 1000
SET SERVEROUT ON SIZE UNLIM
spool timezone_file_2.$ORACLE_SID
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

########################################################################################
print '\nCheck database properties'
$O18_HOME/bin/sqlplus -s $cnxsys <<!
whenever sqlerror exit SQL.SQLCODE
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

########################################################################################
print '\nPostupgrade script'
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

########################################################################################
print '\nPost upgrade additional steps'
print 'Save spfile and define compatible to 18.7.0.0'
$O18_HOME/bin/sqlplus -s $cnxsys <<!
drop restore point DB_UPGRADE;
create pfile='/tmp/spfile${ORACLE_SID}_18_$$' from spfile;
alter system set compatible='18.7.0.0.0' scope=spfile;
shutdown immediate;
startup;
@?/rdbms/admin/utlrp.sql
exit
!

########################################################################################
print '\nInvalid objects after upgrade'
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

########################################################################################
# Statistics
print '\nDictionary, fixed objects and database statistics'
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

########################################################################################
# register in rman catalog
if [[ ! -z $RMANCAT_SID ]]
then
  print '\nRegister with friendly rman catalog'
  cat <<! > $TMPDIR/rman_${pid}.rman
connect catalog rmancat/dba0225@$RMANCAT_SID
connect target /
register database
exit
!
  cat $TMPDIR/rman_${pid}.rman
  echo "$O18_HOME/bin/rman @$TMPDIR/rman_${pid}.rman"  
fi

########################################################################################
# upgrade crs config
if [[ ! -z $REGWGRID ]]
then
  print '\nUpgrade friendly CRS configuration'
  echo "srvctl upgrade database -db $ORACLE_SID -oraclehome $O18_HOME"  
  echo "srvctl config database -db $ORACLE_SID" 
fi
