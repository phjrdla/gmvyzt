#!/bin/bash
#...
#... Preconfigure controlfile backup.
#... This script must be executed only once and only 
#... if the target database is on oracle version 9i.
#... 
#... Usage : Predefine controlfile backup and controlfile backup format. 
#...
#... Author : Vanierschot Betty	
#...
#... Revision 1.0 - Date   : 09/12/2005
#...
#... Revision 2.0 - Date   : 03/10/2007     Author: Jacobs J.
#...      Implement ora_petittest.ksh, password retrieval
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


pgm="rman_config_ddup"



datstart=`date`



cmdlog="UNKNOWN"
connect_catalog_ok=1


# Security variables.
processid="$$"
#ISO_RESULT=/custom/oracle/trace/petittest_${processid}.lst
#ISO_LOGFILE=/custom/oracle/trace/petittest_${processid}.log

SECFILE=/u01/app/oracle/scripts/security/reslist_${HOSTNAME}.txt.gpg

msgerr="nihil"


SID="UNKNOWN"               # Oracle SID parameter : default value 'unknown'
RMAN_SID="UNKNOWN"          # The default RMAN recovery catalog database
DDUP="UNKNOWN"              # The default DDUP Location


USAGE="Usage : /u01/app/oracle/admin/backup/scripts/${pgm}.sh  -d SID -a ADMIN_SID1:ADMIN_SID2"

host=`hostname -s`

err="/u01/app/oracle/admin/backup/log/${pgm}.err"
ok="/u01/app/oracle/admin/backup/log/${pgm}.ok"
log="/u01/app/oracle/admin/backup/log/${pgm}.log"

rm ${log}    1>/dev/null  2>&1
rm ${ok}     1>/dev/null  2>&1
rm ${err}    1>/dev/null  2>&1

#
# Check database environment :
# --------------------------

set -- `getopt d:a: $*`

if [ ${?} -ne 0 ] ;
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
fi
  
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

if [ "${SID}" = "UNKNOWN" ] ;                                                                                     
then                                                                                                              
    msgerr=" STOPPED  -  you have to give an  Oracle SID  as parameter"                                    
                                                                                                                    
    echo ""                                                                                                  >${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    echo "        ${USAGE}"                                                                                 >>${log}
    echo ""                                                                                                 >>${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    mail_error
    exit 1
fi

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

#
# Change the environment to match the environment of the chosen database :
# ----------------------------------------------------------------------
. /usr/local/bin/oraprof ${SID}

oracle_version=`basename ${ORACLE_HOME}`

oktestsys="nihil"
oktesttest_connect="nihil"
oktestrman="nihil"
oktestadmdzdba="nihil"
rmanowner="RMANCAT"

ADM_SID1=`echo $ADM_SID|cut -d: -f1`

ADM_SID2=`echo $ADM_SID|cut -d: -f2`

# Get TEST_CONNECT info for current db  (SID)
#oktesttest_connect=`gpg -qd $SECFILE | grep -w $ORACLE_SID_BASE | grep -i TEST_CONNECT | cut -d ":" -f3`
oktesttest_connect=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:TEST_CONNECT" | cut -d ":" -f3`
[[ -z $oktesttest_connect ]] && { echo "oktesttest_connect is not defined, exit."; exit; }

#/usr/local/bin/ora_petittest.ksh ${ORACLE_SID_BASE} DB TEST_CONNECT ${ADM_SID1} ${processid}
#rcsps=$?
#if [ ${rcsps} -ne 0 ] ;
#then
#          if [ ${rcsps} -eq 1 ] ;
#          then
#            echo "Wrong usage of ora_petittest.ksh (first try) -- review parameters"                          >> ${log}
#            cat ${ISO_LOGFILE}                                                                                >> ${log}
#            mail_error
#            exit 1
#          fi
#          if [ ${rcsps} -eq 2 ] ;
#          then
#            echo "Problem looking for information in administration databases"                                >> ${log}
#            cat ${ISO_LOGFILE}                                                                                >> ${log}
#            mail_error
#            exit 1
#          fi
#else
#          oktesttest_connect=`cat ${ISO_RESULT}`
#          rm -f ${ISO_RESULT}
#fi

#
# Test to see if ADM_SID1 is running :
#-------------------------------------
test_connect="/custom/oracle/trace/test_connect_${ADM_SID1}.trc"

sqlplus /nolog 1>${test_connect} 2>&1  <<EOF
connect test_connect/${oktesttest_connect}@${ADM_SID1};
EOF

CONNECTED=`cat ${test_connect} | grep 'Connected' | cut -f 2 -d " "`
rm ${test_connect} 1>/dev/null 2>&1

if [ ${CONNECTED:-0} != 0 ] ;
then
          ADMIN_INSTANCE=${ADM_SID1}
else
#
# Test to see if ADM_SID2 is running :
# ------------------------------------
           test_connect="/custom/oracle/trace/test_connect_${ADM_SID2}.trc"

           sqlplus /nolog 1>${test_connect} 2>&1  <<EOF
connect test_connect/${oktesttest_connect}@${ADM_SID2};
EOF

           CONNECTED=`cat ${test_connect} | grep 'Connected' | cut -f 2 -d " "`

           rm ${test_connect} 1>/dev/null 2>&1

           if [ ${CONNECTED:-0} != 0 ] ;
           then
                        ADMIN_INSTANCE=${ADM_SID2}
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


# Get DZDBA info for ADMIN_INSTANCE
#oktestadmdzdba=`gpg -qd $SECFILE | grep -i $ADMIN_INSTANCE | grep -i DZDBA | cut -d ":" -f3`
oktestadmdzdba=`gpg -qd $SECFILE | grep -i "$ADMIN_INSTANCE:DZDBA" | cut -d ":" -f3`
[[ -z $oktestadmdzdba ]] && { echo "oktestadmdzdba is not defined, exit."; exit; }

# Get SYS info for current db  (SID)
#oktestsys=`gpg -qd $SECFILE | grep -w $ORACLE_SID_BASE | grep -w SYS | cut -d ":" -f3`
oktestsys=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:SYS:" | cut -d ":" -f3`
[[ -z $oktestsys ]] && { echo "oktestsys is not defined, exit."; exit; }

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
if [ "${DDUP}" = "UNKNOWN" ] ;
then
    msgerr=" STOPPED  -  no DDUP location found in ADMIN database"

    echo ""                                                                                                  >${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    echo "        ${USAGE}"                                                                                 >>${log}
    echo ""                                                                                                 >>${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
#   mail_error
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
#     mail_error
      exit 1
    fi
fi

if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
# Get rman catalog owner info for rman catalog DB
# oktestrman=`gpg -qd $SECFILE | grep -i $RMAN_SID | grep -i ${rmanowner} | cut -d ":" -f3`
  oktestrman=`gpg -qd $SECFILE | grep -i "$RMAN_SID:$rmanowner" | cut -d ":" -f3`
  [[ -z $oktestrman ]] && { echo "oktestrman is not defined, exit."; exit; }
#
#        /usr/local/bin/ora_petittest.ksh ${RMAN_SID} DB ${rmanowner} ${ADMIN_INSTANCE} ${processid}
#        rcsps=$?
#        if [ ${rcsps} -ne 0 ] ;
#        then
#          if [ ${rcsps} -eq 1 ] ;
#          then
#            echo "Wrong usage of ora_petittest.ksh (first try) -- review parameters"                          >> ${log}
#            cat ${ISO_LOGFILE}                                                                                >> ${log}
#	    mail_error
#	    exit 1
#          fi
#          if [ ${rcsps} -eq 2 ] ;
#          then
#            echo "Problem looking for information in administration databases"                                >> ${log}
#            cat ${ISO_LOGFILE}                                                                                >> ${log}
#            mail_error
#	    exit 1
#          fi
#        else
#          oktestrman=`cat ${ISO_RESULT}`
#          rm -f ${ISO_RESULT}
#        fi

fi

# Clean up the LOGFILE of the security procedure
rm -f ${ISO_LOGFILE}

#
# Export the backup directory and the actual oracle sid :
# -----------------------------------------------------
sid=`echo ${SID} | tr '[:upper:]' '[:lower:]'`

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

export DIR_SQL=${ORACLE_BASE}/admin/backup/sql                 # contains the backup sql files
export DIR_LOG=${ORACLE_BASE}/admin/backup/log                 # contains the backup log files

ok="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.ok"        
err="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.err"      
log="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.log"      
cmd="${ORACLE_BASE}/admin/backup/scripts/${SID}_${pgm}.cmd"  
cmdlog="${ORACLE_BASE}/admin/backup/log/${SID}_${pgm}.cmdlog"
                                                               
rm ${log}    1>/dev/null 2>&1                                
rm ${cmd}    1>/dev/null 2>&1                                
rm ${cmdlog} 1>/dev/null 2>&1                                

                                                                                                                  
if [ -f ${err} ] ;                                                                                              
then                                                                                                            
    echo ""                                                                                                >${log}
    echo "============================================================================="                  >>${log}
    echo ""                                                                                               >>${log}
    echo "        ATTENTION : the previous run of  '${pgm}.sh'  -d ${SID}"                                >>${log}
    echo "                    was already in error  !!!"                                                  >>${log}
    echo ""                                                                                               >>${log}
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
# We will check the connectivity to the RMAN catalog with user TEST_CONNECT.
# If something goes wrong here we'll continue the script without a recovery catalog.
# -----------------------------------------------------------------------------------
connect_catalog_ok=1
if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
    if [ "${oktesttest_connect}" != "nihil" ] ;
    then
      test_connect="/custom/oracle/trace/test_connect_${RMAN_SID}.trc"
      sqlplus /nolog 1>${test_connect} 2>&1  <<EOF 
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect test_connect/${oktesttest_connect}@${RMAN_SID};
EOF
      CONNECTED=`cat ${test_connect} | grep 'Connected' | cut -f 2 -d " "`  
      rm ${test_connect}    1>/dev/null 2>&1
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

#
# Test to see if ORACLE_SID is running :
#-------------------------------------
test_connect="/custom/oracle/trace/test_connect_${ORACLE_SID}.trc"

sqlplus /nolog 1>${test_connect} 2>&1  <<EOF
connect test_connect/${oktesttest_connect}@${ORACLE_SID};
EOF

CONNECTED=`cat ${test_connect} | grep 'Connected' | cut -f 2 -d " "`
rm ${test_connect} 1>/dev/null 2>&1

if [ ${CONNECTED:-0} = 0 ] ;
then
                        echo ""                                                                                                      >>${log}
                        echo "============================================================================="                         >>${log}
                        echo ""                                                                                                      >>${log}
                        echo "  Instance ${ORACLE_SID} is not running."                                                              >>${log}
                        echo ""                                                                                                      >>${log}
                        echo "============================================================================="                         >>${log}
                        echo ""                                                                                                      >>${log}
                        mail_error
                        exit 1
fi

#
# Configure the controlfile backup :
# ----------------------------------

echo ""                                                                                           > ${cmd}
echo " configure controlfile autobackup on;"                                                      >>${cmd}
echo " configure controlfile autobackup format for device type disk to '${DIR_BACKUP_CTL}/%F' ;"  >>${cmd}
echo " configure snapshot controlfile name to '${DIR_BACKUP_ROOT}/scontrolfile.ctl';"             >>${cmd}
echo " show all ;"                                                                                >>${cmd}

if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
        ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${ORACLE_SID} rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >${cmdlog}
else
        ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${ORACLE_SID} nocatalog cmdfile ${cmd}                                     >${cmdlog}
fi


echo ""                                                                                >>${cmdlog}
echo ""                                                                                >>${cmdlog}


rcserr=`grep -c "= ERROR MESSAGE STACK FOLLOWS =" ${cmdlog}`                                                              
if [ ${rcserr} -gt 0 ]                                                                                                    
then                                                                                                                      

        msgerr=" ABENDED  on  ${SID} !!!!"                                                                                      

        echo ""                                                                                    >>${log}                     
        echo "============================================================================="       >>${log}                     
        echo ""                                                                                    >>${log}                     
        echo "        RMAN configure  in error :"                                                  >>${log}                     
        echo "        --------------------------"                                                  >>${log}                     
        echo ""                                                                                    >>${log}                     
        echo ""                                                                                    >>${log}                     

        cat ${cmdlog}                                                                              >>${log}                     

        echo ""                                                                                    >>${log}                     
        echo ""                                                                                    >>${log}                     
        echo "============================================================================="       >>${log}                     
        echo ""                                                                                    >>${log}                     
        mail_error
	exit 1                                                                                                                    
fi 


echo ""                                                                                                          >${ok}
echo "${pgm} : SUCCESSFULLY ENDED   on   '${SID}'"                                                              >>${ok}
echo ""                                                                                                         >>${ok}
echo ""                                                                                                         >>${ok}
echo ""                                                                                                         >>${ok}
echo "        Started at  '${datstart}  on  '${host}'."                                                         >>${ok}
echo ""                                                                                                         >>${ok}

echo ""                                                                                                       	>>${ok}
cat ${cmdlog}                                                                                                   >>${ok}
echo ""                                                                                                       	>>${ok}

datend=`date`

echo ""                                                                                                         >>${ok}
echo "        Ended  at  '${datend}'."                                                                          >>${ok}
echo ""                                                                                                         >>${ok}
echo ""                                                                                                         >>${ok}

rm -f ${cmdlog}
