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

echo "Starting upgrade for $ORACLE_SID"

# Variables
export ORACLE_BASE=/u01/app/oracle
export ORACLE_HOME=/u01/app/oracle/product/12.1.0.2
export PATH=/usr/local/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$ORACLE_HOME/bin
export ORACLE_SID

# Pre-upgrade

if [ 1 = 2 ]; then
$ORACLE_BASE/product/18.0.0.0/jdk/bin/java -jar $ORACLE_BASE/product/18.0.0.0/rdbms/admin/preupgrade.jar TERMINAL TEXT
fi

# Create backup pfile

if [ ! \( -d $ORACLE_BASE/admin/$ORACLE_SID/pfile -a -w $ORACLE_BASE/admin/$ORACLE_SID/pfile \) ]; then
mkdir -p $ORACLE_BASE/admin/$ORACLE_SID/pfile
fi

sqlplus "/ as sysdba" <<EOF
create pfile='$ORACLE_BASE/admin/$ORACLE_SID/pfile/init${ORACLE_SID}_before.ora' from spfile;
create restore point upgrade_$ORACLE_SID guarantee flashback database;
select name,time,guarantee_flashback_database from v\$restore_point;
@/u01/app/oracle/cfgtoollogs/$ORACLE_SID/preupgrade/preupgrade_fixups.sql
exit
EOF

# Stop database
srvctl stop database -d $ORACLE_SID

# Copy the config files

cp $ORACLE_HOME/dbs/init$ORACLE_SID.ora /u01/app/oracle/product/18.0.0.0/dbs/
cp $ORACLE_HOME/dbs/orapw$ORACLE_SID /u01/app/oracle/product/18.0.0.0/dbs/
cp $ORACLE_HOME/dbs/spfile$ORACLE_SID.ora /u01/app/oracle/product/18.0.0.0/dbs/

# Switch to 18
export ORACLE_HOME=/u01/app/oracle/product/18.0.0.0
export PATH=/usr/local/bin:/bin:/usr/bin:/usr/local/sbin:/usr/sbin:$ORACLE_HOME/bin

sqlplus "/ as sysdba" <<EOF
startup upgrade
EOF

echo $ORACLE_SID

$ORACLE_HOME/bin/dbupgrade

export LOGDATE=`date +'%Y%m%d'`
cat /u01/app/oracle/product/18.0.0.0/cfgtoollogs/$ORACLE_SID/upgrade${LOGDATE}*/upg_summary.log

sqlplus "/ as sysdba" <<EOF
startup upgrade
SET SERVEROUTPUT ON
DECLARE
  l_tz_version PLS_INTEGER;
BEGIN
  SELECT DBMS_DST.get_latest_timezone_version
  INTO   l_tz_version
  FROM   dual;

  DBMS_OUTPUT.put_line('l_tz_version=' || l_tz_version);
  DBMS_DST.begin_upgrade(l_tz_version);
END;
/
SHUTDOWN IMMEDIATE
STARTUP
SET SERVEROUTPUT ON
DECLARE
  l_failures   PLS_INTEGER;
BEGIN
  DBMS_DST.upgrade_database(l_failures);
  DBMS_OUTPUT.put_line('DBMS_DST.upgrade_database : l_failures=' || l_failures);
  DBMS_DST.end_upgrade(l_failures);
  DBMS_OUTPUT.put_line('DBMS_DST.end_upgrade : l_failures=' || l_failures);
END;
/
SELECT * FROM v\$timezone_file;
@/u01/app/oracle/cfgtoollogs/$ORACLE_SID/preupgrade/postupgrade_fixups.sql
exit
EOF

echo "Continue with script post_upgrade_18_db.sh"


