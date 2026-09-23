1) -- How many total requests are in the system?

SELECT COUNT(*) AS Total_Requests
FROM Requests;

2)-- How many decisions, revisions, follow-ups and escalations were recorded?

SELECT 'Decisions' AS Activity, COUNT(*) AS Total
FROM Decisions

UNION ALL

SELECT 'Revisions', COUNT(*)
FROM Decision_Revisions

UNION ALL

SELECT 'Follow-ups', COUNT(*)
FROM Followup_Actions

UNION ALL

SELECT 'Escalations', COUNT(*)
FROM Escalations;

3) -- Which request types receive the highest number of requests?

SELECT
    rt.RequestTypeName,
    COUNT(*) AS RequestCount
FROM Requests r
JOIN Request_Types rt
    ON r.RequestTypeID = rt.RequestTypeID
GROUP BY rt.RequestTypeName
ORDER BY RequestCount DESC;

4) -- Which priority level generates the most requests?

SELECT
    Priority,
    COUNT(*) AS RequestCount
FROM Requests
GROUP BY Priority
ORDER BY RequestCount DESC;

5) -- What percentage of requests required a decision revision?

SELECT
    CAST(
        COUNT(DISTINCT dr.RequestID) * 100.0
        / COUNT(DISTINCT d.RequestID)
        AS DECIMAL(10,2)
    ) AS RevisionRate
FROM Decisions d
LEFT JOIN Decision_Revisions dr
    ON d.RequestID = dr.RequestID;

6) -- What are the most common reasons for decision revisions?

SELECT
    RevisionReason,
    COUNT(*) AS RevisionCount
FROM Decision_Revisions
GROUP BY RevisionReason
ORDER BY RevisionCount DESC;

7) -- Which decision transitions occur most frequently?

SELECT
    PreviousDecision,
    NewDecision,
    COUNT(*) AS TransitionCount
FROM Decision_Revisions
WHERE PreviousDecision <> NewDecision
GROUP BY
    PreviousDecision,
    NewDecision
ORDER BY TransitionCount DESC;

8)-- Which request types have the highest revision rate?

SELECT
    rt.RequestTypeName,

    COUNT(DISTINCT r.RequestID) AS TotalRequests,

    COUNT(DISTINCT dr.RequestID) AS RevisedRequests,

    CAST(
        COUNT(DISTINCT dr.RequestID) * 100.0
        / COUNT(DISTINCT r.RequestID)
        AS DECIMAL(10,2)
    ) AS RevisionRate

FROM Requests r

JOIN Request_Types rt
    ON r.RequestTypeID = rt.RequestTypeID

LEFT JOIN Decision_Revisions dr
    ON r.RequestID = dr.RequestID

GROUP BY rt.RequestTypeName

ORDER BY RevisionRate DESC;

9) -- Which requests have gone through multiple decision revisions?

WITH DecisionCycles AS
(
    SELECT
        RequestID,
        COUNT(*) AS RevisionCount
    FROM Decision_Revisions
    GROUP BY RequestID
)

SELECT
    RequestID,
    RevisionCount
FROM DecisionCycles
WHERE RevisionCount > 1
ORDER BY RevisionCount DESC;

10) -- Which request types generate the most follow-up workload?

SELECT
    rt.RequestTypeName,

    COUNT(DISTINCT r.RequestID) AS TotalRequests,

    COUNT(fa.ActionID) AS TotalFollowups,

    CAST(
        COUNT(fa.ActionID) * 1.0
        / COUNT(DISTINCT r.RequestID)
        AS DECIMAL(10,2)
    ) AS AvgFollowupsPerRequest

FROM Requests r

JOIN Request_Types rt
    ON r.RequestTypeID = rt.RequestTypeID

LEFT JOIN Followup_Actions fa
    ON r.RequestID = fa.RequestID

GROUP BY rt.RequestTypeName

ORDER BY AvgFollowupsPerRequest DESC;

11) -- Which departments have the highest escalation volume?

SELECT
    dp.DepartmentName,
    COUNT(es.EscalationID) AS EscalationCount
FROM Escalations es
JOIN Departments dp
    ON es.EscalatedToDepartmentID = dp.DepartmentID
GROUP BY dp.DepartmentName
ORDER BY EscalationCount DESC;

12) -- Rank employees based on number of decisions handled

WITH EmployeeWorkload AS
(
    SELECT
        e.EmployeeID,
        e.EmployeeName,
        e.RoleName,
        COUNT(d.DecisionID) AS DecisionsHandled
    FROM Employees e
    LEFT JOIN Decisions d
        ON e.EmployeeID = d.EmployeeID
    GROUP BY
        e.EmployeeID,
        e.EmployeeName,
        e.RoleName
)

SELECT
    EmployeeID,
    EmployeeName,
    RoleName,
    DecisionsHandled,

    RANK() OVER
    (
        ORDER BY DecisionsHandled DESC
    ) AS WorkloadRank

FROM EmployeeWorkload
ORDER BY WorkloadRank;

13) -- Calculate monthly request volume and month-over-month change?

WITH MonthlyRequests AS
(
    SELECT
        DATEFROMPARTS(
            YEAR(CreatedDate),
            MONTH(CreatedDate),
            1
        ) AS RequestMonth,

        COUNT(*) AS RequestCount

    FROM Requests

    GROUP BY
        YEAR(CreatedDate),
        MONTH(CreatedDate)
)

SELECT
    RequestMonth,
    RequestCount,

    LAG(RequestCount) OVER
    (
        ORDER BY RequestMonth
    ) AS PreviousMonthRequests,

    RequestCount
    -
    LAG(RequestCount) OVER
    (
        ORDER BY RequestMonth
    ) AS MoMChange

FROM MonthlyRequests
ORDER BY RequestMonth;

14) -- What is the Decision Debt Score for every request?

WITH DebtCalculation AS
(
    SELECT
        r.RequestID,

        COUNT(DISTINCT dr.RevisionID) AS RevisionCount,

        COUNT(DISTINCT fa.ActionID) AS FollowupCount,

        COUNT(DISTINCT es.EscalationID) AS EscalationCount

    FROM Requests r

    LEFT JOIN Decision_Revisions dr
        ON r.RequestID = dr.RequestID

    LEFT JOIN Followup_Actions fa
        ON r.RequestID = fa.RequestID

    LEFT JOIN Escalations es
        ON r.RequestID = es.RequestID

    GROUP BY r.RequestID
)

SELECT
    RequestID,
    RevisionCount,
    FollowupCount,
    EscalationCount,

    (RevisionCount * 2)
    + FollowupCount
    + (EscalationCount * 2)
    AS DecisionDebtScore

FROM DebtCalculation
ORDER BY DecisionDebtScore DESC;

15) -- Which request types have the highest total Decision Debt?

WITH DebtCalculation AS
(
    SELECT
        r.RequestID,
        r.RequestTypeID,

        COUNT(DISTINCT dr.RevisionID) AS RevisionCount,
        COUNT(DISTINCT fa.ActionID) AS FollowupCount,
        COUNT(DISTINCT es.EscalationID) AS EscalationCount

    FROM Requests r

    LEFT JOIN Decision_Revisions dr
        ON r.RequestID = dr.RequestID

    LEFT JOIN Followup_Actions fa
        ON r.RequestID = fa.RequestID

    LEFT JOIN Escalations es
        ON r.RequestID = es.RequestID

    GROUP BY
        r.RequestID,
        r.RequestTypeID
)

SELECT
    rt.RequestTypeName,

    COUNT(*) AS TotalRequests,

    SUM(RevisionCount) AS TotalRevisions,

    SUM(FollowupCount) AS TotalFollowups,

    SUM(EscalationCount) AS TotalEscalations,

    SUM(
        RevisionCount * 2
        + FollowupCount
        + EscalationCount * 2
    ) AS TotalDecisionDebt

FROM DebtCalculation dc

JOIN Request_Types rt
    ON dc.RequestTypeID = rt.RequestTypeID

GROUP BY rt.RequestTypeName

ORDER BY TotalDecisionDebt DESC;

16) -- Which requests require leadership attention?

WITH DebtCalculation AS
(
    SELECT
        r.RequestID,

        COUNT(DISTINCT dr.RevisionID) AS RevisionCount,
        COUNT(DISTINCT fa.ActionID) AS FollowupCount,
        COUNT(DISTINCT es.EscalationID) AS EscalationCount

    FROM Requests r

    LEFT JOIN Decision_Revisions dr
        ON r.RequestID = dr.RequestID

    LEFT JOIN Followup_Actions fa
        ON r.RequestID = fa.RequestID

    LEFT JOIN Escalations es
        ON r.RequestID = es.RequestID

    GROUP BY r.RequestID
)

SELECT
    RequestID,
    RevisionCount,
    FollowupCount,
    EscalationCount,

    RevisionCount * 2
    + FollowupCount
    + EscalationCount * 2
    AS DecisionDebtScore

FROM DebtCalculation

WHERE
    RevisionCount * 2
    + FollowupCount
    + EscalationCount * 2 >= 8

ORDER BY DecisionDebtScore DESC;

17) -- Which departments generate the highest Decision Debt?

WITH DebtCalculation AS
(
    SELECT
        r.RequestID,
        e.DepartmentID,

        COUNT(DISTINCT dr.RevisionID) AS RevisionCount,
        COUNT(DISTINCT fa.ActionID) AS FollowupCount,
        COUNT(DISTINCT es.EscalationID) AS EscalationCount

    FROM Requests r

    JOIN Decisions d
        ON r.RequestID = d.RequestID

    JOIN Employees e
        ON d.EmployeeID = e.EmployeeID

    LEFT JOIN Decision_Revisions dr
        ON r.RequestID = dr.RequestID

    LEFT JOIN Followup_Actions fa
        ON r.RequestID = fa.RequestID

    LEFT JOIN Escalations es
        ON r.RequestID = es.RequestID

    GROUP BY
        r.RequestID,
        e.DepartmentID
)

SELECT
    dp.DepartmentName,

    COUNT(*) AS RequestsHandled,

    SUM(RevisionCount) AS Revisions,

    SUM(FollowupCount) AS Followups,

    SUM(EscalationCount) AS Escalations,

    SUM(
        RevisionCount * 2
        + FollowupCount
        + EscalationCount * 2
    ) AS TotalDecisionDebt

FROM DebtCalculation dc

JOIN Departments dp
    ON dc.DepartmentID = dp.DepartmentID

GROUP BY dp.DepartmentName

ORDER BY TotalDecisionDebt DESC;

18) -- Are revised requests associated with more escalations?

WITH RequestMetrics AS
(
    SELECT
        r.RequestID,

        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM Decision_Revisions dr
                WHERE dr.RequestID = r.RequestID
            )
            THEN 1
            ELSE 0
        END AS HasRevision,

        CASE
            WHEN EXISTS
            (
                SELECT 1
                FROM Escalations es
                WHERE es.RequestID = r.RequestID
            )
            THEN 1
            ELSE 0
        END AS HasEscalation

    FROM Requests r
)

SELECT
    HasRevision,
    COUNT(*) AS TotalRequests,

    SUM(HasEscalation) AS EscalatedRequests,

    CAST(
        SUM(HasEscalation) * 100.0
        / COUNT(*)
        AS DECIMAL(10,2)
    ) AS EscalationRate

FROM RequestMetrics

GROUP BY HasRevision;

19) -- Build a complete management-level dataset?

WITH DebtCalculation AS
(
    SELECT
        r.RequestID,
        r.CustomerID,
        r.RequestTypeID,
        r.Priority,
        r.Channel,

        COUNT(DISTINCT dr.RevisionID) AS RevisionCount,

        COUNT(DISTINCT fa.ActionID) AS FollowupCount,

        COUNT(DISTINCT es.EscalationID) AS EscalationCount

    FROM Requests r

    LEFT JOIN Decision_Revisions dr
        ON r.RequestID = dr.RequestID

    LEFT JOIN Followup_Actions fa
        ON r.RequestID = fa.RequestID

    LEFT JOIN Escalations es
        ON r.RequestID = es.RequestID

    GROUP BY
        r.RequestID,
        r.CustomerID,
        r.RequestTypeID,
        r.Priority,
        r.Channel
)

SELECT
    dc.RequestID,

    c.CustomerSegment,
    c.Region,

    rt.RequestTypeName,

    dc.Priority,
    dc.Channel,

    dc.RevisionCount,
    dc.FollowupCount,
    dc.EscalationCount,

    dc.RevisionCount * 2
    + dc.FollowupCount
    + dc.EscalationCount * 2
    AS DecisionDebtScore,

    CASE
        WHEN
            dc.RevisionCount * 2
            + dc.FollowupCount
            + dc.EscalationCount * 2 >= 8
        THEN 'Leadership Attention'

        WHEN
            dc.RevisionCount * 2
            + dc.FollowupCount
            + dc.EscalationCount * 2 >= 4
        THEN 'Monitor'

        ELSE 'Normal'
    END AS AttentionLevel

FROM DebtCalculation dc

JOIN Customers c
    ON dc.CustomerID = c.CustomerID

JOIN Request_Types rt
    ON dc.RequestTypeID = rt.RequestTypeID

ORDER BY DecisionDebtScore DESC;

20) -- Final Executive KPI Query

WITH RequestMetrics AS
(
    SELECT
        r.RequestID,

        COUNT(DISTINCT dr.RevisionID) AS RevisionCount,

        COUNT(DISTINCT fa.ActionID) AS FollowupCount,

        COUNT(DISTINCT es.EscalationID) AS EscalationCount

    FROM Requests r

    LEFT JOIN Decision_Revisions dr
        ON r.RequestID = dr.RequestID

    LEFT JOIN Followup_Actions fa
        ON r.RequestID = fa.RequestID

    LEFT JOIN Escalations es
        ON r.RequestID = es.RequestID

    GROUP BY r.RequestID
)

SELECT

    COUNT(*) AS TotalRequests,

    SUM(
        CASE
            WHEN RevisionCount > 0 THEN 1
            ELSE 0
        END
    ) AS RevisedRequests,

    CAST(
        SUM(
            CASE
                WHEN RevisionCount > 0 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*)
        AS DECIMAL(10,2)
    ) AS RevisionRate,

    SUM(
        CASE
            WHEN EscalationCount > 0 THEN 1
            ELSE 0
        END
    ) AS EscalatedRequests,

    CAST(
        SUM(
            CASE
                WHEN EscalationCount > 0 THEN 1
                ELSE 0
            END
        ) * 100.0 / COUNT(*)
        AS DECIMAL(10,2)
    ) AS EscalationRate,

    SUM(
        RevisionCount * 2
        + FollowupCount
        + EscalationCount * 2
    ) AS TotalDecisionDebt,

    CAST(
        AVG(
            RevisionCount * 2
            + FollowupCount
            + EscalationCount * 2
        )
        AS DECIMAL(10,2)
    ) AS AverageDecisionDebt

FROM RequestMetrics;



