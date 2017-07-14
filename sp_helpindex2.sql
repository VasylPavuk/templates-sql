use [master];
GO
if object_id('sp_helpindex2', 'p') is not null drop procedure sp_helpindex2;
GO
create procedure sp_helpindex2
	@ObjectName sysname,
	@Rebuild bit = 0,
	@Reorganize bit = 0
as
begin
	declare @SQL nvarchar(max) ='set nocount on;
	declare @ObjectId int = object_id(''$OBJECT_NAME'');
	if @ObjectId is null
		return;

	select	distinct
			indexName = i.[name], i.index_id, 
			index_description = lower(i.[type_desc])+
				case when i.is_unique = 1 then N'', unique'' else N'''' end+
				case when i.is_primary_key = 1 then N'', primary key '' else N'''' end+
				case when i.is_hypothetical=1 then N'', hypothetical'' else N'''' end+
				case when i.is_disabled = 1 then N'', DISABLED'' else N'''' end, i.filter_definition,
			index_keys = stuff(
			(
				select	N'', [''+c.[name]+case when ic.is_descending_key=1 then N''] DESC'' else N''] ASC'' end
				from	sys.index_columns ic
						inner join sys.columns c on c.[object_id] = @ObjectId and c.column_id = ic.column_id
				where	ic.[object_id] = @ObjectId and ic.index_id = i.index_id and ic.is_included_column = 0
				order by ic.index_column_id
				for xml path('''')
			), 1,2,''''),
			included_columns = stuff(
			(
				select	N'', [''+c.[name]+N'']''
				from	sys.index_columns ic
						inner join sys.columns c on c.[object_id] = @ObjectId and c.column_id = ic.column_id
				where	ic.[object_id] = @ObjectId and ic.index_id = i.index_id and ic.is_included_column = 1
				order by ic.index_column_id
				for xml path('''')
			), 1,2,''''),
			-- located = ds.[name]+N'' (''+ds.[type]+N'')'' collate database_default,
			ips.index_depth, ips.page_count, p.rows, p.partitions, ips.avg_fragmentation_in_percent,
			ius.user_seeks, ius.user_scans, ius.user_lookups, ius.user_updates,
			UsageRate = convert(float, ius.user_seeks+ius.user_scans+ius.user_lookups)/(CASE WHEN ius.user_updates > 0 THEN convert(float, ius.user_updates) ELSE 1.0 END)
			$ReuildCMD
			$ReorganizeCMD
	from	sys.indexes i
			left join sys.objects t on t.[object_id] = @ObjectId
			left join sys.schemas sc on t.[schema_id] = sc.schema_id
			left join sys.data_spaces ds on i.data_space_id = ds.data_space_id
			left join sys.dm_db_index_usage_stats ius on ius.object_id = @ObjectId and i.index_id = ius.index_id and ius.database_id = db_id()
			left join
			(
				select	[object_id], [index_id], max(index_depth) index_depth, sum(page_count) page_count, max(avg_fragmentation_in_percent) avg_fragmentation_in_percent
				from	sys.dm_db_index_physical_stats (db_id(),null,null,null,''LIMITED'')
				group by [object_id], [index_id]

			) ips on ips.object_id = @ObjectId and i.index_id = ips.index_id
			left join
			(
				select	[object_id], index_id, count(distinct partition_id) partitions, sum([rows]) [rows]
				from	sys.partitions
				where	[object_id] = @ObjectId
				group by [object_id], index_id
			) p on i.[object_id] = p.[object_id] and i.[index_id] = p.[index_id]
	where	i.[object_id] = @ObjectId
	order by i.[index_id];
	'

	set @SQL = replace(@SQL, '$OBJECT_NAME', @ObjectName);
	if @Rebuild = 1
		set @SQL = replace(@SQL, '$ReuildCMD', ', ''ALTER INDEX [''+i.name+''] on [''+sc.[name]+''].[''+t.[name]+''] REBUILD;'' rebuild_command')
	else
		set @SQL = replace(@SQL, '$ReuildCMD', '');

	if @Reorganize = 1
		set @SQL = replace(@SQL, '$ReorganizeCMD', ', ''ALTER INDEX [''+i.name+''] on [''+sc.[name]+''].[''+t.[name]+''] REORGANIZE;'' reorganize_command')
	else
		set @SQL = replace(@SQL, '$ReorganizeCMD', '');
	--print(@SQL);
	exec (@SQL);
end
GO
