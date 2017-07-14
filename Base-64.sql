set statistics time on

declare @source varbinary(max), @encoded varchar(max), @decoded varbinary(max)
set @source = convert(varbinary(max), 'Hello')
set @encoded = cast('' as xml).value('xs:base64Binary(sql:variable("@source"))', 'varchar(max)')
set @decoded = cast('' as xml).value('xs:base64Binary(sql:variable("@encoded"))', 'varbinary(max)')

select
    convert(varchar(max), @source) as source_varchar,
    @source as source_binary,
    @encoded as encoded,
    @decoded as decoded_binary,
    convert(varchar(max), @decoded) as decoded_varchar,
    len(convert(varchar(max), @source)),
    len(@encoded)
