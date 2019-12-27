#!/bin/bash
#...
#... Usage : roll logs  of  RMAN backup of archive files 
#...
############################################################################



pgm="rman_roll_log"


datstart=`date`


roll_swerr=0
roll_msgerr="nihil"

roll_DIR="UNKNOWN"         
roll_okfile="UNKNOWN"                     
roll_errfile="UNKNOWN"                     





USAGE="Usage : /u01/app/oracle/admin/backup/scripts/${pgm}.sh  roll_DIR_BACKUP_ALOG  roll_okfile  roll_errfile"





roll_err="/u01/app/oracle/admin/backup/log/${pgm}.err"
roll_log="/u01/app/oracle/admin/backup/log/${pgm}.log"
rm ${roll_err}    1>/dev/null 2>&1
rm ${roll_log}    1>/dev/null 2>&1


if [ $# -eq 3 ] ;
then

  roll_DIR=$1         

  roll_okfile=$2

  roll_errfile=$3


  if [ "${roll_okfile}" != "${roll_errfile}" ] ;
  then


    cd ${roll_DIR}


# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-96 ] ;
    then
      rm  ${roll_okfile}-96                                              1>/dev/null  2>&1
    fi

    if [ -f ${roll_errfile}-96 ] ;
    then
      rm  ${roll_errfile}-96                                             1>/dev/null  2>&1
    fi

    sleep 1


      mv  ${roll_okfile}-95  ${roll_okfile}-96                           1>/dev/null  2>&1
      mv  ${roll_errfile}-95 ${roll_errfile}-96                          1>/dev/null  2>&1

      mv  ${roll_okfile}-94  ${roll_okfile}-95                           1>/dev/null  2>&1
      mv  ${roll_errfile}-94 ${roll_errfile}-95                          1>/dev/null  2>&1

      mv  ${roll_okfile}-93  ${roll_okfile}-94                           1>/dev/null  2>&1
      mv  ${roll_errfile}-93 ${roll_errfile}-94                          1>/dev/null  2>&1

      mv  ${roll_okfile}-92  ${roll_okfile}-93                           1>/dev/null  2>&1
      mv  ${roll_errfile}-92 ${roll_errfile}-93                          1>/dev/null  2>&1

      mv  ${roll_okfile}-91  ${roll_okfile}-92                           1>/dev/null  2>&1
      mv  ${roll_errfile}-91 ${roll_errfile}-92                          1>/dev/null  2>&1

      mv  ${roll_okfile}-90  ${roll_okfile}-91                           1>/dev/null  2>&1
      mv  ${roll_errfile}-90 ${roll_errfile}-91                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-89 ] ;
    then
      mv  ${roll_okfile}-89  ${roll_okfile}-90                           1>/dev/null  2>&1

      rm  ${roll_errfile}-89                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-89 ] ;
      then
        mv  ${roll_errfile}-89 ${roll_errfile}-90                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-88  ${roll_okfile}-89                           1>/dev/null  2>&1
      mv  ${roll_errfile}-88 ${roll_errfile}-89                          1>/dev/null  2>&1

      mv  ${roll_okfile}-87  ${roll_okfile}-88                           1>/dev/null  2>&1
      mv  ${roll_errfile}-87 ${roll_errfile}-88                          1>/dev/null  2>&1

      mv  ${roll_okfile}-86  ${roll_okfile}-87                           1>/dev/null  2>&1
      mv  ${roll_errfile}-86 ${roll_errfile}-87                          1>/dev/null  2>&1

      mv  ${roll_okfile}-85  ${roll_okfile}-86                           1>/dev/null  2>&1
      mv  ${roll_errfile}-85 ${roll_errfile}-86                          1>/dev/null  2>&1

      mv  ${roll_okfile}-84  ${roll_okfile}-85                           1>/dev/null  2>&1
      mv  ${roll_errfile}-84 ${roll_errfile}-85                          1>/dev/null  2>&1

      mv  ${roll_okfile}-83  ${roll_okfile}-84                           1>/dev/null  2>&1
      mv  ${roll_errfile}-83 ${roll_errfile}-84                          1>/dev/null  2>&1

      mv  ${roll_okfile}-82  ${roll_okfile}-83                           1>/dev/null  2>&1
      mv  ${roll_errfile}-82 ${roll_errfile}-83                          1>/dev/null  2>&1

      mv  ${roll_okfile}-81  ${roll_okfile}-82                           1>/dev/null  2>&1
      mv  ${roll_errfile}-81 ${roll_errfile}-82                          1>/dev/null  2>&1

      mv  ${roll_okfile}-80  ${roll_okfile}-81                           1>/dev/null  2>&1
      mv  ${roll_errfile}-80 ${roll_errfile}-81                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-79 ] ;
    then
      mv  ${roll_okfile}-79  ${roll_okfile}-80                           1>/dev/null  2>&1

      rm  ${roll_errfile}-79                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-79 ] ;
      then
        mv  ${roll_errfile}-79 ${roll_errfile}-80                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-78  ${roll_okfile}-79                           1>/dev/null  2>&1
      mv  ${roll_errfile}-78 ${roll_errfile}-79                          1>/dev/null  2>&1

      mv  ${roll_okfile}-77  ${roll_okfile}-78                           1>/dev/null  2>&1
      mv  ${roll_errfile}-77 ${roll_errfile}-78                          1>/dev/null  2>&1

      mv  ${roll_okfile}-76  ${roll_okfile}-77                           1>/dev/null  2>&1
      mv  ${roll_errfile}-76 ${roll_errfile}-77                          1>/dev/null  2>&1

      mv  ${roll_okfile}-75  ${roll_okfile}-76                           1>/dev/null  2>&1
      mv  ${roll_errfile}-75 ${roll_errfile}-76                          1>/dev/null  2>&1

      mv  ${roll_okfile}-74  ${roll_okfile}-75                           1>/dev/null  2>&1
      mv  ${roll_errfile}-74 ${roll_errfile}-75                          1>/dev/null  2>&1

      mv  ${roll_okfile}-73  ${roll_okfile}-74                           1>/dev/null  2>&1
      mv  ${roll_errfile}-73 ${roll_errfile}-74                          1>/dev/null  2>&1

      mv  ${roll_okfile}-72  ${roll_okfile}-73                           1>/dev/null  2>&1
      mv  ${roll_errfile}-72 ${roll_errfile}-73                          1>/dev/null  2>&1

      mv  ${roll_okfile}-71  ${roll_okfile}-72                           1>/dev/null  2>&1
      mv  ${roll_errfile}-71 ${roll_errfile}-72                          1>/dev/null  2>&1

      mv  ${roll_okfile}-70  ${roll_okfile}-71                           1>/dev/null  2>&1
      mv  ${roll_errfile}-70 ${roll_errfile}-71                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-69 ] ;
    then
      mv  ${roll_okfile}-69  ${roll_okfile}-70                           1>/dev/null  2>&1

      rm  ${roll_errfile}-69                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-69 ] ;
      then
        mv  ${roll_errfile}-69 ${roll_errfile}-70                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-68  ${roll_okfile}-69                           1>/dev/null  2>&1
      mv  ${roll_errfile}-68 ${roll_errfile}-69                          1>/dev/null  2>&1

      mv  ${roll_okfile}-67  ${roll_okfile}-68                           1>/dev/null  2>&1
      mv  ${roll_errfile}-67 ${roll_errfile}-68                          1>/dev/null  2>&1

      mv  ${roll_okfile}-66  ${roll_okfile}-67                           1>/dev/null  2>&1
      mv  ${roll_errfile}-66 ${roll_errfile}-67                          1>/dev/null  2>&1

      mv  ${roll_okfile}-65  ${roll_okfile}-66                           1>/dev/null  2>&1
      mv  ${roll_errfile}-65 ${roll_errfile}-66                          1>/dev/null  2>&1

      mv  ${roll_okfile}-64  ${roll_okfile}-65                           1>/dev/null  2>&1
      mv  ${roll_errfile}-64 ${roll_errfile}-65                          1>/dev/null  2>&1

      mv  ${roll_okfile}-63  ${roll_okfile}-64                           1>/dev/null  2>&1
      mv  ${roll_errfile}-63 ${roll_errfile}-64                          1>/dev/null  2>&1

      mv  ${roll_okfile}-62  ${roll_okfile}-63                           1>/dev/null  2>&1
      mv  ${roll_errfile}-62 ${roll_errfile}-63                          1>/dev/null  2>&1

      mv  ${roll_okfile}-61  ${roll_okfile}-62                           1>/dev/null  2>&1
      mv  ${roll_errfile}-61 ${roll_errfile}-62                          1>/dev/null  2>&1

      mv  ${roll_okfile}-60  ${roll_okfile}-61                           1>/dev/null  2>&1
      mv  ${roll_errfile}-60 ${roll_errfile}-61                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-59 ] ;
    then
      mv  ${roll_okfile}-59  ${roll_okfile}-60                           1>/dev/null  2>&1

      rm  ${roll_errfile}-59                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-59 ] ;
      then
        mv  ${roll_errfile}-59 ${roll_errfile}-60                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-58  ${roll_okfile}-59                           1>/dev/null  2>&1
      mv  ${roll_errfile}-58 ${roll_errfile}-59                          1>/dev/null  2>&1

      mv  ${roll_okfile}-57  ${roll_okfile}-58                           1>/dev/null  2>&1
      mv  ${roll_errfile}-57 ${roll_errfile}-58                          1>/dev/null  2>&1

      mv  ${roll_okfile}-56  ${roll_okfile}-57                           1>/dev/null  2>&1
      mv  ${roll_errfile}-56 ${roll_errfile}-57                          1>/dev/null  2>&1

      mv  ${roll_okfile}-55  ${roll_okfile}-56                           1>/dev/null  2>&1
      mv  ${roll_errfile}-55 ${roll_errfile}-56                          1>/dev/null  2>&1

      mv  ${roll_okfile}-54  ${roll_okfile}-55                           1>/dev/null  2>&1
      mv  ${roll_errfile}-54 ${roll_errfile}-55                          1>/dev/null  2>&1

      mv  ${roll_okfile}-53  ${roll_okfile}-54                           1>/dev/null  2>&1
      mv  ${roll_errfile}-53 ${roll_errfile}-54                          1>/dev/null  2>&1

      mv  ${roll_okfile}-52  ${roll_okfile}-53                           1>/dev/null  2>&1
      mv  ${roll_errfile}-52 ${roll_errfile}-53                          1>/dev/null  2>&1

      mv  ${roll_okfile}-51  ${roll_okfile}-52                           1>/dev/null  2>&1
      mv  ${roll_errfile}-51 ${roll_errfile}-52                          1>/dev/null  2>&1

      mv  ${roll_okfile}-50  ${roll_okfile}-51                           1>/dev/null  2>&1
      mv  ${roll_errfile}-50 ${roll_errfile}-51                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-49 ] ;
    then
      mv  ${roll_okfile}-49  ${roll_okfile}-50                           1>/dev/null  2>&1

      rm  ${roll_errfile}-49                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-49 ] ;
      then
        mv  ${roll_errfile}-49 ${roll_errfile}-50                        1>/dev/null  2>&1
      fi
    fi

   sleep 1


      mv  ${roll_okfile}-48  ${roll_okfile}-49                           1>/dev/null  2>&1
      mv  ${roll_errfile}-48 ${roll_errfile}-49                          1>/dev/null  2>&1

      mv  ${roll_okfile}-47  ${roll_okfile}-48                           1>/dev/null  2>&1
      mv  ${roll_errfile}-47 ${roll_errfile}-48                          1>/dev/null  2>&1

      mv  ${roll_okfile}-46  ${roll_okfile}-47                           1>/dev/null  2>&1
      mv  ${roll_errfile}-46 ${roll_errfile}-47                          1>/dev/null  2>&1

      mv  ${roll_okfile}-45  ${roll_okfile}-46                           1>/dev/null  2>&1
      mv  ${roll_errfile}-45 ${roll_errfile}-46                          1>/dev/null  2>&1

      mv  ${roll_okfile}-44  ${roll_okfile}-45                           1>/dev/null  2>&1
      mv  ${roll_errfile}-44 ${roll_errfile}-45                          1>/dev/null  2>&1

      mv  ${roll_okfile}-43  ${roll_okfile}-44                           1>/dev/null  2>&1
      mv  ${roll_errfile}-43 ${roll_errfile}-44                          1>/dev/null  2>&1

      mv  ${roll_okfile}-42  ${roll_okfile}-43                           1>/dev/null  2>&1
      mv  ${roll_errfile}-42 ${roll_errfile}-43                          1>/dev/null  2>&1

      mv  ${roll_okfile}-41  ${roll_okfile}-42                           1>/dev/null  2>&1
      mv  ${roll_errfile}-41 ${roll_errfile}-42                          1>/dev/null  2>&1

      mv  ${roll_okfile}-40  ${roll_okfile}-41                           1>/dev/null  2>&1
      mv  ${roll_errfile}-40 ${roll_errfile}-41                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-39 ] ;
    then
      mv  ${roll_okfile}-39  ${roll_okfile}-40                           1>/dev/null  2>&1

      rm  ${roll_errfile}-39                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-39 ] ;
      then
        mv  ${roll_errfile}-39 ${roll_errfile}-40                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-38  ${roll_okfile}-39                           1>/dev/null  2>&1
      mv  ${roll_errfile}-38 ${roll_errfile}-39                          1>/dev/null  2>&1

      mv  ${roll_okfile}-37  ${roll_okfile}-38                           1>/dev/null  2>&1
      mv  ${roll_errfile}-37 ${roll_errfile}-38                          1>/dev/null  2>&1

      mv  ${roll_okfile}-36  ${roll_okfile}-37                           1>/dev/null  2>&1
      mv  ${roll_errfile}-36 ${roll_errfile}-37                          1>/dev/null  2>&1

      mv  ${roll_okfile}-35  ${roll_okfile}-36                           1>/dev/null  2>&1
      mv  ${roll_errfile}-35 ${roll_errfile}-36                          1>/dev/null  2>&1

      mv  ${roll_okfile}-34  ${roll_okfile}-35                           1>/dev/null  2>&1
      mv  ${roll_errfile}-34 ${roll_errfile}-35                          1>/dev/null  2>&1

      mv  ${roll_okfile}-33  ${roll_okfile}-34                           1>/dev/null  2>&1
      mv  ${roll_errfile}-33 ${roll_errfile}-34                          1>/dev/null  2>&1

      mv  ${roll_okfile}-32  ${roll_okfile}-33                           1>/dev/null  2>&1
      mv  ${roll_errfile}-32 ${roll_errfile}-33                          1>/dev/null  2>&1

      mv  ${roll_okfile}-31  ${roll_okfile}-32                           1>/dev/null  2>&1
      mv  ${roll_errfile}-31 ${roll_errfile}-32                          1>/dev/null  2>&1

      mv  ${roll_okfile}-30  ${roll_okfile}-31                           1>/dev/null  2>&1
      mv  ${roll_errfile}-30 ${roll_errfile}-31                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-29 ] ;
    then
      mv  ${roll_okfile}-29  ${roll_okfile}-30                           1>/dev/null  2>&1

      rm  ${roll_errfile}-29                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-29 ] ;
      then
        mv  ${roll_errfile}-29 ${roll_errfile}-30                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-28  ${roll_okfile}-29                           1>/dev/null  2>&1
      mv  ${roll_errfile}-28 ${roll_errfile}-29                          1>/dev/null  2>&1

      mv  ${roll_okfile}-27  ${roll_okfile}-28                           1>/dev/null  2>&1
      mv  ${roll_errfile}-27 ${roll_errfile}-28                          1>/dev/null  2>&1

      mv  ${roll_okfile}-26  ${roll_okfile}-27                           1>/dev/null  2>&1
      mv  ${roll_errfile}-26 ${roll_errfile}-27                          1>/dev/null  2>&1

      mv  ${roll_okfile}-25  ${roll_okfile}-26                           1>/dev/null  2>&1
      mv  ${roll_errfile}-25 ${roll_errfile}-26                          1>/dev/null  2>&1

      mv  ${roll_okfile}-24  ${roll_okfile}-25                           1>/dev/null  2>&1
      mv  ${roll_errfile}-24 ${roll_errfile}-25                          1>/dev/null  2>&1

      mv  ${roll_okfile}-23  ${roll_okfile}-24                           1>/dev/null  2>&1
      mv  ${roll_errfile}-23 ${roll_errfile}-24                          1>/dev/null  2>&1

      mv  ${roll_okfile}-22  ${roll_okfile}-23                           1>/dev/null  2>&1
      mv  ${roll_errfile}-22 ${roll_errfile}-23                          1>/dev/null  2>&1

      mv  ${roll_okfile}-21  ${roll_okfile}-22                           1>/dev/null  2>&1
      mv  ${roll_errfile}-21 ${roll_errfile}-22                          1>/dev/null  2>&1

      mv  ${roll_okfile}-20  ${roll_okfile}-21                           1>/dev/null  2>&1
      mv  ${roll_errfile}-20 ${roll_errfile}-21                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-19 ] ;
    then
      mv  ${roll_okfile}-19  ${roll_okfile}-20                           1>/dev/null  2>&1

      rm  ${roll_errfile}-19                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-19 ] ;
      then
        mv  ${roll_errfile}-19 ${roll_errfile}-20                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-18  ${roll_okfile}-19                           1>/dev/null  2>&1
      mv  ${roll_errfile}-18 ${roll_errfile}-19                          1>/dev/null  2>&1

      mv  ${roll_okfile}-17  ${roll_okfile}-18                           1>/dev/null  2>&1
      mv  ${roll_errfile}-17 ${roll_errfile}-18                          1>/dev/null  2>&1

      mv  ${roll_okfile}-16  ${roll_okfile}-17                           1>/dev/null  2>&1
      mv  ${roll_errfile}-16 ${roll_errfile}-17                          1>/dev/null  2>&1

      mv  ${roll_okfile}-15  ${roll_okfile}-16                           1>/dev/null  2>&1
      mv  ${roll_errfile}-15 ${roll_errfile}-16                          1>/dev/null  2>&1

      mv  ${roll_okfile}-14  ${roll_okfile}-15                           1>/dev/null  2>&1
      mv  ${roll_errfile}-14 ${roll_errfile}-15                          1>/dev/null  2>&1

      mv  ${roll_okfile}-13  ${roll_okfile}-14                           1>/dev/null  2>&1
      mv  ${roll_errfile}-13 ${roll_errfile}-14                          1>/dev/null  2>&1

      mv  ${roll_okfile}-12  ${roll_okfile}-13                           1>/dev/null  2>&1
      mv  ${roll_errfile}-12 ${roll_errfile}-13                          1>/dev/null  2>&1

      mv  ${roll_okfile}-11  ${roll_okfile}-12                           1>/dev/null  2>&1
      mv  ${roll_errfile}-11 ${roll_errfile}-12                          1>/dev/null  2>&1

      mv  ${roll_okfile}-10  ${roll_okfile}-11                           1>/dev/null  2>&1
      mv  ${roll_errfile}-10 ${roll_errfile}-11                          1>/dev/null  2>&1

# ----------------------------------------------------------------------------------------

    if [ -f ${roll_okfile}-09 ] ;
    then
      mv  ${roll_okfile}-09  ${roll_okfile}-10                           1>/dev/null  2>&1

      rm  ${roll_errfile}-09                                             1>/dev/null  2>&1
    else
      if [ -f ${roll_errfile}-09 ] ;
      then
        mv  ${roll_errfile}-09 ${roll_errfile}-10                        1>/dev/null  2>&1
      fi
    fi

    sleep 1


      mv  ${roll_okfile}-08  ${roll_okfile}-09                           1>/dev/null  2>&1
      mv  ${roll_errfile}-08 ${roll_errfile}-09                          1>/dev/null  2>&1

      mv  ${roll_okfile}-07  ${roll_okfile}-08                           1>/dev/null  2>&1
      mv  ${roll_errfile}-07 ${roll_errfile}-08                          1>/dev/null  2>&1

      mv  ${roll_okfile}-06  ${roll_okfile}-07                           1>/dev/null  2>&1
      mv  ${roll_errfile}-06 ${roll_errfile}-07                          1>/dev/null  2>&1

      mv  ${roll_okfile}-05  ${roll_okfile}-06                           1>/dev/null  2>&1
      mv  ${roll_errfile}-05 ${roll_errfile}-06                          1>/dev/null  2>&1

      mv  ${roll_okfile}-04  ${roll_okfile}-05                           1>/dev/null  2>&1
      mv  ${roll_errfile}-04 ${roll_errfile}-05                          1>/dev/null  2>&1

      mv  ${roll_okfile}-03  ${roll_okfile}-04                           1>/dev/null  2>&1
      mv  ${roll_errfile}-03 ${roll_errfile}-04                          1>/dev/null  2>&1

      mv  ${roll_okfile}-02  ${roll_okfile}-03                           1>/dev/null  2>&1
      mv  ${roll_errfile}-02 ${roll_errfile}-03                          1>/dev/null  2>&1

      mv  ${roll_okfile}-01  ${roll_okfile}-02                           1>/dev/null  2>&1
      mv  ${roll_errfile}-01 ${roll_errfile}-02                          1>/dev/null  2>&1


      if [ -f ${roll_okfile} ] ;
      then
        mv  ${roll_okfile}     ${roll_okfile}-01                         1>/dev/null  2>&1

        rm  ${roll_errfile}                                              1>/dev/null  2>&1
      else
        if [ -f ${roll_errfile} ] ;
        then
          mv  ${roll_errfile}    ${roll_errfile}-01                      1>/dev/null  2>&1
        fi
      fi

# ----------------------------------------------------------------------------------------

  fi

fi

exit 0


