#!/bin/bash
#...
#... Duplicate an Oracle database starting from the backup of the source database
#...      Specifically for databases using ASM.
#... 
#... Usage : duplicate database using RMAN
#...
############################################################################
pgm="rman_duplicate_asm_to_asm"
datstart=`date`



swerr=0
swokwar=0

# Security variables.
processid="$$"
ISO_RESULT=/custom/oracle/trace/petittest_${processid}.lst
ISO_LOGFILE=/custom/oracle/trace/petittest_${processid}.log

msgerr="nihil"


DEST_SID="UNKNOWN"           # Oracle SID             default unknown
SRC_SID="UNKNOWN"       # Source database ID from which the backup has been taken.
RMAN_SID="UNKNOWN"      # The default RMAN recovery catalog database
SHOST_ID="UNKNOWN"	# The remote UNIX host on which the SRC_SID resides.
DHOST_ID="UNKNOWN"	# The remote UNIX host on which the DEST_SID resides.



USAGE="Usage : /u01/app/oracle/admin/restore/scripts/${pgm}.sh  -d DEST_SID -s SRC_SID -r RMAN_SID -a ADM_SID"


host=`hostname -s`



log="/u01/app/oracle/admin/restore/log/${pgm}.log"
logdir="/u01/app/oracle/admin/restore/log"
cmddir="/u01/app/oracle/admin/restore/scripts"
ok="/u01/app/oracle/admin/restore/log/${pgm}.ok"
err="/u01/app/oracle/admin/restore/log/${pgm}.err"

rm ${log}    1>/dev/null 2>&1
rm ${ok}     1>/dev/null 2>&1
rm ${err}    1>/dev/null 2>&1

cmdlog="UNKNOWN"



#
# Check database and environment :
# ------------------------------

set -- `getopt d:r:s:a:  $*`

if [ ${?} -ne 0 ] 
then

msgerr=" STOPPED  -  you did not give the right parameters for this run"

echo ""                                                                                                >${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
echo "        ${USAGE}"                                                                               >>${log}
echo ""                                                                                               >>${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
mailx -s "${title}" IT.database@fluxys.net              < ${log}
mailx -s "${title}" IT.database.team@fluxys.net         < ${log}
rm  ${log}    1>/dev/null  2>&1
exit 1
fi

while [ $# -gt 0 ] 
do
case ${1} in
-d)
DEST_SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
lowerDEST_SID=`echo ${2} | tr '[:upper:]' '[:lower:]'`
shift 2
;;
-r)
RMAN_SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
shift 2
;;
-s)
SRC_SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
lowerSRC_SID=`echo ${2} | tr '[:upper:]' '[:lower:]'`
shift 2
;;
-a)
ADM_SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
lowerADM_SID=`echo ${2} | tr '[:upper:]' '[:lower:]'`
shift 2
;;
--)
shift
break
;;
esac
done

if [ "${DEST_SID}" = "UNKNOWN" ] || [ "${SRC_SID}" = "UNKNOWN" ] || [ "${ADM_SID}" = "UNKNOWN" ] ;
then

msgerr=" STOPPED  -  you have to give at least a DESTINATION Oracle SID, a SOURCE database ID and an ADMIN database ID"  

echo ""                                                                                                >${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
echo "        ${USAGE}"                                                                               >>${log}
echo ""                                                                                               >>${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
mailx -s "${title}" IT.database@fluxys.net              < ${log}
mailx -s "${title}" IT.database.team@fluxys.net         < ${log}
rm  ${log}    1>/dev/null  2>&1
exit 1
fi

log="/u01/app/oracle/admin/restore/log/${DEST_SID}/${pgm}.log"
logdir="/u01/app/oracle/admin/restore/log/${DEST_SID}"
if [ ! -d ${logdir} ] ;
then
mkdir ${logdir}
fi
echo " "										> ${log}
cmddir="/u01/app/oracle/admin/restore/scripts/${DEST_SID}"
if [ ! -d ${cmddir} ] ;
then
mkdir ${cmddir}
fi
if [ ! -d ${cmddir}/pfile_dup ] ;
then
mkdir ${cmddir}/pfile_dup
fi
if [ ! -d ${cmddir}/pfile_src ] ;
then
mkdir ${cmddir}/pfile_src
fi
ok="/u01/app/oracle/admin/restore/log/${DEST_SID}/${pgm}.ok"
err="/u01/app/oracle/admin/restore/log/${DEST_SID}/${pgm}.err"

oktestsysdest="nihil"
oktestsyssrc="nihil"
oktestdzdba_adm="nihil"
rmanowner="RMANCAT"

# Get SYS info for destination db  SID
/usr/local/bin/ora_petittest.ksh ${DEST_SID} DB SYS ${ADM_SID} ${processid}
rcsps=$?
if [ ${rcsps} -ne 0 ] ;
then
if [ ${rcsps} -eq 1 ] ;
then
echo "Wrong usage of ora_petittest.ksh first try -- review parameters"                          >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
if [ ${rcsps} -eq 2 ] ;
then
echo "Problem looking for information in administration databases"                                >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
else
oktestsysdest=`cat ${ISO_RESULT}`
rm -f ${ISO_RESULT}
fi

# Get SYS info for source database for duplication
/usr/local/bin/ora_petittest.ksh ${SRC_SID} DB SYS ${ADM_SID} ${processid}
rcsps=$?
if [ ${rcsps} -ne 0 ] ;
then
if [ ${rcsps} -eq 1 ] ;
then
echo "Wrong usage of ora_petittest.ksh first try -- review parameters"                          >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
if [ ${rcsps} -eq 2 ] ;
then
echo "Problem looking for information in administration databases"                                >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
else
oktestsyssrc=`cat ${ISO_RESULT}`
rm -f ${ISO_RESULT}
fi

# Get rman catalog owner info for rman catalog DB
/usr/local/bin/ora_petittest.ksh ${RMAN_SID} DB ${rmanowner} ${ADM_SID} ${processid}
rcsps=$?
if [ ${rcsps} -ne 0 ] ;
then
if [ ${rcsps} -eq 1 ] ;
then
echo "Wrong usage of ora_petittest.ksh first try -- review parameters"                          >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
if [ ${rcsps} -eq 2 ] ;
then
echo "Problem looking for information in administration databases"                                >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
else
oktestrman=`cat ${ISO_RESULT}`
rm -f ${ISO_RESULT}
fi

# Get dzdba info for administration DB
/usr/local/bin/ora_petittest.ksh ${ADM_SID} DB DZDBA ${ADM_SID} ${processid}
rcsps=$?
if [ ${rcsps} -ne 0 ] ;
then
if [ ${rcsps} -eq 1 ] ;
then
echo "Wrong usage of ora_petittest.ksh first try -- review parameters"                          >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
if [ ${rcsps} -eq 2 ] ;
then
echo "Problem looking for information in administration databases"                                >> ${log}
cat ${ISO_LOGFILE}                                                                                >> ${log}
swerr=1
fi
else
oktestdzdba_adm=`cat ${ISO_RESULT}`
rm -f ${ISO_RESULT}
fi

# Clean up the LOGFILE of the security procedure
rm -f ${ISO_LOGFILE}

# create a SQL-script to reset the passwords of the schema owners back to the ones used now in the duplicate database.
sqlplus -s /nolog <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect dzdba/${oktestdzdba_adm}@${ADM_SID}
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
spool ${logdir}/alter_user_passwd.sql;
select 'alter user '||user_account||' identified by "'||dbsec_endescrypt.flx_dbsec_select(tns_srv,user_account,'DB')||'" ;'
from dbsec where tns_srv='${DEST_SID}' and entity_type = 'DB';
spool off;
set serveroutput on;
spool ${logdir}/reset_privs_00_revoke_table_privs.sql
execute pck_flx_restore_privs.revoke_table_privs ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_01_revoke_roles.sql
execute pck_flx_restore_privs.revoke_roles_from_users ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_02_drop_roles.sql
execute pck_flx_restore_privs.drop_roles ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_03_drop_flx_user.sql
execute pck_flx_restore_privs.drop_flx_user ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_04_drop_role_owner.sql
execute pck_flx_restore_privs.drop_role_owner ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_05_create_role_owner.sql
execute pck_flx_restore_privs.create_role_owner ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_06_create_flx_user.sql
execute pck_flx_restore_privs.create_flx_user ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_07_create_roles.sql
execute pck_flx_restore_privs.create_roles ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_08_link_roles.sql
execute pck_flx_restore_privs.link_roles_to_users ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_09_create_table_privs.sql
execute pck_flx_restore_privs.create_table_privs ('${SRC_SID}','${DEST_SID}');
spool off;
spool ${logdir}/reset_privs_10_schema_owners.log
exec pck_flx_restore_privs.check_schema_owners('${SRC_SID}','${DEST_SID}');
spool off;
exit;
EOF
if [ $? -ne 0 ] || [ ! -s ${logdir}/alter_user_passwd.sql ] ;
then
swerr=1
echo ""                                                                                                >${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
echo "        Attention: error when creating alter user identified script "                           >>${log}
echo ""                                                                                               >>${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
fi       
if [ `grep -c "ATTENTION" ${logdir}/reset_privs_10_schema_owners.log` -ne 0 ] ;
then
cat ${logdir}/reset_privs_10_schema_owners.log
question_answer="Y"
echo ""
echo ""
read -p " Do you want to continu [Y] :" question_answer
echo ""
echo ""
question_answer=`echo ${question_answer} | tr '[:lower:]' '[:upper:]'`

if [ "${question_answer}" = "N" ] ;
then
exit
fi
fi

tabel="v\$parameter"
tabel2="v\$datafile"
tabel3="v\$tempfile"
tabel4="v\$logfile"
tabel5="v\$controlfile"
sqlplus -s /nolog <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect sys/${oktestsysdest}@${DEST_SID} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
set lines 2000;
set trimspool on;
spool ${logdir}/alter_global_name.sql;
select 'alter database rename global_name to '||global_name||';' from global_name;
spool off;
spool ${logdir}/cluster_info_${DEST_SID}.log;
select value from $tabel where name = 'cluster_database' ;
spool off;
spool ${logdir}/spfile_info_${DEST_SID}.log;
select value from $tabel where name = 'spfile';
spool off;
spool ${logdir}/recreate_db_links.log;
select 'create database link '||owner||'.'||db_link||' connect by '||username||' identified by xxx using '''||host||''';'
from dba_db_links;
spool off;
spool ${logdir}/remove_oldfiles_${DEST_SID}.sh
select 'asmcmd <<EOF' from dual;
select 'rm -f '||name from $tabel2;
select 'rm -f '||name from $tabel3;
select 'rm -f '||member from $tabel4;
select 'rm -f '||name from $tabel5;
select 'rm -f +FRA/${DEST_SID}/FLASHBACK/*' from dual;
select 'rm -rf +FRA/${DEST_SID}/ARCHIVELOG/*' from dual;
select 'exit' from dual;
select 'EOF' from dual;
spool off;
create pfile='${cmddir}/pfile_dup/init${DEST_SID}.ora' from spfile;
alter database backup controlfile to trace;
exit;
EOF
if [ $? -ne 0 ] ;
then
swerr=1
echo ""                                                                                                >${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
echo "        Attention: error when creating pfile of duplicate database "                            >>${log}
echo ""                                                                                               >>${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
fi

tabel="v\$parameter"
tabel2="v\$datafile"
tabel3="v\$log"
tabel4="v\$logfile"
tabel5="v\$tempfile"

sqlplus -s /nolog <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect sys/${oktestsyssrc}@${SRC_SID} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
set lines 2000;
set trimspool on;
spool ${cmddir}/pfile_src/init${SRC_SID}.ora;
select value from $tabel where name='control_files';
spool off;
spool ${logdir}/newname_file.log
select 'set newname for datafile '||file#||' to ''+DATA'';' from $tabel2;
select 'set newname for tempfile '||file#||' to ''+DATA'';' from $tabel5;
spool off;
set serveroutput on;
spool ${logdir}/redologfile_thread1_file.log
declare
i2_logteller number :=0;
i2_logmember number := 0;
cursor c_loggroups is
select group#,bytes/1024 grootte from $tabel3 where thread#=1;
begin
i2_logteller := 0;
for group_rec in c_loggroups LOOP
IF i2_logteller = 0 THEN
dbms_output.put_line ('group '||group_rec.group#||' (''+FRA'',''+DATA'') size '||group_rec.grootte||'K');
ELSE
dbms_output.put_line (', group '||group_rec.group#||' (''+FRA'',''+DATA'') size '||group_rec.grootte||'K');
END IF;
i2_logteller := i2_logteller + 1;
END LOOP;
END;
/
spool off;
spool ${logdir}/tempfile_file.log
select 'alter tablespace '||tablespace_name||' add tempfile size '||bytes/1024||'K;' from dba_temp_files;
spool off;
exit;
EOF

if [ $? -ne 0 ] ;
then
swerr=1
echo ""                                                                                                >${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
echo "        Attention: error when creating pfile of source database "                               >>${log}
echo ""                                                                                               >>${log}
echo "============================================================================="                  >>${log}
echo ""                                                                                               >>${log}
fi

if [ ${swerr} -eq "0" ] ;
then 

DHOST_ID=`sqlplus -s /nolog <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect dzdba/${oktestdzdba_adm}@${ADM_SID}
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
select replace(server_name,'|') from databases where global_name = '${DEST_SID}';
exit
EOF`
echo ${DEST_SID}
echo ${DHOST_ID}
fi
echo ${DHOST_ID}
scp -pr ${logdir}/* ${DHOST_ID}:${logdir}/.

scp -pr ${cmddir}/* ${DHOST_ID}:${cmddir}/.


exit 0
