declare @dbname sysname = db_name();

with xmlnamespaces
    (
        default 'http://schemas.microsoft.com/sqlserver/2004/07/showplan'
    )
select
        stmt.value('(@StatementText)[1]', 'varchar(max)'),
        t.value('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)'),
        t.value('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)'),
        t.value('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)'),
        ic.data_type as ConvertFrom,
        ic.character_maximum_length as ConvertFromLength,
        t.value('(@DataType)[1]', 'varchar(128)') as ConvertTo,
        t.value('(@Length)[1]', 'int') as convertToLength,
        query_plan
from    sys.dm_exec_cached_plans cp
        cross apply sys.dm_exec_query_plan(plan_handle) as qp
        cross apply query_plan.nodes('/ShowPlanXML/BatchSequence/Batch/Statements/StmtSimple') batch(stmt)
        cross apply stmt.nodes('.//Convert[@Implicit="1"]') n(t)
        inner join INFORMATION_SCHEMA.COLUMNS ic on
            quotename(ic.TABLE_SCHEMA) = t.value('(ScalarOperator/Identifier/ColumnReference/@Schema)[1]', 'varchar(128)') and
            quotename(ic.table_name) = t.value('(ScalarOperator/Identifier/ColumnReference/@Table)[1]', 'varchar(128)') and
            ic.COLUMN_NAME = t.value('(ScalarOperator/Identifier/ColumnReference/@Column)[1]', 'varchar(128)')
where   t.exist('ScalarOperator/Identifier/ColumnReference[@Database=sql:variable("@dbname")][@Schema!="[sys]"]') = 1