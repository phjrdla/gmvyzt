#!/bin/bash
#...
#... Rman Backup of archive files 
#... 
#... Usage : backup of archive files using RMAN
#...
#...  26/09/2007 - JJA
#...	- Implementation ora_petittest.ksh
#...	- Start online backup depending on occup backup filesystem + type database
#...
#...  20/08/2008 - JJA
#...    - Test connectivity problems on RMAN catalog 
#...          In case of problems switch to backup NOCATALOG
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

pgm="rman_backup_arc_ddup"

datstart=`date`

# Security variables.
processid="$$"
#ISO_RESULT=/custom/oracle/trace/petittest_${processid}.lst
#ISO_LOGFILE=/custom/oracle/trace/petittest_${processid}.log

SECFILE=/u01/app/oracle/scripts/security/reslist_${HOSTNAME}.txt.gpg

msgerr="nihil"

SID="UNKNOWN"           # Oracle SID             (default unknown)
RMAN_SID="UNKNOWN"       # The default RMAN recovery catalog database
DDUP="UNKNOWN"          	# The default DDUP Location

USAGE="Usage on SECONDARY Db server : /u01/app/oracle/admin/backup/scripts/${pgm}.sh  -d SID -a ADMIN_SID1:ADMIN_SID2"

host=`hostname -s`
OSname=`uname`

log="/u01/app/oracle/admin/backup/log/${pgm}.log"
ok="/u01/app/oracle/admin/backup/log/${pgm}.ok"
err="/u01/app/oracle/admin/backup/log/${pgm}.err"

rm ${log}    1>/dev/null  2>&1
rm ${ok}     1>/dev/null  2>&1
rm ${err}    1>/dev/null  2>&1

cmdlog="UNKNOWN"

swerr=0
#
# Check database and environment :
# ------------------------------

set -- `getopt d:a: $*`

if [ ${?} -ne 0 ] 
then
  swerr=1

  msgerr=" STOPPED  -  you didn't give the right parameters for this run."

  echo ""                                                                                                >${log}
  echo "============================================================================="                  >>${log}
  echo ""                                                                                               >>${log}
  echo "        ${USAGE}"                                                                               >>${log}
  echo ""                                                                                               >>${log}
  echo "============================================================================="                  >>${log}
  echo ""                                                                                               >>${log}
else
  while [ $# -gt 0 ] 
  do
    case ${1} in
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
    swerr=1

    msgerr=" STOPPED  -  you have to give at least an  Oracle SID  as parameter."  

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
      swerr=1

      msgerr=" STOPPED  -  database  '${SID}'  doesn't exist on  '${host}'." 

      echo ""                                                                                              >${log}
      echo "============================================================================="                >>${log}
      echo ""                                                                                             >>${log}
      echo "        ${USAGE}"                                                                             >>${log}
      echo ""                                                                                             >>${log}
      echo "============================================================================="                >>${log}
      echo ""                                                                                             >>${log}
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
oktestrman="nihil"
rmanowner="RMANCAT"

ADM_SID1=`echo $ADM_SID|cut -d: -f1`

ADM_SID2=`echo $ADM_SID|cut -d: -f2`

# Get DZDBA info for ADM_SID1
oktestadmdzdba1=`gpg -qd $SECFILE | grep -i "$ADM_SID1:DZDBA" | cut -d ":" -f3`
[[ -z $oktestadmdzdba1 ]] && { echo "oktestadmdzdba1 is not defined, exit."; exit; }

# Get DZDBA info for ADM_SID2
oktestadmdzdba2=`gpg -qd $SECFILE | grep -i "$ADM_SID2:DZDBA" | cut -d ":" -f3`
[[ -z $oktestadmdzdba2 ]] && { echo "oktestadmdzdba2 is not defined, exit."; exit; }

# Get SYS info for current db  (SID)
oktestsys=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:SYS:" | cut -d ":" -f3`
[[ -z $oktestsys ]] && { echo "oktestsys is not defined, exit."; exit; }

# Get TEST_CONNECT info for the DB
oktesttest_connect=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:TEST_CONNECT" | cut -d ":" -f3`
[[ -z $oktesttest_connect ]] && { echo "oktesttest_connect is not defined, exit."; exit; }

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
	  oktestadmdzdba=${oktestadmdzdba1}
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
	  		oktestadmdzdba=${oktestadmdzdba2}
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
#echo ${oktestadmdzdba}
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
  echo "on veut $rmanowner"
  [[ -z $oktestrman ]] && { echo "oktestrman is not defined, exit."; exit; }

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


caller="archive"

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

cd ${DIR_BACKUP_ALOG}

okfile="${SID}_${pgm}.ok"   
errfile="${SID}_${pgm}.err"

cp_ok="${DIR_BACKUP_ALOG}/${okfile}"   
cp_err="${DIR_BACKUP_ALOG}/${errfile}"


ok="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.ok"
err="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.err"

log="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.log"

cmd="/u01/app/oracle/admin/backup/scripts/${SID}_${pgm}.cmd"
cmdlog="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.cmdlog"   

arc_to_copy_from_remote="/u01/app/oracle/admin/backup/scripts/${SID}_arc_to_copy_from_remote.lst"
arc_to_copy_too_remote="/u01/app/oracle/admin/backup/scripts/${SID}_arc_to_copy_too_remote.lst"
          
rm ${log}    1>/dev/null 2>&1
rm ${cmd}    1>/dev/null 2>&1
rm ${cmdlog} 1>/dev/null 2>&1

/u01/app/oracle/admin/backup/scripts/rman_roll_log.sh ${DIR_BACKUP_ALOG}  ${okfile}  ${errfile}

if [ -f ${err} ] ;
then
            echo ""                                                                                            >${log}
            echo "============================================================================="              >>${log}
            echo ""                                                                                           >>${log}
            echo "        ATTENTION : the previous run of  '${pgm}.sh  -d ${SID} -r ${RMAN_SID}'"             >>${log}
            echo "                    was already in error  !!!"                                              >>${log}
            echo ""                                                                                           >>${log}
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

if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
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
spool ${DIR_BACKUP_ALOG}/database_info_${SID}.log;
select type||'|'||backup_compress from databases where SID = '${ORACLE_SID_BASE}' and server_name like '%|'||upper('$host')||'|%';
spool off;
exit;
EOF
fi
rcsps=$?
database_type="P"
backup_compress="N"
if [ ${rcsps} -eq 0 ] && [ -s ${DIR_BACKUP_ALOG}/database_info_${SID}.log ];
then
            database_type=`cat ${DIR_BACKUP_ALOG}/database_info_${SID}.log | cut -f 1 -d '|' `
            backup_compress=`cat ${DIR_BACKUP_ALOG}/database_info_${SID}.log | cut -f 2 -d '|' `
fi
        
if [ ${STANDBY_DB} -eq 0 ] ;
then

#
# Start backup of archive files using RMAN :
# -----------------------------------------

            export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

            doublequot=\"


            if [ "`echo ${oracle_version} | cut -c1-1`" = "8" ] ;
            then
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
                ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${ORACLE_RAC_SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd}  >>${cmdlog}
              else
                ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${ORACLE_RAC_SID} nocatalog cmdfile ${cmd}                                      >>${cmdlog}
              fi

              mv ${cmd} ${cmd}-1  1>/dev/null 2>&1
            else
              rm ${cmd}-1         1>/dev/null 2>&1
            fi


            if [ "${RMAN_SID}" != "UNKNOWN" ] ;
            then
              echo " resync catalog ;"                                                                             >${cmd}
            else
              echo ""                                                                                              >${cmd}
            fi
	    echo " configure controlfile autobackup format for device type disk to '${DIR_BACKUP_CTL}/%F' ;"    >>${cmd}
            echo " run {"                                                                                       >>${cmd}


            echo "   allocate channel ch_backup_${SID} type disk format '${DIR_BACKUP_ALOG}/ALOG_%d_%U' ;"    >>${cmd}

            echo "   backup"                                                                                    >>${cmd}


            if [ "`echo ${oracle_version} | cut -c1-1`" != "8" ] ;
            then
              echo "   tag ${SID}_alog_online"                                                                  >>${cmd}
            fi
            if [ "${backup_compress}" = "Y" ] ;
            then
              echo "   as compressed backupset"                                                                 	>>${cmd}
            fi
            echo "   (archivelog all delete input);"                                                             >>${cmd}

            echo "   release channel ch_backup_${SID} ;"                                                      >>${cmd}

            echo " }"                                                                                           >>${cmd}
            echo " list backup of archivelog from time 'SYSDATE-1';"                                            >>${cmd}

            if [ "${RMAN_SID}" != "UNKNOWN" ] ;
            then
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd}        >>${cmdlog}
            else
              ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd}                                            >>${cmdlog}
            fi


            rcserr=`grep -c "= ERROR MESSAGE STACK FOLLOWS =" ${cmdlog}`
            if [ ${rcserr} -gt 0 ]
            then
              swerr=1 

              msgerr=" ABENDED  on  '${SID}' !!!" 

              echo ""                                                                                    >>${log}
              echo "============================================================================="       >>${log}
              echo ""                                                                                    >>${log}
              echo "        RMAN Backup Archive in error !!!"                                            >>${log}
              echo ""                                                                                    >>${log}
              echo ""                                                                                    >>${log}

              cat ${cmdlog}                                                                              >>${log}

              echo ""                                                                                    >>${log}
              echo ""                                                                                    >>${log}
              echo "============================================================================="       >>${log}

            fi

      else

        ok="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.ok"
        err="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.err"

        log="/u01/app/oracle/admin/backup/log/${SID}_${pgm}.log"

        rm ${log}    1>/dev/null 2>&1

        /u01/app/oracle/admin/backup/scripts/rman_roll_log.sh ${DIR_BACKUP_ALOG}  ${okfile}  ${errfile}

        if [ -f ${err} ] ;
        then
          echo ""                                                                                            >${log}
          echo "============================================================================="              >>${log}
          echo ""                                                                                           >>${log}
          echo "        ATTENTION : the previous run of  '${pgm}.sh  -d ${SID} -r ${RMAN_SID}'"             >>${log}
          echo "                    was already in error  !!!"                                              >>${log}
          echo ""                                                                                           >>${log}
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


        swokwar=1

        echo ""                                                                                                      >>${log}
        echo "============================================================================="                         >>${log}
        echo ""                                                                                                      >>${log}
        echo " On server '${host}' local instance '${ORACLE_RAC_SID}' is '${clus_dcc2_db_status}' (not SECONDARY)."  >>${log}
        echo ""                                                                                                      >>${log}
        echo "============================================================================="                         >>${log}
        echo ""                                                                                                      >>${log}

      fi



datend=`date`

export charset=us-ascii


if [ ${swerr} -eq 1 ] ;
then

  echo ""                                                                                                            >${err}
  echo "${pgm} : ${msgerr}."                                                                                        >>${err}
  echo ""                                                                                                           >>${err}
  echo ""                                                                                                           >>${err}
  echo ""                                                                                                           >>${err}
  echo ""                                                                                                           >>${err}
  echo ""                                                                                                           >>${err}
  echo "        Started at  '${datstart}  on  '${host}'."                                                           >>${err}
  echo ""                                                                                                           >>${err}

  echo ""                                                                                                           >>${err}
  cat  ${log}                                                                                                       >>${err}
  echo ""                                                                                                           >>${err}

  echo ""                                                                                                           >>${err}
  echo "        Ended   at  '${datend}'."                                                                           >>${err}
  echo ""                                                                                                           >>${err}
  echo ""                                                                                                           >>${err}

  title="ERROR within a :  '/u01/app/oracle/admin/backup/scripts/${pgm}.sh  -d ${SID} -r ${RMAN_SID}'  execution."

  mailx -s "${title}" IT.database@fluxys.net              < ${err}
  mailx -s "${title}" IT.database.team@fluxys.net         < ${err}


  rm  ${log}     1>/dev/null  2>&1
  rm  ${cmdlog}  1>/dev/null  2>&1

  cp ${err} ${cp_err}

else

  echo ""                                                                                                          >${ok}
  echo "${pgm} : SUCCESSFULLY ENDED   on   '${SID}'"                                                              >>${ok}
  echo ""                                                                                                         >>${ok}

  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}
  echo "        Started at  '${datstart}  on  '${host}'."                                                         >>${ok}
  echo ""                                                                                                         >>${ok}

  echo ""                                                                                                         >>${ok}
  echo "        Ended  at  '${datend}'."                                                                          >>${ok}
  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}

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
   
fi

if [ ${swerr} -eq 0 ] ;
then
  exit 0
else
  exit 1
fi
 
