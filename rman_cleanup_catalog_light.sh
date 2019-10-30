#!/bin/bash
#...
#... cleanup of the RMAN recovery catalog.
#...   The script performs a crosscheck for all the backups older than 31 days.
#...   If the backup files aren't available on disk the backups are marked expired
#...   As second action this script performs a delete of all expired backups.
#... 
#... Usage : cleanup of the RMAN recovery catalog
#...
#... Author : Jacobs Jan (Cronos)
#...
#... Revision 1.0 - Date   : 26/03/2001
#...
#... Revision 2.0 - Date   : 15/02/2002  -  Desmet A.
#... 
#... Revision 3.0 - Date : 12/01/2004  - Jacobs J.
#...      Accept a new parameter which indicates the database with
#...      the RMAN recovery catalog.
#... 
#... Revision 4.0 - Date : 03/10/2007  - Jacobs J.
#...      Implement ora_petittest.ksh, password retrieval
#... 
#... Revision 5.0 - Date : 29/10/2019  - Briens P.
#...      Implement of PasswordState and adaptation to single instance
#... 
############################################################################

pgm="rman_cleanup_catalog_light"

datstart=`date`

swerr=0
swokwar=0
cmdlog="UNKNOWN"
connect_catalog_ok=1

# Security variables.
processid="$$"

# PasswordState repository
SECFILE=/u01/app/oracle/scripts/security/reslist_${HOSTNAME}.txt.gpg

msgerr="nihil"


SID="UNKNOWN"           # Oracle SID parameter : default value 'unknown'
RMAN_SID="UNKNOWN"       # The default RMAN recovery catalog database

USAGE="Usage on PRIMARY Db server : /u01/app/oracle/admin/backup/scripts/${pgm}.sh  -d SID -a ADM_SID1:ADM_SID2"

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

set -- `getopt d:r: $*`

if [ ${?} -ne 0 ] ;
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
  exit 1
fi

while [ $# -gt 0 ]                                                                                            
do                                                                                                            
    case ${1} in                                                                                                
        -d)
                SID=`echo ${2} | tr '[:lower:]' '[:upper:]'`
                shift 2
                ;;
        -r)
                RMAN=`echo ${2} | tr '[:lower:]' '[:upper:]'`
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
    swerr=1                                                                                                         
    msgerr=" STOPPED  -  you have to give at least an  Oracle SID  as parameter."                                    
                                                                                                                    
    echo ""                                                                                                  >${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    echo "        ${USAGE}"                                                                                 >>${log}
    echo ""                                                                                                 >>${log}
    echo "============================================================================="                    >>${log}
    echo ""                                                                                                 >>${log}
    exit 1
fi

grep -v ^# /etc/oratab | grep ^"${SID}":                                                                        
rcssid=$?                                                                                                       

if [ ${rcssid} != 0 ]                                                                                           
then                                                                                                            
      swerr=1                                                                                                       

      msgerr=" STOPPED  -  database  '${SID}'  doesn't exist on  '${host}'."                                         
                                                                                                                    
      echo ""                                                                                                >${log}
      echo "============================================================================="                  >>${log}
      echo ""                                                                                               >>${log}
      echo "        ${USAGE}"                                                                               >>${log}
      echo ""                                                                                               >>${log}
      echo "============================================================================="                  >>${log}
      echo ""                                                                                               >>${log}
      exit 1
fi

#
# Change the environment to match the environment of the chosen database :
# ----------------------------------------------------------------------
. /usr/local/bin/oraprof ${SID}

oracle_version=`basename ${ORACLE_HOME}`

oktestsys="nihil"
oktesttest_connect="nihil"
rmanowner="RMANCAT"
oktestrman="nihil"

RMAN_SID=`echo $RMAN|cut -d: -f1`
DDUP=`echo $RMAN|cut -d: -f2`

# Get TEST_CONNECT info for current db  (SID)
oktesttest_connect=`gpg -qd $SECFILE | grep -i "${ORACLE_SID_BASE}:TEST_CONNECT" | cut -d ":" -f3`
[[ -z $oktesttest_connect ]] && { echo "oktesttest_connect is not defined, exit."; exit; }

# Get SYS info for current db  (SID)
oktestsys=`gpg -qd $SECFILE | grep -i "$ORACLE_SID_BASE:SYS:" | cut -d ":" -f3`
[[ -z $oktestsys ]] && { echo "oktestsys is not defined, exit."; exit; }

# Get DZDBA info for ADMIN_INSTANCE
oktestadmdzdba=`gpg -qd $SECFILE | grep -i "$ADMIN_INSTANCE:DZDBA" | cut -d ":" -f3`
[[ -z $oktestadmdzdba ]] && { echo "oktestadmdzdba is not defined, exit."; exit; }


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

if [ "${RMAN_SID}" != "UNKNOWN" ] ;
then
# Get rman catalog owner info for rman catalog DB
oktestrman=`gpg -qd $SECFILE | grep -i "$RMAN_SID:$rmanowner:" | cut -d ":" -f3`
[[ -z $oktestrman ]] && { echo "oktestrman is not defined, exit."; exit; }

fi

if [ ${swerr} -eq 0 ] ;
then                   

#
# Export the backup directory and the actual oracle sid :
# -----------------------------------------------------
  sid=`echo ${SID} | tr '[:upper:]' '[:lower:]'`
  export DIR_SQL=${ORACLE_BASE}/admin/backup/sql                # contains the backup sql files
  export DIR_LOG=${ORACLE_BASE}/admin/backup/log                # contains the backup log files

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
# We will check the connectivity to the RMAN catalog 
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

  caller="cleanupcatalog"

#
# Cleanup the recovery catalog :
# ----------------------------

      echo ""                                                                                        > ${cmd}
      echo " allocate channel for maintenance type disk;"                                          >>${cmd}
      echo " crosscheck backup completed before 'SYSDATE-31';"                                       >>${cmd}
      echo " release channel;"                                                                       >>${cmd}


      if [ "${RMAN_SID}" != "UNKNOWN" ] ;
      then
            ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} catalog ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >${cmdlog}
      else
            ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} nocatalog cmdfile ${cmd} >${cmdlog}
      fi

      echo ""                                                                                                    >>${cmdlog}
      echo ""                                                                                                    >>${cmdlog}

#
# Get the last date of a succesfull backup (only if we use a recovery catalog):
# -----------------------------------------------------------------------------
      if [ "${RMAN_SID}" != "UNKNOWN" ] ;
      then
        sqlplus -s ${rmanowner}/${oktestrman}@${RMAN_SID}  @${DIR_SQL}/get_last_backup_date ${SID}                 >>${cmdlog}

        lastbackupdate=`cat ${DIR_LOG}/get_last_backup_date_${SID}.lst`

        echo ""                                                                                                    >>${cmdlog}
        echo ""                                                                                                    >>${cmdlog}

        if [ ${lastbackupdate:-0} = 0 ] ;
        then
          swerr=1

          msgerr=" Error encountered while searching for last backup date" 
                                                                                                                   
          echo ""                                                                                             >>${log}
          echo "============================================================================="                >>${log}
          echo ""                                                                                             >>${log}
          echo "        ERROR within sql script : @${DIR_SQL}/get_last_backup_date ${SID}"                    >>${log}
          echo "        -----------------------"                                                              >>${log}
          echo ""                                                                                             >>${log}
          echo ""                                                                                             >>${log}

          cat ${cmdlog}                                                                                       >>${log}

          echo ""                                                                                             >>${log}
          echo ""                                                                                             >>${log}
          echo "============================================================================="                >>${log}
          echo ""                                                                                             >>${log} 

        else

#
# Delete all the expired backup information but leave the last seven days in the catalog even if they are expired :
# ---------------------------------------------------------------------------------------------------------------

          mv  ${cmd}  ${cmd}-1     1>/dev/null  2>&1

          echo ""                                                                                         >${cmd}
          echo " allocate channel for maintenance type disk;"                                          >>${cmd}
          echo " delete expired backup completed before '${lastbackupdate}';"                            >>${cmd}
          echo " release channel;"                                                                       >>${cmd}

          ${ORACLE_HOME}/bin/rman target sys/${oktestsys}@${SID} catalog ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >>${cmdlog}

        fi
                                                                                                           
        echo ""                                                                                                     >>${cmdlog}
        echo ""                                                                                                     >>${cmdlog}
                                                                                                                            
                                                                                                                            
        rcserr=`grep -c "= ERROR MESSAGE STACK FOLLOWS =" ${cmdlog}`                                                              
        if [ ${rcserr} -gt 0 ]                                                                                                    
        then                                                                                                                      
          swerr=1                                                                                                                 

          msgerr=" ABENDED  on  ${SID} !!!!"                                                                                      


          echo ""                                                                                    >>${log}                     
          echo "============================================================================="       >>${log}                     
          echo ""                                                                                    >>${log}                     
          echo "        RMAN cleanup catalog  in error :"                                            >>${log}                     
          echo "        ------------------------------"                                              >>${log}                     
          echo ""                                                                                    >>${log}                     
          echo ""                                                                                    >>${log}                     

          cat ${cmdlog}                                                                              >>${log}                     

          echo ""                                                                                    >>${log}                     
          echo ""                                                                                    >>${log}                     
          echo "============================================================================="       >>${log}                     
          echo ""                                                                                    >>${log}                     
                                                                                                                            
        fi
      fi 
    else

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


    swokwar=1

    echo ""                                                                                                        >>${log}
    echo "============================================================================="                           >>${log}
    echo ""                                                                                                        >>${log}
    echo " On server '${host}' the Oracle local instance  '${SID}'  seems not running."                 >>${log}
    echo ""                                                                                                        >>${log}
    echo "============================================================================="                           >>${log}
    echo ""                                                                                                        >>${log}

  fi

             
             
datend=`date`

export charset=us-ascii                                                                             

                                                                                                    
if [ ${swerr} -eq 1 ] ;                                                                             
then                                                                                                
                                                                                                    
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
                                                                                                    
  title="ERROR within a :  '${ORACLE_BASE}/admin/backup/scripts/${pgm}.sh  -d ${SID}  -r ${RMAN_SID}'  execution."  
                                                                                                    
  mailx -s "${title}" IT.database@fluxys.net              < ${err}                                         
  mailx -s "${title}" IT.database.team@fluxys.net         < ${err}                                         
                                                                                                                           
                                                                                                                           
  rm  ${log}     1>/dev/null  2>&1                                                                                         
  rm  ${cmdlog}  1>/dev/null  2>&1                                                                                         
                                                                                                                           
  exit 1
                                                                                                                           
else                                                                                                                       
                                                                                                                           
  echo ""                                                                                                          >${ok}
  echo "${pgm} : SUCCESSFULLY ENDED   on   '${SID}'"                                                              >>${ok}
  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}
  echo "        Started at  '${datstart}  on  '${host}'."                                                         >>${ok}
  echo ""                                                                                                         >>${ok}

  if [ ${swokwar} -eq 1 ] ;
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

  if [ ${swokwar} -eq 1 ] ;
  then
    cp ${ok} /custom/oracle/RAC

     exit 1
   else
     exit 0
  fi
fi                                

#
