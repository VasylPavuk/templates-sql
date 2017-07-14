with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan',
		'http://schemas.microsoft.com/sqlserver/2004/07/showplan' as p1
    )
select	top 100 qs.plan_handle,
		qs.creation_time, qs.last_execution_time, qs.total_elapsed_time, qs.execution_count,
		qp.query_plan.value('(//StmtSimple/@StatementText)[1]', 'nvarchar(1000)') StmtSimple,
		qp.query_plan.value('(//MissingIndexes/MissingIndexGroup/MissingIndex/@Schema)[1]', 'nvarchar(128)') [Schema],
		qp.query_plan.value('(//MissingIndexes/MissingIndexGroup/MissingIndex/@Table)[1]', 'nvarchar(128)') [Table],
		qp.query_plan.value('(//MissingIndexes/MissingIndexGroup/@Impact)[1]', 'float') Impact,
		qp.query_plan.query('//MissingIndexes/MissingIndexGroup/MissingIndex') MissingIndex,
		qp.query_plan
from
	(
		select	qs.plan_handle, min(qs.creation_time) creation_time, max(qs.last_execution_time) last_execution_time, sum(qs.execution_count) execution_count, sum(qs.total_elapsed_time) total_elapsed_time, sum(qs.total_logical_reads) total_logical_reads
		from	sys.dm_exec_query_stats qs
		group by qs.plan_handle
	) qs
		cross apply sys.dm_exec_query_plan(qs.[plan_handle]) as qp
		--outer apply qp.query_plan.nodes('//MissingIndexes/MissingIndexGroup/MissingIndex') m(i)
where	qp.query_plan is not null and qs.total_elapsed_time > 1000
		and qp.query_plan.exist('//MissingIndexes') = 1
		and qp.query_plan.value('(//MissingIndexes/MissingIndexGroup/MissingIndex/@Table)[1]', 'nvarchar(128)') not like '%#%' -- exclude missing indexes on temporary tables
		--AND qp.query_plan.value('(//MissingIndexes/MissingIndexGroup/MissingIndex/@Table)[1]', 'nvarchar(128)') = '[IncomingMessage]'
order by qs.execution_count desc;
--order by qs.execution_count desc;
-- dbcc freeproccache(0x0500050064D35B2E303C69EB0500000001000000000000000000000000000000000000000000000000000000) -- remove single execution plan from cache
