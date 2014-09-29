DECLARE @sql1 varchar(max)='tmp.'+@servername+'_raw_requests';

DECLARE @sql2 varchar(max)='CREATE TABLE ' + @sql1 +
'(
  time VARCHAR(255),
  ad_id VARCHAR(255),
  width VARCHAR(255),
  height VARCHAR(255),
  profile_key VARCHAR(255),
  partner_channel_id VARCHAR(255),
  response_code VARCHAR(255)
);';

USE [database]

IF OBJECT_ID(@sql1) IS NULL
EXEC(@sql2)


SET @sql1='tmp.'+@servername+'_raw_impressions';

SET @sql2='CREATE TABLE ' + @sql1 +
'(
  time VARCHAR(255),
  ad_id VARCHAR(255),
  width VARCHAR(255),
  height VARCHAR(255),
  profile_key VARCHAR(255),
  partner_channel_id VARCHAR(255),
  response_code VARCHAR(255)
);';

IF OBJECT_ID(@sql1) IS NULL
EXEC(@sql2)


SET @sql1='tmp.'+@servername+'_raw_clicks';

SET @sql2='CREATE TABLE ' + @sql1 +
'(
  time VARCHAR(255),
  ad_id VARCHAR(255),
  width VARCHAR(255),
  height VARCHAR(255),
  profile_key VARCHAR(255),
  partner_channel_id VARCHAR(255),
  response_code VARCHAR(255)
);';

IF OBJECT_ID(@sql1) IS NULL
EXEC(@sql2)


SET @sql1='tmp.'+@servername+'_stats_hourly';

SET @sql2='CREATE TABLE ' + @sql1 +
'(
  hour_id INT NOT NULL,
  ad_id INT,
  time DATETIME NOT NULL,
  requests INT NOT NULL,
  impressions INT NOT NULL,
  clicks INT NOT NULL,
  partner_channel_id INT NOT NULL,
  response_code INT NOT NULL,
  created_at DATETIME NOT NULL
);';



IF OBJECT_ID(@sql1) IS NULL
EXEC(@sql2)
