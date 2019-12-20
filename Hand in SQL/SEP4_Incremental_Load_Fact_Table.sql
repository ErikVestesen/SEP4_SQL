DROP TABLE DW_Temp_Fact_Data;
---------------------
---Update DW facts---
---------------------

DECLARE @endDate Date = '2099/01/01' 

--Create Temp fact table
CREATE TABLE DW_Temp_Fact_Data (
D_ID INT NULL,
S_ID INT NULL,
W_ID INT NULL,
M_ID INT NULL,
MeasureID int NULL,
SensorID int NULL,
WineCellarID int NULL,
InsertedDate DATETIME NULL,
DailyAverageCO2 DECIMAL(18,2) NULL,
DailyAverageTemperature DECIMAL(18,2) NULL,
DailyAverageHumidity DECIMAL(18,2) NULL
)

--Insert business keys
INSERT INTO DW_Temp_Fact_Data 
(MeasureID, SensorID, WineCellarID, InsertedDate)
SELECT
M.M_ID, S.SensorID, W.WinecellarID, M.Date_Inserted
From SEP4.dbo.Sensor S
JOIN SEP4.dbo.WineCellar W on W.WinecellarID = S.WinecellarID
JOIN SEP4.dbo.Measurement M on M.SensorID = S.SensorID
WHERE M.Date_Inserted > (select max(Last_updated) from DW_Update)
--AND M.DataType = S.SensorName

--Look up surrogate keys
UPDATE DW_Temp_Fact_Data
SET M_ID = (
SELECT m.M_ID FROM DW_D_Measurement m
WHERE m.MeasureID = DW_Temp_Fact_Data.MeasureID
AND m.validTo = @endDate
)

UPDATE DW_Temp_Fact_Data
SET W_ID = (
SELECT w.W_ID FROM DW_D_WineCellar w
WHERE w.WineCellarID = DW_Temp_Fact_Data.WineCellarID
AND w.validTo = @endDate
)

UPDATE DW_Temp_Fact_Data
SET S_ID = (
SELECT s.S_ID FROM DW_D_Sensor s
WHERE s.SensorID = DW_Temp_Fact_Data.SensorID
AND s.validTo = @endDate
)

UPDATE DW_Temp_Fact_Data
SET D_ID = (
SELECT max(c.D_ID) FROM DW_D_Calendar c
WHERE c.EntireDateInserted = DW_Temp_Fact_Data.InsertedDate
)

--Update metrics
Update 
	DW_Temp_Fact_Data 
Set 
	DailyAverageCO2 = (
		SELECT DISTINCT a.Average FROM 
		(
			Select AVG(DataValue) as Average, 
			CONVERT(date, MeasureTimestamp) as dateTimestamp
			from DW_D_Measurement where SensorID in 
			(   
				Select SensorID from DW_D_Sensor where WineCellarID = 1 
			)   
			and DataName  = 'CO2'
			GROUP BY CONVERT(date, MeasureTimestamp) 
		) a, DW_D_Measurement m
		WHERE m.M_ID = DW_Temp_Fact_Data.M_ID
		AND CONVERT(date, m.MeasureTimestamp) = a.dateTimestamp
	),
	DailyAverageTemperature = (
		SELECT DISTINCT a.Average FROM 
		(
			Select AVG(DataValue) as Average, 
			CONVERT(date, MeasureTimestamp) as dateTimestamp
			from DW_D_Measurement where SensorID in 
			(   
				Select SensorID from DW_D_Sensor where WineCellarID = 1 
			)   
			and DataName  = 'Temperature'
			GROUP BY CONVERT(date, MeasureTimestamp) 
		) a, DW_D_Measurement m
		WHERE m.M_ID = DW_Temp_Fact_Data.M_ID
		AND CONVERT(date, m.MeasureTimestamp) = a.dateTimestamp
	),
	DailyAverageHumidity = (
		SELECT DISTINCT a.Average FROM 
		(
			Select AVG(DataValue) as Average, 
			CONVERT(date, MeasureTimestamp) as dateTimestamp
			from DW_D_Measurement where SensorID in 
			(   
				Select SensorID from DW_D_Sensor where WineCellarID = 1 
			)   
			and DataName  = 'Humidity'
			GROUP BY CONVERT(date, MeasureTimestamp) 
		) a, DW_D_Measurement m
		WHERE m.M_ID = DW_Temp_Fact_Data.M_ID
		AND CONVERT(date, m.MeasureTimestamp) = a.dateTimestamp
	)

--Populate DW fact table 
INSERT INTO DW_F_Data (D_ID, W_ID, S_ID, M_ID, DailyAverageCO2, DailyAverageHumidity, DailyAverageTemperature)
SELECT D_ID, W_ID, S_ID, M_ID, DailyAverageCO2, DailyAverageHumidity, DailyAverageTemperature
FROM DW_Temp_Fact_Data
