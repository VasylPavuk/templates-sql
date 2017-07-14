select  top (20)
        total_worker_time/execution_count/1000000.0 as AvgCPU,
        total_worker_time/1000000.0 as TotalCPU,
        total_elapsed_time/execution_count/1000000.0 as AvgDuration,
        total_elapsed_time/1000000.0 as TotalDuration,
        max_elapsed_time/1000000.0 as MaxDuration,
        (total_logical_reads+total_physical_reads)/execution_count/1000000.0 as AvgReads,
        (total_logical_reads+total_physical_reads)/1000000.0 as TotalReads,
        (total_logical_writes)/1000000.0 as TotalWrites,
        execution_count,
        SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
        (
            (
                case qs.statement_end_offset
                    when -1
                    then datalength(st.text)
                    else qs.statement_end_offset
                    end - qs.statement_start_offset
            )/2) + 1
        ) as txt,
        qs.plan_handle,
        objectName = '['+sc.[name]+'].['+o.[name]+']',
        qp.query_plan
from    sys.dm_exec_query_stats as qs
        outer apply sys.dm_exec_sql_text(qs.[sql_handle]) as st
        outer apply sys.dm_exec_query_plan (qs.plan_handle) as qp
        left join sys.objects o on qp.objectid = o.object_id
        left join sys.schemas sc on o.schema_id = sc.schema_id
order by TotalCPU desc;

-- dbcc freeproccache(plan_handle)
