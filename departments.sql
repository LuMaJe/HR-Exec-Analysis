WITH pay_rates AS (
  SELECT      -- calculating the pay rates per employee
    EmployeeID,
    COUNT(EmployeeID)-1 AS number_raises,
    MIN(Rate) AS Starting_rate,
    MAX(Rate) AS Current_rate
  FROM `tc-da-1.adwentureworks_db.employeepayhistory`
  GROUP BY EmployeeID
  ),

  depts AS (      --filtering out department changes of employees and matching employees to departments
    SELECT
      EmployeeID,
      Name
    FROM `tc-da-1.adwentureworks_db.employeedepartmenthistory` edhist
    JOIN `tc-da-1.adwentureworks_db.department` dept
    ON dept.DepartmentID = edhist.DepartmentID 
    WHERE EndDate IS NULL
    ),

  latest_date AS (      --assuming the date is 26th Jan 2005 (based on only using historical data)
    SELECT
      MAX(ModifiedDate) AS LatestDate
    FROM `tc-da-1.adwentureworks_db.employee`
    ),

  employees AS (      -- creating the final table of employees
  SELECT
    emp_add.EmployeeID,
    City,
    PostalCode,
    sp.Name AS State,
    CountryRegionCode,
    ManagerID,
    CASE WHEN emp.EmployeeID IN (SELECT ManagerID FROM `tc-da-1.adwentureworks_db.employee`) THEN 1 ELSE 0 END AS Is_manager, --labelling if the employee is a manager or not
    Title AS JobTitle,
    depts.Name AS Department,
    DATE(BirthDate) AS Birth_date,
    DATETIME_DIFF(DATE(LatestDate), BirthDate, Year) AS Age,    --can be considered 'current age'
    MaritalStatus,
    Gender,
    DATE(HireDate) AS Hire_date,
    EXTRACT(YEAR FROM DATE(HireDate)) AS Year_hired,
    DATETIME_DIFF(DATE(LatestDate), HireDate, Year) AS Years_at_company,
    SalariedFlag,
    VacationHours,
    SickLeaveHours,
    pr.number_raises,
    pr.Starting_rate,
    pr.Current_rate,
    (pr.Current_rate - pr.Starting_rate) / pr.Starting_rate * 100 AS pct_pay_change -- calculating pay increase since being at company
  FROM `tc-da-1.adwentureworks_db.employeeaddress` emp_add
  JOIN `tc-da-1.adwentureworks_db.address` add
  ON emp_add.AddressID = add.AddressID
  JOIN `tc-da-1.adwentureworks_db.stateprovince` sp
  ON add.StateProvinceID = sp.StateProvinceID
  JOIN `tc-da-1.adwentureworks_db.employee` emp
  ON emp.EmployeeId = emp_add.EmployeeID
  JOIN pay_rates pr
  ON pr.EmployeeID = emp.EmployeeId
  JOIN depts
  ON depts.EmployeeID = emp.EmployeeId
  , latest_date)

SELECT * FROM employees
  managers AS (       --finding pay rates for managers
    SELECT
      Department,
      AVG(Current_rate) AS avg_pay_rate,
      SUM(Current_rate) AS total_pay_rate,
    FROM employees
    WHERE Is_manager = 1
    GROUP BY Department
  ),

  teammates AS (      --finding pay rates for non-managers (teammates)
    SELECT
      Department,
      AVG(Current_rate) AS avg_pay_rate,
      SUM(Current_rate) AS total_pay_rate,
    FROM employees
    WHERE Is_manager = 0
    GROUP BY Department
  ),

  depts_agg AS (    -- aggregating by department
    SELECT
      emp.Department,
      COUNT(DISTINCT EmployeeID) As num_employees,
      AVG(Age) AS avg_age,
      APPROX_QUANTILES(Age, 100)[OFFSET (50)] AS median_age,
      AVG(VacationHours) AS avg_vacation,
      APPROX_QUANTILES(VacationHours, 100)[OFFSET (50)] AS median_vacation,
      AVG(SickLeaveHours) AS avg_sick_leave,
      APPROX_QUANTILES(SickLeaveHours, 100)[OFFSET (50)] AS median_sick_leave,
      SUM(VacationHours) / COUNT(DISTINCT EmployeeID) AS vacation_per_num_emp,
      SUM(SickLeaveHours) / COUNT(DISTINCT EmployeeID) AS sick_leave_per_num_emp, 
      COUNT(DISTINCT ManagerID) AS num_managers,
      COUNT(DISTINCT EmployeeID) / COUNT(DISTINCT ManagerID) AS emps_per_manager,
      AVG(Current_rate) AS avg_pay_rate,
      man.avg_pay_rate AS avg_manager_rate,
      man.total_pay_rate AS total_manager_rate,
      team.avg_pay_rate AS avg_team_rate,
      team.total_pay_rate AS total_team_rate
    FROM employees emp
    LEFT JOIN managers man          -- joining additional CTE's with pay rate data
    ON man.Department = emp.Department
    LEFT JOIN teammates team
    ON team.Department = emp.Department
    GROUP BY
      Department,
      avg_manager_rate,
      total_manager_rate,
      avg_team_rate,
      total_team_rate
  )

SELECT * FROM  depts_agg