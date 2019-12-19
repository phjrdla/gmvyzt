set lines 250
set pages 200

column module     format a40 trunc
column username   format a20 trunc
column program    format a30 trunc
column module     format a20 trunc
column osuser     format a20 trunc
column schemaname format a20 trunc
column "kill_cmd" format a60 trunc

select sid
      ,serial#
      ,username
	  ,command
	  ,state
	  ,status 
	  ,program
      ,module
      ,schemaname
      ,osuser
      ,'alter system kill session '''||to_char(sid)||','||to_char(serial#)||''';' "kill_cmd"
  from v$session
 order by sid
/
