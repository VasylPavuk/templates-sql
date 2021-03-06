declare @IndexName sysname = N'[PK_Organization]';
with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select	x.usecounts, x.refcounts, x.size_in_bytes, x.cacheobjtype, db_name(st.[dbid]) [database_name], object_name(st.[objectid], st.[dbid]) [object_name], y.total_elapsed_time,y.total_worker_time, y.total_logical_reads, y.total_physical_reads, y.total_logical_writes, x.query_plan, x.[plan_handle]
from
	(
		select	top (20) cp.usecounts, cp.refcounts, cp.size_in_bytes, cp.cacheobjtype, cp.objtype, qp.query_plan, cp.[plan_handle]
		from	sys.dm_exec_cached_plans cp
				cross apply sys.dm_exec_query_plan(cp.[plan_handle]) as qp
		where	qp.query_plan.exist('//IndexScan[@Lookup="1"]/Object[@Index=sql:variable("@IndexName")]')=1
		order by cp.usecounts desc
	) x
	cross apply sys.dm_exec_sql_text(x.[plan_handle]) as st
	outer apply
	(
		select	sum(total_elapsed_time) total_elapsed_time, sum(total_worker_time) total_worker_time, sum(total_logical_reads) total_logical_reads, sum(total_physical_reads) total_physical_reads, sum(total_logical_writes) total_logical_writes
		from	sys.dm_exec_query_stats qs
		where	x.plan_handle = qs.plan_handle
	) y
order by x.usecounts desc

/*
dbcc freeproccache(0x05000500CF87082DD06617A70800000001000000000000000000000000000000000000000000000000000000) -- qs.plan_handle as parameter
*/
