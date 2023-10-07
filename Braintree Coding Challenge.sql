/*Create a SQL database using the attached CSV files.*/
--Database created in SQL Server by creating a new database in the object explorer and importing each .csv file via tasks -> import flat file

/*Use the database to answer the following questions. All answers that return money values should be rounded to 2 decimal points and preceded by the "$" symbol (e.g. "$1432.10"). All answers that return percent values should be between -100.00 to 100.00, rounded to 2 decimal points and followed by the "%" symbol (e.g. "58.30%").*/

/*1a. Alphabetically list all of the country codes in the continent_map table that appear more than once. Display any values where country_code is null as country_code = "FOO" and make this row appear first in the list, even though it should alphabetically sort to the middle.*/

SELECT 
	country_code
FROM -- Subquery to change NULL values to 'FOO'
	(
	SELECT 
	CASE WHEN country_code IS NULL THEN 'FOO' -- Case statement to change NULL values to 'FOO'
		 ELSE country_code END AS country_code -- Leave non-NULL values as their original value
	FROM continent_map
	) AS sub
GROUP BY country_code
HAVING COUNT(country_code) > 1 -- Filter just country codes that appear more than once
ORDER BY
	CASE WHEN country_code = 'FOO' THEN 1 ELSE 2 END, -- Move 'FOO' to first result
	country_code; -- Sort remaining results alphabetically by country_code

/*1b. For all countries that have multiple rows in the continent_map table, delete all multiple records leaving only the 1 record per country. The record that you keep should be the first one when sorted by the continent_code alphabetically ascending. Provide the queries and explanation of step(s) that you follow to delete these records.*/

-- Add a number to uniquely identify each entry
ALTER TABLE continent_map
ADD row_num INT IDENTITY(1,1);

-- Define a CTE containing all records except the first instance of the country code (these will be deleted)
WITH duplicates AS
	(
	SELECT row_num, duplicate_num, country_code, continent_code
		FROM 
			(
			SELECT
				row_num,
				ROW_NUMBER() OVER -- Create a column to number each occurence of a country code
					(
					PARTITION BY country_code 
					ORDER BY country_code, continent_code
					) AS duplicate_num, 
				country_code, 
				continent_code
			FROM continent_map
			) AS sub
			WHERE duplicate_num > 1 -- Only keep the non-first occurences of a country code
	)

-- Remove the instances in the duplicates CTE from continent_map table
DELETE c
FROM continent_map AS c
INNER JOIN duplicates 
	ON c.row_num = duplicates.row_num; -- Using the unique identifier created earlier to join the tables

-- The deletion of the duplicates should have deleted all but one NULL value. This will delete the last one
DELETE FROM continent_map
WHERE country_code IS NULL;

-- Drop the row_num column since it is no longer needed
ALTER TABLE continent_map
DROP COLUMN row_num;

/*2. List the countries ranked 10-12 in each continent by the percent of year-over-year growth descending from 2011 to 2012. The percent of growth should be calculated as: ((2012 gdp - 2011 gdp) / 2011 gdp) The list should include the columns: rank, continent_name, country_code, country_name, growth_percent*/

-- Create CTE to extract 2011 gdp of each country
WITH gdp_2011 AS 
	(
	SELECT p.country_code, gdp_per_capita
	FROM 
		per_capita AS p
		INNER JOIN countries AS c1
			ON p.country_code = c1.country_code
	WHERE 
		year = 2011 -- Filter only 2011 gdp's
		AND gdp_per_capita IS NOT NULL -- Remove NULL gdp's to avoid skewing the ranking
	),

-- Create CTE to extract 2012 gdp of each country
gdp_2012 AS
	(
	SELECT p.country_code, gdp_per_capita
	FROM 
		per_capita AS p
		INNER JOIN countries AS c1
			ON p.country_code = c1.country_code
	WHERE 
		year = 2012 -- Filter only 2011 gdp's
		AND gdp_per_capita IS NOT NULL -- Remove NULL gdp's to avoid skewing the ranking
	),

-- Create CTE to calculate year-over-year growth of GDP from 2011 to 2012
gdp_growth AS
	(
	SELECT
		c1.country_code,
		ROUND(100.0 * (gdp_2012.gdp_per_capita - gdp_2011.gdp_per_capita) / gdp_2011.gdp_per_capita, 2) AS growth_percent -- Calcualte year-over-year growth of GDP, rounded according to the instructions
	FROM 
		countries AS c1
		INNER JOIN gdp_2011	
			ON c1.country_code = gdp_2011.country_code
		INNER JOIN gdp_2012
			ON c1.country_code = gdp_2012.country_code
	),

-- Create CTE with the growth percent sorted
gdp_growth_sorted AS
	(
	SELECT
		ROW_NUMBER() OVER(ORDER BY growth_percent DESC) AS rank_num, -- Rank countries by growth_percent
		country_code,
		growth_percent
	FROM gdp_growth
	)

-- Actual query to draw required data from previous four CTEs
SELECT
	g.rank_num,
	c1.continent_code,
	g.country_code,
	c2.country_name,
	CONCAT(g.growth_percent, '%') AS growth_percent -- Format growth_percent according to instructions
FROM 
	gdp_growth_sorted AS g
	INNER JOIN continent_map AS c1 -- Join needed to retrieve continent_code
		ON g.country_code = c1.country_code
	INNER JOIN countries AS c2 -- Join needed to retrive country_name
		ON g.country_code = c2.country_code
WHERE g.rank_num BETWEEN 10 AND 12 -- Filter out only ranks 10-12 per instructions
ORDER BY rank_num; -- Sort from highest to lowest rank

/*3. For the year 2012, create a 3 column, 1 row report showing the percent share of gdp_per_capita for the following regions: Asia, Europe, the Rest of the World.*/

-- Create CTE to calculate gdp percentages for Asia, Europe, and the rest of the world
WITH cte AS
	(
	SELECT 
		region,
		ROUND(100.0 * region_gdp / SUM(region_gdp) OVER(), 2) AS percent_gdp -- Calculate percentage of gdp, rounded
	FROM -- Subquery to get the gdp of Asia, Europe and the rest of the world
		(
		SELECT
			region,
			SUM(gdp_per_capita) AS region_gdp
		FROM
			(
			SELECT -- Case statement to create groups of "Asia", "Europe", and "Rest of the World"
				CASE WHEN continent_name = 'Asia' THEN continent_name
						WHEN continent_name = 'Europe' THEN continent_name
						ELSE 'Rest of the World' END AS region,
				gdp_per_capita
			FROM 
				per_capita AS p -- Multiple joins required to extract gdp_per_capita and continent_name
				INNER JOIN countries AS c1
					ON p.country_code = c1.country_code
				INNER JOIN continent_map AS c2
					ON p.country_code = c2.country_code
				INNER JOIN continents AS c3
					ON c2.continent_code = c3.continent_code
			WHERE 
				year = 2012 -- Filter to just 2012 gdp's
				AND gdp_per_capita IS NOT NULL -- Filter out NULL gdp's
			) AS sub
			GROUP BY region
		) AS sub
	),

-- Create CTE to PIVOT table to wide format
cte2 AS
	(
	SELECT *
	FROM cte
	PIVOT
		(
		SUM(percent_gdp)
		FOR region IN (
			[Asia],
			[Europe],
			[Rest of the World]
			)
		) AS pivot_table
	)

-- Actual query to format percentages according to instructions
SELECT
	CONCAT(Asia, '%') AS Asia,
	CONCAT(Europe, '%') AS Europe,
	CONCAT([Rest of the World], '%') AS [Rest of the World]
FROM cte2;

/*4a. What is the count of countries and sum of their related gdp_per_capita values for the year 2007 where the string 'an' (case insensitive) appears anywhere in the country name?*/

SELECT SERVERPROPERTY('COLLATION'); -- Confirm database is not case sensitive by default

SELECT 
	COUNT(p.country_code) AS count, -- Count number of countries with 'an' (not case sensitive) in their name
	CONCAT('$', CAST(ROUND(SUM(p.gdp_per_capita), 2) AS DECIMAL(10, 2))) AS total_gdp -- Format gdp per instructions
FROM 
	per_capita AS p
	INNER JOIN countries AS c
		ON p.country_code = c.country_code
WHERE 
	year = 2007 -- Filter to just 2007 gdp's
	AND country_name LIKE '%an%'; -- Filter to country_name's containing 'an'; by default, not case sensitive

/*4b. Repeat question 4a, but this time make the query case sensitive.*/

SELECT 
	COUNT(p.country_code) AS count, -- Count number of countries with 'an' (case sensitive) in their name
	CONCAT('$', CAST(ROUND(SUM(p.gdp_per_capita), 2) AS DECIMAL(10, 2))) AS total_gdp -- Format gdp per instructions
--	FORMAT(SUM(p.gdp_per_capita), '$0,.00K') AS total_gdp -- Format total gdp according to instructions
FROM 
	per_capita AS p
	INNER JOIN countries AS c
		ON p.country_code = c.country_code
WHERE year = 2007 -- Filter to just 2007 gdp's
	  AND country_name LIKE '%an%' COLLATE SQL_Latin1_General_CP1_CS_AS; -- Use case sensitive collation to filter

/*5. Find the sum of gpd_per_capita by year and the count of countries for each year that have non-null gdp_per_capita where (i) the year is before 2012 and (ii) the country has a null gdp_per_capita in 2012. Your result should have the columns: year, country_count, total*/

SELECT
	year,
	COUNT(country_code) AS country_count,
	CONCAT('$', CAST(ROUND(SUM(gdp_per_capita), 2) AS DECIMAL(10,2))) AS total
FROM 
	per_capita
WHERE 
	year < 2012
	AND gdp_per_capita IS NOT NULL
	AND country_code IN (
		SELECT country_code
		FROM per_capita
		WHERE year = 2012
			  AND gdp_per_capita IS NULL)
GROUP BY year

/*6. All in a single query, execute all of the steps below and provide the results as your final answer:
  a. create a single list of all per_capita records for year 2009 that includes columns: continent_name, country_code, country_name, gdp_per_capita
  b. order this list by: continent_name ascending, characters 2 through 4 (inclusive) of the country_name descending
  c. create a running total of gdp_per_capita by continent_name
  d. return only the first record from the ordered list for which each continent's running total of gdp_per_capita meets or exceeds $70,000.00 with the following columns: continent_name, country_code, country_name, gdp_per_capita, running_total*/

SELECT
	sub3.continent_name,
	sub3.country_code,
	sub3.country_name,
	CONCAT('$', CAST(ROUND(sub3.gdp_per_capita, 2) AS DECIMAL(10,2))) AS gdp_per_capita, -- Format per instructions
	CONCAT('$', CAST(ROUND(sub3.running_total, 2) AS DECIMAL(10,2))) AS running_total -- Format per instructions
FROM
	( -- Begin subquery sub2
	SELECT
		continent_name,
		MIN(row_num) AS row_num -- Extract the first instance of each continent when running_total exceeds $70,000
	FROM 
		( -- Begin subquery sub1
		SELECT
			ROW_NUMBER() OVER( -- Create a row number for each country, partitioned by continent
				PARTITION BY
					c3.continent_name
				ORDER BY
					continent_name, -- First order by continent name
					SUBSTRING(c1.country_name, 2, 4) DESC) AS row_num, -- Then order by characters 2-4, DESC
			c3.continent_name,
			p.country_code,
			c1.country_name,
			p.gdp_per_capita,
			SUM(p.gdp_per_capita) OVER( -- Create running_total column, partitioned by continent
				PARTITION BY
					c3.continent_name
				ORDER BY
					continent_name, -- First order by continent name
					SUBSTRING(c1.country_name, 2, 4) DESC) AS running_total -- Then order by characters 2-4, DESC
		FROM 
			per_capita AS p
			INNER JOIN countries AS c1
				ON p.country_code = c1.country_code
			INNER JOIN continent_map AS c2
				ON p.country_code = c2.country_code
			INNER JOIN continents AS c3
				ON c2.continent_code = c3.continent_code
		WHERE 
			year = 2009 -- Limit to gdp's in year 2009
		) AS sub1 -- End subquery sub1
	WHERE
		running_total >= 70000 -- Filter to only running totals that meet or exceed $70,000
	GROUP BY continent_name
	) AS sub2 -- End subquery sub2
INNER JOIN
	(
	SELECT
	ROW_NUMBER() OVER( -- Create a row number for each country, partitioned by continent
		PARTITION BY
			c3.continent_name
		ORDER BY
			continent_name, -- First order by continent name
			SUBSTRING(c1.country_name, 2, 4) DESC) AS row_num, -- Then order by characters 2-4, DESC
	c3.continent_name,
	p.country_code,
	c1.country_name,
	p.gdp_per_capita,
	SUM(p.gdp_per_capita) OVER( -- Create running_total column, partitioned by continent
		PARTITION BY
			c3.continent_name
		ORDER BY
			continent_name,
			SUBSTRING(c1.country_name, 2, 4) DESC) AS running_total -- Then order by characters 2-4, DESC
	FROM 
		per_capita AS p
		INNER JOIN countries AS c1
			ON p.country_code = c1.country_code
		INNER JOIN continent_map AS c2
			ON p.country_code = c2.country_code
		INNER JOIN continents AS c3
			ON c2.continent_code = c3.continent_code
	WHERE 
		year = 2009) AS sub3 -- Limit to gdp's in year 2009
	ON sub2.row_num = sub3.row_num -- Joining based on row_num of first instance of running_total exceeding $70,000
WHERE
	sub2.continent_name = sub3.continent_name; -- Limit table to accurately match instances with same continents

/* The question asked for this task to be accomplished in a single query, but I was not sure if CTEs can be used in single queries, so I left them out. The above query using subqueries and inner joins accomplished the task of executing everything in a single query, but if I were choosing how to do this myself, I would do it the below way using CTEs instead. It is most logical and takes up far fewer lines of code*/

-- Create CTE to join tables, add running_total column, and row numbers for each country, partitioned by continent
WITH cte AS
	(
	SELECT
		ROW_NUMBER() OVER( -- Create a row number for each country, partitioned by continent
			PARTITION BY
				c3.continent_name
			ORDER BY
				continent_name, -- First order by continent name
				SUBSTRING(c1.country_name, 2, 4) DESC) AS row_num, -- Then order by characters 2-4, DESC
		c3.continent_name,
		p.country_code,
		c1.country_name,
		p.gdp_per_capita,
		SUM(p.gdp_per_capita) OVER( -- Create running_total column, partitioned by continent
			PARTITION BY
				c3.continent_name
			ORDER BY
				continent_name, -- First order by continent name
				SUBSTRING(c1.country_name, 2, 4) DESC) AS running_total -- Then order by characters 2-4, DESC
	FROM 
		per_capita AS p
		INNER JOIN countries AS c1
			ON p.country_code = c1.country_code
		INNER JOIN continent_map AS c2
			ON p.country_code = c2.country_code
		INNER JOIN continents AS c3
			ON c2.continent_code = c3.continent_code
	WHERE 
		year = 2009 -- Limit to gdp's in year 2009
	),

-- Create CTE to extract first row number for each continent when running total exceeded $70,000
cte2 AS
	(
	SELECT
		MIN(row_num) AS row_num, -- Extract the first instance of each continent when running_total exceeds $70,000
		continent_name
	FROM 
		cte
	WHERE 
		running_total >= 70000 -- Filter to only running totals that meet or exceed $70,000
	GROUP BY 
		continent_name -- GROUP BY continent_name to get the first instance of running_total exceeding $70,000
	)

SELECT 
	cte.continent_name,
	cte.country_code,
	cte.country_name,
	CONCAT('$', CAST(ROUND(cte.gdp_per_capita, 2) AS DECIMAL(10,2))) AS gdp_per_capita, -- Format per instructions
	CONCAT('$', CAST(ROUND(cte.running_total, 2) AS DECIMAL(10,2))) AS running_total -- Format per instructions
FROM 
	cte
INNER JOIN cte2
	ON cte.row_num = cte2.row_num  -- Joining based on row_num of first instance of running_total exceeding $70,000
WHERE
	cte.continent_name = cte2.continent_name; -- Limit table to accurately match instances with same continents

/*7. Find the country with the highest average gdp_per_capita for each continent for all years. Now compare your list to the following data set. Please describe any and all mistakes that you can find with the data set below. Include any code that you use to help detect these mistakes.
	rank	continent_name	country_code	country_name	avg_gdp_per_capita
	1		Africa			SYC				Seychelles		$11,348.66
	1		Asia			KWT				Kuwait			$43,192.49
	1		Europe			MCO				Monaco			$152,936.10
	1		North America	BMU				Bermuda			$83,788.48
	1		Oceania			AUS				Australia		$47,070.39
	1		South America	CHL				Chile			$10,781.71*/

-- Create CTE to calculate the average GDP of each country across the years
WITH avg_per_capita AS
	(
	SELECT
		country_code,
		AVG(gdp_per_capita) AS avg_gdp_per_capita
	FROM
		per_capita
	GROUP BY
		country_code
	),

-- Create CTE to join average GDP CTE to the rest of the tables
cte AS
	(
	SELECT
		ROW_NUMBER() OVER(PARTITION BY c3.continent_name ORDER BY a.avg_gdp_per_capita DESC) AS rank_num, -- Rank each country by its average GDP, partitioned by continent
		c3.continent_name,
		a.country_code,
		c1.country_name,
		CONCAT('$', CAST(ROUND((a.avg_gdp_per_capita), 2) AS DECIMAL(10, 2))) AS avg_gdp_per_capita -- Format per instructions
	FROM
		avg_per_capita AS a
	INNER JOIN countries AS c1
		ON a.country_code = c1.country_code
	INNER JOIN continent_map AS c2
		ON a.country_code = c2.country_code
	INNER JOIN continents AS c3
		ON c2.continent_code = c3.continent_code
	)

-- Select the country with the highest GDP for each continent
SELECT *
FROM cte
WHERE rank_num = 1

/* The results of my query have different countries with highest average gdp's in Asia and Africa. According to my query, Equatorial Guinea and Qatar have the highest GDPs in Africa and Asia, respectively, but according to the problem, Seychelles and Kuwait have the highest GDPs. Additionally, the average GDPs for Monaco, Bermuda, and Australia differ from mine.*/

-- Quick manual check for any NULLs or other weird values for the relevant countries.
SELECT *
FROM 
	per_capita AS p
	INNER JOIN countries AS c1
		ON p.country_code = c1.country_code
	INNER JOIN continent_map AS c2
		ON p.country_code = c2.country_code
	INNER JOIN continents AS c3
		ON c2.continent_code = c3.continent_code
WHERE c1.country_name IN ('Seychelles', 'Kuwait', 'Equatorial Guinea', 'Qatar', 'Monaco', 'Bermuda', 'Australia')
ORDER by c1.country_name, year;
-- Only odd thing found was the NULL value for Monaco's gdp_per_capita in 2012

-- Modifying one of the CTEs from above to look at each country's average GDP
SELECT
	country_name,
	CONCAT('$', CAST(ROUND(AVG(gdp_per_capita), 2) AS DECIMAL(10, 2))) AS avg_gdp_per_capita
FROM per_capita
INNER JOIN countries
	ON per_capita.country_code = countries.country_code
WHERE countries.country_name IN ('Seychelles', 'Kuwait', 'Equatorial Guinea', 'Qatar', 'Monaco', 'Bermuda', 'Australia')
GROUP BY
	country_name;

/* According to these results, the average GDPs for Seychelles and Kuwait are $11,348.66 and $43,192.49, respectively. These values match the results of the problem data set, even if they are not actually higher than Equatorial Guinea and Qatar's average GDPs of $17,955.72 and $70,567.96, respectively.*/

-- Modifying the code for solving the problem to look at the average GDP of all African and Asian countries
WITH avg_per_capita AS
	(
	SELECT
		country_code,
		AVG(gdp_per_capita) AS avg_gdp_per_capita
	FROM
		per_capita
	GROUP BY
		country_code
	),

-- Create CTE to join average GDP CTE to the rest of the tables
cte AS
	(
	SELECT
		ROW_NUMBER() OVER(PARTITION BY c3.continent_name ORDER BY a.avg_gdp_per_capita DESC) AS rank_num, -- Rank each country by its average GDP, partitioned by continent
		c3.continent_name,
		a.country_code,
		c1.country_name,
		CONCAT('$', CAST(ROUND((a.avg_gdp_per_capita), 2) AS DECIMAL(10, 2))) AS avg_gdp_per_capita -- Format per instructions
	FROM
		avg_per_capita AS a
	INNER JOIN countries AS c1
		ON a.country_code = c1.country_code
	INNER JOIN continent_map AS c2
		ON a.country_code = c2.country_code
	INNER JOIN continents AS c3
		ON c2.continent_code = c3.continent_code
	)

-- Select the country with the highest GDP for each continent
SELECT *
FROM cte
WHERE continent_name IN ('Africa', 'Asia')
/*According to these results, Seychelles is the country in Africa with the second-highest average GDP ($11,348.66), which is the same as the GDP listed in the problem's data set. Also according to these results, Kuwait is the country in Asia with the third-highest average GDP ($43,192.49), which is the same as the GDP listed in the problem's data set.*/