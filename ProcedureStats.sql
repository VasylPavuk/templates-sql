select  x.ProcedureName, x.databaseName, x.execution_count, x.total_worker_time, x.total_elapsed_time, x.last_execution_time,
        x.total_physical_reads, x.total_logical_reads, x.total_logical_writes,
        AvgTime = convert(money, 1.0 * x.total_elapsed_time / x.execution_count)
        , qp.query_plan
from
    (
        select  top (50)
                ProcedureName           = object_name(ps.object_id, ps.database_id),
				databaseName			= db_name(ps.database_id),
                execution_count         = sum(ps.execution_count),
                total_worker_time       = sum(ps.total_worker_time)/1000000.0,
                total_physical_reads    = sum(ps.total_physical_reads),
                total_logical_reads     = sum(ps.total_logical_reads),
                total_logical_writes    = sum(ps.total_logical_writes),
                total_elapsed_time      = sum(ps.total_elapsed_time)/1000000.0,
                last_execution_time     = max(ps.last_execution_time),
                ps.plan_handle
        from    sys.dm_exec_procedure_stats ps
		where	ps.database_id = db_id()
        group by object_name(ps.object_id, ps.database_id), ps.plan_handle, db_name(ps.database_id)
        --having sum(execution_count) > 1000
        --order by sum(total_elapsed_time)/sum(execution_count) desc -- order by average time
        order by sum(ps.total_elapsed_time) desc
    )x
    outer apply sys.dm_exec_query_plan (x.plan_handle) as qp
--where	x.ProcedureName = 'spGetCAODashboardDetails'
order by total_worker_time desc;