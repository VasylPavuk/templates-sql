-- time to wait for query statistics changes
declare @delayTime datetime = '00:10:00';

if object_id('tempdb..#exec_stats') is not null drop table #exec_stats;

select	[sql_handle], [plan_handle],
		-sum([execution_count]) [execution_count],
		-sum([total_worker_time]) [total_worker_time],
		-sum([total_physical_reads]) [total_physical_reads],
		-sum([total_logical_writes]) [total_logical_writes],
		-sum([total_logical_reads]) [total_logical_reads],
		-sum([total_elapsed_time]) [total_elapsed_time]
into	#exec_stats
from    sys.dm_exec_query_stats as qs
group by [sql_handle], [plan_handle];

waitfor delay @delayTime;

select	top (100)
        objectName = object_name(qp.objectid, qp.[dbid]),
		databaseName = db_name(qp.[dbid]),
        qp.query_plan,
		y.[total_elapsed_time], y.[execution_count], y.[total_worker_time], y.[total_physical_reads], y.[total_logical_writes], y.[total_logical_reads], [total_elapsed_time]/[execution_count] [AvgTime],
		[plan_handle]
from
	(
		select	[sql_handle], [plan_handle],
				sum([execution_count]) [execution_count],
				sum([total_worker_time]) [total_worker_time],
				sum([total_physical_reads]) [total_physical_reads],
				sum([total_logical_writes]) [total_logical_writes],
				sum([total_logical_reads]) [total_logical_reads],
				sum([total_elapsed_time]) [total_elapsed_time]
		from
			(
				select	[sql_handle], [plan_handle],
						sum([execution_count]) [execution_count],
						sum([total_worker_time]) [total_worker_time],
						sum([total_physical_reads]) [total_physical_reads],
						sum([total_logical_writes]) [total_logical_writes],
						sum([total_logical_reads]) [total_logical_reads],
						sum([total_elapsed_time]) [total_elapsed_time]
				from    sys.dm_exec_query_stats as qs
				group by [sql_handle], [plan_handle]
				union all
				select	[sql_handle], [plan_handle], [execution_count], [total_worker_time], [total_physical_reads], [total_logical_writes],[total_logical_reads], [total_elapsed_time]
				from	#exec_stats
			) es
		group by [sql_handle], [plan_handle]
		having sum([execution_count]) > 0
	) y
    outer apply sys.dm_exec_sql_text(y.[sql_handle]) as st
    outer apply sys.dm_exec_query_plan (y.plan_handle) as qp
order by y.[total_worker_time] desc;