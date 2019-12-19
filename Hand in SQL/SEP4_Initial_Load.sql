USE sep4
go
--TODO (for initial load):

--discuss fact table values... only got ids right now

--Update calendar surrogate key, missing an ID
--Fill data warehouse fact

--Entire incremential load stuff, not now plz

-----------------------
---Create Dimensions---
-----------------------
DROP TABLE DW_Update;
DROP TABLE DW_F_Data;
DROP TABLE DW_D_Sensor;
DROP TABLE DW_D_Calendar;
DROP TABLE DW_D_WineCellar;
DROP TABLE DW_D_Measurement;

CREATE TABLE DW_D_Measurement(
M_ID INT PRIMARY KEY IDENTITY (1, 1), 
MeasureID INT,
DataName NVARCHAR(50),
DataValue DECIMAL(18,2),
SensorID INT,
MeasureTimestamp Datetime,
validFrom DATE,
validTo DATE
);

CREATE TABLE DW_D_WineCellar(
W_ID INT PRIMARY KEY IDENTITY (1, 1), 
WineCellarID INT,
CellarName NVARCHAR(50),
validFrom DATE,
validTo DATE
);

CREATE TABLE DW_D_Calendar(
D_ID INT PRIMARY KEY IDENTITY (1, 1), 
EntireDateInserted DATETIME,
DD_inserted INT,
MM_inserted INT,
YYYY_inserted INT,
HH24_inserted INT,
MM60_inserted INT,
WeekNumber_inserted INT, 
NameOfMonth_inserted NVARCHAR(50), 
NameOfWeekday_inserted NVARCHAR(50)
);


CREATE TABLE DW_D_Sensor(
S_ID INT PRIMARY KEY IDENTITY (1, 1),
SensorID INT,
SensorName NVARCHAR(50),
RoomLocation NVARCHAR(50), 
WineCellarID INT,
validFrom DATE,
validTo DATE
);

CREATE TABLE DW_F_Data(
	D_ID INT REFERENCES DW_D_Calendar(D_ID),
	S_ID INT REFERENCES DW_D_Sensor(S_ID),
	W_ID INT REFERENCES DW_D_WineCellar(W_ID),
	M_ID INT REFERENCES DW_D_Measurement(M_ID),
	DailyAverageCO2 DECIMAL(18,2),
	DailyAverageTemperature  DECIMAL(18,2),
	DailyAverageHumidity DECIMAL(18,2)
);

CREATE TABLE DW_Update(
	Last_updated Date
)
--Insert last updated date into table
INSERT INTO DW_Update(Last_updated) select CAST(GETDATE() as date)

-----------
---Stage---
-----------
DROP TABLE Stage_Sensor;
DROP TABLE Stage_Calendar;
DROP TABLE Stage_WineCellar;
DROP TABLE Stage_Measurement;

CREATE TABLE Stage_Measurement(
M_ID INT PRIMARY KEY, 
DataName NVARCHAR(50),
DataValue DECIMAL(18,2),
SensorID INT,
MeasureTimestamp DATETIME
);

CREATE TABLE Stage_WineCellar(
W_ID INT PRIMARY KEY, 
CellarName NVARCHAR(50) 
);

CREATE TABLE Stage_Calendar(
D_ID INT PRIMARY KEY , 
EntireDateInserted DATETIME,
DD_inserted INT,
MM_inserted INT,
YYYY_inserted INT,
HH24_inserted INT,
MM60_inserted INT,
WeekNumber_inserted INT, 
NameOfMonth_inserted NVARCHAR(50), 
NameOfWeekday_inserted NVARCHAR(50)
);


CREATE TABLE Stage_Sensor(
S_ID INT PRIMARY KEY,
SensorName NVARCHAR(50),
RoomLocation NVARCHAR(50), 
WineCellarID INT
);

----------------
---Fill Stage---
----------------
--Stage Measurement
INSERT INTO Stage_Measurement(M_ID,DataName,DataValue,SensorID,MeasureTimestamp)
SELECT M_ID,DataType,DataValue,SensorID,Date_Inserted
FROM sep4.dbo.Measurement

--Stage WineCellar
INSERT INTO Stage_WineCellar(W_ID,CellarName)
SELECT WinecellarID,CellarName
FROM sep4.dbo.WineCellar

--Stage Sensor
INSERT INTO Stage_Sensor(S_ID,SensorName,RoomLocation,WineCellarID)
SELECT SensorID,SensorName,RoomLocation,WineCellarID
FROM sep4.dbo.Sensor

--Stage Calendar
INSERT INTO Stage_Calendar(D_ID, EntireDateInserted,DD_inserted, MM_inserted,YYYY_inserted,HH24_inserted,MM60_inserted,WeekNumber_inserted,NameOfMonth_inserted, NameOfWeekday_inserted)
Select m.M_ID ,m.Date_Inserted,DAY(m.Date_Inserted),MONTH(m.Date_Inserted),YEAR(m.Date_Inserted),DATEPART(HOUR,m.Date_Inserted),
DATEPART(MINUTE,m.Date_Inserted), DATEPART(week, m.Date_Inserted), DATENAME(month, m.Date_Inserted), DATENAME(WEEKDAY, m.Date_Inserted)
FROM sep4.dbo.Measurement m

----------------
---Stage Fact---
----------------
DROP TABLE Stage_Fact_Data;
CREATE TABLE Stage_Fact_Data(
M_ID int NULL,
W_ID int NULL,
S_ID int NULL,
D_ID int NULL,
MeasureID int NULL,
SensorID int NULL,
WineCellarID int NULL,
InsertedDate DATETIME NULL
);

---------------------
---Fill Stage fact---
---------------------
INSERT INTO Stage_Fact_Data 
(MeasureID, SensorID, WineCellarID, InsertedDate)
SELECT
M.M_ID, S.SensorID, W.WinecellarID, C.EntireDateInserted
From SEP4.dbo.Sensor S
JOIN SEP4.dbo.WineCellar W on W.WinecellarID = S.WinecellarID
JOIN SEP4.dbo.Measurement M on M.SensorID = S.SensorID
JOIN sep4.dbo.Stage_Calendar C on C.EntireDateInserted = M.Date_Inserted
WHERE M.DataType = S.SensorName

------------------------------------
---Fill Data warehouse Dimensions---
------------------------------------
DECLARE @endTime date;
DECLARE @now date;
set @endTime = '2099/01/01'
set @now = (select max(Last_updated) from DW_Update)

--Calendar
INSERT INTO DW_D_Calendar(EntireDateInserted,DD_inserted,MM_inserted,YYYY_inserted,HH24_inserted,MM60_inserted,WeekNumber_inserted,NameOfMonth_inserted, NameOfWeekday_inserted)
SELECT EntireDateInserted,DD_inserted,MM_inserted,YYYY_inserted,HH24_inserted,MM60_inserted,WeekNumber_inserted,NameOfMonth_inserted, NameOfWeekday_inserted
FROM Stage_Calendar

--WineCellar
INSERT INTO DW_D_WineCellar(WineCellarID,CellarName,validFrom, validTo)
SELECT W_ID,CellarName, @now, @endTime
FROM Stage_WineCellar

--Measurement
INSERT INTO DW_D_Measurement(MeasureID,DataName,DataValue,MeasureTimestamp,SensorID, validFrom, validTo)
SELECT M_ID,DataName,DataValue,MeasureTimestamp,SensorID, @now, @endTime
FROM Stage_Measurement

--Sensor
INSERT INTO DW_D_Sensor(SensorID,SensorName,RoomLocation,WineCellarID, validFrom, validTo)
SELECT S_ID,SensorName,RoomLocation,WineCellarID, @now, @endTime
FROM Stage_Sensor

---------------------------
---Update surrogate keys---
---------------------------
----WineCellar
UPDATE Stage_Fact_Data
SET W_ID = (
	SELECT W_ID 
	FROM DW_D_WineCellar w 
	WHERE w.WineCellarID = Stage_Fact_Data.WineCellarID
)

----Measurement
UPDATE Stage_Fact_Data
SET M_ID = (
	SELECT M_ID 
	FROM DW_D_Measurement m
	WHERE m.MeasureID = Stage_Fact_Data.MeasureID
)

----Sensor
UPDATE Stage_Fact_Data
SET S_ID = (
	SELECT S_ID 
	FROM DW_D_Sensor s
	WHERE s.SensorID = Stage_Fact_Data.SensorID
)


----Calendar
UPDATE Stage_Fact_Data
SET D_ID = (
	SELECT top 1(c.D_ID)
	FROM DW_D_Calendar c 
	WHERE c.EntireDateInserted = Stage_Fact_Data.InsertedDate
)
------------------------------
---Fill Data warehouse fact---
------------------------------
INSERT INTO DW_F_Data(S_ID, W_ID, M_ID, D_ID)
SELECT S_ID, W_ID, M_ID, D_ID 
FROM Stage_Fact_Data
