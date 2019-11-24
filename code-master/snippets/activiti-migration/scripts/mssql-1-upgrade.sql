create table ACT_RU_INCIDENT (
  ID_ nvarchar(64) not null,
  INCIDENT_TIMESTAMP_ datetime2 not null,
  INCIDENT_MSG_ nvarchar(4000),
  INCIDENT_TYPE_ nvarchar(255) not null,
  EXECUTION_ID_ nvarchar(64),
  ACTIVITY_ID_ nvarchar(255),
  PROC_INST_ID_ nvarchar(64),
  PROC_DEF_ID_ nvarchar(64),
  CAUSE_INCIDENT_ID_ nvarchar(64),
  ROOT_CAUSE_INCIDENT_ID_ nvarchar(64),
  CONFIGURATION_ nvarchar(255),
  primary key (ID_)
);

create index ACT_IDX_INC_CONFIGURATION on ACT_RU_INCIDENT(CONFIGURATION_);

alter table ACT_RU_INCIDENT
    add constraint ACT_FK_INC_EXE
    foreign key (EXECUTION_ID_)
    references ACT_RU_EXECUTION (ID_);

alter table ACT_RU_INCIDENT
    add constraint ACT_FK_INC_PROCINST
    foreign key (PROC_INST_ID_)
    references ACT_RU_EXECUTION (ID_);

alter table ACT_RU_INCIDENT
    add constraint ACT_FK_INC_PROCDEF
    foreign key (PROC_DEF_ID_)
    references ACT_RE_PROCDEF (ID_);

alter table ACT_RU_INCIDENT
    add constraint ACT_FK_INC_CAUSE
    foreign key (CAUSE_INCIDENT_ID_)
    references ACT_RU_INCIDENT (ID_);

alter table ACT_RU_INCIDENT
    add constraint ACT_FK_INC_RCAUSE
    foreign key (ROOT_CAUSE_INCIDENT_ID_)
    references ACT_RU_INCIDENT (ID_);




/** add ACT_INST_ID_ column to execution table */
alter table ACT_RU_EXECUTION
    add ACT_INST_ID_ nvarchar(64);


/** populate ACT_INST_ID_ from history */

/** get from history for active activity instances */
UPDATE
    ACT_RU_EXECUTION
SET
    ACT_INST_ID_  = (
        SELECT
            MAX(ID_)
        FROM
            ACT_HI_ACTINST HAI
        WHERE
            HAI.EXECUTION_ID_ = E.ID_
        AND
            END_TIME_ is null
    )
FROM
    ACT_RU_EXECUTION E
WHERE
    E.ACT_INST_ID_ is null
AND
    E.ACT_ID_ is not null;


/** set act_inst_id for inactive parents of scope executions */
UPDATE
    ACT_RU_EXECUTION
SET
    ACT_INST_ID_  = (
        SELECT
            MIN(HAI.ID_)
        FROM
            ACT_HI_ACTINST HAI
        INNER JOIN
            ACT_RU_EXECUTION SCOPE
            ON
                HAI.EXECUTION_ID_ = SCOPE.ID_
            AND
                SCOPE.PARENT_ID_ = E.ID_
            AND
                SCOPE.IS_SCOPE_ = 1
        WHERE
            HAI.END_TIME_ is null
        AND
            NOT EXISTS (
                SELECT
                    ACT_INST_ID_
                FROM
                    ACT_RU_EXECUTION CHILD
                WHERE
                    CHILD.ACT_INST_ID_ = HAI.ID_
                AND
                    E.ACT_ID_ is not null
            )
    )
FROM
    ACT_RU_EXECUTION E
WHERE
    E.ACT_INST_ID_ is null;

/** remaining executions get id from parent  */
UPDATE
    ACT_RU_EXECUTION
SET
    ACT_INST_ID_  = (
        SELECT
          ACT_INST_ID_ FROM ACT_RU_EXECUTION PARENT
        WHERE
            PARENT.ID_ = E.PARENT_ID_
        AND
            PARENT.ACT_ID_ = E.ACT_ID_
    )
FROM
    ACT_RU_EXECUTION E
WHERE
    E.ACT_INST_ID_ is null;
/**AND
    not exists (
        SELECT
            ID_
        FROM
            ACT_RU_EXECUTION CHILD
        WHERE
            CHILD.PARENT_ID_ = E.ID_
    );*/

/** remaining executions use execution id as activity instance id */
UPDATE
    ACT_RU_EXECUTION
SET
    ACT_INST_ID_  = ID_
WHERE
    ACT_INST_ID_ is null;


/** mark MI-scope executions in temporary column */
alter table ACT_RU_EXECUTION
    add IS_MI_SCOPE_ tinyint;


UPDATE
    ACT_RU_EXECUTION
SET
    IS_MI_SCOPE_ = 1
FROM
    ACT_RU_EXECUTION MI_SCOPE
WHERE
    MI_SCOPE.IS_SCOPE_ = 1
AND
    MI_SCOPE.ACT_ID_ is not null
AND EXISTS (
    SELECT
        ID_
    FROM
        ACT_RU_EXECUTION MI_CONCUR
    WHERE
        MI_CONCUR.PARENT_ID_ = MI_SCOPE.ID_
    AND
        MI_CONCUR.IS_SCOPE_ = 0
    AND
        MI_CONCUR.IS_CONCURRENT_ = 1
    AND
        MI_CONCUR.ACT_ID_ = MI_SCOPE.ACT_ID_
);

/** set IS_ACTIVE to false for MI-Scopes: */
UPDATE
    ACT_RU_EXECUTION
SET
    IS_ACTIVE_ = 0
WHERE
    IS_MI_SCOPE_ = 1;

/** set correct root for mi-parallel:
    CASE 1: process instance (use ID_) */
UPDATE
    ACT_RU_EXECUTION
SET
    ACT_INST_ID_  = MI_ROOT.ID_
FROM
    ACT_RU_EXECUTION MI_ROOT
WHERE
    MI_ROOT.ID_ = MI_ROOT.PROC_INST_ID_
AND EXISTS (
    SELECT
        ID_
    FROM
        ACT_RU_EXECUTION MI_SCOPE
    WHERE
        MI_SCOPE.PARENT_ID_ = MI_ROOT.ID_
    AND
        MI_SCOPE.IS_MI_SCOPE_ = 1
);

/**
    CASE 2: scopes below process instance (use ACT_INST_ID_ from parent) */
UPDATE
    ACT_RU_EXECUTION
SET
    ACT_INST_ID_  =  (
        SELECT
            ACT_INST_ID_
        FROM
            ACT_RU_EXECUTION PARENT
        WHERE
            PARENT.ID_ = MI_ROOT.PARENT_ID_
    )
FROM
    ACT_RU_EXECUTION MI_ROOT
WHERE
    MI_ROOT.ID_ != MI_ROOT.PROC_INST_ID_
AND EXISTS (
    SELECT
        ID_
    FROM
        ACT_RU_EXECUTION MI_SCOPE
    WHERE
        MI_SCOPE.PARENT_ID_ = MI_ROOT.ID_
    AND
        MI_SCOPE.IS_MI_SCOPE_ = 1
);

alter table ACT_RU_EXECUTION
    drop COLUMN IS_MI_SCOPE_;

/** add SUSPENSION_STATE_ column to task table */
-- alter table ACT_RU_TASK
--    add SUSPENSION_STATE_ int;

UPDATE ACT_RU_TASK
SET SUSPENSION_STATE_ = (
  SELECT SUSPENSION_STATE_
  FROM ACT_RU_EXECUTION E
  WHERE E.ID_ = EXECUTION_ID_
);

UPDATE ACT_RU_TASK
SET SUSPENSION_STATE_ = 1
WHERE SUSPENSION_STATE_ is null;

/** add authorizations **/

create table ACT_RU_AUTHORIZATION (
  ID_ varchar(64) not null,
  REV_ integer not null,
  TYPE_ integer not null,
  GROUP_ID_ varchar(255),
  USER_ID_ varchar(255),
  RESOURCE_TYPE_ integer not null,
  RESOURCE_ID_ varchar(64),
  PERMS_ integer,
  primary key (ID_)
);

create unique index ACT_UNIQ_AUTH_USER on ACT_RU_AUTHORIZATION (TYPE_,USER_ID_,RESOURCE_TYPE_,RESOURCE_ID_) where USER_ID_ is not null;
create unique index ACT_UNIQ_AUTH_GROUP on ACT_RU_AUTHORIZATION (TYPE_,GROUP_ID_,RESOURCE_TYPE_,RESOURCE_ID_) where GROUP_ID_ is not null;

/** add deployment ids to jobs **/
alter table ACT_RU_JOB
    add DEPLOYMENT_ID_ nvarchar(64);

/** add parent act inst ID */
alter table ACT_HI_ACTINST
    add PARENT_ACT_INST_ID_ nvarchar(64);-- add new column to historic activity instance table --
alter table ACT_HI_ACTINST
    add ACT_INST_STATE_ tinyint;

-- add follow-up date to tasks --
alter table ACT_RU_TASK
    add FOLLOW_UP_DATE_ datetime2;
alter table ACT_HI_TASKINST
    add FOLLOW_UP_DATE_ datetime2;

-- add JOBDEF table --
create table ACT_RU_JOBDEF (
    ID_ nvarchar(64) NOT NULL,
    REV_ integer,
    PROC_DEF_ID_ nvarchar(64) NOT NULL,
    PROC_DEF_KEY_ nvarchar(255) NOT NULL,
    ACT_ID_ nvarchar(255) NOT NULL,
    JOB_TYPE_ nvarchar(255) NOT NULL,
    JOB_CONFIGURATION_ nvarchar(255),
    SUSPENSION_STATE_ tinyint,
    primary key (ID_)
);

-- add new columns to job table --
alter table ACT_RU_JOB
    add PROCESS_DEF_ID_ nvarchar(64);

alter table ACT_RU_JOB
    add PROCESS_DEF_KEY_ nvarchar(64);

alter table ACT_RU_JOB
    add SUSPENSION_STATE_ tinyint;

alter table ACT_RU_JOB
    add JOB_DEF_ID_ nvarchar(64);

-- update job table with values from execution table --

UPDATE
    ACT_RU_JOB
SET
    PROCESS_DEF_ID_  = (
        SELECT
            PI.PROC_DEF_ID_
        FROM
            ACT_RU_EXECUTION PI
        WHERE
            PI.ID_ = PROCESS_INSTANCE_ID_
    ),
    SUSPENSION_STATE_  = (
        SELECT
            PI.SUSPENSION_STATE_
        FROM
            ACT_RU_EXECUTION PI
        WHERE
            PI.ID_ = PROCESS_INSTANCE_ID_
    );

UPDATE
    ACT_RU_JOB
SET
    PROCESS_DEF_KEY_  = (
        SELECT
            PD.KEY_
        FROM
            ACT_RE_PROCDEF PD
        WHERE
            PD.ID_ = PROCESS_DEF_ID_
    );

-- add Hist OP Log table --

create table ACT_HI_OP_LOG (
    ID_ nvarchar(64) not null,
    PROC_DEF_ID_ nvarchar(64),
    PROC_INST_ID_ nvarchar(64),
    EXECUTION_ID_ nvarchar(64),
    TASK_ID_ nvarchar(64),
    USER_ID_ nvarchar(255),
    TIMESTAMP_ datetime2 not null,
    OPERATION_TYPE_ nvarchar(64),
    OPERATION_ID_ nvarchar(64),
    ENTITY_TYPE_ nvarchar(30),
    PROPERTY_ nvarchar(64),
    ORG_VALUE_ nvarchar(4000),
    NEW_VALUE_ nvarchar(4000),
    primary key (ID_)
);

-- add new column to ACT_HI_VARINST --

alter table ACT_HI_VARINST
    add ACT_INST_ID_ nvarchar(64);

alter table ACT_HI_DETAIL
    add VAR_INST_ID_ nvarchar(64);

alter table ACT_HI_TASKINST
    add ACT_INST_ID_ nvarchar(64);

-- set cached entity state to 63 on all executions --

UPDATE
    ACT_RU_EXECUTION
SET
    CACHED_ENT_STATE_ = 63;

-- add new table ACT_HI_INCIDENT --

create table ACT_HI_INCIDENT (
  ID_ nvarchar(64) not null,
  PROC_DEF_ID_ nvarchar(64),
  PROC_INST_ID_ nvarchar(64),
  EXECUTION_ID_ nvarchar(64),
  CREATE_TIME_ datetime2 not null,
  END_TIME_ datetime2,
  INCIDENT_MSG_ nvarchar(4000),
  INCIDENT_TYPE_ nvarchar(255) not null,
  ACTIVITY_ID_ nvarchar(255),
  CAUSE_INCIDENT_ID_ nvarchar(64),
  ROOT_CAUSE_INCIDENT_ID_ nvarchar(64),
  CONFIGURATION_ nvarchar(255),
  INCIDENT_STATE_ integer,
  primary key (ID_)
);

-- update ACT_RU_VARIABLE table --

-- add new column --

ALTER TABLE ACT_RU_VARIABLE
    add VAR_SCOPE_ nvarchar(64);

-- migrate execution variables --

UPDATE
  ACT_RU_VARIABLE

SET
  VAR_SCOPE_ = EXECUTION_ID_

WHERE
  EXECUTION_ID_ is not null AND
  TASK_ID_ is null;

-- migrate task variables --

UPDATE
  ACT_RU_VARIABLE

SET
  VAR_SCOPE_ = TASK_ID_

WHERE
  TASK_ID_ is not null;

-- set VAR_SCOPE_ not null--

ALTER TABLE ACT_RU_VARIABLE
    ALTER COLUMN VAR_SCOPE_ nvarchar(64) NOT NULL;

-- add unique constraint --

CREATE UNIQUE INDEX ACT_UNIQ_VARIABLE ON ACT_RU_VARIABLE(VAR_SCOPE_, NAME_);

-- indexes for concurrency problems - https://app.camunda.com/jira/browse/CAM-1646 --
create index ACT_IDX_EXECUTION_PROC on ACT_RU_EXECUTION(PROC_DEF_ID_);
create index ACT_IDX_EXECUTION_PARENT on ACT_RU_EXECUTION(PARENT_ID_);
create index ACT_IDX_EXECUTION_SUPER on ACT_RU_EXECUTION(SUPER_EXEC_);
create index ACT_IDX_EVENT_SUBSCR_EXEC on ACT_RU_EVENT_SUBSCR(EXECUTION_ID_);
create index ACT_IDX_BA_DEPLOYMENT on ACT_GE_BYTEARRAY(DEPLOYMENT_ID_);
create index ACT_IDX_IDENT_LNK_TASK on ACT_RU_IDENTITYLINK(TASK_ID_);
create index ACT_IDX_INCIDENT_EXEC on ACT_RU_INCIDENT(EXECUTION_ID_);
create index ACT_IDX_INCIDENT_PROCINST on ACT_RU_INCIDENT(PROC_INST_ID_);
create index ACT_IDX_INCIDENT_PROC_DEF_ID on ACT_RU_INCIDENT(PROC_DEF_ID_);
create index ACT_IDX_INCIDENT_CAUSE on ACT_RU_INCIDENT(CAUSE_INCIDENT_ID_);
create index ACT_IDX_INCIDENT_ROOT_CAUSE on ACT_RU_INCIDENT(ROOT_CAUSE_INCIDENT_ID_);
create index ACT_IDX_JOB_EXCEPTION_STACK on ACT_RU_JOB(EXCEPTION_STACK_ID_);
create index ACT_IDX_VARIABLE_BA on ACT_RU_VARIABLE(BYTEARRAY_ID_);
create index ACT_IDX_VARIABLE_EXEC on ACT_RU_VARIABLE(EXECUTION_ID_);
create index ACT_IDX_VARIABLE_PROCINST on ACT_RU_VARIABLE(PROC_INST_ID_);
create index ACT_IDX_TASK_EXEC on ACT_RU_TASK(EXECUTION_ID_);
create index ACT_IDX_TASK_PROCINST on ACT_RU_TASK(PROC_INST_ID_);
create index ACT_IDX_TASK_PROC_DEF_ID on ACT_RU_TASK(PROC_DEF_ID_);-- add deployment.lock row to property table --
INSERT INTO ACT_GE_PROPERTY
  VALUES ('deployment.lock', '0', 1);

-- add revision column to incident table --
ALTER TABLE ACT_RU_INCIDENT
  ADD REV_ INT;

-- set initial incident revision to 1 --
UPDATE
  ACT_RU_INCIDENT
SET
  REV_ = 1;

-- set incident revision column to not null --
ALTER TABLE ACT_RU_INCIDENT
  ALTER COLUMN REV_ INT NOT NULL;

-- case management

ALTER TABLE ACT_RU_VARIABLE
  ADD CASE_EXECUTION_ID_ nvarchar(64);

ALTER TABLE ACT_RU_VARIABLE
  ADD CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_RU_TASK
  ADD CASE_EXECUTION_ID_ nvarchar(64);

ALTER TABLE ACT_RU_TASK
  ADD CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_RU_TASK
  ADD CASE_DEF_ID_ nvarchar(64);

ALTER TABLE ACT_RU_EXECUTION
  ADD SUPER_CASE_EXEC_ nvarchar(64);

ALTER TABLE ACT_RU_EXECUTION
  ADD CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_HI_OP_LOG
  ADD CASE_EXECUTION_ID_ nvarchar(64);

ALTER TABLE ACT_HI_OP_LOG
  ADD CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_HI_OP_LOG
  ADD CASE_DEF_ID_ nvarchar(64);

ALTER TABLE ACT_HI_OP_LOG
  ADD PROC_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_PROCINST
  ADD CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_HI_TASKINST
  ADD CASE_EXECUTION_ID_ nvarchar(64);

ALTER TABLE ACT_HI_TASKINST
  ADD CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_HI_TASKINST
  ADD CASE_DEF_ID_ nvarchar(64);

-- create case definition table --
create table ACT_RE_CASE_DEF (
    ID_ nvarchar(64) not null,
    REV_ int,
    CATEGORY_ nvarchar(255),
    NAME_ nvarchar(255),
    KEY_ nvarchar(255) not null,
    VERSION_ int not null,
    DEPLOYMENT_ID_ nvarchar(64),
    RESOURCE_NAME_ nvarchar(4000),
    DGRM_RESOURCE_NAME_ nvarchar(4000),
    primary key (ID_)
);

-- create case execution table --
create table ACT_RU_CASE_EXECUTION (
    ID_ nvarchar(64) NOT NULL,
    REV_ int,
    CASE_INST_ID_ nvarchar(64),
    SUPER_CASE_EXEC_ nvarchar(64),
    BUSINESS_KEY_ nvarchar(255),
    PARENT_ID_ nvarchar(64),
    CASE_DEF_ID_ nvarchar(64),
    ACT_ID_ nvarchar(255),
    PREV_STATE_ int,
    CURRENT_STATE_ int,
    primary key (ID_)
);

-- create case sentry part table --

create table ACT_RU_CASE_SENTRY_PART (
    ID_ nvarchar(64) NOT NULL,
    REV_ int,
    CASE_INST_ID_ nvarchar(64),
    CASE_EXEC_ID_ nvarchar(64),
    SENTRY_ID_ nvarchar(255),
    TYPE_ nvarchar(255),
    SOURCE_CASE_EXEC_ID_ nvarchar(64),
    STANDARD_EVENT_ nvarchar(255),
    SATISFIED_ tinyint,
    primary key (ID_)
);

-- create unique constraint on ACT_RE_CASE_DEF --
alter table ACT_RE_CASE_DEF
    add constraint ACT_UNIQ_CASE_DEF
    unique (KEY_,VERSION_);

-- create index on business key --
create index ACT_IDX_CASE_EXEC_BUSKEY on ACT_RU_CASE_EXECUTION(BUSINESS_KEY_);

-- create foreign key constraints on ACT_RU_CASE_EXECUTION --
alter table ACT_RU_CASE_EXECUTION
    add constraint ACT_FK_CASE_EXE_CASE_INST
    foreign key (CASE_INST_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

alter table ACT_RU_CASE_EXECUTION
    add constraint ACT_FK_CASE_EXE_PARENT
    foreign key (PARENT_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

alter table ACT_RU_CASE_EXECUTION
    add constraint ACT_FK_CASE_EXE_CASE_DEF
    foreign key (CASE_DEF_ID_)
    references ACT_RE_CASE_DEF(ID_);

-- create foreign key constraints on ACT_RU_VARIABLE --
alter table ACT_RU_VARIABLE
    add constraint ACT_FK_VAR_CASE_EXE
    foreign key (CASE_EXECUTION_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

alter table ACT_RU_VARIABLE
    add constraint ACT_FK_VAR_CASE_INST
    foreign key (CASE_INST_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

-- create foreign key constraints on ACT_RU_TASK --
alter table ACT_RU_TASK
    add constraint ACT_FK_TASK_CASE_EXE
    foreign key (CASE_EXECUTION_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

alter table ACT_RU_TASK
  add constraint ACT_FK_TASK_CASE_DEF
  foreign key (CASE_DEF_ID_)
  references ACT_RE_CASE_DEF(ID_);

-- create foreign key constraints on ACT_RU_CASE_SENTRY_PART --
alter table ACT_RU_CASE_SENTRY_PART
    add constraint ACT_FK_CASE_SENTRY_CASE_INST
    foreign key (CASE_INST_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

alter table ACT_RU_CASE_SENTRY_PART
    add constraint ACT_FK_CASE_SENTRY_CASE_EXEC
    foreign key (CASE_EXEC_ID_)
    references ACT_RU_CASE_EXECUTION(ID_);

-- indexes for concurrency problems - https://app.camunda.com/jira/browse/CAM-1646 --
create index ACT_IDX_CASE_EXEC_CASE on ACT_RU_CASE_EXECUTION(CASE_DEF_ID_);
create index ACT_IDX_CASE_EXEC_PARENT on ACT_RU_CASE_EXECUTION(PARENT_ID_);
create index ACT_IDX_VARIABLE_CASE_EXEC on ACT_RU_VARIABLE(CASE_EXECUTION_ID_);
create index ACT_IDX_VARIABLE_CASE_INST on ACT_RU_VARIABLE(CASE_INST_ID_);
create index ACT_IDX_TASK_CASE_EXEC on ACT_RU_TASK(CASE_EXECUTION_ID_);
create index ACT_IDX_TASK_CASE_DEF_ID on ACT_RU_TASK(CASE_DEF_ID_);

-- add indexes for ACT_RU_CASE_SENTRY_PART --
create index ACT_IDX_CASE_SENTRY_CASE_INST on ACT_RU_CASE_SENTRY_PART(CASE_INST_ID_);
create index ACT_IDX_CASE_SENTRY_CASE_EXEC on ACT_RU_CASE_SENTRY_PART(CASE_EXEC_ID_);

-- create filter table
create table ACT_RU_FILTER (
  ID_ nvarchar(64) not null,
  REV_ integer not null,
  RESOURCE_TYPE_ nvarchar(255) not null,
  NAME_ nvarchar(255) not null,
  OWNER_ nvarchar(255),
  QUERY_ nvarchar(max) not null,
  PROPERTIES_ nvarchar(max),
  primary key (ID_)
);

-- add index to improve job executor performance
create index ACT_IDX_JOB_PROCINST on ACT_RU_JOB(PROCESS_INSTANCE_ID_);

-- create historic case instance/activity table and indexes --
create table ACT_HI_CASEINST (
    ID_ nvarchar(64) not null,
    CASE_INST_ID_ nvarchar(64) not null,
    BUSINESS_KEY_ nvarchar(255),
    CASE_DEF_ID_ nvarchar(64) not null,
    CREATE_TIME_ datetime2 not null,
    CLOSE_TIME_ datetime2,
    DURATION_ numeric(19,0),
    STATE_ tinyint,
    CREATE_USER_ID_ nvarchar(255),
    SUPER_CASE_INSTANCE_ID_ nvarchar(64),
    primary key (ID_),
    unique (CASE_INST_ID_)
);

create table ACT_HI_CASEACTINST (
    ID_ nvarchar(64) not null,
    PARENT_ACT_INST_ID_ nvarchar(64),
    CASE_DEF_ID_ nvarchar(64) not null,
    CASE_INST_ID_ nvarchar(64) not null,
    CASE_ACT_ID_ nvarchar(255) not null,
    TASK_ID_ nvarchar(64),
    CALL_PROC_INST_ID_ nvarchar(64),
    CALL_CASE_INST_ID_ nvarchar(64),
    CASE_ACT_NAME_ nvarchar(255),
    CASE_ACT_TYPE_ nvarchar(255),
    CREATE_TIME_ datetime2 not null,
    END_TIME_ datetime2,
    DURATION_ numeric(19,0),
    STATE_ tinyint,
    primary key (ID_)
);

create index ACT_IDX_HI_CAS_I_CLOSE on ACT_HI_CASEINST(CLOSE_TIME_);
create index ACT_IDX_HI_CAS_I_BUSKEY on ACT_HI_CASEINST(BUSINESS_KEY_);
create index ACT_IDX_HI_CAS_A_I_CREATE on ACT_HI_CASEACTINST(CREATE_TIME_);
create index ACT_IDX_HI_CAS_A_I_END on ACT_HI_CASEACTINST(END_TIME_);
create index ACT_IDX_HI_CAS_A_I_COMP on ACT_HI_CASEACTINST(CASE_ACT_ID_, END_TIME_, ID_);

create index ACT_IDX_TASK_ASSIGNEE on ACT_RU_TASK(ASSIGNEE_);

-- add case instance/execution to historic variable instance and detail --
alter table ACT_HI_VARINST
  add CASE_INST_ID_ nvarchar(64);

alter table ACT_HI_VARINST
  add CASE_EXECUTION_ID_ nvarchar(64);

alter table ACT_HI_DETAIL
  add CASE_INST_ID_ nvarchar(64);

alter table ACT_HI_DETAIL
  add CASE_EXECUTION_ID_ nvarchar(64);

create index ACT_IDX_HI_DETAIL_CASE_INST on ACT_HI_DETAIL(CASE_INST_ID_);
create index ACT_IDX_HI_DETAIL_CASE_EXEC on ACT_HI_DETAIL(CASE_EXECUTION_ID_);
create index ACT_IDX_HI_CASEVAR_CASE_INST on ACT_HI_VARINST(CASE_INST_ID_);
-- indexes to improve deployment
create index ACT_IDX_BYTEARRAY_NAME on ACT_GE_BYTEARRAY(NAME_);
create index ACT_IDX_DEPLOYMENT_NAME on ACT_RE_DEPLOYMENT(NAME_);
create index ACT_IDX_JOBDEF_PROC_DEF_ID ON ACT_RU_JOBDEF(PROC_DEF_ID_);
create index ACT_IDX_JOB_HANDLER_TYPE ON ACT_RU_JOB(HANDLER_TYPE_);
create index ACT_IDX_EVENT_SUBSCR_EVT_NAME ON ACT_RU_EVENT_SUBSCR(EVENT_NAME_);
create index ACT_IDX_PROCDEF_DEPLOYMENT_ID ON ACT_RE_PROCDEF(DEPLOYMENT_ID_);
-- case management --

ALTER TABLE ACT_RU_CASE_EXECUTION
  ADD SUPER_EXEC_ nvarchar(64);

ALTER TABLE ACT_RU_CASE_EXECUTION
  ADD REQUIRED_ tinyint;

-- history --

ALTER TABLE ACT_HI_ACTINST
  ADD CALL_CASE_INST_ID_ nvarchar(64);

ALTER TABLE ACT_HI_PROCINST
  ADD SUPER_CASE_INSTANCE_ID_ nvarchar(64);

ALTER TABLE ACT_HI_CASEINST
  ADD SUPER_PROCESS_INSTANCE_ID_ nvarchar(64);

ALTER TABLE ACT_HI_CASEACTINST
  ADD REQUIRED_ tinyint;

ALTER TABLE ACT_HI_OP_LOG
  ADD JOB_ID_ nvarchar(64);

ALTER TABLE ACT_HI_OP_LOG
  ADD JOB_DEF_ID_ nvarchar(64);

create table ACT_HI_JOB_LOG (
    ID_ nvarchar(64) not null,
    TIMESTAMP_ datetime2 not null,
    JOB_ID_ nvarchar(64) not null,
    JOB_DUEDATE_ datetime2,
    JOB_RETRIES_ integer,
    JOB_EXCEPTION_MSG_ nvarchar(4000),
    JOB_EXCEPTION_STACK_ID_ nvarchar(64),
    JOB_STATE_ integer,
    JOB_DEF_ID_ nvarchar(64),
    JOB_DEF_TYPE_ nvarchar(255),
    JOB_DEF_CONFIGURATION_ nvarchar(255),
    ACT_ID_ nvarchar(64),
    EXECUTION_ID_ nvarchar(64),
    PROCESS_INSTANCE_ID_ nvarchar(64),
    PROCESS_DEF_ID_ nvarchar(64),
    PROCESS_DEF_KEY_ nvarchar(255),
    DEPLOYMENT_ID_ nvarchar(64),
    SEQUENCE_COUNTER_ numeric(19,0),
    primary key (ID_)
);

create index ACT_IDX_HI_JOB_LOG_PROCINST on ACT_HI_JOB_LOG(PROCESS_INSTANCE_ID_);
create index ACT_IDX_HI_JOB_LOG_PROCDEF on ACT_HI_JOB_LOG(PROCESS_DEF_ID_);

-- history: add columns PROC_DEF_KEY_, PROC_DEF_ID_, CASE_DEF_KEY_, CASE_DEF_ID_ --

ALTER TABLE ACT_HI_PROCINST
  ADD PROC_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_ACTINST
  ADD PROC_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_TASKINST
  ADD PROC_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_TASKINST
  ADD CASE_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_VARINST
  ADD PROC_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_VARINST
  ADD PROC_DEF_ID_ nvarchar(64);

ALTER TABLE ACT_HI_VARINST
  ADD CASE_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_VARINST
  ADD CASE_DEF_ID_ nvarchar(64);

ALTER TABLE ACT_HI_DETAIL
  ADD PROC_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_DETAIL
  ADD PROC_DEF_ID_ nvarchar(64);

ALTER TABLE ACT_HI_DETAIL
  ADD CASE_DEF_KEY_ nvarchar(255);

ALTER TABLE ACT_HI_DETAIL
  ADD CASE_DEF_ID_ nvarchar(64);

ALTER TABLE ACT_HI_INCIDENT
  ADD PROC_DEF_KEY_ nvarchar(255);

-- sequence counter

ALTER TABLE ACT_RU_EXECUTION
  ADD SEQUENCE_COUNTER_ numeric(19,0);

ALTER TABLE ACT_HI_ACTINST
  ADD SEQUENCE_COUNTER_ numeric(19,0);

ALTER TABLE ACT_RU_VARIABLE
  ADD SEQUENCE_COUNTER_ numeric(19,0);

ALTER TABLE ACT_HI_DETAIL
  ADD SEQUENCE_COUNTER_ numeric(19,0);

ALTER TABLE ACT_RU_JOB
  ADD SEQUENCE_COUNTER_ numeric(19,0);

-- AUTHORIZATION --

-- add grant authorizations for group camunda-admin:
INSERT INTO
  ACT_RU_AUTHORIZATION (ID_, TYPE_, GROUP_ID_, RESOURCE_TYPE_, RESOURCE_ID_, PERMS_, REV_)
VALUES
  ('camunda-admin-grant-process-definition', 1, 'camunda-admin', 6, '*', 2147483647, 1),
  ('camunda-admin-grant-task', 1, 'camunda-admin', 7, '*', 2147483647, 1),
  ('camunda-admin-grant-process-instance', 1, 'camunda-admin', 8, '*', 2147483647, 1),
  ('camunda-admin-grant-deployment', 1, 'camunda-admin', 9, '*', 2147483647, 1);

-- add global grant authorizations for new authorization resources:
-- DEPLOYMENT
-- PROCESS_DEFINITION
-- PROCESS_INSTANCE
-- TASK
-- with ALL permissions

INSERT INTO
  ACT_RU_AUTHORIZATION (ID_, TYPE_, USER_ID_, RESOURCE_TYPE_, RESOURCE_ID_, PERMS_, REV_)
VALUES
  ('global-grant-process-definition', 0, '*', 6, '*', 2147483647, 1),
  ('global-grant-task', 0, '*', 7, '*', 2147483647, 1),
  ('global-grant-process-instance', 0, '*', 8, '*', 2147483647, 1),
  ('global-grant-deployment', 0, '*', 9, '*', 2147483647, 1);

-- variables --

ALTER TABLE ACT_RU_VARIABLE
  ADD IS_CONCURRENT_LOCAL_ tinyint;

-- metrics --

create table ACT_RU_METER_LOG (
  ID_ nvarchar(64) not null,
  NAME_ nvarchar(64) not null,
  VALUE_ numeric(19,0),
  TIMESTAMP_ datetime2 not null,
  primary key (ID_)
);

create index ACT_IDX_METER_LOG on ACT_RU_METER_LOG(NAME_,TIMESTAMP_);alter table ACT_HI_JOB_LOG
  alter column ACT_ID_ nvarchar(255);
-- index for deadlock problem - https://app.camunda.com/jira/browse/CAM-4440 --
create index ACT_IDX_AUTH_RESOURCE_ID on ACT_RU_AUTHORIZATION(RESOURCE_ID_);

-- indexes to improve deployment
-- create index ACT_IDX_BYTEARRAY_NAME on ACT_GE_BYTEARRAY(NAME_);
-- create index ACT_IDX_DEPLOYMENT_NAME on ACT_RE_DEPLOYMENT(NAME_);
-- create index ACT_IDX_JOBDEF_PROC_DEF_ID ON ACT_RU_JOBDEF(PROC_DEF_ID_);
-- create index ACT_IDX_JOB_HANDLER_TYPE ON ACT_RU_JOB(HANDLER_TYPE_);
-- create index ACT_IDX_EVENT_SUBSCR_EVT_NAME ON ACT_RU_EVENT_SUBSCR(EVENT_NAME_);
-- create index ACT_IDX_PROCDEF_DEPLOYMENT_ID ON ACT_RE_PROCDEF(DEPLOYMENT_ID_);

-- INCREASE process def key column size https://app.camunda.com/jira/browse/CAM-4328 --
alter table ACT_RU_JOB
  alter column PROCESS_DEF_KEY_ nvarchar(255);-- https://app.camunda.com/jira/browse/CAM-5364 --
create index ACT_IDX_AUTH_GROUP_ID on ACT_RU_AUTHORIZATION(GROUP_ID_);-- metrics --

ALTER TABLE ACT_RU_METER_LOG
  ADD REPORTER_ nvarchar(255);

-- job prioritization --

ALTER TABLE ACT_RU_JOB
  ADD PRIORITY_ numeric(19,0) NOT NULL
  DEFAULT 0;

ALTER TABLE ACT_RU_JOBDEF
  ADD JOB_PRIORITY_ numeric(19,0);

ALTER TABLE ACT_HI_JOB_LOG
  ADD JOB_PRIORITY_ numeric(19,0) NOT NULL
  DEFAULT 0;

-- create decision definition table --
create table ACT_RE_DECISION_DEF (
    ID_ nvarchar(64) not null,
    REV_ int,
    CATEGORY_ nvarchar(255),
    NAME_ nvarchar(255),
    KEY_ nvarchar(255) not null,
    VERSION_ int not null,
    DEPLOYMENT_ID_ nvarchar(64),
    RESOURCE_NAME_ nvarchar(4000),
    DGRM_RESOURCE_NAME_ nvarchar(4000),
    primary key (ID_)
);

-- create unique constraint on ACT_RE_DECISION_DEF --
alter table ACT_RE_DECISION_DEF
    add constraint ACT_UNIQ_DECISION_DEF
    unique (KEY_,VERSION_);

-- case sentry part source --

ALTER TABLE ACT_RU_CASE_SENTRY_PART
  ADD SOURCE_ nvarchar(255);

-- create history decision instance table --
create table ACT_HI_DECINST (
    ID_ nvarchar(64) NOT NULL,
    DEC_DEF_ID_ nvarchar(64) NOT NULL,
    DEC_DEF_KEY_ nvarchar(255) NOT NULL,
    DEC_DEF_NAME_ nvarchar(255),
    PROC_DEF_KEY_ nvarchar(255),
    PROC_DEF_ID_ nvarchar(64),
    PROC_INST_ID_ nvarchar(64),
    CASE_DEF_KEY_ nvarchar(255),
    CASE_DEF_ID_ nvarchar(64),
    CASE_INST_ID_ nvarchar(64),
    ACT_INST_ID_ nvarchar(64),
    ACT_ID_ nvarchar(255),
    EVAL_TIME_ datetime2 not null,
    COLLECT_VALUE_ double precision,
    primary key (ID_)
);

-- create history decision input table --
create table ACT_HI_DEC_IN (
    ID_ nvarchar(64) NOT NULL,
    DEC_INST_ID_ nvarchar(64) NOT NULL,
    CLAUSE_ID_ nvarchar(64) NOT NULL,
    CLAUSE_NAME_ nvarchar(255),
    VAR_TYPE_ nvarchar(100),
    BYTEARRAY_ID_ nvarchar(64),
    DOUBLE_ double precision,
    LONG_ numeric(19,0),
    TEXT_ nvarchar(4000),
    TEXT2_ nvarchar(4000),
    primary key (ID_)
);

-- create history decision output table --
create table ACT_HI_DEC_OUT (
    ID_ nvarchar(64) NOT NULL,
    DEC_INST_ID_ nvarchar(64) NOT NULL,
    CLAUSE_ID_ nvarchar(64) NOT NULL,
    CLAUSE_NAME_ nvarchar(255),
    RULE_ID_ nvarchar(64) NOT NULL,
    RULE_ORDER_ int,
    VAR_NAME_ nvarchar(255),
    VAR_TYPE_ nvarchar(100),
    BYTEARRAY_ID_ nvarchar(64),
    DOUBLE_ double precision,
    LONG_ numeric(19,0),
    TEXT_ nvarchar(4000),
    TEXT2_ nvarchar(4000),
    primary key (ID_)
);

-- create indexes for historic decision tables
create index ACT_IDX_HI_DEC_INST_ID on ACT_HI_DECINST(DEC_DEF_ID_);
create index ACT_IDX_HI_DEC_INST_KEY on ACT_HI_DECINST(DEC_DEF_KEY_);
create index ACT_IDX_HI_DEC_INST_PI on ACT_HI_DECINST(PROC_INST_ID_);
create index ACT_IDX_HI_DEC_INST_CI on ACT_HI_DECINST(CASE_INST_ID_);
create index ACT_IDX_HI_DEC_INST_ACT on ACT_HI_DECINST(ACT_ID_);
create index ACT_IDX_HI_DEC_INST_ACT_INST on ACT_HI_DECINST(ACT_INST_ID_);
create index ACT_IDX_HI_DEC_INST_TIME on ACT_HI_DECINST(EVAL_TIME_);

create index ACT_IDX_HI_DEC_IN_INST on ACT_HI_DEC_IN(DEC_INST_ID_);
create index ACT_IDX_HI_DEC_IN_CLAUSE on ACT_HI_DEC_IN(DEC_INST_ID_, CLAUSE_ID_);

create index ACT_IDX_HI_DEC_OUT_INST on ACT_HI_DEC_OUT(DEC_INST_ID_);
create index ACT_IDX_HI_DEC_OUT_RULE on ACT_HI_DEC_OUT(RULE_ORDER_, CLAUSE_ID_);

-- add grant authorization for group camunda-admin:
INSERT INTO
  ACT_RU_AUTHORIZATION (ID_, TYPE_, GROUP_ID_, RESOURCE_TYPE_, RESOURCE_ID_, PERMS_, REV_)
VALUES
  ('camunda-admin-grant-decision-definition', 1, 'camunda-admin', 10, '*', 2147483647, 1);

-- external tasks --

create table ACT_RU_EXT_TASK (
  ID_ nvarchar(64) not null,
  REV_ integer not null,
  WORKER_ID_ nvarchar(255),
  TOPIC_NAME_ nvarchar(255),
  RETRIES_ int,
  ERROR_MSG_ nvarchar(4000),
  LOCK_EXP_TIME_ datetime2,
  EXECUTION_ID_ nvarchar(64),
  SUSPENSION_STATE_ tinyint,
  PROC_INST_ID_ nvarchar(64),
  PROC_DEF_ID_ nvarchar(64),
  PROC_DEF_KEY_ nvarchar(255),
  ACT_ID_ nvarchar(255),
  ACT_INST_ID_ nvarchar(64),
  primary key (ID_)
);

alter table ACT_RU_EXT_TASK
    add constraint ACT_FK_EXT_TASK_EXE
    foreign key (EXECUTION_ID_)
    references ACT_RU_EXECUTION (ID_);

create index ACT_IDX_EXT_TASK_TOPIC on ACT_RU_EXT_TASK(TOPIC_NAME_);

-- deployment --

ALTER TABLE ACT_RE_DEPLOYMENT
  ADD SOURCE_ nvarchar(255);

ALTER TABLE ACT_HI_OP_LOG
  ADD DEPLOYMENT_ID_ nvarchar(64);

-- job suspension state

ALTER TABLE ACT_RU_JOB
  ADD DEFAULT 1
  FOR SUSPENSION_STATE_;

  -- relevant for jobs created in Camunda 7.0
UPDATE ACT_RU_JOB
  SET SUSPENSION_STATE_ = 1
  WHERE SUSPENSION_STATE_ IS NULL;

ALTER TABLE ACT_RU_JOB
  ALTER COLUMN SUSPENSION_STATE_ tinyint
  NOT NULL;
-- index to improve historic activity instance query - https://app.camunda.com/jira/browse/CAM-5257 --
create index ACT_IDX_HI_ACT_INST_STATS on ACT_HI_ACTINST(PROC_DEF_ID_, ACT_ID_, END_TIME_, ACT_INST_STATE_);
-- index to prevent deadlock on fk constraint - https://app.camunda.com/jira/browse/CAM-5440 --
create index ACT_IDX_EXT_TASK_EXEC on ACT_RU_EXT_TASK(EXECUTION_ID_);
-- https://app.camunda.com/jira/browse/CAM-5364 --
create index ACT_IDX_AUTH_GROUP_ID on ACT_RU_AUTHORIZATION(GROUP_ID_);-- INCREASE process def key column size https://app.camunda.com/jira/browse/CAM-4328 --
alter table ACT_RU_JOB
  alter column PROCESS_DEF_KEY_ nvarchar(255);-- create missing foreign key contraint on ACT_RU_EXECUTION
alter table ACT_RU_EXECUTION
    add constraint ACT_FK_EXE_PROCINST
    foreign key (PROC_INST_ID_)
    references ACT_RU_EXECUTION (ID_);

-- semantic version --

ALTER TABLE ACT_RE_PROCDEF
  ADD VERSION_TAG_ nvarchar(64);

create index ACT_IDX_PROCDEF_VER_TAG on ACT_RE_PROCDEF(VERSION_TAG_);

-- AUTHORIZATION --

-- add grant authorizations for group camunda-admin:
INSERT INTO
  ACT_RU_AUTHORIZATION (ID_, TYPE_, GROUP_ID_, RESOURCE_TYPE_, RESOURCE_ID_, PERMS_, REV_)
VALUES
  ('camunda-admin-grant-tenant', 1, 'camunda-admin', 11, '*', 2147483647, 1),
  ('camunda-admin-grant-tenant-membership', 1, 'camunda-admin', 12, '*', 2147483647, 1),
  ('camunda-admin-grant-batch', 1, 'camunda-admin', 13, '*', 2147483647, 1);

-- tenant id --

--ALTER TABLE ACT_RE_DEPLOYMENT
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_DEPLOYMENT_TENANT_ID on ACT_RE_DEPLOYMENT(TENANT_ID_);

--ALTER TABLE ACT_RE_PROCDEF
--  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_RE_PROCDEF
       DROP CONSTRAINT ACT_UNIQ_PROCDEF;

create index ACT_IDX_PROCDEF_TENANT_ID ON ACT_RE_PROCDEF(TENANT_ID_);

--ALTER TABLE ACT_RU_EXECUTION
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_EXEC_TENANT_ID on ACT_RU_EXECUTION(TENANT_ID_);

--ALTER TABLE ACT_RU_TASK
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_TASK_TENANT_ID on ACT_RU_TASK(TENANT_ID_);

ALTER TABLE ACT_RU_VARIABLE
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_VARIABLE_TENANT_ID on ACT_RU_VARIABLE(TENANT_ID_);

--ALTER TABLE ACT_RU_EVENT_SUBSCR
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_EVENT_SUBSCR_TENANT_ID on ACT_RU_EVENT_SUBSCR(TENANT_ID_);

--ALTER TABLE ACT_RU_JOB
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_JOB_TENANT_ID on ACT_RU_JOB(TENANT_ID_);

ALTER TABLE ACT_RU_JOBDEF
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_JOBDEF_TENANT_ID on ACT_RU_JOBDEF(TENANT_ID_);

ALTER TABLE ACT_RU_INCIDENT
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_RU_IDENTITYLINK
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_INC_TENANT_ID on ACT_RU_INCIDENT(TENANT_ID_);

ALTER TABLE ACT_RU_EXT_TASK
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_EXT_TASK_TENANT_ID on ACT_RU_EXT_TASK(TENANT_ID_);

ALTER TABLE ACT_RE_DECISION_DEF
       DROP CONSTRAINT ACT_UNIQ_DECISION_DEF;

ALTER TABLE ACT_RE_DECISION_DEF
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_DEC_DEF_TENANT_ID on ACT_RE_DECISION_DEF(TENANT_ID_);

ALTER TABLE ACT_RE_CASE_DEF
       DROP CONSTRAINT ACT_UNIQ_CASE_DEF;

ALTER TABLE ACT_RE_CASE_DEF
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_CASE_DEF_TENANT_ID on ACT_RE_CASE_DEF(TENANT_ID_);

ALTER TABLE ACT_GE_BYTEARRAY
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_RU_CASE_EXECUTION
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_CASE_EXEC_TENANT_ID on ACT_RU_CASE_EXECUTION(TENANT_ID_);

ALTER TABLE ACT_RU_CASE_SENTRY_PART
  ADD TENANT_ID_ nvarchar(64);

-- user on historic decision instance --

ALTER TABLE ACT_HI_DECINST
  ADD USER_ID_ nvarchar(255);

-- tenant id on history --

--ALTER TABLE ACT_HI_PROCINST
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_PRO_INST_TENANT_ID on ACT_HI_PROCINST(TENANT_ID_);

--ALTER TABLE ACT_HI_ACTINST
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_ACT_INST_TENANT_ID on ACT_HI_ACTINST(TENANT_ID_);

--ALTER TABLE ACT_HI_TASKINST
--  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_TASK_INST_TENANT_ID on ACT_HI_TASKINST(TENANT_ID_);

ALTER TABLE ACT_HI_VARINST
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_VAR_INST_TENANT_ID on ACT_HI_VARINST(TENANT_ID_);

ALTER TABLE ACT_HI_DETAIL
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_DETAIL_TENANT_ID on ACT_HI_DETAIL(TENANT_ID_);

ALTER TABLE ACT_HI_INCIDENT
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_INCIDENT_TENANT_ID on ACT_HI_INCIDENT(TENANT_ID_);

ALTER TABLE ACT_HI_JOB_LOG
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_JOB_LOG_TENANT_ID on ACT_HI_JOB_LOG(TENANT_ID_);

ALTER TABLE ACT_HI_COMMENT
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_HI_ATTACHMENT
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_HI_OP_LOG
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_HI_DEC_IN
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_HI_DEC_OUT
  ADD TENANT_ID_ nvarchar(64);

ALTER TABLE ACT_HI_DECINST
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_DEC_INST_TENANT_ID on ACT_HI_DECINST(TENANT_ID_);

ALTER TABLE ACT_HI_CASEINST
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_CAS_I_TENANT_ID on ACT_HI_CASEINST(TENANT_ID_);

ALTER TABLE ACT_HI_CASEACTINST
  ADD TENANT_ID_ nvarchar(64);

create index ACT_IDX_HI_CAS_A_I_TENANT_ID on ACT_HI_CASEACTINST(TENANT_ID_);

-- add tenant table

create table ACT_ID_TENANT (
    ID_ nvarchar(64),
    REV_ int,
    NAME_ nvarchar(255),
    primary key (ID_)
);

create table ACT_ID_TENANT_MEMBER (
    ID_ nvarchar(64) not null,
    TENANT_ID_ nvarchar(64) not null,
    USER_ID_ nvarchar(64),
    GROUP_ID_ nvarchar(64),
    primary key (ID_)
);

alter table ACT_ID_TENANT_MEMBER
    add constraint ACT_FK_TENANT_MEMB
    foreign key (TENANT_ID_)
    references ACT_ID_TENANT (ID_);

alter table ACT_ID_TENANT_MEMBER
    add constraint ACT_FK_TENANT_MEMB_USER
    foreign key (USER_ID_)
    references ACT_ID_USER (ID_);

alter table ACT_ID_TENANT_MEMBER
    add constraint ACT_FK_TENANT_MEMB_GROUP
    foreign key (GROUP_ID_)
    references ACT_ID_GROUP (ID_);

create unique index ACT_UNIQ_TENANT_MEMB_USER on ACT_ID_TENANT_MEMBER (TENANT_ID_, USER_ID_) where USER_ID_ is not null;
create unique index ACT_UNIQ_TENANT_MEMB_GROUP on ACT_ID_TENANT_MEMBER (TENANT_ID_, GROUP_ID_) where GROUP_ID_ is not null;

--  BATCH --

-- remove not null from job definition table --
alter table ACT_RU_JOBDEF
	alter column PROC_DEF_ID_ nvarchar(64) null;
alter table ACT_RU_JOBDEF
	alter column PROC_DEF_KEY_ nvarchar(255) null;
alter table ACT_RU_JOBDEF
	alter column ACT_ID_ nvarchar(255) null;

create table ACT_RU_BATCH (
    ID_ nvarchar(64) not null,
    REV_ int not null,
    TYPE_ nvarchar(255),
    TOTAL_JOBS_ int,
    JOBS_CREATED_ int,
    JOBS_PER_SEED_ int,
    INVOCATIONS_PER_JOB_ int,
    SEED_JOB_DEF_ID_ nvarchar(64),
    BATCH_JOB_DEF_ID_ nvarchar(64),
    MONITOR_JOB_DEF_ID_ nvarchar(64),
    SUSPENSION_STATE_ tinyint,
    CONFIGURATION_ nvarchar(255),
    TENANT_ID_ nvarchar(64),
    primary key (ID_)
);

create table ACT_HI_BATCH (
    ID_ nvarchar(64) not null,
    TYPE_ nvarchar(255),
    TOTAL_JOBS_ int,
    JOBS_PER_SEED_ int,
    INVOCATIONS_PER_JOB_ int,
    SEED_JOB_DEF_ID_ nvarchar(64),
    MONITOR_JOB_DEF_ID_ nvarchar(64),
    BATCH_JOB_DEF_ID_ nvarchar(64),
    TENANT_ID_  nvarchar(64),
    START_TIME_ datetime2 not null,
    END_TIME_ datetime2,
    primary key (ID_)
);
--create table ACT_HI_IDENTITYLINK (
--    ID_ nvarchar(64) not null,
--    TIMESTAMP_ datetime2 not null,
--    TYPE_ nvarchar(255),
--    USER_ID_ nvarchar(255),
--    GROUP_ID_ nvarchar(255),
--    TASK_ID_ nvarchar(64),
--    PROC_DEF_ID_ nvarchar(64),
--    OPERATION_TYPE_ nvarchar(64),
--    ASSIGNER_ID_ nvarchar(64),
--    PROC_DEF_KEY_ nvarchar(255),
--    TENANT_ID_ nvarchar(64),
--    primary key (ID_)
--);
--create index ACT_IDX_HI_IDENT_LNK_USER on ACT_HI_IDENTITYLINK(USER_ID_);
create index ACT_IDX_HI_IDENT_LNK_GROUP on ACT_HI_IDENTITYLINK(GROUP_ID_);
--create index ACT_IDX_HI_IDENT_LNK_TENANT_ID on ACT_HI_IDENTITYLINK(TENANT_ID_);

create index ACT_IDX_JOB_JOB_DEF_ID on ACT_RU_JOB(JOB_DEF_ID_);
create index ACT_IDX_HI_JOB_LOG_JOB_DEF_ID on ACT_HI_JOB_LOG(JOB_DEF_ID_);

create index ACT_IDX_BATCH_SEED_JOB_DEF ON ACT_RU_BATCH(SEED_JOB_DEF_ID_);
alter table ACT_RU_BATCH
    add constraint ACT_FK_BATCH_SEED_JOB_DEF
    foreign key (SEED_JOB_DEF_ID_)
    references ACT_RU_JOBDEF (ID_);

create index ACT_IDX_BATCH_MONITOR_JOB_DEF ON ACT_RU_BATCH(MONITOR_JOB_DEF_ID_);
alter table ACT_RU_BATCH
    add constraint ACT_FK_BATCH_MONITOR_JOB_DEF
    foreign key (MONITOR_JOB_DEF_ID_)
    references ACT_RU_JOBDEF (ID_);

create index ACT_IDX_BATCH_JOB_DEF ON ACT_RU_BATCH(BATCH_JOB_DEF_ID_);
alter table ACT_RU_BATCH
    add constraint ACT_FK_BATCH_JOB_DEF
    foreign key (BATCH_JOB_DEF_ID_)
    references ACT_RU_JOBDEF (ID_);


-- TASK PRIORITY --

ALTER TABLE ACT_RU_EXT_TASK
  ADD PRIORITY_ numeric(19,0) NOT NULL DEFAULT 0;

create index ACT_IDX_EXT_TASK_PRIORITY ON ACT_RU_EXT_TASK(PRIORITY_);

-- HI OP PROC INDECIES --

create index ACT_IDX_HI_OP_LOG_PROCINST on ACT_HI_OP_LOG(PROC_INST_ID_);
create index ACT_IDX_HI_OP_LOG_PROCDEF on ACT_HI_OP_LOG(PROC_DEF_ID_);

-- JOB_DEF_ID_ on INCIDENTS --
ALTER TABLE ACT_RU_INCIDENT
  ADD JOB_DEF_ID_ nvarchar(64);

create index ACT_IDX_INCIDENT_JOB_DEF on ACT_RU_INCIDENT(JOB_DEF_ID_);
alter table ACT_RU_INCIDENT
    add constraint ACT_FK_INC_JOB_DEF
    foreign key (JOB_DEF_ID_)
    references ACT_RU_JOBDEF (ID_);

ALTER TABLE ACT_HI_INCIDENT
  ADD JOB_DEF_ID_ nvarchar(64);

-- BATCH_ID_ on ACT_HI_OP_LOG --
ALTER TABLE ACT_HI_OP_LOG
  ADD BATCH_ID_ nvarchar(64);
