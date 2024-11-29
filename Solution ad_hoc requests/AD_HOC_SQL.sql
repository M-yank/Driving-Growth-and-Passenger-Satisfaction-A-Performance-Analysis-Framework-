#Business Request 1
select count(*) from fact_trips; #total trips
select #fare per km
sum(fare_amount)/ sum(distance_travelled_km)
from fact_trips
where distance_travelled_km>0;
select sum(fare_amount)/ count(trip_id)
from fact_trips; #fare per trip
SELECT 
    dc.city_name,
    COUNT(ft.trip_id) AS total_trips,
    (COUNT(ft.trip_id)*100 / (SELECT COUNT(*) FROM fact_trips)) AS contribution_to_total_trips
FROM 
    fact_trips ft
JOIN 
    dim_city dc
ON 
    ft.city_id = dc.city_id
GROUP BY 
    dc.city_name
ORDER BY 
    contribution_to_total_trips DESC; #city contribution

SELECT 
    dc.city_name AS City,
    COUNT(ft.trip_id) AS Total_Trips,
    AVG(ft.fare_amount / ft.distance_travelled_km) AS Avg_Fare_Per_Km,
    AVG(ft.fare_amount) AS Avg_Fare_Per_Trip,
    (COUNT(ft.trip_id) * 100.0 / (SELECT COUNT(*) FROM fact_trips)) AS Contribution_To_Total_Trips_Percentage
FROM 
    fact_trips ft
JOIN 
    dim_city dc
ON 
    ft.city_id = dc.city_id
GROUP BY 
    dc.city_name
ORDER BY 
    Total_Trips DESC;
    
    #Business Request 2
WITH ActualTrips AS (
    
    SELECT 
        dc.city_name,
        dd.start_of_month,
        COUNT(ft.trip_id) AS actual_trips,
        ft.city_id
    FROM 
        trips_db.fact_trips ft
    JOIN 
        trips_db.dim_date dd 
    ON 
        ft.date = dd.date
    JOIN 
        trips_db.dim_city dc
    ON 
        ft.city_id = dc.city_id
    GROUP BY 
        dc.city_name, dd.start_of_month, ft.city_id
),
TargetTrips AS (

    SELECT 
        mt.city_id,
        mt.month AS start_of_month,
        mt.total_target_trips
    FROM 
        targets_db.monthly_target_trips mt
),
PerformanceReport AS (
  
    SELECT 
        at.city_name,
        at.city_id,
        SUM(at.actual_trips) AS actual_trips,
        SUM(tt.total_target_trips) AS total_target_trips,
        CASE 
            WHEN SUM(at.actual_trips) > SUM(tt.total_target_trips) THEN 'Above Target'
            ELSE 'Below Target'
        END AS overall_performance_status,
        AVG((at.actual_trips - tt.total_target_trips) * 100.0 / tt.total_target_trips) AS avg_percent_difference
    FROM 
        ActualTrips at
    LEFT JOIN 
        TargetTrips tt
    ON 
        at.city_id = tt.city_id AND at.start_of_month = tt.start_of_month
    GROUP BY 
        at.city_name, at.city_id
)

SELECT 
    city_name,
    actual_trips,
    total_target_trips,
    overall_performance_status,
    ROUND(avg_percent_difference, 2) AS avg_percent_difference
FROM 
    PerformanceReport
ORDER BY 
    city_name;


#Business Request 3
WITH CleanedData AS (
    -- Step 1: Clean `trip_count` to extract numeric values
    SELECT 
        dct.city_name,
        drt.city_id,
        drt.repeat_passenger_count,
        CAST(REPLACE(trip_count, '-trips', '') AS UNSIGNED) AS trip_count
    FROM 
        dim_repeat_trip_distribution drt
    JOIN 
        dim_city dct
    ON 
        drt.city_id = dct.city_id
),
PercentageDistribution AS (
    -- Step 2: Calculate the total repeat passengers and percentage distribution
    SELECT 
        city_name,
        trip_count,
        SUM(repeat_passenger_count) AS passenger_count,
        (SUM(repeat_passenger_count) * 100.0 / SUM(SUM(repeat_passenger_count)) 
         OVER (PARTITION BY city_name)) AS percentage_distribution
    FROM 
        CleanedData
    GROUP BY 
        city_name, trip_count
)
-- Step 3: Pivot the data to display `trip_count` categories as columns
SELECT 
    city_name,
    ROUND(MAX(CASE WHEN trip_count = 2 THEN percentage_distribution END), 2) AS "2_Trips",
    ROUND(MAX(CASE WHEN trip_count = 3 THEN percentage_distribution END), 2) AS "3_Trips",
    ROUND(MAX(CASE WHEN trip_count = 4 THEN percentage_distribution END), 2) AS "4_Trips",
    ROUND(MAX(CASE WHEN trip_count = 5 THEN percentage_distribution END), 2) AS "5_Trips",
    ROUND(MAX(CASE WHEN trip_count = 6 THEN percentage_distribution END), 2) AS "6_Trips",
    ROUND(MAX(CASE WHEN trip_count = 7 THEN percentage_distribution END), 2) AS "7_Trips",
    ROUND(MAX(CASE WHEN trip_count = 8 THEN percentage_distribution END), 2) AS "8_Trips",
    ROUND(MAX(CASE WHEN trip_count = 9 THEN percentage_distribution END), 2) AS "9_Trips",
    ROUND(MAX(CASE WHEN trip_count = 10 THEN percentage_distribution END), 2) AS "10_Trips"
FROM 
    PercentageDistribution
GROUP BY 
    city_name
ORDER BY 
    city_name;

#Business Request 4.1
WITH CityPassengerSummary AS (
    -- Step 1: Calculate total new passengers for each city
    SELECT 
        dc.city_name,
        SUM(fps.new_passengers) AS total_new_passengers
    FROM 
        fact_passenger_summary fps
    JOIN 
        dim_city dc
    ON 
        fps.city_id = dc.city_id
    GROUP BY 
        dc.city_name
),
RankedCities AS (
    -- Step 2: Rank cities based on total new passengers
    SELECT 
        city_name,
        total_new_passengers,
        RANK() OVER (ORDER BY total_new_passengers DESC) AS city_rank
    FROM 
        CityPassengerSummary
)
-- Step 3: Identify the top 3 cities
SELECT 
    city_name,
    total_new_passengers,
    CASE 
        WHEN city_rank <= 3 THEN 'Top 3'
        ELSE NULL
    END AS city_category
FROM 
    RankedCities
ORDER BY 
    city_rank;

#Business Request 4.2
WITH CityPassengerSummary AS (
    -- Step 1: Calculate total new passengers for each city
    SELECT 
        dc.city_name,
        SUM(fps.new_passengers) AS total_new_passengers
    FROM 
        fact_passenger_summary fps
    JOIN 
        dim_city dc
    ON 
        fps.city_id = dc.city_id
    GROUP BY 
        dc.city_name
),
RankedCities AS (
    -- Step 2: Rank cities by total new passengers in ascending order
    SELECT 
        city_name,
        total_new_passengers,
        RANK() OVER (ORDER BY total_new_passengers ASC) AS city_rank
    FROM 
        CityPassengerSummary
)
-- Step 3: Filter for bottom 3 cities and assign the "Bottom 3" category
SELECT 
    city_name,
    total_new_passengers,
    'Bottom 3' AS city_category
FROM 
    RankedCities
WHERE 
    city_rank <= 3
ORDER BY 
    total_new_passengers ASC;

#Business Request 5
WITH MonthlyRevenue AS (
    -- Step 1: Calculate total fare amount for each city and month
    SELECT 
        dc.city_name,
        dd.month_name AS revenue_month,
        SUM(ft.fare_amount) AS monthly_revenue
    FROM 
        fact_trips ft
    JOIN 
        dim_city dc
    ON 
        ft.city_id = dc.city_id
    JOIN 
        dim_date dd
    ON 
        ft.date = dd.date
    GROUP BY 
        dc.city_name, dd.month_name
),
CityTotalRevenue AS (
    -- Step 2: Calculate total revenue for each city
    SELECT 
        city_name,
        SUM(monthly_revenue) AS total_revenue
    FROM 
        MonthlyRevenue
    GROUP BY 
        city_name
),
HighestRevenueMonth AS (
    -- Step 3: Identify the month with the highest revenue for each city
    SELECT 
        mr.city_name,
        mr.revenue_month AS highest_revenue_month,
        mr.monthly_revenue AS highest_revenue,
        ctr.total_revenue,
        (mr.monthly_revenue * 100.0 / ctr.total_revenue) AS percentage_contribution
    FROM 
        MonthlyRevenue mr
    JOIN 
        CityTotalRevenue ctr
    ON 
        mr.city_name = ctr.city_name
    WHERE 
        mr.monthly_revenue = (
            SELECT 
                MAX(monthly_revenue)
            FROM 
                MonthlyRevenue
            WHERE 
                city_name = mr.city_name
        )
)
-- Step 4: Final selection of fields
SELECT 
    city_name,
    highest_revenue_month,
    highest_revenue AS revenue,
    ROUND(percentage_contribution, 2) AS percentage_contribution
FROM 
    HighestRevenueMonth
ORDER BY 
    city_name;

#Business Request 6
WITH MonthlyRepeatRate AS (
    -- Step 1: Calculate total passengers and repeat passengers for each city and month
    SELECT 
        dc.city_name,
        dd.month_name,
        SUM(fps.total_passengers) AS total_passengers,
        SUM(fps.repeat_passengers) AS repeat_passengers
    FROM 
        fact_passenger_summary fps
    JOIN 
        dim_city dc
    ON 
        fps.city_id = dc.city_id
    JOIN 
        dim_date dd
    ON 
        fps.month = dd.start_of_month
    GROUP BY 
        dc.city_name, dd.month_name
),
CityTotalRepeatRate AS (
    -- Step 2: Calculate the total repeat passenger rate across all months for each city
    SELECT 
        dc.city_name,
        SUM(fps.total_passengers) AS city_total_passengers,
        SUM(fps.repeat_passengers) AS city_repeat_passengers
    FROM 
        fact_passenger_summary fps
    JOIN 
        dim_city dc
    ON 
        fps.city_id = dc.city_id
    GROUP BY 
        dc.city_name
)
-- Step 3: Combine both metrics and calculate repeat passenger rates
SELECT 
    mrr.city_name,
    mrr.month_name AS month,
    mrr.total_passengers,
    mrr.repeat_passengers,
    ROUND((mrr.repeat_passengers * 100.0) / NULLIF(mrr.total_passengers, 0), 2) AS monthly_repeat_passenger_rate,
    ROUND((ctr.city_repeat_passengers * 100.0) / NULLIF(ctr.city_total_passengers, 0), 2) AS city_repeat_passenger_rate
FROM 
    MonthlyRepeatRate mrr
JOIN 
    CityTotalRepeatRate ctr
ON 
    mrr.city_name = ctr.city_name
ORDER BY 
    mrr.city_name;
    


