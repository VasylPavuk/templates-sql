use [master]
go
if object_id('dbo.sp_indexperformance', 'p') is not null
	drop procedure dbo.sp_indexperformance;
go
create procedure dbo.sp_indexperformance
(
	@timeDuration int,
	@objectName	sysname
)as
begin
	declare @query nvarchar(max) = N'
	declare
		@timeDuration int = $timeDuration,
		@objectName	sysname = ''$objectName'';

	declare @delayTime datetime = convert(datetime, dateadd(second, @timeDuration, 0));
	declare @object_id int = object_id(@objectName);

	declare @usage_stats table
	(
		[object_id] int,
		[index_id] int,
		[user_seeks] bigint,
		[user_scans] bigint,
		[user_lookups] bigint,
		[user_updates] bigint,
		primary key clustered ([object_id], [index_id])
	);

	if @object_id is null
		insert into @usage_stats
		select	us.[object_id], us.[index_id], -us.[user_seeks], -us.[user_scans], -us.[user_lookups], -us.[user_updates]
		from	sys.dm_db_index_usage_stats us
		where	us.database_id = db_id()
	else
		insert into @usage_stats
		select	us.[object_id], us.[index_id], -us.[user_seeks], -us.[user_scans], -us.[user_lookups], -us.[user_updates]
		from	sys.dm_db_index_usage_stats us
		where	us.database_id = db_id()
				and us.[object_id] = @object_id;

	waitfor delay @delayTime;

	if @object_id is null
		update	s
		set		[user_seeks] += us.[user_seeks], [user_scans] += us.[user_scans], [user_lookups] += us.[user_lookups], [user_updates] += us.[user_updates]
		from	@usage_stats s
				inner join sys.dm_db_index_usage_stats us on s.[object_id] = us.[object_id] and s.[index_id] = us.[index_id]
		where	us.database_id = db_id()
	else
		update	s
		set		[user_seeks] += us.[user_seeks], [user_scans] += us.[user_scans], [user_lookups] += us.[user_lookups], [user_updates] += us.[user_updates]
		from	@usage_stats s
				inner join sys.dm_db_index_usage_stats us on s.[object_id] = us.[object_id] and s.[index_id] = us.[index_id]
		where	us.database_id = db_id()
				and us.[object_id] = @object_id;

	select	''[''+sc.[name]+''].[''+o.[name]+'']'' objectName, i.[name] indexName,
			us.[index_id], us.[user_seeks], us.[user_scans], us.[user_lookups], us.[user_updates],
			rating = rank()over(order by (us.[user_seeks]+us.[user_scans]+us.[user_lookups]/(us.[user_updates]+1))desc),
			ips.index_depth, ips.page_count, p.rows, p.partitions, ips.avg_fragmentation_in_percent,
				index_description = lower(i.[type_desc])+
					case when i.is_unique = 1 then N'', unique'' else N'''' end+
					case when i.is_primary_key = 1 then N'', primary key '' else N'''' end+
					case when i.is_hypothetical=1 then N'', hypothetical'' else N'''' end+
					case when i.is_disabled = 1 then N'', DISABLED'' else N'''' end, i.filter_definition,
				index_keys = stuff(
				(
					select	N'', [''+c.[name]+case when ic.is_descending_key=1 then N''] DESC'' else N''] ASC'' end
					from	sys.index_columns ic
							inner join sys.columns c on c.[object_id] = i.[object_id] and c.column_id = ic.column_id
					where	ic.[object_id] = i.[object_id] and ic.index_id = i.index_id and ic.is_included_column = 0
					order by ic.index_column_id
					for xml path('''')
				), 1,2,''''),
				included_columns = stuff(
				(
					select	N'', [''+c.[name]+N'']''
					from	sys.index_columns ic
							inner join sys.columns c on c.[object_id] = i.[object_id] and c.column_id = ic.column_id
					where	ic.[object_id] = i.[object_id] and ic.index_id = i.index_id and ic.is_included_column = 1
					order by ic.index_column_id
					for xml path('''')
				), 1,2,'''')
	from	@usage_stats us
			inner join sys.indexes i on us.[object_id] = i.[object_id] and us.[index_id] = i.[index_id]
			inner join sys.objects o on i.[object_id] = o.[object_id]
			inner join sys.schemas sc on o.[schema_id] = sc.[schema_id]
			left join
			(
				select	[object_id], [index_id], max(index_depth) index_depth, sum(page_count) page_count, max(avg_fragmentation_in_percent) avg_fragmentation_in_percent
				from	sys.dm_db_index_physical_stats (db_id(),null,null,null,''LIMITED'')
				group by [object_id], [index_id]

			) ips on ips.[object_id] = i.[object_id] and i.index_id = ips.index_id
			inner join
			(
				select	[object_id], index_id, count(distinct partition_id) partitions, sum([rows]) [rows]
				from	sys.partitions
				group by [object_id], index_id
			) p on i.[object_id] = p.[object_id] and i.[index_id] = p.[index_id]
	order by objectName, us.[index_id];'

	set @query = replace(replace(@query, '$timeDuration', @timeDuration), '$objectName', isnull(@objectName, ''));
	exec (@Query);
end
go
