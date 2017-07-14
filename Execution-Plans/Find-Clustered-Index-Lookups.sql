-- this query could be long-running
declare @IndexName sysname = N'[PK_RateClass]';
with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select	top 10 qs.plan_handle, qs.query_hash, qs.query_plan_hash, qs.creation_time, qs.last_execution_time, qs.execution_count, qs.total_elapsed_time/1000000.0 total_elapsed_time, qs.total_logical_reads, qp.query_plan,
		sc.[name]+'.'+o.[name] [object_name]
from	sys.dm_exec_query_stats qs
		cross apply sys.dm_exec_query_plan(qs.[plan_handle]) as qp
		cross apply sys.dm_exec_sql_text(qs.[sql_handle]) as st
		inner join sys.objects o on st.objectid = o.[object_id]
		inner join sys.schemas sc on o.[schema_id] = sc.[schema_id]
where	qp.query_plan.exist('//IndexScan[@Lookup="1"]/Object[@Index=sql:variable("@IndexName")]')=1
order by qs.execution_count desc;
-- dbcc freeproccache(0x05000500D283D759F0EE9B920800000001000000000000000000000000000000000000000000000000000000) -- qs.plan_handle as parameter
