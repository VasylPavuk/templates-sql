set nocount on;
declare @objectName sysname = 'msg.IncomingMessage';
select  DatabaseName=db_name(),ObjectName=N'['+sc.[name]+N'].['+o.[name]+N']', IndexName = i.[name], i.is_disabled, i.filter_definition,-- i.[type_desc], 
        UseRate = convert(money,(ius.user_seeks+ius.user_scans+ius.user_lookups+1.0)/(ius.user_updates+1.0)),
        UpdRate = convert(money,(ius.user_updates+1.0)/(ius.user_seeks+ius.user_scans+ius.user_lookups+1.0)),
        --LastStatsUpdate = stats_date(s.object_id, s.stats_id),
        ius.user_seeks, ius.user_scans, ius.user_lookups, ius.user_updates,
        ips.index_depth, ips.page_count, ips.avg_fragmentation_in_percent,
        --os.leaf_insert_count, os.leaf_delete_count, os.leaf_update_count, os.nonleaf_insert_count, os.nonleaf_delete_count, os.nonleaf_update_count,
        --os.row_lock_count, os.row_lock_wait_count,os.row_lock_wait_in_ms,os.page_lock_count,os.page_lock_wait_count,os.page_lock_wait_in_ms,
        --os.index_lock_promotion_attempt_count,os.index_lock_promotion_count,
        --os.page_latch_wait_count,os.page_latch_wait_in_ms,os.page_io_latch_wait_count,os.page_io_latch_wait_in_ms,
        --os.tree_page_latch_wait_count,os.tree_page_latch_wait_in_ms,os.tree_page_io_latch_wait_count,os.tree_page_io_latch_wait_in_ms
         ReorganizeCMD = 'alter index ['+i.[name]+'] on ['+sc.[name]+'].['+o.[name]+'] reorganize;'
from    sys.schemas sc
        inner join sys.tables o on sc.schema_id = o.schema_id
        inner join sys.indexes i on o.object_id=i.object_id
        left join sys.dm_db_index_usage_stats ius on i.object_id=ius.object_id and i.index_id=ius.index_id and database_id=db_id()
        left join sys.dm_db_index_physical_stats (db_id(),null,null,null,'LIMITED') ips on i.object_id=ips.object_id and i.index_id = ips.index_id
        --left join sys.dm_db_index_operational_stats(db_id(),NULL,NULL,NULL) os on i.object_id = os.object_id and i.index_id = os.index_id
where   sc.[name] not in ('sys') and i.[name] is not null
		--and i.[type] > 1 and ius.user_seeks+ius.user_scans+ius.user_lookups = 0
		--and ips.page_count > 1000 and ips.avg_fragmentation_in_percent > 20
order by UpdRate desc, useRate asc, ObjectName, IndexName;
--order by ius.user_seeks+ius.user_scans+ius.user_lookups asc, ius.user_updates desc;
--order by avg_fragmentation_in_percent*sqrt(ips.page_count+1)*ius.user_scans desc, avg_fragmentation_in_percent*ips.page_count desc;
--order by ips.page_count*ius.user_scans desc, avg_fragmentation_in_percent desc
