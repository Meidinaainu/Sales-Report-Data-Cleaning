USE car_sales;

SELECT *
FROM car_sales_report;

#Create New Tables
CREATE TABLE sales_staging1
LIKE car_sales_report;

SELECT *
FROM sales_staging1;

INSERT sales_staging1
SELECT *
FROM car_sales_report;

-- Remove Duplicates
#Check The Duplicates
WITH duplicate_cte AS
(
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY Car_id, `Date`, `Customer Name`, Gender, `Annual Income`, Dealer_Name, 
			Company, Model, `Engine`, Transmission, Color, `Price ($)`, Dealer_No, 
			`Body Style`, Phone, Dealer_Region) AS row_num
FROM sales_staging1
)

SELECT *
FROM duplicate_cte
WHERE row_num > 1;

#Create New Table Without Duplicates
CREATE TABLE `sales_staging2` (
  `Car_id` text,
  `Date` text,
  `Customer Name` text,
  `Gender` text,
  `Annual Income` int DEFAULT NULL,
  `Dealer_Name` text,
  `Company` text,
  `Model` text,
  `Engine` text,
  `Transmission` text,
  `Color` text,
  `Price ($)` int DEFAULT NULL,
  `Dealer_No` text,
  `Body Style` text,
  `Phone` text,
  `Dealer_Region` text,
  `row_num` INT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

SELECT *
FROM sales_staging2;

#Remove The Duplicates
INSERT INTO sales_staging2
SELECT *,
ROW_NUMBER() OVER(
PARTITION BY Car_id, `Date`, `Customer Name`, Gender, `Annual Income`, Dealer_Name, 
			Company, Model, `Engine`, Transmission, Color, `Price ($)`, Dealer_No, 
			`Body Style`, Phone, Dealer_Region) AS row_num
FROM sales_staging1;

SELECT *
FROM sales_staging2
WHERE row_num > 1;

DELETE
FROM sales_staging2
WHERE row_num > 1;

-- Standardizing Data
SELECT Dealer_name, TRIM(Dealer_name), `Engine`, TRIM(`Engine`)
FROM sales_staging2;

UPDATE sales_staging2
SET Dealer_name = TRIM(Dealer_name), `Engine` = TRIM(`Engine`);

#Check Spellings
SELECT DISTINCT Model
FROM sales_staging2
ORDER BY 1;

#Correct Spellings
SELECT *
FROM sales_staging2
WHERE Model LIKE '300%';

UPDATE sales_staging2
SET Model = '300M'
WHERE Model = '300 M';

SELECT *
FROM sales_staging2
WHERE Model LIKE 'De%';

UPDATE sales_staging2
SET Model = 'DeVille'
WHERE Model = 'De Ville';

SELECT *
FROM sales_staging2
WHERE Model LIKE '%rango';

UPDATE sales_staging2
SET Model = 'Durango'
WHERE Model = 'Dur ango';

SELECT DISTINCT Dealer_Region
FROM sales_staging2
ORDER BY 1;

#Remove Symbols
SELECT DISTINCT Dealer_region, TRIM(TRAILING '.' FROM Dealer_region)
FROM sales_staging2
ORDER BY 1;

UPDATE sales_staging2
SET Dealer_region = TRIM(TRAILING '.' FROM Dealer_region);

SELECT DISTINCT Dealer_region, TRIM(TRAILING '-' FROM Dealer_region)
FROM sales_staging2
ORDER BY 1;

UPDATE sales_staging2
SET Dealer_region = TRIM(TRAILING '-' FROM Dealer_region);

#Transform `date` from text to date
SELECT `date`,
STR_TO_DATE(`date`, '%m/%d/%Y')
FROM sales_staging2;

UPDATE sales_staging2
SET `date` = STR_TO_DATE(`date`, '%m/%d/%Y');

ALTER TABLE sales_staging2
MODIFY COLUMN `date` DATE;

-- Null Values
#Check NULL Values
SELECT *
FROM sales_staging2
WHERE Company = '';

SELECT *
FROM sales_staging2
WHERE Model = 'Celica';

#Transform Company from '' to NULL
UPDATE sales_staging2
SET Company = NULL
WHERE Company ='';

# Fix NULL Values
SELECT ss1.Company, ss2.Company
FROM sales_staging2 AS ss1
JOIN sales_staging2 AS ss2
	ON ss1.Model = ss2.Model
    AND ss1.`Body Style` = ss2.`Body Style`
WHERE ss1.Company IS NULL
AND ss2.Company IS NOT NULL;

UPDATE sales_staging2 AS ss1
JOIN sales_staging2 AS ss2
	ON ss1.Model = ss2.Model
    AND ss1.`Body Style` = ss2.`Body Style`
SET ss1.Company = ss2.Company
WHERE ss1.Company IS NULL 
AND ss2.Company IS NOT NULL;

-- Delete Column and Rows
SELECT *
FROM sales_staging2
WHERE Company IS NULL
AND Model = ''
AND `Engine` = ''
AND Color = ''
AND `Price ($)` IS NULL;

DELETE
FROM sales_staging2
WHERE Company IS NULL
AND Model = ''
AND `Engine` = ''
AND Color = ''
AND `Price ($)` IS NULL;

ALTER TABLE sales_staging2
DROP COLUMN row_num;

-- Final Data
SELECT *
FROM sales_staging2;




-- Exploratory Data Analysis
SELECT *
FROM sales_staging2;

#Whos people with annual income > 1000000 and sorted by car price
SELECT *
FROM sales_staging2
WHERE `Annual Income` > 1000000 
ORDER BY `price ($)` DESC;

#Dealers based on sales from the highest to the lowest
SELECT Dealer_name, SUM(`Price ($)`)
FROM sales_staging2
GROUP BY Dealer_name
ORDER BY 2 DESC;

#Car Company and Model based on sales from the highest to the lowest
SELECT Company, Model, SUM(`Price ($)`)
FROM sales_staging2
GROUP BY Company
ORDER BY 3 DESC;

#Region based on sales from the highest to the lowest
SELECT Dealer_Region, SUM(`Price ($)`)
FROM sales_staging2
GROUP BY Dealer_Region
ORDER BY 2 DESC;

#Check the earliest and latest date
SELECT MIN(`date`), MAX(`date`)
FROM sales_staging2;

#Year based on sales from the highest to the lowest
SELECT YEAR(`date`), SUM(`Price ($)`)
FROM sales_staging2
WHERE YEAR(`date`) IS NOT NULL
GROUP BY YEAR(`date`)
ORDER BY 1 DESC;

#Month based on sales from the highest to the lowest
SELECT SUBSTRING(`date`,1,7) AS `Month`, SUM(`Price ($)`)
FROM sales_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `Month`
ORDER BY 2 DESC;

#Count Rolling Total
WITH Month_year_total AS
(
SELECT SUBSTRING(`date`,1,7) AS `Month`, SUM(`Price ($)`) AS total_sales
FROM sales_staging2
WHERE SUBSTRING(`date`,1,7) IS NOT NULL
GROUP BY `Month`
ORDER BY 2 DESC
)

SELECT `Month`, total_sales,
SUM(total_sales) OVER (ORDER BY `Month`) AS rolling_total
FROM Month_year_total;

#Top 3 dealers with high sales in each year
WITH dealer_year (dealer, years, total_sales) AS
(
SELECT Dealer_name, YEAR(`date`), SUM(`Price ($)`)
FROM sales_staging2
GROUP BY Dealer_name, YEAR(`date`)
), dealer_year_rank AS
(
SELECT *, DENSE_RANK() OVER (PARTITION BY years ORDER BY total_sales DESC) AS ranking
FROM dealer_year
WHERE years IS NOT NULL)

SELECT *
FROM dealer_year_rank
WHERE ranking <= 3;
;