--DROP TABLE Measurement
--DROP TABLE Sensor
--DROP TABLE WineCellar

CREATE TABLE WineCellar(
WinecellarID int Primary key not null,
CellarName varchar(100),
CellarStreetname varchar(100),
CellarZipcode varchar(100),
CellarCity varchar(100),
CellarCountry varchar(100)
)

CREATE TABLE Sensor(
SensorID int primary key not null,
SensorName nvarchar(50),
RoomLocation nvarchar(50),
WinecellarID int foreign key(WinecellarID) references WineCellar 
)

CREATE TABLE Measurement (
M_ID int primary key not null,
Date_Inserted datetime,
DataType nvarchar(50),
DataValue decimal(18,2),
SensorID int foreign key(SensorID) references Sensor
)