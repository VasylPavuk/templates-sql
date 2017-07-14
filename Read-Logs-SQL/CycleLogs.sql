-- make a cycle of error logs
exec master.sys.sp_cycle_errorlog;
-- make a cycle agent error log
EXEC dbo.sp_cycle_agent_errorlog
