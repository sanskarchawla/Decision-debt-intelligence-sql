
CREATE TABLE Departments
(
    DepartmentID INT PRIMARY KEY,
    DepartmentName VARCHAR(100) NOT NULL
);
GO

CREATE TABLE Request_Types
(
    RequestTypeID INT PRIMARY KEY,
    RequestTypeName VARCHAR(100) NOT NULL
);
GO

CREATE TABLE Employees
(
    EmployeeID INT PRIMARY KEY,
    EmployeeName VARCHAR(100) NOT NULL,
    DepartmentID INT NOT NULL,
    HireDate DATE NOT NULL,
    RoleName VARCHAR(100) NOT NULL,

    CONSTRAINT FK_Employees_Departments
        FOREIGN KEY (DepartmentID)
        REFERENCES Departments(DepartmentID)
);
GO

CREATE TABLE Customers
(
    CustomerID INT PRIMARY KEY,
    CustomerSegment VARCHAR(50) NOT NULL,
    CustomerSince DATE NOT NULL,
    Region VARCHAR(50) NOT NULL
);
GO

CREATE TABLE Requests
(
    RequestID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    RequestTypeID INT NOT NULL,
    CreatedDate DATE NOT NULL,
    Priority VARCHAR(20) NOT NULL,
    Channel VARCHAR(50) NOT NULL,

    CONSTRAINT FK_Requests_Customers
        FOREIGN KEY (CustomerID)
        REFERENCES Customers(CustomerID),

    CONSTRAINT FK_Requests_RequestTypes
        FOREIGN KEY (RequestTypeID)
        REFERENCES Request_Types(RequestTypeID)
);
GO

CREATE TABLE Decisions
(
    DecisionID INT PRIMARY KEY,
    RequestID INT NOT NULL,
    EmployeeID INT NOT NULL,
    DecisionType VARCHAR(50) NOT NULL,
    DecisionDate DATE NOT NULL,
    DecisionReason VARCHAR(255),
    DecisionStatus VARCHAR(50) NOT NULL,

    CONSTRAINT FK_Decisions_Requests
        FOREIGN KEY (RequestID)
        REFERENCES Requests(RequestID),

    CONSTRAINT FK_Decisions_Employees
        FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID)
);
GO

CREATE TABLE Decision_Revisions
(
    RevisionID INT PRIMARY KEY,
    RequestID INT NOT NULL,
    PreviousDecision VARCHAR(50) NOT NULL,
    NewDecision VARCHAR(50) NOT NULL,
    RevisionDate DATE NOT NULL,
    RevisionReason VARCHAR(255),
    EmployeeID INT NOT NULL,

    CONSTRAINT FK_Revisions_Requests
        FOREIGN KEY (RequestID)
        REFERENCES Requests(RequestID),

    CONSTRAINT FK_Revisions_Employees
        FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID)
);
GO

CREATE TABLE Followup_Actions
(
    ActionID INT PRIMARY KEY,
    RequestID INT NOT NULL,
    ActionType VARCHAR(100) NOT NULL,
    ActionDate DATE NOT NULL,
    EmployeeID INT NOT NULL,
    ActionStatus VARCHAR(50) NOT NULL,

    CONSTRAINT FK_Followup_Requests
        FOREIGN KEY (RequestID)
        REFERENCES Requests(RequestID),

    CONSTRAINT FK_Followup_Employees
        FOREIGN KEY (EmployeeID)
        REFERENCES Employees(EmployeeID)
);
GO

CREATE TABLE Escalations
(
    EscalationID INT PRIMARY KEY,
    RequestID INT NOT NULL,
    EscalationDate DATE NOT NULL,
    EscalationReason VARCHAR(255) NOT NULL,
    EscalatedToDepartmentID INT NOT NULL,
    ResolutionDate DATE NULL,

    CONSTRAINT FK_Escalations_Requests
        FOREIGN KEY (RequestID)
        REFERENCES Requests(RequestID),

    CONSTRAINT FK_Escalations_Departments
        FOREIGN KEY (EscalatedToDepartmentID)
        REFERENCES Departments(DepartmentID)
);
GO
