use sep4
go

DROP TABLE DW_Changed_Sensor;
DROP TABLE DW_Changed_Winecellar;
DROP TABLE DW_Changed_Measurement;

CREATE TABLE DW_Changed_Measurement(
MeasureID INT,
DataName NVARCHAR(50),
DataValue DECIMAL(18,2),
SensorID INT,
MeasureTimestamp Datetime
);

CREATE TABLE DW_Changed_Winecellar (
WineCellarID INT,
CellarName NVARCHAR(50)
);

CREATE TABLE DW_Changed_Sensor(
SensorID INT,
SensorName NVARCHAR(50),
RoomLocation NVARCHAR(50), 
WineCellarID INT
);

---Last updated variables
DECLARE @lastUpdated Date = (Select Last_updated from DW_update) --31/12/1997
DECLARE @lastUpdatedPlusOne Date = DATEADD(day,1,(Select Last_updated from DW_update)) -- 01/01/1998
DECLARE @endDate Date = '2099/01/01' 


------------
---Sensor---
------------

--Insert added sensors
INSERT INTO sep4.dbo.DW_D_Sensor(SensorID,SensorName,RoomLocation,WineCellarID, validFrom, validTo)
Select SensorID,SensorName,RoomLocation,WineCellarID, @lastUpdatedPlusOne, @endDate from sep4.dbo.Sensor
WHERE SensorID in 
(
	( --today
	SELECT SensorID FROM sep4.dbo.Sensor
	)
	EXCEPT
	( --yesterday
	SELECT SensorID FROM sep4.dbo.DW_D_Sensor
	)
)

--Update deleted Sensors
UPDATE sep4.dbo.DW_D_Sensor set validTo = @lastUpdated
WHERE SensorID in 
(
	( --Yesterday and past
	SELECT SensorID FROM sep4.dbo.DW_D_Sensor
	)
	EXCEPT
	( --Today
	SELECT SensorID FROM sep4.dbo.Sensor
	)
)

--Insert and update changed Sensors
INSERT INTO DW_Changed_Sensor (SensorID,SensorName,RoomLocation,WineCellarID)
(
	SELECT SensorID, SensorName, RoomLocation, WineCellarID FROM Sensor --Today
	EXCEPT --Yesterday
	(
		SELECT SensorID, SensorName, RoomLocation, WineCellarID FROM DW_D_Sensor 
	)
	EXCEPT
	(
		SELECT SensorID, SensorName, RoomLocation, WineCellarID FROM Sensor
		WHERE SensorID NOT IN 
		(
			SELECT SensorID FROM DW_D_Sensor
		)
	)
)

UPDATE DW_D_Sensor
SET validTo =  @lastUpdated
WHERE SensorID in
(SELECT SensorID
FROM DW_Changed_Sensor)

--Insert new row in dimension table
INSERT INTO DW_D_Sensor(SensorID,SensorName,RoomLocation,WineCellarID, validFrom, validTo)
SELECT SensorID,SensorName,RoomLocation,WineCellarID, @lastUpdatedPlusOne, @endDate 
FROM DW_Changed_Sensor

-----------------
---Measurement---
-----------------
---Test
--Insert into Measurement(Date_Inserted, DataType, DataValue)VALUES (GETDATE(), 'CO2', 123)

--Insert added measurement
INSERT INTO sep4.dbo.DW_D_Measurement(MeasureID,DataName,DataValue,MeasureTimestamp,SensorID, validFrom, validTo)
Select M_ID,DataType,DataValue,Date_Inserted,SensorID, @lastUpdatedPlusOne, @endDate from sep4.dbo.Measurement
WHERE M_ID in 
(
	( --today
	SELECT M_ID FROM sep4.dbo.Measurement
	)
	EXCEPT
	( --yesterday
	SELECT MeasureID FROM sep4.dbo.DW_D_Measurement
	)
)

--Update deleted measurement
UPDATE sep4.dbo.DW_D_Measurement set validTo = @lastUpdated
WHERE MeasureID in 
(
	( --Yesterday and past
	SELECT MeasureID FROM sep4.dbo.DW_D_Measurement
	)
	EXCEPT
	( --Today
	SELECT MeasureID FROM sep4.dbo.Measurement
	)
)

--Insert and update changed Measurements
INSERT INTO DW_Changed_Measurement(MeasureID,DataName,DataValue,MeasureTimestamp,SensorID)
(
	SELECT M_ID,DataType,DataValue,Date_Inserted,SensorID FROM Measurement --Today
	EXCEPT --Yesterday
	(
		SELECT MeasureID,DataName,DataValue,MeasureTimestamp,SensorID FROM DW_D_Measurement
	)
	EXCEPT
	(
		SELECT M_ID,DataType,DataValue,Date_Inserted,SensorID FROM Measurement
		WHERE M_ID NOT IN 
		(
			SELECT MeasureID FROM DW_D_Measurement
		)
	)
)

UPDATE DW_D_Measurement
SET validTo =  @lastUpdated
WHERE MeasureID in
(SELECT MeasureID
FROM DW_Changed_Measurement)
--Insert new row in dimension table
INSERT INTO DW_D_Measurement(MeasureID,DataName,DataValue,MeasureTimestamp,SensorID, validFrom, validTo)
SELECT MeasureID,DataName,DataValue,MeasureTimestamp,SensorID, @lastUpdatedPlusOne, @endDate FROM DW_Changed_Measurement

----------------
---Winecellar---
----------------

--Insert added winecellar
INSERT INTO sep4.dbo.DW_D_WineCellar(WineCellarID,CellarName, validFrom, validTo)
Select WineCellarID,CellarName, @lastUpdatedPlusOne, @endDate from sep4.dbo.WineCellar
WHERE WineCellarID in 
(
	( --today
	SELECT WineCellarID FROM sep4.dbo.WineCellar
	)
	EXCEPT
	( --yesterday
	SELECT WineCellarID FROM sep4.dbo.DW_D_WineCellar
	)
)

--Update deleted measurement
UPDATE sep4.dbo.DW_D_WineCellar set validTo = @lastUpdated
WHERE WineCellarID in 
(
	( --Yesterday and past
	SELECT WineCellarID FROM sep4.dbo.DW_D_WineCellar
	)
	EXCEPT
	( --Today
	SELECT WineCellarID FROM sep4.dbo.WineCellar
	)
)

--Insert and update changed Winecellers
INSERT INTO DW_Changed_Winecellar(WineCellarID,CellarName)
(
	SELECT WineCellarID,CellarName FROM WineCellar --Today
	EXCEPT --Yesterday
	(
		SELECT WineCellarID,CellarName FROM DW_D_WineCellar
	)
	EXCEPT
	(
		SELECT WineCellarID,CellarName FROM WineCellar
		WHERE WineCellarID NOT IN 
		(
			SELECT WineCellarID FROM DW_D_WineCellar
		)
	)
)

UPDATE DW_D_WineCellar
SET validTo = @lastUpdated
WHERE WineCellarID in
(SELECT WineCellarID
FROM DW_Changed_Winecellar)
--Insert new row in dimension table
INSERT INTO DW_D_WineCellar(WineCellarID,CellarName, validFrom, validTo)
SELECT WineCellarID,CellarName, @lastUpdatedPlusOne, @endDate FROM DW_Changed_Winecellar

--select * from DW_D_Measurement order by MeasureTimestamp desc