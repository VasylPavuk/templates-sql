select	d.database_id, d.[name], d.state_desc, d.recovery_model_desc
from	sys.databases d

select  session_id as SPID, command, a.text AS Query, start_time, [duration] = convert(time, getdate()-start_time), percent_complete,
        dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time 
from    sys.dm_exec_requests r
        cross apply sys.dm_exec_sql_text(r.sql_handle) a 
where   r.command in ('BACKUP DATABASE','RESTORE DATABASE', 'RESTORE LOG', 'DBCC TABLE CHECK')
