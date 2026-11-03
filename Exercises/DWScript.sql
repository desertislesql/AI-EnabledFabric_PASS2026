/* ---------- Reset (safe to rerun) ---------- */
DROP TABLE IF EXISTS dbo.FactSales;
DROP TABLE IF EXISTS dbo.DimCustomer;
DROP TABLE IF EXISTS dbo.DimProduct;
DROP TABLE IF EXISTS dbo.DimDate;
DROP TABLE IF EXISTS dbo.Numbers;

/* ---------- Helper numbers table (0 to 9999) ---------- */
CREATE TABLE dbo.Numbers AS
SELECT ones.d + tens.d * 10 + hundreds.d * 100 + thousands.d * 1000 AS n
FROM       (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS ones(d)
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS tens(d)
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS hundreds(d)
CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7),(8),(9)) AS thousands(d);

/* ---------- DimCustomer ---------- */
CREATE TABLE dbo.DimCustomer (
    CustomerKey  INT          NOT NULL,
    CustomerName VARCHAR(100) NOT NULL,
    City         VARCHAR(50)  NOT NULL,
    Country      VARCHAR(50)  NOT NULL,
    Region       VARCHAR(30)  NOT NULL
);

INSERT INTO dbo.DimCustomer (CustomerKey, CustomerName, City, Country, Region) VALUES
 (1,  'Alpine Outfitters',   'Zurich',         'Switzerland',    'Europe'),
 (2,  'Nordic Trail Supply', 'Stockholm',      'Sweden',         'Europe'),
 (3,  'Rhein Cycle Works',   'Cologne',        'Germany',        'Europe'),
 (4,  'Velo Lumiere',        'Lyon',           'France',         'Europe'),
 (5,  'Thames Riders',       'London',         'United Kingdom', 'Europe'),
 (6,  'Sierra Ruta',         'Madrid',         'Spain',          'Europe'),
 (7,  'Dolomiti Sport',      'Milan',          'Italy',          'Europe'),
 (8,  'Bavaria Bikes',       'Munich',         'Germany',        'Europe'),
 (9,  'Cascade Cycles',      'Seattle',        'United States',  'North America'),
 (10, 'Desert Spoke',        'Phoenix',        'United States',  'North America'),
 (11, 'Lakeshore Gear',      'Chicago',        'United States',  'North America'),
 (12, 'Maple Pedal Co',      'Toronto',        'Canada',         'North America'),
 (13, 'Pacific Coast Bikes', 'Vancouver',      'Canada',         'North America'),
 (14, 'Ruta Azteca',         'Mexico City',    'Mexico',         'Latin America'),
 (15, 'Pedal Carioca',       'Rio de Janeiro', 'Brazil',         'Latin America'),
 (16, 'Andes Ciclismo',      'Santiago',       'Chile',          'Latin America'),
 (17, 'Sakura Cycle House',  'Osaka',          'Japan',          'Asia Pacific'),
 (18, 'Harbour Bikes',       'Sydney',         'Australia',      'Asia Pacific'),
 (19, 'Kiwi Trail Co',       'Auckland',       'New Zealand',    'Asia Pacific'),
 (20, 'Lion City Riders',    'Singapore',      'Singapore',      'Asia Pacific');

/* ---------- DimProduct ---------- */
CREATE TABLE dbo.DimProduct (
    ProductKey  INT           NOT NULL,
    ProductName VARCHAR(100)  NOT NULL,
    Category    VARCHAR(50)   NOT NULL,
    ListPrice   DECIMAL(10,2) NOT NULL
);

INSERT INTO dbo.DimProduct (ProductKey, ProductName, Category, ListPrice) VALUES
 (1,  'Road Bike 500',      'Bikes',       1450.00),
 (2,  'Mountain Bike 300',  'Bikes',       1199.00),
 (3,  'Hybrid Bike 200',    'Bikes',        799.00),
 (4,  'Helmet Pro',         'Accessories',   89.00),
 (5,  'LED Light Set',      'Accessories',   45.00),
 (6,  'Water Bottle Cage',  'Accessories',   12.50),
 (7,  'Cycling Jersey',     'Clothing',      65.00),
 (8,  'Padded Shorts',      'Clothing',      55.00),
 (9,  'Rain Jacket',        'Clothing',     120.00),
 (10, 'Carbon Wheelset',    'Components',   950.00),
 (11, 'Disc Brake Kit',     'Components',   210.00),
 (12, 'Chain and Cassette', 'Components',   135.00);

/* ---------- DimDate (2024-01-01 to 2025-12-31) ---------- */
CREATE TABLE dbo.DimDate (
    DateKey     INT         NOT NULL,
    [Date]      DATE        NOT NULL,
    [Year]      INT         NOT NULL,
    [Quarter]   VARCHAR(2)  NOT NULL,
    MonthNumber INT         NOT NULL,
    [MonthName] VARCHAR(10) NOT NULL
);

INSERT INTO dbo.DimDate (DateKey, [Date], [Year], [Quarter], MonthNumber, [MonthName])
SELECT
    YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d),
    d,
    YEAR(d),
    'Q' + CAST(DATEPART(QUARTER, d) AS VARCHAR(1)),
    MONTH(d),
    DATENAME(MONTH, d)
FROM (
    SELECT DATEADD(DAY, n, CAST('2024-01-01' AS DATE)) AS d
    FROM dbo.Numbers
    WHERE n BETWEEN 0 AND 730
) AS x;

/* ---------- FactSales (2,000 sales lines) ---------- */
CREATE TABLE dbo.FactSales (
    SalesKey    INT           NOT NULL,
    OrderNumber INT           NOT NULL,
    DateKey     INT           NOT NULL,
    CustomerKey INT           NOT NULL,
    ProductKey  INT           NOT NULL,
    Quantity    INT           NOT NULL,
    UnitPrice   DECIMAL(10,2) NOT NULL,
    DiscountPct DECIMAL(4,2)  NOT NULL,
    Revenue     DECIMAL(12,2) NOT NULL
);

INSERT INTO dbo.FactSales
    (SalesKey, OrderNumber, DateKey, CustomerKey, ProductKey, Quantity, UnitPrice, DiscountPct, Revenue)
SELECT
    s.n,
    100000 + s.n,
    YEAR(s.OrderDate) * 10000 + MONTH(s.OrderDate) * 100 + DAY(s.OrderDate),
    s.CustomerKey,
    s.ProductKey,
    s.Quantity,
    p.ListPrice,
    s.DiscountPct,
    CAST(s.Quantity * p.ListPrice * (1 - s.DiscountPct) AS DECIMAL(12,2))
FROM (
    SELECT
        n,
        DATEADD(DAY, (n * 37) % 731, CAST('2024-01-01' AS DATE)) AS OrderDate,
        CASE WHEN n % 5 = 0 THEN (n % 3) + 1 ELSE (n * 7) % 20 + 1 END AS CustomerKey,
        (n * 11) % 12 + 1 AS ProductKey,
        (n * 17) % 5 + 1  AS Quantity,
        CAST(CASE WHEN n % 10 = 0 THEN 0.10
                  WHEN n % 7  = 0 THEN 0.05
                  ELSE 0 END AS DECIMAL(4,2)) AS DiscountPct
    FROM dbo.Numbers
    WHERE n BETWEEN 1 AND 2000
) AS s
JOIN dbo.DimProduct AS p ON p.ProductKey = s.ProductKey;

/* ---------- Keys (not enforced; used for model metadata) ---------- */
ALTER TABLE dbo.DimCustomer ADD CONSTRAINT PK_DimCustomer PRIMARY KEY NONCLUSTERED (CustomerKey) NOT ENFORCED;
ALTER TABLE dbo.DimProduct  ADD CONSTRAINT PK_DimProduct  PRIMARY KEY NONCLUSTERED (ProductKey)  NOT ENFORCED;
ALTER TABLE dbo.DimDate     ADD CONSTRAINT PK_DimDate     PRIMARY KEY NONCLUSTERED (DateKey)     NOT ENFORCED;
ALTER TABLE dbo.FactSales   ADD CONSTRAINT PK_FactSales   PRIMARY KEY NONCLUSTERED (SalesKey)    NOT ENFORCED;

ALTER TABLE dbo.FactSales ADD CONSTRAINT FK_FactSales_Customer
    FOREIGN KEY (CustomerKey) REFERENCES dbo.DimCustomer (CustomerKey) NOT ENFORCED;
ALTER TABLE dbo.FactSales ADD CONSTRAINT FK_FactSales_Product
    FOREIGN KEY (ProductKey)  REFERENCES dbo.DimProduct (ProductKey)   NOT ENFORCED;
ALTER TABLE dbo.FactSales ADD CONSTRAINT FK_FactSales_Date
    FOREIGN KEY (DateKey)     REFERENCES dbo.DimDate (DateKey)         NOT ENFORCED;

/* ---------- Remove helper table ---------- */
DROP TABLE dbo.Numbers;
