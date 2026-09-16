CREATE TABLE [dbo].[DeploymentLog] (
    [DeploymentId]   INT             IDENTITY (1, 1) NOT NULL,
    [DeploymentDate] DATETIME2 (0)   CONSTRAINT [DF_DeploymentLog_DeploymentDate] DEFAULT (sysutcdatetime()) NOT NULL,
    [CommitSha]      NVARCHAR (100)  NOT NULL,
    [Environment]    NVARCHAR (50)   NOT NULL,
    [Status]         NVARCHAR (20)   NOT NULL,
    [ExecutedBy]     NVARCHAR (255)  NOT NULL,
    [ErrorMessage]   NVARCHAR (4000) NULL,
    CONSTRAINT [PK_DeploymentLog] PRIMARY KEY CLUSTERED ([DeploymentId] ASC)
);

