-- SQLite
SELECT * 
FROM telco_customers 
LIMIT 5

## Churn Rate by Contract Type

SELECT
    Contract,
    ROUND(AVG(ChurnBinary) * 100, 2) AS ChurnRate,
    COUNT(customerID) AS CustomerCount
FROM telco_customers
GROUP BY Contract;

## Customer Risk Profile Distribution by Contract Type
Select
    Contract,
    Sum(
    Case
        When customer_risk_profile = 'High Risk' Then 1
        Else 0
    End) AS HighRiskCount,
    Sum(
    Case
        When customer_risk_profile = 'Medium Risk' Then 1
        Else 0
    End) AS MediumRiskCount,
    Sum(
    Case
        When customer_risk_profile = 'Loyal' Then 1
        Else 0
    End) AS LoyalCount
From telco_customers
Group By Contract;

## Revenue Analysis by Customer Risk Profile
WITH segment_summary AS (

    SELECT
        Customer_Risk_Profile,
        Round(AVG(MonthlyCharges), 2) AS AvgMonthlyCharge,
        Round(AVG(TotalCharges), 2) AS AvgTotalCharge,
        COUNT(customerID) AS CustomerCount

    FROM telco_customers

    GROUP BY Customer_Risk_Profile
)

SELECT
    Customer_Risk_Profile,
    AvgMonthlyCharge,
    AvgTotalCharge,
    CustomerCount,

    RANK() OVER (
        ORDER BY AvgTotalCharge DESC
    ) AS RevenueRank

FROM segment_summary; 

## Revenue Leakage by Risk Profile

Select
    Customer_Risk_Profile,
    Sum(MonthlyCharges) AS TotalRevenueLoss,
    Round(AVG(MonthlyCharges), 2) AS AvgRevenueLoss,
    COUNT(customerID) AS CustomerCount
From telco_customers
Where ChurnBinary = 1
Group By Customer_Risk_Profile
Order By TotalRevenueLoss DESC;

## Revenue Leakage by Contract
Select
    Contract,
    Sum(MonthlyCharges) AS TotalRevenueLoss,
    Round(AVG(MonthlyCharges), 2) AS AvgRevenueLoss,
    COUNT(customerID) AS CustomerCount
From telco_customers
Where ChurnBinary = 1
Group By Contract
Order By TotalRevenueLoss DESC;

## Revenue Leakage by Pricing Tier
Select
    MonthlyChargeGroup AS Pricing_Tier,
    Sum(MonthlyCharges) AS TotalRevenueLoss,
    Round(AVG(MonthlyCharges), 2) AS AvgRevenueLoss,
    COUNT(customerID) AS CustomerCount
From telco_customers
Where ChurnBinary = 1
Group By MonthlyChargeGroup
Order By TotalRevenueLoss DESC;

# Customer Value Segmentation
Select 
    Customer_Value_Segment,
    Round(AVG(totalcharges), 2) AS AvgTotalCharges,
    Count(customerID) AS CustomerCount
From (
Select 
customerID,
totalcharges,
Case
        When totalcharges > (
        SELECT AVG(totalcharges)
        FROM telco_customers) Then 'High Value'
        Else 'Standard Value'
        End AS Customer_Value_Segment
From telco_customers
) t
Group By Customer_Value_Segment;

## Customer Value Segmentation by Contract Type

WITH customer_value_cte AS (
    SELECT
        customerID,
        Contract,
        TotalCharges,
        ChurnBinary,
        CASE
            WHEN TotalCharges > (
                SELECT AVG(TotalCharges)
                FROM telco_customers
            )
            THEN 'High Value'
            ELSE 'Standard Value'
        END AS Customer_Value_Segment
    FROM telco_customers
)

SELECT
    Customer_Value_Segment,
    Contract,
    COUNT(customerID) AS CustomerCount,
    ROUND(AVG(TotalCharges), 2) AS AvgTotalCharges,
    ROUND(AVG(ChurnBinary) * 100, 2) AS ChurnRate
FROM customer_value_cte
GROUP BY
    Customer_Value_Segment,
    Contract
ORDER BY AvgTotalCharges DESC;

## Cohort/Lifecycle Style Analysis

Select tenuregroup,
    Count(customerID) AS CustomerCount,
    Round(AVG(MonthlyCharges), 2) AS AvgMonthlyCharges,
    Round(AVG(TotalCharges), 2) AS AvgTotalCharges,
    Round(AVG(ChurnBinary) * 100, 2) AS ChurnRate,
    Round(Avg(TotalServices), 2) AS AvgTotalServices
From telco_customers
Group By tenuregroup
Order By tenuregroup;

Select 
    Lifecycle_Segment,
    Count(customerID) AS CustomerCount,
    Round(AVG(MonthlyCharges), 2) AS AvgMonthlyCharges,
    Round(AVG(TotalCharges), 2) AS AvgTotalCharges,
    Round(AVG(ChurnBinary) * 100, 2) AS ChurnRate,
    Round(Avg(TotalServices), 2) AS AvgTotalServices
From (
    Select 
        customerID,
        MonthlyCharges,
        TotalCharges,
        ChurnBinary,
        TotalServices,
        Case
            When tenuregroup = '0-12 Months' And ChurnBinary = 1 then 'Early Churner'
            When tenuregroup = '49+ Months' And ChurnBinary = 0 then 'Loyal Customer'
    Else 'Other'
End AS Lifecycle_Segment
    From telco_customers
) t
WHERE Lifecycle_Segment != 'Other'
Group By Lifecycle_Segment
Order By Lifecycle_Segment;

##Retention_Priority_Segment

With base as (
Select
    customer_risk_profile,
    Count(customerID) AS CustomerCount,
    Round(AVG(MonthlyCharges), 2) AS AvgMonthlyCharges,
    Round(AVG(TotalCharges), 2) AS AvgTotalCharges,
    Round(AVG(ChurnBinary) * 100, 2) AS ChurnRate,
    Round(Avg(TotalServices), 2) AS AvgTotalServices,
    Case
                When TotalCharges > (
                    SELECT AVG(TotalCharges)
                    FROM telco_customers
                )
                THEN 'High Value'
                ELSE 'Standard Value'
            END AS customer_value_segment
    From telco_customers
    GROUP BY
    customer_risk_profile,
    customer_value_segment
    )

    Select 
    customer_risk_profile,
    customer_value_segment,
    CustomerCount,
    AvgMonthlyCharges,
    AvgTotalCharges,
    ChurnRate,
    AvgTotalServices,
    Case
        When customer_risk_profile = 'High Risk' And customer_value_segment = 'High Value' Then 'Critical Retention Priority'
        When customer_risk_profile = 'Medium Risk' And customer_value_segment = 'Standard Value' Then 'Growth Opportunity'
        When customer_risk_profile = 'Loyal' And customer_value_segment = 'High Value' Then 'Stable High Value'
        Else 'Low Priority'
    End AS Retention_Priority_Segment
    From base
    Order By ChurnRate DESC;
