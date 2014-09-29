DECLARE @activity varchar(255) = 'Ship';
DECLARE @status varchar(255) = 'success';
DECLARE @file varchar(255) = '2014-08-26.tar.gz.split03';
USE [database]

IF NOT EXISTS (
SELECT  schema_name
FROM    information_schema.schemata
WHERE   schema_name = 'shipping' )
BEGIN
EXEC sp_executesql N'CREATE SCHEMA shipping'
END

IF OBJECT_ID('shipping.log') IS NULL

CREATE TABLE shipping.log
(
activity VARCHAR(255) NOT NULL,
status VARCHAR(255) NOT NULL,
date_time datetime NOT NULL,
filename VARCHAR(255) NOT NULL
)

INSERT INTO shipping.log
VALUES(@activity, @status, GETDATE(), @file)
