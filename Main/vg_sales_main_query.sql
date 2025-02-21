#Importing Data
CREATE DATABASE IF NOT EXISTS vg_project; 



#-----------------------------------------------------------------------------------------------------------------------------------
#Cleaning Data
DESCRIBE vg_sales;

SELECT * 
FROM vg_sales;

#Nulls?
SELECT * 
FROM vg_sales
WHERE `Rank` IS NULL 
OR `Name` IS NULL
OR Platform IS NULL
OR `Year` IS NULL
OR Genre IS NULL
OR Publisher IS NULL
OR NA_Sales IS NULL
OR EU_SALES IS NULL
OR Other_Sales IS NULL
OR Global_Sales IS NULL;

#Duplicates by name, platform, year and pubslisher?
SELECT `Name`, Platform, `Year`, Publisher, COUNT(*)
FROM vg_sales
GROUP BY `Name`, Platform, `Year`, Publisher
HAVING COUNT(*) > 1;

#Madden NFL 13 on PS3 had a duplicate so must investigate:
SELECT *
FROM vg_sales
WHERE Name = 'Madden NFL 13' 
AND Platform = 'PS3';
#Let's drop the Madden NFL 13 with the lower rank as it only has 0.01 in Global sales which doesn't make sense
DELETE  
FROM vg_sales
WHERE Name = 'Madden NFL 13' 
AND Platform = 'PS3'
AND Global_Sales = 0.01;
#Fix error: Allow for deletion of rows in the actual table
SET SQL_SAFE_UPDATES = 0;

#Check for inconsistencies in spelling, numbers, etc.
SELECT DISTINCT `Name`
FROM vg_sales;

SELECT DISTINCT Platform
FROM vg_sales;

SELECT DISTINCT `Year`
FROM vg_sales;

SELECT DISTINCT Genre
FROM vg_sales;

SELECT DISTINCT Publisher
From vg_sales;

#Renaming some Platform titles as I don't like how they're labelled
START TRANSACTION; 

UPDATE vg_sales
SET Platform = 
CASE
	WHEN Platform = 'XOne' THEN 'Xbox One'
    WHEN Platform = 'XB' THEN 'Xbox'
    WHEN Platform = 'X360' THEN 'Xbox 360'
    WHEN Platform = 'PSV' THEN 'PSVita'
    WHEN Platform = 'GC' THEN 'GameCube'
    WHEN Platform = 'WS' THEN 'WonderSwan'
    WHEN Platform = 'GB' THEN 'Game Boy'
    WHEN Platform = 'GBA' THEN 'Game Boy Advance'
    ELSE Platform #keep others the same
END;

COMMIT;

# We know that this is data from 1980 - ~2020 so let's determine if there are any outliers (found none)
SELECT *
FROM vg_sales
WHERE year < 1980 OR year > 2020;

#Now let's check for year consistency with some of the platform release dates (Only done with mainstream consoles)
#If data is correct, there should be nothing showing up in any of the query prompts
#PS4 | Xbox One released in 2013, PS3 | Wii released 2006, Xbox 360 released in 2005,
#WiiU released in 2012, 3DS | PsVita in 2011
#For query efficiency, we will make a query for each of the consoles above that are released on the same year
SELECT *
FROM vg_sales
WHERE Platform IN ('PS4', 'Xbox One') 
AND `Year` < 2013;

SELECT *
FROM vg_sales
WHERE Platform IN ('PS3', 'WII')
AND `Year` < 2006;

SELECT * 
FROM vg_sales
WHERE Platform = 'Xbox 360'
AND `Year` < 2005;

SELECT *
FROM vg_sales
WHERE Platform = 'WiiU'
AND `Year` < 2012;

SELECT *
FROM vg_sales
WHERE Platform IN ('3DS', 'PSVita') 
AND `Year` < 2011;

#Check if Rank column shows any inconsistencies. There are 16600 total rows in raw data
SELECT DISTINCT COUNT(`Rank`)
FROM vg_sales;
SELECT COUNT(`Rank`) 
FROM vg_sales; #Gives same value as distinct which is good (16326)

SELECT * 
FROM vg_sales
ORDER BY `Rank` DESC;

SELECT * 
FROM vg_sales
WHERE `Rank` < 1
OR `Rank` > (SELECT COUNT(`Rank`) FROM vg_sales);
#I noticed that there was a big gap in finding the count of the number of rows (16326) and the highest rank (16600)
#After investigation, I realized that MySQL was only able to import 16300+ rows from the original 16600.
#After using Excel to observe the raw data, I found that it didnt import any of the original data with 'N/A' 
#as the year because I set the data type to 'int' 
# I then came to a conclusion that this is fine since if it doesn't tell us a year, then we can't really use it
# as information when we actually get to the EDA

#We will check some rows whether the sales add up to the Global_Sales
# We know that there's 16326 rows in the data so we will make a query that shows us all the rows where
#NA_sales + EU_sales + JP_Sales + Other_sales = Global_sales and see if that gives us the same amount of rows.
WITH sales_summed_to_global AS (
	SELECT *
	FROM vg_sales
	WHERE (NA_Sales + EU_Sales + JP_Sales + Other_Sales) = Global_Sales
    )
SELECT COUNT(*)
FROM sales_summed_to_global; #Came up with a count of 9670 and =/= 16326 so we need to investigate this


WITH sales_not_summed_to_global AS (
	SELECT *
	FROM vg_sales
	WHERE (NA_Sales + EU_Sales + JP_Sales + Other_Sales) != Global_Sales
    )
SELECT COUNT(*) # Count of 6650 so 9670(sales add up to global) + 6650 (sales not added up to global) = 16326
FROM sales_not_summed_to_global
ORDER BY `Rank` ASC; 

SELECT *
FROM vg_sales
WHERE (NA_Sales + EU_Sales + JP_Sales + Other_Sales) != Global_Sales;
#After looking at the head of the data, it seems that the global sales seem to be rounded up by the .00 decimal 
#since a lot of global sales are off by ~0.01 - 0.02. We can narrow it down by seeing which of the rows are off by more 
#than one decimal and seeing if there are any that actually have a big gap from the actual sum of regional sales 
#compared to global

#Below selects rows where the sum of all regional sales is noticeably different (by at least 0.02) 
#from Global_Sales.
SELECT *
FROM vg_sales
WHERE ((NA_Sales + EU_Sales + JP_Sales + Other_Sales) > Global_Sales + 0.02) 
OR ((NA_Sales + EU_Sales + JP_Sales + Other_Sales) < Global_Sales - 0.02);
#Turns out that none of them are actually have a greater deviation than +- 0.02 or $20000, so we can disregard
#this as a floating point error and won't skew our sales data significantly

SET SQL_SAFE_UPDATES = 1;





#-----------------------------------------------------------------------------------------------------------------------------------
#Exploratory Data Analysis -> There is a more in depth insight on my data analysis in the "Exploratory_data_analysis.docx" Word file


# What are the top-selling games globally?
SELECT *
FROM vg_sales
ORDER BY Global_Sales DESC;

#Not published by nintendo
SELECT *
FROM vg_sales
WHERE Publisher NOT LIKE 'Nintendo'
ORDER BY Global_Sales DESC;
#Top 16 and after (not made by nintendo) have a popularity in shooter and action genre

#What regions contribute to the most global_sales in all the data? Let's make it into a percentage too
SELECT ROUND(SUM(NA_Sales), 2) AS Total_NA_Sales, ROUND(SUM(EU_Sales), 2) Total_EU_Sales, 
	ROUND(SUM(JP_Sales),2) Total_JP_Sales, ROUND(SUM(Other_Sales),2) Total_Other_Sales, ROUND(SUM(Global_Sales), 2) Total_Global_Sales
FROM vg_sales;

#Now put into a CTE for percentage
WITH total_sales AS ( 
	SELECT ROUND(SUM(NA_Sales), 2) AS tnas, ROUND(SUM(EU_Sales), 2) teus, 
	ROUND(SUM(JP_Sales),2) tjps, ROUND(SUM(Other_Sales),2) tos, ROUND(SUM(Global_Sales), 2) tgs
	FROM vg_sales
    )
SELECT ROUND((tnas / tgs) * 100,2) AS Total_NA_Sales_percent, ROUND((teus / tgs) * 100,2) AS Total_EU_Sales_percent, 
ROUND((tjps / tgs) * 100,2) AS Total_JP_Sales_percent, ROUND((tos / tgs) * 100,2) AS Total_Other_Sales_percent,
tgs AS Total_Global_Sales
FROM total_sales;

#How have video game sales pattern trended over the years? 
#After comparing averages, I also only want to grab the games 
#with the highest global sales for each year so I can see their genres, the publisher, etc.
SELECT `Year`, ROUND(AVG(Global_Sales), 2) AS Average_Global_Sales
FROM vg_sales
GROUP BY `Year`;
	
WITH greatest_sales_by_year AS (
	SELECT *, ROW_NUMBER() OVER(PARTITION BY `Year` ORDER BY Global_Sales DESC) AS rank_by_year
    FROM vg_sales
    )
SELECT *
FROM greatest_sales_by_year
WHERE rank_by_year = 1;


#How does platform affect game sales? We could compare the top 1 rank global sales for each platform but instead I want
#to grab the average sales for each platform and then compare that instead
#I only want to look at the trend from 1980 - 2015 (this would exclude some platforms)

SELECT Platform, ROUND(AVG(Global_Sales), 2) AS Average_Global_Sales
FROM vg_sales
WHERE `Year` BETWEEN 1980 AND 2015
GROUP BY Platform
ORDER BY Average_Global_Sales DESC;


#I want to see the growth comparing 1980 -2000 vs. 2001-2015 in terms of platform usage
SELECT Platform, 
       CASE 
           WHEN `Year` BETWEEN 1980 AND 2000 THEN '1980-2000'
           WHEN `Year` BETWEEN 2001 AND 2015 THEN '2001-2015'
       END AS Year_Range, 
       COUNT(*) AS num_games, 
       ROUND(SUM(Global_Sales), 2) AS total_sales
FROM vg_sales
WHERE `Year` BETWEEN 1980 AND 2015
GROUP BY Platform, Year_Range
ORDER BY Year_Range, total_sales DESC;


#When looking at specific regions, are there games that succeed better? Do regions correlate with game genre?
#I want to see if sales makes up half or majority of global sales FOR SPECIFIC GAMES for each region so I used 0.5
#NA
SELECT Genre, COUNT(Genre) AS num_games
FROM (SELECT *
	FROM vg_sales
	WHERE (NA_Sales / Global_Sales) >= 0.5
    ) AS nagenres
GROUP BY Genre
ORDER BY num_games DESC;
#EU
SELECT Genre, COUNT(Genre) AS num_games
FROM (SELECT *
	FROM vg_sales
	WHERE (EU_Sales / Global_Sales) >= 0.5
    ) AS eugenres
GROUP BY Genre
ORDER BY num_games DESC;
#JP
SELECT Genre, COUNT(Genre) AS num_games
FROM (SELECT *
	FROM vg_sales
	WHERE (JP_Sales / Global_Sales) >= 0.5
    ) AS jpgenres
GROUP BY Genre
ORDER BY num_games DESC;
#Global
SELECT Genre, COUNT(Genre) AS num_games
FROM vg_sales
GROUP BY Genre
ORDER BY num_games DESC;

#Overall, I want to look at the popular regions when it comes to genres. This is not for specific games unlike above.
SELECT 
    Genre,
    ROUND(SUM(NA_Sales) / SUM(Global_Sales) * 100, 2) AS NA_Percentage,
    ROUND(SUM(EU_Sales) / SUM(Global_Sales) * 100, 2) AS EU_Percentage,
    ROUND(SUM(JP_Sales) / SUM(Global_Sales) * 100, 2) AS JP_Percentage,
    ROUND(SUM(Other_Sales) / SUM(Global_Sales) * 100, 2) AS Other_Percentage,
    ROUND(SUM(Global_Sales), 2) AS Total_Global_Sales
FROM vg_sales
WHERE Global_Sales > 0  -- Avoid division by zero
GROUP BY Genre
ORDER BY Total_Global_Sales DESC;

#Are there any trends in genre popularity over time?
#I want to see the trend in Genre overall from 1980 -2000 vs. 2000-2015
SELECT Genre, 
       CASE 
           WHEN `Year` BETWEEN 1980 AND 2000 THEN '1980-2000'
           WHEN `Year` BETWEEN 2001 AND 2015 THEN '2001-2015'
       END AS Year_Range, 
       COUNT(*) AS num_games, 
       ROUND(SUM(Global_Sales), 2) AS total_sales
FROM vg_sales
WHERE `Year` BETWEEN 1980 AND 2015
GROUP BY Genre, Year_Range
ORDER BY Year_Range, num_games DESC;

#Do certain platforms have higher sales in specific regions (e.g., Xbox in NA, PlayStation in EU)?
SELECT 
    Platform,
    ROUND(SUM(NA_Sales) / SUM(Global_Sales) * 100, 2) AS NA_Percentage,
    ROUND(SUM(EU_Sales) / SUM(Global_Sales) * 100, 2) AS EU_Percentage,
    ROUND(SUM(JP_Sales) / SUM(Global_Sales) * 100, 2) AS JP_Percentage,
    ROUND(SUM(Other_Sales) / SUM(Global_Sales) * 100, 2) AS Other_Percentage,
    ROUND(SUM(Global_Sales), 2) AS Total_Global_Sales
FROM vg_sales
WHERE Global_Sales > 0  -- Avoid division by zero
GROUP BY Platform
ORDER BY Total_Global_Sales DESC;

#Specific Questions for deeper insight ->
#How do games that launched on multiple platforms compare to exclusives in terms of sales?

#From data, we grab the game name, count of number of platforms they're on, 
#and their total global sales combined on the platforms as a cte
#For viewing:
SELECT `Name`, 
COUNT(DISTINCT Platform) AS Platform_Count,
SUM(Global_Sales) AS Total_Game_Global_Sales
FROM vg_sales
GROUP BY `Name`;

#Put into a cte
WITH game_sales AS ( 
    SELECT 
        `Name`,
        COUNT(DISTINCT Platform) AS Platform_Count,
        SUM(Global_Sales) AS Total_Game_Global_Sales
    FROM vg_sales
    GROUP BY `Name` 
)
SELECT 
    CASE #OR -> IF(Platform_Count = 1, 'Exclusive', 'Multi-Platform') AS Launch_Type
        WHEN Platform_Count = 1 THEN 'Platform-Exclusive' #Game on one platform
        ELSE 'Multi-Platform' # Game on more than one platform
    END AS Launch_Type,
    COUNT(*) AS Num_Games,
    ROUND(AVG(Total_Game_Global_Sales), 2) AS Average_Global_Sales,
    ROUND(SUM(Total_Game_Global_Sales), 2) AS Total_Global_Sales
FROM game_sales
GROUP BY Launch_Type;
