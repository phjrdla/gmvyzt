#!/bin/bash
#...
#... Backup of an Oracle online database. Only actual datafiles 
#... are backed up (including the current control file).
#... 
#... Usage : backup of databases using RMAN
#...
#... Author : Jacobs Jan (Cronos)
#...
#... Revision 1.0 - Date : 26/02/2001
#...
#... Revision 1.1 - Date : 27/03/2001
#...      Add a resync of the recovery catalog before the backup command.
#... 
#... Revision 1.2 - Date : 27/03/2001
#...      Add the cleanup of the recovery catalog
#... 
#... Revision 2   - Date : 15/05/2001  - Desmet A.
#...      Interaction with Exchange  and  new Legato control files location
#... 
#... Revision 3   - Date : 08/01/2004  - Jacobs J.
#...      Accept a new parameter which indicates the database with
#...      the RMAN recovery catalog.
#... 
#... Revision 4   - Date : 12/12/2005  - Vanierschot B.
#...      Persistent configuration of controlfile backup.
#... 
#... Revision 5   - Date : 14/05/2007  - Jacobs J.
#...      Accept a new parameter (-D) which indicates the directory where RMAN should create the backup pieces.
#...
#... Revision 6   - Date : 02/10/2007  - Jacobs J.
#...	  Implementation ora_petittest.ksh
#...
############################################################################
function mail_error {
  datend=`date`
  echo ""                                                                                    >${err}
  echo "${pgm} : ${msgerr}."                                                                >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}
  echo "        Started at  '${datstart}  on  '${host}'."                                   >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}
  cat  ${log}                                                                               >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}
  echo "        Ended   at  '${datend}'."                                                   >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}

  title="ERROR within a :  '${ORACLE_BASE}/admin/backup/scripts/${pgm}.sh  -d ${SID}  -a ADMIN_SID1:ADMIN_SID2'  execution."

  mailx -s "${title}" IT.database@fluxys.net              < ${err}
  mailx -s "${title}" IT.database.team@fluxys.net         < ${err}

  rm  ${log}     1>/dev/null  2>&1
  rm  ${cmdlog}  1>/dev/null  2>&1
}

pgm="rman_online_ddup"

datstart=`date`

connect_catalog_ok=1

# Security variables.
processid="$$"
#ISO_RESULT=/custom/oracle/trace/petittest_${processid}.lst
#ISO_LOGFILE=/custom/oracle/trace/petittest_${processid}.log

SECFILE=/u01/app/oracle/scripts/security/reslist_${HOSTNAME}.txt.gpg

msgerr="nihil"

SID="UNKNOWN"           # Oracle SID             (default unknown)
RMAN_SID="UNKNOWN"      # The default RMAN recovery catalog database
TBSSPC=N            	# Rman tablespace backup (default NO)
DEST_DIR="UNKNOWN"      # The directory on which you would like to create this backup.
DDUP="UNKNOWN"          	# The default DDUP Location

USAGE="Usage : /u01/app/oracle/admin/backup/scripts/${pgm}.sh  -d SID -a ADMIN_SID1:ADMIN_SID2"

host=`hostname -s`
OSname=`uname`

# Determine the number of CPU's on the server
# For Linux, via /proc/cpuinfo
number_of_cpus=`cat /proc/cpuinfo | grep "^processor" | wc -l`
# In case the backup needs to be compressed, limit the number of channels depending on the number of CPU's on the server.
# Allocate, for compress, maximum half of the CPU's for number of channels.

log="/u01/app/oracle/admin/backup/log/${pgm}.log"
ok="/u01/app/oracle/admin/backup/log/${pgm}.ok"
err="/u01/app/oracle/admin/backup/log/${pgm}.err"

rm ${log}    1>/dev/null 2>&1
rm ${ok}     1>/dev/null 2>&1
rm ${err}    1>/dev/null 2>&1

cmdlog="UNKNOWN"

#
# Check database and environment :
# ------------------------------

set -- `getopt d:a:t  $*`

if [ ${?} -ne 0 ] 
then
  msgerr=" STOPPED  -  you didn't give the right parameters for this run"

  echo ""                                                                                                >${log}
  echo "============================================================================="                  >>${log}
  echo ""                                                                                               >>${log}
  echo "        ${USAGE}"                                                                               >>${log}
  echo ""                                                                                               >>${log}
  echo "============================================================================="                  >>${log}
  echo ""                                                                                               >>${log}
  mail_error
  exit 1
else
  while [ $# -gt 0 ] 
  do
    case ${1} in
	-t)
		TBSSPC=Y
		shift
		;;
	-d)
                SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
		shift 2
		;;
        -a)
                ADM_SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
                shift 2
                ;;
	--)
		shift
		break
		;;
    esac
  done
fi

if [ "${SID}" = "UNKNOWN" ] ;
then

    msgerr=" STOPPED  -  you have to give at least an  Oracle SID  as parameter"  

    echo ""                                                                                                >${log}
    echo "============================================================================="                  >>${log}
    echo ""                                                                                               >>${log}
    echo "        ${USAGE}"                                                                               >>${log}
    echo ""                                                                                               >>${log}
    echo "============================================================================="                  >>${log}
    echo ""                                                                                               >>${log}
    mail_error
    exit 1
else
    grep -v ^# /etc/oratab | grep ^"${SID}":
    rcssid=$?

    if [ ${rcssid} != 0 ] 
    then
      msgerr=" STOPPED  -  database  '${SID}'  doesn't exist on  '${host}'"  

      echo ""                                                                                                >${log}
      echo "============================================================================="                  >>${log}
      echo ""                                                                                               >>${log}
      echo "        ${USAGE}"                                                                               >>${log}
      echo ""                                                                                               >>${log}
      echo "============================================================================="                  >>${log}
      echo ""                                                                                               >>${log}
      mail_error
      exit 1
    fi
fi

#
# Change the environment to match the environment of the chosen database :
# ----------------------------------------------------------------------
. /usr/local/bin/oraprof ${SID}

oracle_version=`basename ${ORACLE_HOME}`

oktestsys="nihil"
oktestdzdba_adm="nihil"
oktesttest_connect="nihil"
rmanowner="RMANCAT"
oktestrman="nihil"

ADM_SID1=`echo $ADM_SID|cut -d: -f1`

ADM_SID2=`echo $ADM_SID|cut -d: -f2`

# Get DZDBA info for ADM_SID1

oktestadm1dzdba=`gpg -qd $SECFILE | grep -i "$ADM_SID1:DZDBA" | cut -d ":" -f3`
[[ -z $oktestadm1dzdba ]] && { echo "oktestadm1dzdba not defined, exit."; exit; }

# Get DZDBA info for ADM_SID2
oktestadm2dzdba=`gpg -qd $SECFILE | grep -i "$ADM_SID2:DZDBA" | cut -d ":" -f3`
[[ -z $oktestadm2dzdba ]] && { echo "oktestadm2dzdba not defined, exit."; exit; }

# Get SYS info for current db  (SID)
oktestsys=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:SYS:" | cut -d ":" -f3`
[[ -z $oktestsys ]] && { echo "oktestsys not defined, exit."; exit; }

# Get TEST_CONNECT info for the DB
oktesttest_connect=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:TEST_CONNECT" | cut -d ":" -f3`
[[ -z $oktesttest_connect ]] && { echo "oktesttest_connect not defined, exit."; exit; }

#
# Test to see if ADM_SID1 is running :
#-------------------------------------
test_connect="/custom/oracle/trace/test_connect_${processid}_${ADM_SID1}.trc"

sqlplus /nolog 1>${test_connect} 2>&1  <<EOF
connect test_connect/${oktesttest_connect}@${ADM_SID1};
EOF

CONNECTED=`cat ${test_connect} | grep 'Connected' | cut -f 2 -d " "`
rm ${test_connect} 1>/dev/null 2>&1

if [ ${CONNECTED:-0} != 0 ] ;
then
          ADMIN_INSTANCE=${ADM_SID1}
	  oktestadmdzdba=${oktestadm1dzdba}
else
#
# Test to see if ADM_SID2 is running :
# ------------------------------------
           test_connect="/custom/oracle/trace/test_connect_${processid}_${ADM_SID2}.trc"

           sqlplus /nolog 1>${test_connect} 2>&1  <<EOF
connect test_connect/${oktesttest_connect}@${ADM_SID2};
EOF

           CONNECTED=`cat ${test_connect} | grep 'Connected' | cut -f 2 -d " "`

           rm ${test_connect} 1>/dev/null 2>&1

           if [ ${CONNECTED:-0} != 0 ] ;
           then
                        ADMIN_INSTANCE=${ADM_SID2}
			oktestadmdzdba=${oktestadm2dzdba}
           else
                        echo ""                                                                                                      >>${log}
                        echo "============================================================================="                         >>${log}
                        echo ""                                                                                                      >>${log}
                        echo "  ADMIN Instance ${ADM_SID1} and instance  ${ADM_SID2}  were not running."                               >>${log}
                        echo ""                                                                                                      >>${log}
                        echo "============================================================================="                         >>${log}
                        echo ""                                                                                                      >>${log}
                        mail_error
                        exit 1
           fi
fi

sqlplus -s /nolog <<EOF
whenever sqlerror exit rollback;
connect dzdba/${oktestadmdzdba}@${ADMIN_INSTANCE}
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
set trimspool on;
spool /var/tmp/database_info_${SID}.log;
select nvl(rman_sid,'UNKNOWN')||'|'||nvl(backup_location,'UNKNOWN') from databases where SID = '${ORACLE_SID_BASE}' and server_name like '%|'||upper('$host')||'|%';
spool off;
exit;
EOF

RMAN_SID=`cat /var/tmp/database_info_${SID}.log|cut -d"|" -f1`

DDUP=`cat /var/tmp/database_info_${SID}.log|cut -d"|" -f2`

if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
# Get rman catalog owner info for rman catalog DB
        
  oktestrman=`gpg -qd $SECFILE | grep -i "$RMAN_SID:$rmanowner" | cut -d ":" -f3`
  [[ -z $oktestrman ]] && { echo "oktestrman not defined, exit."; exit; }

fi

# Clean up the LOGFILE of the security procedure
rm -f ${ISO_LOGFILE}
  
if [ "${DDUP}" = "UNKNOWN" ] ;                                                                                     
then                                                                                                              
    msgerr=" STOPPED  -  you have to give a DDUP location as parameter"                                    
                                                                                                                    
    echo ""                                                                                                  >${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    echo "        ${USAGE}"                                                                                 >>${log}
    echo ""                                                                                                 >>${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    mail_error
    exit 1
else                                                                                                              
    if [ ! -d /${DDUP}/backup/${SID} ]
    then
                msgerr=" STOPPED  -  DDUP Location '${DDUP}/backup/${SID}'  doesn't exist on  '${host}'"

                echo ""                                                                                                >${log}
                echo "============================================================================="                  >>${log}
                echo ""                                                                                               >>${log}
                echo "        ${USAGE}"                                                                               >>${log}
                echo ""                                                                                               >>${log}
                echo "============================================================================="                  >>${log}
                echo ""                                                                                               >>${log}
 		mail_error
		exit 1
    fi
fi  

#
# Export the backup directory and the actual oracle sid :
# -----------------------------------------------------
DIR_BACKUP_ROOT="UNKNOWN"                               # contains the backup files
DIR_BACKUP_DATA="UNKNOWN"                               # contains the backup files
DIR_BACKUP_CTL="UNKNOWN"                                # contains the backup files of controlfile
DIR_BACKUP_ALOG="UNKNOWN"                               # contains the backup files of archived redologs
DIR_SQL="UNKNOWN"                                       # contains the sql and lst files

BACKUP_DATE=`date +%Y%m%d`
  
if [ -d /${DDUP}/backup/${SID} ] ;
then
    export DIR_BACKUP_ROOT=/${DDUP}/backup/${SID}    
    export DIR_BACKUP_DATA=/${DDUP}/backup/${SID}/data_${BACKUP_DATE}     	
	if [ ! -d ${DIR_BACKUP_DATA} ]
	then 
		mkdir ${DIR_BACKUP_DATA}
	fi
    export DIR_BACKUP_CTL=/${DDUP}/backup/${SID}/ctl_${BACKUP_DATE}
	if [ ! -d ${DIR_BACKUP_CTL} ]
	then 
		mkdir ${DIR_BACKUP_CTL}
	fi	
    export DIR_BACKUP_ALOG=/${DDUP}/backup/${SID}/alog_${BACKUP_DATE}     		
	if [ ! -d ${DIR_BACKUP_ALOG} ]
	then 
		mkdir ${DIR_BACKUP_ALOG}
	fi
fi

export DIR_SQL=${ORACLE_BASE}/admin/backup/sql                

# 
# We will check the connectivity to the RMAN catalog with user RMANCAT
# If something goes wrong here we'll continue the script without a recovery catalog.
# -----------------------------------------------------------------------------------
connect_catalog_ok=1
if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
      if [ "${oktestrman}" != "nihil" ] ;
      then
        test_rman="/custom/oracle/trace/test_rman_${ORACLE_SID}.trc"
        sqlplus /nolog 1>${test_rman} 2>&1  <<EOF 
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect rmancat/${oktestrman}@${RMAN_SID};
EOF
        CONNECTED=`cat ${test_rman} | grep 'Connected' | cut -f 2 -d " "`  
        rm ${test_rman}    1>/dev/null 2>&1
        if [ ${CONNECTED:-0} != 0 ] ;
        then
          connect_catalog_ok=1
        else
          connect_catalog_ok=0
          RMAN_SID="UNKNOWN"
        fi
      else
        connect_catalog_ok=0
      fi
fi

caller="online"

STANDBY_DB=0
# ---------------------------------------------------------------------------------------
#   Here we'll perform the check to see if it's a standby database. 
#   If YES we'll continue the backup program.
# ---------------------------------------------------------------------------------------
echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;"                                               >${DIR_SQL}/info_${SID}.sql
echo "connect sys/${oktestsys}@${SID} as sysdba"                                        >>${DIR_SQL}/info_${SID}.sql
echo "set feedback off;"                                                                >>${DIR_SQL}/info_${SID}.sql
echo "set verify   off;"                                                                >>${DIR_SQL}/info_${SID}.sql
echo "set head     off;"                                                                >>${DIR_SQL}/info_${SID}.sql
echo "set echo     off;"                                                                >>${DIR_SQL}/info_${SID}.sql
echo "set termout  off;"                                                                >>${DIR_SQL}/info_${SID}.sql
echo "set pages 0;"                                                                     >>${DIR_SQL}/info_${SID}.sql
echo "spool ${DIR_BACKUP_DATA}/${SID}_backup_info.txt;"                                 >>${DIR_SQL}/info_${SID}.sql
echo "select controlfile_type from v\$database;"                                        >>${DIR_SQL}/info_${SID}.sql
echo "exit;"                                                                            >>${DIR_SQL}/info_${SID}.sql

${ORACLE_HOME}/bin/sqlplus -s /nolog @${DIR_SQL}/info_${SID}.sql   >> /dev/null
rcsps=$?
rm ${DIR_SQL}/info_${SID}.sql

rcserr=`grep -c "ORA-" ${DIR_BACKUP_DATA}/${SID}_backup_info.txt`
if [ ${rcserr} -eq 0 ] && [ ${rcsps} -eq 0 ];
then
        STANDBY_DB=`grep -c "STANDBY" ${DIR_BACKUP_DATA}/${SID}_backup_info.txt`
fi

swerr=1

while [ ${swerr} -gt 0 ] ;
do
          RESULT=`ps -ef | grep "rman target" | grep "@${ORACLE_SID_BASE}" | grep -v grep`
          rcsps=$?

          if [ ${rcsps} -eq 0 ] ;
          then

            let "swerr=${swerr}+1"

            if [ ${swerr} -eq 5 ] ;
            then
              datend=`date`

              export charset=us-ascii

              msgerr=" STOPPED  -  a previous RMAN session for  ${SID}  has been running for at least 30 minutes ==> this run is stopped."

              title="ERROR within a :  '${ORACLE_BASE}/admin/backup/scripts/${pgm}.sh ${START_PARAMS}'  execution."

              echo ""                                                                                    >${log}
              echo "${pgm} : ${msgerr}."                                                                >>${log}
              echo ""                                                                                   >>${log}
              echo ""                                                                                   >>${log}
              echo "        Started at  '${datstart}  on  '${host}'."                                   >>${log}
              echo ""                                                                                   >>${log}
              echo ""                                                                                   >>${log}
              echo "        Ended   at  '${datend}'."                                                   >>${log}
              echo ""                                                                                   >>${log}
              echo ""                                                                                   >>${log}

 	      mail_error

              rm  ${log}    1>/dev/null  2>&1

              exit 1
            fi

            sleep 300
	  else
		swerr=0
          fi
done

cd ${DIR_BACKUP_DATA}

okfile="${SID}_${pgm}.ok"
errfile="${SID}_${pgm}.err"

cp_data_ok="${DIR_BACKUP_DATA}/${okfile}"
cp_data_err="${DIR_BACKUP_DATA}/${errfile}"

cp_alog_ok="${DIR_BACKUP_ALOG}/${okfile}"
cp_alog_err="${DIR_BACKUP_ALOG}/${errfile}"


ok="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.ok"   
err="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.err"

log="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.log"

cmd="${ORACLE_BASE}/admin/backup/scripts/${SID}_${pgm}.cmd"
cmdlog="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.cmdlog"

arc_to_copy_from_remote="/u01/app/oracle/admin/backup/scripts/${SID}_arc_to_copy_from_remote.lst"
arc_to_copy_too_remote="/u01/app/oracle/admin/backup/scripts/${SID}_arc_to_copy_too_remote.lst"
          
rm ${log}    1>/dev/null 2>&1
rm ${cmd}    1>/dev/null 2>&1
rm ${cmdlog} 1>/dev/null 2>&1

if [ -f ${err} ] ;
then
          echo ""                                                                                              >${log}
          echo "============================================================================="                >>${log}
          echo ""                                                                                             >>${log}
          echo "        ATTENTION : the previous run of  '${pgm}.sh  -d ${SID}'"                              >>${log}
          echo "                    was already in error  !!!"                                                >>${log}
          echo ""                                                                                             >>${log}
fi

rm  ${ok}-5                   1>/dev/null  2>&1
mv  ${ok}-4      ${ok}-5      1>/dev/null  2>&1
mv  ${ok}-3      ${ok}-4      1>/dev/null  2>&1
mv  ${ok}-2      ${ok}-3      1>/dev/null  2>&1
mv  ${ok}-1      ${ok}-2      1>/dev/null  2>&1
mv  ${ok}        ${ok}-1      1>/dev/null  2>&1

rm  ${err}-5                  1>/dev/null  2>&1
mv  ${err}-4     ${err}-5     1>/dev/null  2>&1
mv  ${err}-3     ${err}-4     1>/dev/null  2>&1
mv  ${err}-2     ${err}-3     1>/dev/null  2>&1
mv  ${err}-1     ${err}-2     1>/dev/null  2>&1
mv  ${err}       ${err}-1     1>/dev/null  2>&1


#
# Check to see if any tablespace are in backup mode and if so ==> ends the backup mode :
# ------------------------------------------------------------------------------------

#if [ ${STANDBY_DB} -eq 0 ] ;
#then
#          echo ""                                                                                               >>${cmdlog}
#          echo ""                                                                                               >>${cmdlog}
#          echo ""                                                                                               >>${cmdlog}
#          echo "        Ends  'backup mode'  on any tablespace with a PL/SQL procedure :"                       >>${cmdlog}
#          echo ""                                                                                               >>${cmdlog}
#
#          ${ORACLE_HOME}/bin/sqlplus -s "sys/${oktestsys}@${ORACLE_SID_BASE} as sysdba" @${DIR_SQL}/check_end_backup.sql  >>${cmdlog}
#
#          echo ""                                                                                               >>${cmdlog}
#          echo ""                                                                                               >>${cmdlog}
#
#          if [ "${RMAN_SID}" != "UNKNOWN" ] ;
#          then
##
## Check to see if any tablespace for this DB has to be put offline before backup (skip tablespaces) :
## -------------------------------------------------------------------------------------------------
#
#            echo ""                                                                                                                >>${cmdlog}
#            echo ""                                                                                                                >>${cmdlog}
#            echo ""                                                                                                                >>${cmdlog}
#            echo " Put tablespaces offline (if present in dzdba.backup_offline_tablespaces@${RMAN_SID}) with a PL/SQL procedure :" >>${cmdlog}
#            echo ""                                                                                                                >>${cmdlog}
#
## Initialize the result file if it already exists :
## -----------------------------------------------
#            echo "exit;"                                                     >${DIR_SQL}/put_tablespace_offline_${SID}.sql
#
## Construct the SQL-file to put the tablespaces offline :
## -----------------------------------------------------
#
#
#            rm  ${DIR_SQL}/run_check_offline_tablespaces.sql  1>/dev/null  2>&1
#
#            echo "WHENEVER SQLERROR EXIT;"                                 >${DIR_SQL}/run_check_offline_tablespaces.sql
#            echo "connect dzdba/${oktestdzdba_adm}@${RMAN_SID}"           >>${DIR_SQL}/run_check_offline_tablespaces.sql
#            echo "start ${DIR_SQL}/check_offline_tablespaces.sql ${SID}"  >>${DIR_SQL}/run_check_offline_tablespaces.sql
#
#            ${ORACLE_HOME}/bin/sqlplus /nolog  @${DIR_SQL}/run_check_offline_tablespaces.sql                                       >>${cmdlog}
#
#            rm  ${DIR_SQL}/run_check_offline_tablespaces.sql  1>/dev/null  2>&1
#
## Put the tablespaces offline :
## ---------------------------
#            ${ORACLE_HOME}/bin/sqlplus -s "sys/${oktestsys}@${ORACLE_SID_BASE} as sysdba" @${DIR_SQL}/put_tablespace_offline_${SID}.sql      >>${cmdlog}
#
#
#            echo ""                                                                                                                >>${cmdlog}
#            echo ""                                                                                                                >>${cmdlog}
#          fi
#fi

#
# Determine if there's a standby database as archive destination:
# ------------------------------------------------------------------

rm -f ${DIR_BACKUP_DATA}/standby_destinations.lst       > /dev/null

tabel="v\$archive_dest"

sqlplus -s /nolog <<EOF
connect sys/${oktestsys} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
spool ${DIR_BACKUP_DATA}/standby_destinations.lst
select count(*) from $tabel where target = 'STANDBY' and status = 'VALID';
exit;
EOF

rman_standby_destinations=`cat ${DIR_BACKUP_DATA}/standby_destinations.lst`
rm ${DIR_BACKUP_DATA}/standby_destinations.lst

if [ ${STANDBY_DB} -eq 0 ] ;
then

#
# Determining the list of archive redo logs needed for this RMAN online backup :
# ----------------------------------------------------------------------------

          rm -f ${DIR_BACKUP_DATA}/needed_log.lst                 > /dev/null
          rm -f ${DIR_BACKUP_DATA}/shipped_logs_to_stby.lst       > /dev/null

          tabel="v\$archived_log"

          sqlplus -s /nolog <<EOF
connect sys/${oktestsys} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
spool ${DIR_BACKUP_DATA}/needed_log.lst
select 'Sequence : '||sequence# from $tabel where completion_time = (select max(completion_time) from $tabel);
spool off;
spool ${DIR_BACKUP_DATA}/shipped_logs_to_stby.lst
select thread#||'|'||max(sequence#) from $tabel where standby_dest = 'YES' group by thread#;
spool off;
exit;
EOF


          rman_online_before_redo=`cat ${DIR_BACKUP_DATA}/needed_log.lst`
          rm ${DIR_BACKUP_DATA}/needed_log.lst
fi


# Copy  initXXX.ora, spfileXXX.ora (content only)  and  orapwXXX  files to backup directory :            
# -----------------------------------------------------------------------------------------
mv ${DIR_BACKUP_ROOT}/*.log ${DIR_BACKUP_DATA} 1>/dev/null 2>&1

PFILE=${ORACLE_HOME}/dbs/init${ORACLE_SID}.ora
cp ${PFILE}		 	            ${DIR_BACKUP_DATA}               1>/dev/null 2>&1


if [ "`echo ${oracle_version} | cut -c1-1`" != "8" ] ;
then
          echo ""                                         >>${cmdlog}

          sqlplus -s /nolog  1>>${cmdlog}  2>>${cmdlog}   <<EOF  
connect sys/${oktestsys} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
create pfile='${DIR_BACKUP_DATA}/spfile${ORACLE_SID_BASE}.content' from spfile;
exit;
EOF

          echo ""                                         >>${cmdlog}
fi

cp ${ORACLE_HOME}/dbs/orapw${ORACLE_SID}    ${DIR_BACKUP_DATA}            

# --------------------------------------------------------------------------------------
#  In case we're working with dataguard broker, take a backup of the dr config files
# --------------------------------------------------------------------------------------
if [ ${rman_standby_destinations} -gt 0 ] || [ ${STANDBY_DB} -ne 0 ] ;
then
          tabel="v\$parameter"

          sqlplus -s /nolog <<EOF
connect sys/${oktestsys} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
spool ${DIR_BACKUP_DATA}/dg_broker_config_files.lst
select value from $tabel where name like 'dg_broker_config_file%';
spool off;
exit;
EOF

          if [ -s ${DIR_BACKUP_DATA}/dg_broker_config_files.lst ] ;
          then
            for dg_broker_file in `cat ${DIR_BACKUP_DATA}/dg_broker_config_files.lst`
            do
              if [ -f ${dg_broker_file} ] ;
              then
                cp ${dg_broker_file} ${DIR_BACKUP_DATA}
              fi
            done
          fi
fi

if [ ${STANDBY_DB} -eq 0 ] ;
then
#
# Create a file with important Db information (like DBID necessary for recovery with RMAN)  in DIR_BACKUP_DATA :
# ------------------------------------------------------------------------------------------------------------
        echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;"                                               >${DIR_SQL}/info_${SID}.sql
        echo "connect sys/${oktestsys}@${SID} as sysdba"                                        >>${DIR_SQL}/info_${SID}.sql
        echo "spool ${DIR_BACKUP_DATA}/${SID}_backup_info.txt;"                                 >>${DIR_SQL}/info_${SID}.sql
        echo "select dbid \"DBID for RMAN (if needed) :\" from v\$database;"                    >>${DIR_SQL}/info_${SID}.sql
        echo "select 'Control file type: '||controlfile_type \"CTL - file:\" from v\$database;" >>${DIR_SQL}/info_${SID}.sql
        echo "exit;"                                                                            >>${DIR_SQL}/info_${SID}.sql

        ${ORACLE_HOME}/bin/sqlplus -s /nolog @${DIR_SQL}/info_${SID}.sql                        >>${cmdlog}

        rm ${DIR_SQL}/info_${SID}.sql

        echo " "                                                                                                             >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
        echo "For this RMAN online backup you will need following archived redo logs for instance ${SID} :"       	     >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
        echo "------------------------------------------------------------------------------------------"                    >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
        echo ""                                                                                                              >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
        echo " - after      ${rman_online_before_redo}"                                                                      >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
        echo " "                                                                                                             >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
fi

# -----------------------------------------------------------------------------------------------------------
#  Check if we're working with a standby database. If YES (STANDBY_DB = 1) then don't backup the database
# -----------------------------------------------------------------------------------------------------------
STANDBY_DB=0
STANDBY_DB=`grep -c "Control file type: STANDBY" ${DIR_BACKUP_DATA}/${SID}_backup_info.txt`
if [ ${STANDBY_DB} -eq 0 ] ;
then
          export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

          if [ "${TBSSPC}" = "N" ]
          then    
            doublequot=\"

#
# Resync  catalog
# ------------------------------------------------

              echo ""                                                                                                >${cmd}

              if [ "${RMAN_SID}" != "UNKNOWN" ] ;
              then
                echo " resync catalog ;"                                                                            >>${cmd}
              fi

              echo " run {"                                                                                         >>${cmd}
              echo "   sql ${doublequot}alter system archive log current${doublequot};"                             >>${cmd}
              echo " }"                                                                                             >>${cmd}

              if [ "${RMAN_SID}" != "UNKNOWN" ] ;
              then
                ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd}  >>${cmdlog}
              else
                ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                      >>${cmdlog}
              fi

              mv ${cmd} ${cmd}-4  1>/dev/null 2>&1

#
# Crosscheck archivelogs :
# ----------------------
            echo ""                                                                                                >${cmd}
            echo " allocate channel for maintenance type disk;"                                                 >>${cmd}
            echo " change archivelog all crosscheck;"                                                             >>${cmd}
            echo " release channel;"                                                                              >>${cmd}

            if [ "${RMAN_SID}" != "UNKNOWN" ] ;
            then
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd}  >>${cmdlog}
            else
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                      >>${cmdlog}
            fi

            mv ${cmd} ${cmd}-3  1>/dev/null 2>&1


#
# Start backup of database-files using RMAN :
# -----------------------------------------

            if [ "${RMAN_SID}" != "UNKNOWN" ] ;
            then
              echo " resync catalog ;"                                                                            >${cmd}
            else
              echo ""                                                                                             >${cmd}
            fi

#  In case you want the backup is to a specific directory change the persistent config for autocontrolfile backup
            echo " configure controlfile autobackup format for device type disk to '${DIR_BACKUP_CTL}/%F' ;"    >>${cmd}

            number_of_channels=4
            echo " run {"                                                                                         >>${cmd}
            channel_number=0
            while [ ${number_of_channels} -gt ${channel_number} ]
            do
              let "channel_number=${channel_number}+1"
              echo "   allocate channel ch${channel_number}_backup_${SID} type disk format '${DIR_BACKUP_DATA}/FULLON_%d_%U' ;"     >>${cmd}
            done
            echo "   backup section size 2G incremental level 0"                                                  >>${cmd}  
 #          echo "   filesperset 1"                                                                               >>${cmd}  
            echo "   skip offline"                                                                                >>${cmd}
            echo "   tag ${SID}_db_online"                                                                        >>${cmd}
            echo "   (database) ;"                                                                                >>${cmd}
            channel_number=0
            while [ ${number_of_channels} -gt ${channel_number} ]
            do
              let "channel_number=${channel_number}+1"
              echo "   release  channel ch${channel_number}_backup_${SID} ;"                                      >>${cmd}
            done
            echo " }"                                                                                             >>${cmd}

            if [ "${RMAN_SID}" != "UNKNOWN" ] ;
            then
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >>${cmdlog}
            else
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                     >>${cmdlog}
            fi

            mv ${cmd} ${cmd}-2  1>/dev/null 2>&1


#
# Start backup of archivelog / controfile files using RMAN :
# --------------------------------------------------------


            echo " run {"                                                                                          >${cmd}

                sqlplus -s /nolog <<EOF
connect sys/${oktestsys}@${SID} as sysdba
alter system archive log current;
exit;
EOF
            echo "   allocate channel ch_backup_${SID} type disk format '${DIR_BACKUP_ALOG}/ALOG_%d_%U' ;"     >>${cmd}
            echo "   backup"                                                                                     >>${cmd}
            echo "   tag ${SID}_alog_online"                                                                   >>${cmd}
            if [ -s ${DIR_BACKUP_DATA}/shipped_logs_to_stby.lst ] ;
            then
                echo "   (archivelog all);"                                                                        >>${cmd}
                while read LINE
                do
                  thread_number=`echo $LINE | cut -f 1 -d '|'`
                  sequence_number=`echo $LINE | cut -f 2 -d '|'`
                  echo "   delete noprompt archivelog until sequence=${sequence_number} thread=${thread_number} backed up 1 times to device type disk;"   >>${cmd}
                done < ${DIR_BACKUP_DATA}/shipped_logs_to_stby.lst
	    else
                echo "   (archivelog all delete input);"                                                           >>${cmd}
            fi

            echo "   release channel ch_backup_${SID} ;"                                                       >>${cmd}
            echo "   allocate channel ch_backup_${SID} type disk format '${DIR_BACKUP_DATA}/FULLON_ctl_%d_%U' ;" >>${cmd}
            echo "   backup"                                                                                     >>${cmd}
            echo "   tag ${SID}_ctl_online"                                                                      >>${cmd}
            echo "   (current controlfile);"                                                                     >>${cmd}
            echo "   release channel ch_backup_${SID} ;"                                                         >>${cmd}
            echo " }"                                                                                            >>${cmd}


            echo " list backup of archivelog from time 'SYSDATE-1';"	                                       >>${cmd}

            if [ "${RMAN_SID}" != "UNKNOWN" ] ;
            then
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >>${cmdlog}
            else
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                     >>${cmdlog}
            fi

          else

            sqlplus -s "sys/${oktestsys}@${SID} as sysdba" @${DIR_SQL}/oracle_tablespaces.sql ${SID}                    
            for tabspace in $(cat ${DIR_SQL}/oracle_tablespaces_${SID}.lst | sort -u)
            do
              if [ "${RMAN_SID}" != "UNKNOWN" ] ;
              then
                echo " resync catalog ;"                                                                                >${cmd}
              else
                echo ""                                                                                                 >${cmd}
              fi
              echo " run {"                                                                                            >>${cmd}
              echo "   allocate channel ch_backup_${SID} type disk format '${DIR_BACKUP_DATA}/FULLON_tbs_%d_%U' ;"     >>${cmd}
              echo "   backup section size 2G incremental level 0"                                                     >>${cmd}  
 #            echo "   filesperset 1"                                                                                  >>${cmd}  
              echo "   tag ${SID}_tbs_${tabspace}_online"                                                              >>${cmd}
              echo "   (tablespace ${tabspace}) ;"                                                                     >>${cmd}
              echo "   release  channel ch_backup_${SID} ;"                                                            >>${cmd}
              echo "   allocate channel ch_backup_${SID} type disk format '${DIR_BACKUP_DATA}/FULLON_ctl_%d_%U' ;"     >>${cmd}
              echo "   backup"                                                                                         >>${cmd}
              echo "   tag ${SID}_ctl_online"                                                                          >>${cmd}
              echo "   (current controlfile);"                                                                         >>${cmd}
              echo "   release channel ch_backup_${SID} ;"                                                             >>${cmd}
              echo " }"                                                                                                >>${cmd}

              if [ "${RMAN_SID}" != "UNKNOWN" ] ;
              then
                ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >>${cmdlog}
              else
                ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                     >>${cmdlog}
              fi

            done
          fi

#
# Determining the list of archive redo logs needed for this RMAN online backup (suite) :
# ------------------------------------------------------------------------------------

          tabel="v\$archived_log"

          sqlplus -s /nolog <<EOF
connect sys/${oktestsys} as sysdba
set feedback off;
set verify off;
set heading off;
set echo off;
set termout off;
set pages 0;
spool ${DIR_BACKUP_DATA}/needed_log.lst
select 'Sequence : '||sequence# from $tabel where completion_time = (select max(completion_time) from $tabel);
spool off;
exit;
EOF


          rman_online_after_redo=`cat ${DIR_BACKUP_DATA}/needed_log.lst`
          rm ${DIR_BACKUP_DATA}/needed_log.lst


          echo " - including  ${rman_online_after_redo}"               >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt
          echo " "                                                     >>${DIR_BACKUP_DATA}/${SID}_backup_info.txt

             

#
# Making a copy of the control file  :
# ---------------------------------

          mv ${cmd} ${cmd}-1  1>/dev/null 2>&1

          echo " run {"                                                                                        >${cmd}
          echo "       allocate channel ch_copy_${SID} type disk ;"                                           >>${cmd}
          echo "       copy current controlfile to '${DIR_BACKUP_DATA}/control01_${processid}.ctl' ;"                      >>${cmd}
          echo "       release channel ch_copy_${SID} ;"                                                      >>${cmd} 
          echo " }"                                                                                           >>${cmd}


          if [ "${RMAN_SID}" != "UNKNOWN" ] ;
          then
            ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd}    >>${cmdlog}
          else
            ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                        >>${cmdlog}
          fi


          if [ "${RMAN_SID}" != "UNKNOWN" ] ;
          then
            echo "Kuku !"
#
# Check to see if any tablespace for this DB has to be put online after backup (skipped tablespaces) :
# --------------------------------------------------------------------------------------------------

#           echo ""                                                                                                        >>${cmdlog}
#           echo ""                                                                                                        >>${cmdlog}
#           echo ""                                                                                                        >>${cmdlog}
#           echo " Puts tablespace online (if present in dzdba.backup_offline_tablespaces@${RMAN_SID}) with a PL/SQL procedure :" >>${cmdlog}
#           echo ""                                                                                                        >>${cmdlog}



# Initialize the result file if it already exists :
# -----------------------------------------------
#           echo "exit;"                                                     >${DIR_SQL}/put_tablespace_online_${SID}.sql


# Construct the SQL-file to put the tablespaces online :
# -----------------------------------------------------

#           rm  ${DIR_SQL}/run_check_online_tablespaces.sql  1>/dev/null  2>&1

#           echo "WHENEVER SQLERROR EXIT;"                                >${DIR_SQL}/run_check_online_tablespaces.sql
#           echo "connect dzdba/${oktestdzdba_adm}@${RMAN_SID}"          >>${DIR_SQL}/run_check_online_tablespaces.sql
#           echo "start ${DIR_SQL}/check_online_tablespaces.sql ${SID}"  >>${DIR_SQL}/run_check_online_tablespaces.sql

#           ${ORACLE_HOME}/bin/sqlplus /nolog  @${DIR_SQL}/run_check_online_tablespaces.sql                                       >>${cmdlog}

#           rm  ${DIR_SQL}/run_check_online_tablespaces.sql  1>/dev/null  2>&1


# Put the tablespaces online :
# --------------------------
#           ${ORACLE_HOME}/bin/sqlplus -s "sys/${oktestsys}@${SID} as sysdba" @${DIR_SQL}/put_tablespace_online_${SID}.sql      >>${cmdlog}
          fi

          echo ""                                                                                                        >>${cmdlog}
          echo ""                                                                                                        >>${cmdlog}


          rcserr=`grep -c "= ERROR MESSAGE STACK FOLLOWS =" ${cmdlog}`
          if [ ${rcserr} -gt 0 ]
          then
            swerr=1 

            msgerr=" ABENDED  on  ${SID} !!!" 

            echo ""                                                                                    >>${log}
            echo "============================================================================="       >>${log}
            echo ""                                                                                    >>${log}
            echo "        RMAN  Online  Backup  in error :"                                            >>${log}
            echo "        ------------------------------"                                              >>${log}
            echo ""                                                                                    >>${log}
            echo ""                                                                                    >>${log}

            cat ${cmdlog}                                                                              >>${log}

            echo ""                                                                                    >>${log}
            echo ""                                                                                    >>${log}
            echo "============================================================================="       >>${log}
            echo ""                                                                                    >>${log}
          fi
fi          # end if (fi) for STANDBY_DB -eq 0

ok="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.ok"   
err="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.err"

log="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.log"

rm ${log}    1>/dev/null 2>&1

if [ -f ${err} ] ;
then
        echo ""                                                                                              >${log}
        echo "============================================================================="                >>${log}
        echo ""                                                                                             >>${log}
        echo "        ATTENTION : the previous run of  '${pgm}.sh  -d ${SID}'"                              >>${log}
        echo "                    was already in error  !!!"                                                >>${log}
        echo ""                                                                                             >>${log}
fi

rm  ${ok}-5                   1>/dev/null  2>&1
mv  ${ok}-4      ${ok}-5      1>/dev/null  2>&1
mv  ${ok}-3      ${ok}-4      1>/dev/null  2>&1
mv  ${ok}-2      ${ok}-3      1>/dev/null  2>&1
mv  ${ok}-1      ${ok}-2      1>/dev/null  2>&1
mv  ${ok}        ${ok}-1      1>/dev/null  2>&1

rm  ${err}-5                  1>/dev/null  2>&1
mv  ${err}-4     ${err}-5     1>/dev/null  2>&1
mv  ${err}-3     ${err}-4     1>/dev/null  2>&1
mv  ${err}-2     ${err}-3     1>/dev/null  2>&1
mv  ${err}-1     ${err}-2     1>/dev/null  2>&1
mv  ${err}       ${err}-1     1>/dev/null  2>&1


swokwar=2

#echo ""                                                                                                        >>${log}
#echo "============================================================================="                           >>${log}
#echo ""                                                                                                        >>${log}
#echo " On server '${host}' the Oracle local instance  '${SID}'  seems not running."                 >>${log}
#echo ""                                                                                                        >>${log}
#echo "============================================================================="                           >>${log}
#echo ""                                                                                                        >>${log}


datend=`date`

export charset=us-ascii


if [ ${swerr} -eq 1 ] ;
then 

  echo ""                                                                                    >${err}
  echo "${pgm} : ${msgerr}."                                                                >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}
  echo "        Started at  '${datstart}'  on  '${host}'."                                  >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}
  echo "        Ended   at  '${datend}'."                                                   >>${err}
  echo ""                                                                                   >>${err}
  echo ""                                                                                   >>${err}

  echo ""                                                                                   >>${err}
  cat  ${log}                                                                               >>${err}
  echo ""                                                                                   >>${err}

  title="ERROR within a :  '${ORACLE_BASE}/admin/backup/scripts/${pgm}.sh  -d ${SID} -r ${RMAN_SID}'  execution."

   mailx -s "${title}" IT.database@fluxys.net              < ${err}                                         
   mailx -s "${title}" IT.database.team@fluxys.net         < ${err}                                         


  rm  ${log}     1>/dev/null  2>&1
  rm  ${cmdlog}  1>/dev/null  2>&1

  cp ${err} ${cp_data_err}
  cp ${err} ${cp_alog_err}

else

  echo ""                                                                                                          >${ok}
  echo "${pgm} : SUCCESSFULLY ENDED   on   '${SID}'"                                                              >>${ok}
  echo ""                                                                                                         >>${ok}

  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}
  echo "        Started at  '${datstart}  on  '${host}'."                                                         >>${ok}
  echo ""                                                                                                         >>${ok}


  if [ ${swokwar} -ge 1 ] ;
  then
    echo ""                                                                                                       >>${ok}
    cat ${log}                                                                                                    >>${ok}
    echo ""                                                                                                       >>${ok}
  fi

  echo ""                                                                                                         >>${ok}
  echo "        Ended  at  '${datend}'."                                                                          >>${ok}
  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}

  if [ ${swokwar} -eq 0 -a ${connect_catalog_ok} -eq 0 ] ;
  then
      echo ""                                                                                          >>${ok}
      echo "==================================================================================="       >>${ok}
      echo ""                                                                                          >>${ok}
      echo " There is a problem while connecting to the RMAN catalog - backup with NOCATALOG."         >>${ok}
      echo ""                                                                                          >>${ok}
      echo "==================================================================================="       >>${ok}
      echo ""                                                                                          >>${ok}

      title="Warning within a :   '/u01/app/oracle/admin/backup/scripts/${pgm}.sh  -d ${SID} -r ${RMAN_SID}'  execution."

      mailx -s "${title}" IT.database@fluxys.net           < ${ok}
      mailx -s "${title}" IT.database.team@fluxys.net      < ${ok}
  fi

  if [ -s ${cmdlog} ] ;
  then
    echo ""                                                                                                         >>${ok}
    echo ""                                                                                                         >>${ok}
    echo "======================================================================================================"   >>${ok}
    echo ""                                                                                                         >>${ok}
    cat  ${cmdlog}                                                                                                  >>${ok}
    echo ""                                                                                                         >>${ok}
    echo "======================================================================================================"   >>${ok}
    echo ""                                                                                                         >>${ok}
  fi


  rm  ${log}     1>/dev/null  2>&1
  rm  ${cmdlog}  1>/dev/null  2>&1


#  if [ ${swokwar} -eq 2 ] ;
#  then
#    cp ${ok} /custom/oracle/RAC
#  else
    cp ${ok} ${cp_data_ok}
    cp ${ok} ${cp_alog_ok}
#  fi
fi


#
# Cleanup Backup Directories to only keep 30 Days
#
#
# Calculate 30 days backward
#
	today=`date +%s`
	let date30=${today}-2592000
	keep_date=`date -d @${date30} +%Y%m%d`
#
# Create list of directories
#
	ls -d ${DIR_BACKUP_ROOT}/alog_* > ${DIR_BACKUP_ROOT}/directory_list.lst
	ls -d ${DIR_BACKUP_ROOT}/ctl_* >> ${DIR_BACKUP_ROOT}/directory_list.lst
	ls -d ${DIR_BACKUP_ROOT}/data_* >> ${DIR_BACKUP_ROOT}/directory_list.lst
#
# Remove directories older than 30 days
#
	for line in `cat ${DIR_BACKUP_ROOT}/directory_list.lst`
	do 
		DIR_DATE=`echo ${line}|rev|cut -c1-8|rev`
		if [ "${DIR_DATE}" -lt "${keep_date}" ] 
		then  
			rm -Rf ${line} 
		fi 
	done
if [ ${swokwar} -eq 2 ] ;
then
	if [ ${swerr} -eq 0 ] ;
	then

	  if [ ${STANDBY_DB} -eq 0 ] ;
	  then
#
# Cleanup the recovery catalog :
# ----------------------------
	    ${ORACLE_BASE}/admin/backup/scripts/rman_cleanup_catalog.sh -d ${SID} -a ${ADM_SID}
	  fi

	  exit 0
	else
	  exit 1
	fi
fi
