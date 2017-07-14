select  db_name([files].database_id) as databaseName, [files].physical_name,
        [stats].num_of_writes, convert(money, 1.0*stats.io_stall_write_ms/stats.num_of_writes) as avg_write_stall_ms,
        stats.num_of_reads, convert(money, 1.0*stats.io_stall_read_ms/stats.num_of_reads)as avg_read_stall_ms
from    sys.dm_io_virtual_file_stats(default, default) [stats]
        inner join sys.master_files [files] on [stats].database_id = [files].database_id and [stats].file_id = [files].file_id
--where   [files].[type] = 0

-- this works for current database
select  [% of Free Space] = convert(money, 100.0*unallocated_extent_page_count/total_page_count)
from    sys.dm_db_file_space_usage
