DECLARE @stats_hourly varchar(255)='tmp.'+@servername+'_stats_hourly';
DECLARE @raw_requests varchar(255)='tmp.'+@servername+'_raw_requests';
DECLARE @raw_impressions varchar(255)='tmp.'+@servername+'_raw_impressions';
DECLARE @raw_clicks varchar(255)='tmp.'+@servername+'_raw_clicks';

DECLARE @insert_from_raw_requests varchar(max)='INSERT INTO '+@stats_hourly+
    ' SELECT
            hour_id=DATEDIFF(s,''1970-01-01 00:00:00'',SUBSTRING(time,1,10)+'' ''+SUBSTRING(time,12,2)+'':00''),
            ad_id=LTRIM(RTRIM(ad_id)),
            time=CONVERT(datetime, SUBSTRING(time, 1, 10)+'' ''+SUBSTRING(time, 12, 2)+'':00''),
            requests=1,
            impressions=0,
            clicks=0,
            partner_channel_id=LTRIM(RTRIM(partner_channel_id)),
            response_code=LTRIM(RTRIM(response_code)),
            created_at=CURRENT_TIMESTAMP
    FROM '+@raw_requests;


DECLARE @insert_from_raw_impressions varchar(max)='INSERT INTO '+@stats_hourly+
    ' SELECT
            hour_id=DATEDIFF(s, ''1970-01-01 00:00:00'', SUBSTRING(time, 1, 10)+'' ''+SUBSTRING(time, 12, 2)+'':00''),
            ad_id=LTRIM(RTRIM(ad_id)),
            time=CONVERT(datetime, SUBSTRING(time, 1, 10)+'' ''+SUBSTRING(time, 12, 2)+'':00''),
            requests=0,
            impressions=1,
            clicks=0,
            partner_channel_id=LTRIM(RTRIM(partner_channel_id)),
            response_code=LTRIM(RTRIM(response_code)),
            created_at=CURRENT_TIMESTAMP
    FROM '+@raw_impressions;


DECLARE @insert_from_raw_clicks varchar(max)='INSERT INTO '+@stats_hourly+
    ' SELECT
            hour_id=DATEDIFF(s, ''1970-01-01 00:00:00'', SUBSTRING(time, 1, 10)+'' ''+SUBSTRING(time, 12, 2)+'':00''),
            ad_id=LTRIM(RTRIM(ad_id)),
            time=CONVERT(datetime, SUBSTRING(time, 1, 10)+'' ''+SUBSTRING(time, 12, 2)+'':00''),
            requests=0,
            impressions=0,
            clicks=1,
            partner_channel_id=LTRIM(RTRIM(partner_channel_id)),
            response_code=LTRIM(RTRIM(response_code)),
            created_at=CURRENT_TIMESTAMP
    FROM '+@raw_clicks;


DECLARE @insert_from_deliver_stats_hourly varchar(max)='INSERT INTO '+@stats_hourly+
    ' SELECT
            hour_id,
            ad_id,
            time,
            requests,
            impressions,
            clicks,
            partner_channel_id,
            response_code,
            created_at
    FROM deliver.stats_hourly';

USE [database]

-- seeding data from different raw feed into one table
EXEC(@insert_from_raw_requests)
EXEC(@insert_from_raw_impressions)
EXEC(@insert_from_raw_clicks)

-- seeding hostorical data into same table
EXEC(@insert_from_deliver_stats_hourly)

