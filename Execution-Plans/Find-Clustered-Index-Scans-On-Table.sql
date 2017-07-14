-- this query could be long-running
declare @SchemaName sysname = N'[stl]', @TableName sysname = N'[Theme]';
with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select	top 20 qs.plan_handle, qs.creation_time, qs.last_execution_time, qs.execution_count, qs.total_elapsed_time/1000000.0 total_elapsed_time, qs.total_logical_reads, qp.query_plan,
		sc.[name]+'.'+o.[name] [object_name]
from
	(
		select	qs.plan_handle, min(qs.creation_time) creation_time, max(qs.last_execution_time) last_execution_time, sum(qs.execution_count) execution_count, sum(qs.total_elapsed_time) total_elapsed_time, sum(qs.total_logical_reads) total_logical_reads
		from	sys.dm_exec_query_stats qs
		group by qs.plan_handle
	) qs
		cross apply sys.dm_exec_query_plan(qs.[plan_handle]) as qp
		cross apply sys.dm_exec_sql_text(qs.[plan_handle]) as st
		inner join sys.objects o on st.objectid = o.[object_id]
		inner join sys.schemas sc on o.[schema_id] = sc.[schema_id]
where	qp.query_plan.exist('//RelOp[@PhysicalOp="Clustered Index Scan"]/OutputList/ColumnReference[@Schema=sql:variable("@SchemaName")][@Table=sql:variable("@TableName")]')=1
order by qs.execution_count desc;
/*
dbcc freeproccache(0x0500050064D35B2EC0BB9D920800000001000000000000000000000000000000000000000000000000000000) -- qs.plan_handle as parameter
*/
