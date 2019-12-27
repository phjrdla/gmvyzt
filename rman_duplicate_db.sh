#!/bin/bash
pgm="rman_duplicate_db"
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

. /usr/local/bin/oraprof ${DEST_SID}

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

#
# Export the backup directory and the actual oracle sid :
# -----------------------------------------------------
DIR_BACKUP_ROOT="UNKNOWN"                                # contains the backup files
DIR_SQL="UNKNOWN"                                        # contains the sql and lst files

sid=`echo ${DEST_SID} | tr '[:upper:]' '[:lower:]'`

export DIR_BACKUP_ROOT=/DD2500/backup/${DEST_SID}

export DIR_SQL=${ORACLE_BASE}/admin/restore/sql/${DEST_SID}

if [ -d ${DIR_BACKUP_ROOT} ] ;
then

if [ ${swerr} -eq 0 ] ;
then
# create the init.ora file necessary for the duplication of the database.
#   - necessary changes to make
#       3) Remove the value of the control_files parameter

src_controlfiles="1"
          for src_controlfile in $(sed -e 's/,//g' -e "s/${SRC_SID}/${SID}/g" -e "s/${lowerSRC_SID}/${lowerSID}/g" -e 's/\//\\\//g' ${cmddir}/pfile_src/init${SRC_SID}.ora)
          do
            len=`expr length "${src_controlfiles}"`
            if [ ${len} -gt 1 ] ;
            then
              src_controlfiles="${src_controlfiles}, \'${src_controlfile}\'"
            else
              src_controlfiles="\'${src_controlfile}\'"
            fi
          done


          sed -e "s/control_files=.*$/control_files=${src_controlfiles}/" ${cmddir}/pfile_dup/init${DEST_SID}.ora > ${cmddir}/pfile_dup/init${DEST_SID}_dup.ora
          cp ${cmddir}/pfile_dup/init${DEST_SID}_dup.ora ${cmddir}/pfile_dup/init${DEST_SID}_end.ora

#
#
#  Stop the database which is going to be replaced by the duplicate.
# 
# -------------------------------------------------------------------------------
              echo ""
              read -p " Shutdown the database '${DEST_SID}' manually [Y] : " question_answer
              echo ""
              echo ""
              question_answer=`echo ${question_answer} | tr '[:lower:]' '[:upper:]'`
  
              if [ "${question_answer}" = "N" ] ;
              then
                exit
              fi

# ------------------------------------------------------------
#   The database has been shutdown ask check user
# ------------------------------------------------------------
              echo ""
              echo ""
              question_answer="Y"
              echo ""
              echo "The instances ${DEST_SID} should have been stopped. Please check with 'ps-ef|grep pmon' "
              read -p " Is it OK to continue: [Y] :" question_answer
              echo ""
              echo ""
              question_answer=`echo ${question_answer} | tr '[:lower:]' '[:upper:]'`

              if [ "${question_answer}" = "N" ] ;
              then
                exit
              fi

# ------------------------------------------------------
#   Remove the existing files of the target database
# ------------------------------------------------------
              if [ -s ${logdir}/remove_oldfiles_${DEST_SID}.sh ] ;
              then
                chmod 755 ${logdir}/remove_oldfiles_${DEST_SID}.sh
                question_answer="Y"
                echo ""
                echo ""
                echo ""
                echo ""
                echo "Please run the script ${logdir}/remove_oldfiles_${DEST_SID}.sh in another session"
		echo "connected as user grid on your current node "
                echo ""
                read -p " Is it OK to continue: [Y] :" question_answer
                echo ""
                echo ""
                question_answer=`echo ${question_answer} | tr '[:lower:]' '[:upper:]'`

                if [ "${question_answer}" = "N" ] ;
                then
                  exit
                fi
              fi

          
          export NLS_DATE_FORMAT="DD-MON-YYYY HH24:MI:SS"

          doublequot=\"

#
# Start the duplicate database in nomount mode:
# -----------------------------------------------
            echo " "
            echo " "
            echo " Database ${DEST_SID} is restarted in nomount mode single instance "
            echo " "
            echo " "
            echo " "
            sqlplus -s /nolog <<EOF
WHENEVER SQLERROR EXIT SQL.SQLCODE;
connect sys/${oktestsysdest} as sysdba
startup nomount pfile=${cmddir}/pfile_dup/init${DEST_SID}_dup.ora;
exit;
EOF

          oracle_version=`basename ${ORACLE_HOME}`

# Start duplicate of database using RMAN :
# -----------------------------------------

          echo " +---------------------------------------------------------------------------+ "
          echo " +              RMAN script generation                                       + "
          echo " +              ------------------------                                     + "
          echo " +     Make sure the backupsets which you need are locally available.        + "
          echo " +                                                                           + "
          echo " +     Please verify presence of rman backup same dir struct as source DB    + "
          echo " +                                                                           + "
          echo " +---------------------------------------------------------------------------+ "

          datetime_to_recover="NULL"
          echo " "
          echo " "
          read -p " Specify the time to recover format= DD-MON-YYYY HH24:MI:SS : " datetime_to_recover
          echo " "
          echo " "
          if [ "${datetime_to_recover}" = "NULL" ] ;
          then
              echo " Data - time to recover not given ---  STOP processing "
              exit
          fi
	  cmd="${cmddir}/${DEST_SID}_${pgm}.cmd"

          mv ${cmd} ${cmd}-2  1>/dev/null 2>&1

          echo ""                									>${cmd}

          echo " run {"                                                                           	>>${cmd}
  
          echo "   allocate auxiliary channel ch1_dup_${DEST_SID} type disk ;"     			>>${cmd}
          echo "   allocate auxiliary channel ch2_dup_${DEST_SID} type disk ;"     			>>${cmd}
          echo "   allocate auxiliary channel ch3_dup_${DEST_SID} type disk ;"     			>>${cmd}
          echo "   allocate auxiliary channel ch4_dup_${DEST_SID} type disk ;"     			>>${cmd}

          cat ${logdir}/newname_file.log								>>${cmd}

          echo "   duplicate database ${SRC_SID} to ${DEST_SID}"                                      	>>${cmd}  

          echo "   until time '${datetime_to_recover}'"                                           	>>${cmd}  
          echo "   pfile = ${cmddir}/pfile_dup/init${DEST_SID}_dup.ora"					>>${cmd}
          echo "   logfile"                                                                       	>>${cmd}

          cat ${logdir}/redologfile_thread1_file.log							>>${cmd}
          echo ";"											>>${cmd}


          echo " }"                                                                               	>>${cmd}

        
          question_answer="Y"
          echo ""
          echo ""
          echo ""
          echo ""
          echo ""
          read -p " Is it OK to continue with rman script execution [Y] :" question_answer
          echo ""
          echo ""
          question_answer=`echo ${question_answer} | tr '[:lower:]' '[:upper:]'`

          if [ "${question_answer}" = "N" ] ;
          then
             exit
          fi

          if [ "${RMAN_SID}" != "UNKNOWN" ] ;
          then
              rman auxiliary / rcvcat ${rmanowner}/${oktestrman}@${RMAN_SID} cmdfile ${cmd} >>${cmdlog}
          else
              rman auxiliary / nocatalog cmdfile ${cmd}                                     >>${cmdlog}
          fi

          rcserr=`grep -c "= ERROR MESSAGE STACK FOLLOWS =" ${cmdlog}`
          if [ ${rcserr} -gt 0 ]
          then
              swerr=1 

              msgerr=" ABENDED  on  ${SID} !!!" 

              echo ""                                                                                    >>${log}
              echo "============================================================================="       >>${log}
              echo ""                                                                                    >>${log}
              echo "        RMAN  Duplicate db    in error :"                                            >>${log}
              echo "        ------------------------------"                                              >>${log}
              echo ""                                                                                    >>${log}
              echo ""                                                                                    >>${log}

              cat ${cmdlog}                                                                              >>${log}

              echo ""                                                                                    >>${log}
              echo ""                                                                                    >>${log}
              echo "============================================================================="       >>${log}
              echo ""                                                                                    >>${log}
          fi

        
          if [ ${swerr} -eq 0 ] ;
          then

#     Execute the content of the earlier created file to add fysical files to the temp tablespace.
#
              clear
              echo " "
              echo " "
              echo "   Post duplication scripts are starting "
              echo "   -------------------------------------- "
              echo " "
              echo " "
              echo " "
              echo "connect sys/${oktestsysdest} as sysdba"					> ${logdir}/post_dup_file.sql
              echo "spool ${logdir}/post_dup_file.log"					>> ${logdir}/post_dup_file.sql
              cat ${logdir}/alter_user_passwd.sql					>> ${logdir}/post_dup_file.sql
              cat ${logdir}/alter_global_name.sql					>> ${logdir}/post_dup_file.sql
              echo "grant sysdba,sysoper to system, dzdba;"				>> ${logdir}/post_dup_file.sql
              echo "WHENEVER SQLERROR EXIT SQL.SQLCODE;"				>> ${logdir}/post_dup_file.sql
              if [ -s ${logdir}/spfile_info_${DEST_SID}.log ] ;
              then
                echo "  SPFILE for the database will be recreated "
                echo " "
                spfile_SID=`cat ${logdir}/spfile_info_${DEST_SID}.log`
                echo "create spfile='${spfile_DEST_SID}' from pfile='${cmddir}/pfile_dup/init${DEST_SID}.ora';" >> ${logdir}/post_dup_file.sql
		echo "host rm -f $ORACLE_HOME/dbs/spfile${DEST_SID}*.ora" >> ${logdir}/post_dup_file.sql
              else
                echo "  SPFILE for the database could not be created -----   PLEASE VERIFY "
                echo " "
              fi
              echo "shutdown immediate;"						>> ${logdir}/post_dup_file.sql
              echo "spool off;"								>> ${logdir}/post_dup_file.sql
              echo "exit;"								>> ${logdir}/post_dup_file.sql
              sqlplus -s /nolog @${logdir}/post_dup_file.sql
              if [ $? -ne 0 ] ;
              then
                swerr=1
                echo ""                                                                                         >${log}
                echo "============================================================================="            >>${log}
                echo ""                                                                                         >>${log}
                echo "        Attention: error during post-sql steps please verify logfiles"                   >>${log}
                echo ""                                                                                         >>${log}
                echo "============================================================================="            >>${log}
                echo ""                                                                                         >>${log}
              fi       
          fi
      fi
fi


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

  title="ERROR within a :  '${ORACLE_BASE}/admin/restore/scripts/${pgm}.sh  execution."

  mailx -s "${title}" IT.database@fluxys.net              < ${err}
  mailx -s "${title}" IT.database.team@fluxys.net         < ${err}


  rm  ${log}     1>/dev/null  2>&1
  rm  ${cmdlog}  1>/dev/null  2>&1


else

  echo ""                                                                                                          >${ok}
  echo "${pgm} : SUCCESSFULLY ENDED   on   '${DEST_SID}'"                                                              >>${ok}
  echo ""                                                                                                         >>${ok}

  echo ""                                                                                                         >>${ok}
  echo ""                                                                                                         >>${ok}
  echo "        Started at  '${datstart}'  on  '${host}'."                                                         >>${ok}
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
