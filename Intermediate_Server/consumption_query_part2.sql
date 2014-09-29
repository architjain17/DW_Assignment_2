DECLARE @stats_hourly varchar(255)='tmp.'+@servername+'_stats_hourly';

DECLARE @compute_result varchar(max)='INSERT INTO deliver.stats_hourly
SELECT  hour_id, ad_id, time, SUM(requests), SUM(impressions), SUM(clicks), partner_channel_id, response_code, CURRENT_TIMESTAMP
FROM '+@stats_hourly+
' GROUP BY time, hour_id, ad_id, partner_channel_id, response_code'


USE [database]

SET XACT_ABORT ON 
BEGIN TRANSACTION t

-- truncating historical data
TRUNCATE TABLE deliver.stats_hourly

-- seeding all data into final resultant table
EXEC(@compute_result)

COMMIT TRANSACTION t