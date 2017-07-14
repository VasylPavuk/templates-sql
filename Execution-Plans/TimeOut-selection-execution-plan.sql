-- execution plans that aborted optimization because timeout appeared
with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select	top (10) qs.plan_handle,
		qs.creation_time, qs.last_execution_time, qs.total_elapsed_time, qs.execution_count,
		qs.total_worker_time, qs.total_physical_reads, qs.total_logical_reads, qs.total_logical_writes, qs.total_grant_kb,
		object_name(st.objectid, st.dbid) [object_name], qp.query_plan
from	sys.dm_exec_query_stats qs
		cross apply sys.dm_exec_query_plan(qs.[plan_handle]) as qp
		cross apply sys.dm_exec_sql_text(qs.[plan_handle]) as st
where	qp.query_plan is not null
		and qp.query_plan.exist('//StmtSimple[@StatementOptmEarlyAbortReason="TimeOut"]') = 1
order by qs.total_elapsed_time desc;