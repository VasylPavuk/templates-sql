with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select	x.creation_time, x.last_execution_time, x.total_elapsed_time, x.execution_count, x.total_worker_time, x.total_physical_reads, x.total_logical_reads, x.total_logical_writes, x.total_grant_kb, qp.query_plan,
		p.o.value('./@NodeId', 'int') NodeId,
		p.o.value('./@PhysicalOp', 'nvarchar(64)') PhysicalOp,
		p.o.value('./@LogicalOp', 'nvarchar(64)') LogicalOp,
		p.o.value('./@EstimatedTotalSubtreeCost', 'float') EstimatedTotalSubtreeCost,
		p.o.value('./@EstimateCPU', 'float') EstimateCPU,
		p.o.value('./@EstimateIO', 'float') EstimateIO
from
	(	-- get top 1 heavy execution plan (measure by total_elapsed_time)
		select	top 3 qs.plan_handle, qs.creation_time, qs.last_execution_time, qs.total_elapsed_time, qs.execution_count,
				qs.total_worker_time, qs.total_physical_reads, qs.total_logical_reads, qs.total_logical_writes, qs.total_grant_kb
		from	sys.dm_exec_query_stats qs
		order by qs.total_elapsed_time desc
	) x
	cross apply sys.dm_exec_query_plan(x.[plan_handle]) as qp
	cross apply query_plan.nodes('//RelOp') p(o)
where	qp.query_plan is not null
order by p.o.value('./@EstimateCPU', 'float')+p.o.value('./@EstimateIO', 'float') desc;
/*
SELECT TOP 3 
        RelOp.op.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan";  
           @PhysicalOp', 'varchar(50)') AS PhysicalOp, 
        dest.text, 
        deqs.execution_count, 
        RelOp.op.value('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; 
        @EstimatedTotalSubtreeCost', 'float') AS EstimatedCost 
FROM    sys.dm_exec_query_stats AS deqs 
        CROSS APPLY sys.dm_exec_sql_text(deqs.sql_handle) AS dest 
        CROSS APPLY sys.dm_exec_query_plan(deqs.plan_handle) AS deqp 
        CROSS APPLY deqp.query_plan.nodes('declare default element namespace "http://schemas.microsoft.com/sqlserver/2004/07/showplan"; 
    //RelOp') RelOp (op) 
ORDER BY deqs.execution_count DESC
*/