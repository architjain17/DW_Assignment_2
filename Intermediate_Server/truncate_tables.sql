DECLARE @stats_hourly varchar(255)='tmp.'+@servername+'_stats_hourly';
DECLARE @raw_requests varchar(255)='tmp.'+@servername+'_raw_requests';
DECLARE @raw_impressions varchar(255)='tmp.'+@servername+'_raw_impressions';
DECLARE @raw_clicks varchar(255)='tmp.'+@servername+'_raw_clicks';

USE [database]

DECLARE @sql1 varchar(255)='TRUNCATE TABLE '+@raw_clicks
EXEC(@sql1)

SET @sql1='TRUNCATE TABLE '+@raw_requests
EXEC(@sql1)

SET @sql1='TRUNCATE TABLE '+@raw_impressions
EXEC(@sql1)

SET @sql1='TRUNCATE TABLE '+@stats_hourly
EXEC(@sql1)
