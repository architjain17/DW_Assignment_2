SET XACT_ABORT ON 
BEGIN TRANSACTION t

USE [database]
GO

-- making clean tables from raw tables

INSERT INTO clean.raw_requests
    SELECT 
            CONVERT(datetime, SUBSTRING(time, 1, 10)+' '+SUBSTRING(time, 12, 2)+':00'),
            DATEDIFF(s, '1970-01-01 00:00:00', SUBSTRING(time, 1, 10)+' '+SUBSTRING(time, 12, 2)+':00'),
            LTRIM(RTRIM(ad_id)),
            LTRIM(RTRIM(width)),
            LTRIM(RTRIM(height)),
            LTRIM(RTRIM(profile_key)),
            LTRIM(RTRIM(partner_channel_id)),
            LTRIM(RTRIM(response_code))
    FROM raw.raw_requests
GO

INSERT INTO clean.raw_impressions
    SELECT 
            CONVERT(datetime, SUBSTRING(time, 1, 10)+' '+SUBSTRING(time, 12, 2)+':00'),
            DATEDIFF(s, '1970-01-01 00:00:00', SUBSTRING(time, 1, 10)+' '+SUBSTRING(time, 12, 2)+':00'),
            LTRIM(RTRIM(ad_id)),
            LTRIM(RTRIM(width)),
            LTRIM(RTRIM(height)),
            LTRIM(RTRIM(profile_key)),
            LTRIM(RTRIM(partner_channel_id)),
            LTRIM(RTRIM(response_code))
    FROM raw.raw_impressions
GO

INSERT INTO clean.raw_clicks
    SELECT 
            CONVERT(datetime, SUBSTRING(time, 1, 10)+' '+SUBSTRING(time, 12, 2)+':00'),
            DATEDIFF(s, '1970-01-01 00:00:00', SUBSTRING(time, 1, 10)+' '+SUBSTRING(time, 12, 2)+':00'),
            LTRIM(RTRIM(ad_id)),
            LTRIM(RTRIM(width)),
            LTRIM(RTRIM(height)),
            LTRIM(RTRIM(profile_key)),
            LTRIM(RTRIM(partner_channel_id)),
            LTRIM(RTRIM(response_code))
    FROM raw.raw_clicks
GO

-- calculating per day requests, impressions and clicks

INSERT INTO clean.process_requests
SELECT  time, hour_id, ad_id, partner_channel_id, response_code, COUNT(*)
FROM clean.raw_requests
GROUP BY time, hour_id, ad_id, partner_channel_id, response_code
GO

INSERT INTO clean.process_impressions
SELECT  time, hour_id, ad_id, partner_channel_id, response_code, COUNT(*)
FROM clean.raw_impressions
GROUP BY time, hour_id, ad_id, partner_channel_id, response_code
GO

INSERT INTO clean.process_clicks
SELECT  time, hour_id, ad_id, partner_channel_id, response_code, COUNT(*)
FROM clean.raw_clicks
GROUP BY time, hour_id, ad_id, partner_channel_id, response_code
GO

-- joining result of three tables into intermediate table

INSERT INTO clean.stats_hourly

SELECT  hour_id=COALESCE(r.hour_id, i.hour_id, c.hour_id),
        ad_id=COALESCE(r.ad_id, i.ad_id, c.ad_id),
        time=COALESCE(r.time, i.time, c.time),
        requests=ISNULL(r.requests, 0),
        impressions=ISNULL(i.impressions, 0),
        clicks=ISNULL(c.clicks, 0),
        partner_channel_id=COALESCE(r.partner_channel_id, i.partner_channel_id, c.partner_channel_id),
        response_code=COALESCE(r.response_code, i.response_code, c.response_code),
        created_at=CURRENT_TIMESTAMP

FROM clean.process_requests r FULL OUTER JOIN clean.process_impressions i
ON  r.time = i.time AND
    r.hour_id = i.hour_id AND
    (r.ad_id = i.ad_id OR (r.ad_id IS NULL AND i.ad_id IS NULL)) AND
    r.partner_channel_id = i.partner_channel_id AND
    r.response_code = i.response_code

FULL OUTER JOIN clean.process_clicks c
ON  c.time = i.time AND
    c.hour_id = i.hour_id AND
    (c.ad_id = i.ad_id OR (c.ad_id IS NULL AND i.ad_id IS NULL)) AND
    c.partner_channel_id = i.partner_channel_id AND
    c.response_code = i.response_code

-- joining result of one day with previous results

-- updating existing rows

UPDATE deliver.stats_hourly

SET  hour_id=h.hour_id,
        ad_id=h.ad_id,
        time=h.time,
        requests=h.requests+s.requests,
        impressions=h.impressions+s.impressions,
        clicks=h.clicks+s.clicks,
        partner_channel_id=h.partner_channel_id,
        response_code=h.response_code,
        created_at=CURRENT_TIMESTAMP

FROM deliver.stats_hourly h INNER JOIN clean.stats_hourly s
ON  h.time = s.time AND
    h.hour_id = s.hour_id AND
    (h.ad_id = s.ad_id OR (h.ad_id IS NULL AND s.ad_id IS NULL)) AND
    h.partner_channel_id = s.partner_channel_id AND
    h.response_code = s.response_code

-- insert new rows in deliver.stats_hourly from clean.stats_hourly

INSERT INTO deliver.stats_hourly

SELECT  hour_id=s.hour_id,
        ad_id=s.ad_id,
        time=s.time,
        requests=s.requests,
        impressions=s.impressions,
        clicks=s.clicks,
        partner_channel_id=s.partner_channel_id,
        response_code=s.response_code,
        created_at=s.created_at

FROM deliver.stats_hourly h RIGHT OUTER JOIN clean.stats_hourly s
ON  h.time = s.time AND
    h.hour_id = s.hour_id AND
    (h.ad_id = s.ad_id OR (h.ad_id IS NULL AND s.ad_id IS NULL)) AND
    h.partner_channel_id = s.partner_channel_id AND
    h.response_code = s.response_code
WHERE
    h.time IS NULL


-- truncating tables

TRUNCATE TABLE raw.raw_requests
TRUNCATE TABLE raw.raw_impressions
TRUNCATE TABLE raw.raw_clicks
TRUNCATE TABLE clean.raw_requests
TRUNCATE TABLE clean.raw_impressions
TRUNCATE TABLE clean.raw_clicks
TRUNCATE TABLE clean.process_requests
TRUNCATE TABLE clean.process_impressions
TRUNCATE TABLE clean.process_clicks
TRUNCATE TABLE clean.stats_hourly


COMMIT TRANSACTION t
