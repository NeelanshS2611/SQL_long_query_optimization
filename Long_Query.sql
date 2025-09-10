USE practise_quest;

DROP TABLE IF EXISTS employees;

-- Employees table to get employee information
CREATE TABLE employees (
    employee_id INT PRIMARY KEY,
    name VARCHAR(10) NOT NULL,
    join_date DATE NOT NULL,
    department VARCHAR(10) NOT NULL
);

INSERT INTO employees (employee_id, name, join_date, department)
VALUES
    (1, 'Alice', '2018-06-15', 'IT'),
    (2, 'Bob', '2019-02-10', 'Finance'),
    (3, 'Charlie', '2017-09-20', 'HR'),
    (4, 'David', '2020-01-05', 'IT'),
    (5, 'Eve', '2016-07-30', 'Finance'),
    (6, 'Sumit', '2016-06-30', 'Finance');
    
    
-- Salary_history table to track salary chnages and promotions
CREATE TABLE salary_history (
    employee_id INT,
    change_date DATE NOT NULL,
    salary DECIMAL(10,2) NOT NULL,
    promotion VARCHAR(3)
);

INSERT INTO salary_history (employee_id, change_date, salary, promotion)
VALUES
    (1, '2018-06-15', 50000, 'No'),
    (1, '2019-08-20', 55000, 'No'),
    (1, '2021-02-10', 70000, 'Yes'),
    (2, '2019-02-10', 48000, 'No'),
    (2, '2020-05-15', 52000, 'Yes'),
    (2, '2023-01-25', 68000, 'Yes'),
    (3, '2017-09-20', 60000, 'No'),
    (3, '2019-12-10', 65000, 'No'),
    (3, '2022-06-30', 72000, 'Yes'),
    (4, '2020-01-05', 45000, 'No'),
    (4, '2021-07-18', 49000, 'No'),
    (5, '2016-07-30', 55000, 'No'),
    (5, '2018-11-22', 62000, 'Yes'),
    (5, '2021-09-10', 75000, 'Yes'),
    (6, '2016-06-30', 55000, 'No'),
    (6, '2017-11-22', 50000, 'No'),
    (6, '2018-11-22', 40000, 'No'),
    (6, '2021-09-10', 75000, 'Yes');

/*    
1. Find the latest salary for each employee.
2. Calculate the total number of promotions each employee has received.
3. Determie the maximum salsry hike percentage between two consecutive salary chnages for each employee
4. identify employees whose salary has never decreased overtime.
5. Find the average time(in months) between salary chnages for each employee
6. Rank employees by their salary growth rate (From first to last recorded salary), breaking ties by earliest join date.

Combine all the results into one output
*/

-- GENERAL Query
With cte as 
(
SELECT *, RANK() OVER(partition by employee_id order by change_date desc) as rnk_desc,
RANK() OVER(partition by employee_id order by change_date asc) as rnk_asc
FROM salary_history
),
latest_salary as
(
SELECT employee_id, salary as latest_salary
FROM cte
WHERE rnk_desc = 1
),
promotion_count as 
(
SELECT employee_id, count(*) as no_of_promotion
FROM cte
WHERE promotion = 'Yes'
GROUP BY employee_id
),
previous_salary_cte as
( 
SELECT *,
LEAD(salary,1) OVER(Partition by employee_id order by change_date desc) as previous_salary,
LEAD(change_date,1) OVER(Partition by employee_id order by change_date desc) as previous_change_date
FROM cte 
),
hike_percentage as
(
SELECT employee_id, max(ROUND(((salary-previous_salary)/previous_salary)*100,2)) as max_hike_percentage
FROM previous_salary_cte
group by employee_id
),
salary_decreased as
(
SELECT distinct(employee_id), 'N' as never_decreased
FROM previous_salary_cte
WHERE salary< previous_salary
),
average_months as
(
SELECT employee_id, round(AVG(timestampdiff(MONTH,previous_change_date,change_date)),2) as avg_month_between_changes
FROM previous_salary_cte
GROUP BY employee_id
),
 salary_growth as
(
SELECT employee_id,
MAX(CASE WHEN rnk_desc = 1 then salary end )/ MAX(CASE WHEN rnk_asc = 1 then salary end) as salary_growth_ratio,
MIN(change_date) as join_date
FROM cte
GROUP BY employee_id
),
salary_growth_rank as
(SELECT *,
RANK() OVER(ORDER BY salary_growth_ratio desc, join_date asc) as RankByGrowth
FROM salary_growth
)

SELECT e.employee_id, e.name, 
s.latest_salary, 
coalesce(p.no_of_promotion,0) as no_of_promotion, 
h.max_hike_percentage, 
coalesce(sd.never_decreased, 'Y') as salary_not_decreased,
a.avg_month_between_changes,
g.RankByGrowth
FROM employees as e
LEFT JOIN latest_salary as s ON e.employee_id =  s.employee_id
LEFT JOIN promotion_count as p on e.employee_id =  p.employee_id
LEFT JOIN hike_percentage as h on e.employee_id =  h.employee_id
LEFT JOIN salary_decreased as sd on e.employee_id =  sd.employee_id
LEFT JOIN average_months as a on e.employee_id =  a.employee_id
LEFT JOIN salary_growth_rank as g on e.employee_id =  g.employee_id
order by e.employee_id;

-- Optimized Query 
With cte as 
(
SELECT *, RANK() OVER(partition by employee_id order by change_date desc) as rnk_desc,
RANK() OVER(partition by employee_id order by change_date asc) as rnk_asc,
LEAD(salary,1) OVER(Partition by employee_id order by change_date desc) as previous_salary,
LEAD(change_date,1) OVER(Partition by employee_id order by change_date desc) as previous_change_date
FROM salary_history
),
salary_growth as
(
SELECT employee_id,
MAX(CASE WHEN rnk_desc = 1 then salary end )/ MAX(CASE WHEN rnk_asc = 1 then salary end) as salary_growth_ratio,
MIN(change_date) as join_date
FROM cte
GROUP BY employee_id
)
SELECT cte.employee_id, e.name,
MAX(CASE WHEN rnk_desc=1 THEN salary end )as latest_salary,
count(CASE WHEN promotion = 'Yes' then promotion end) as no_of_promotions,
max(ROUND(((salary-previous_salary)/previous_salary)*100,2)) as max_hike_percentage,
case when MAX(CASE WHEN salary < previous_salary then 1 else 0 end) = 0 then 'Y' else 'N' end as salary_never_decreased,
round(AVG(timestampdiff(MONTH,previous_change_date,change_date)),2) as avg_month_between_changes,
RANK() OVER(ORDER BY sg.salary_growth_ratio desc, sg.join_date asc) as RankByGrowth
FROM cte
Inner join salary_growth sg ON cte.employee_id = sg.employee_id
INNER JOIN employees as e ON cte.employee_id = e.employee_id
GROUP BY cte.employee_id, e.name
ORDER BY cte.employee_id;
