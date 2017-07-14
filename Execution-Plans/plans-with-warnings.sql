with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select	top 20 qs.plan_handle, qs.creation_time, qs.last_execution_time, qs.total_elapsed_time, qs.execution_count,
		qs.total_worker_time, qs.total_physical_reads, qs.total_logical_reads, qs.total_logical_writes, qs.total_grant_kb, qp.query_plan,
		qp.query_plan.value('(//Warnings/@NoJoinPredicate)[1]', 'bit') NoJoinPredicate,
		qp.query_plan.value('(//UnmatchedIndexes/Parameterization/Object/@Schema)[1]', 'varchar(128)')+'.'+
		qp.query_plan.value('(//UnmatchedIndexes/Parameterization/Object/@Table)[1]', 'varchar(128)')+' '+
		qp.query_plan.value('(//UnmatchedIndexes/Parameterization/Object/@Index)[1]', 'varchar(128)') UnmatchedIndexes,
		qp.query_plan.value('(//Warnings/PlanAffectingConvert/@Expression)[1]', 'nvarchar(1024)') ConvertIssue,
		qp.query_plan.value('(//Warnings/ColumnsWithNoStatistics/ColumnReference/@Schema)[1]', 'nvarchar(1024)')+'.'+
		qp.query_plan.value('(//Warnings/ColumnsWithNoStatistics/ColumnReference/@Table)[1]', 'nvarchar(1024)')+'.'+
		qp.query_plan.value('(//Warnings/ColumnsWithNoStatistics/ColumnReference/@Column)[1]', 'nvarchar(1024)') ColumnsWithNoStatistics
from	sys.dm_exec_query_stats qs
		cross apply sys.dm_exec_query_plan(qs.[plan_handle]) as qp
where	qp.query_plan is not null
		and qp.query_plan.exist('//Warnings') = 1
order by qs.total_worker_time desc;
