
DROP TABLE logs, receivers_comms, receiving_conns, job_scheduler, sysinfo, senders_comms, sending_conns;


CREATE TABLE job_scheduler (jidx SERIAL PRIMARY KEY, 
                        jobdata bytea NOT NULL,
                        jstate CHAR(5) NOT NULL DEFAULT 'N-1',
                        jtype TEXT NOT NULL DEFAULT '1',
                        jsource TEXT NOT NULL,
                        jobid UUID UNIQUE NOT NULL,
                        jparent_jobid UUID REFERENCES job_scheduler(jobid) 
                            ON UPDATE CASCADE ON DELETE CASCADE,
                        jdestination TEXT NOT NULL DEFAULT 0,
                        jpriority  TEXT NOT NULL DEFAULT '10',
                        jcreation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);


CREATE TABLE receivers_comms (rcomid SERIAL PRIMARY KEY, 
                              mdata bytea NOT NULL, 
                              mtype INTEGER NOT NULL);

CREATE TABLE receiving_conns (rfd TEXT NOT NULL PRIMARY KEY, 
                              ripaddr TEXT NOT NULL, 
                              rcstatus TEXT NOT NULL,
                              rctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE sending_conns (sconnid SERIAL PRIMARY KEY, 
                            sfd INTEGER NOT NULL,
                            sipaddr BIGINT NOT NULL, 
                            scstatus SMALLINT NOT NULL,
                            sctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE senders_comms (scommid SERIAL PRIMARY KEY, 
                            mdata1 BIGINT NOT NULL,
                            mdata2 INTEGER NOT NULL, 
                            mtype SMALLINT NOT NULL);

CREATE TABLE logs (logid SERIAL PRIMARY KEY,
                   log TEXT NOT NULL,
                   lgtime TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE sysinfo (system_name CHAR(10) PRIMARY key,
                        ipaddress BIGINT NOT NULL,
                        port INTEGER NOT NULL,
                        systems_capacity INTEGER NOT NULL);


CREATE OR REPLACE FUNCTION create_message(
    message_type text,
    messaget bytea,
    message_source text,
    message_destination text,
    message_priority text
) RETURNS bytea
AS
$$
DECLARE   
    hnmessage bytea;
    fixed_type text;
    fixed_source text;
    fixed_destination text;
    fixed_priority text;
BEGIN
    fixed_type := lpad(message_type, 5, ' ');
    fixed_source := lpad(message_source, 5, ' ');
    fixed_destination := lpad(message_destination, 5, ' ');
    fixed_priority := lpad(message_priority, 5, ' ');
    
    hnmessage := gen_random_uuid()::text::bytea || fixed_type::bytea || 
                fixed_source::bytea || fixed_destination::bytea || 
                fixed_priority::bytea ||  to_char(now(), 'YYYY-MM-DD HH24:MI:SS.US')::bytea || messaget;
    
    RETURN md5(hnmessage)::bytea || hnmessage;
END;
$$
LANGUAGE 'plpgsql';


INSERT INTO job_scheduler
    (jobdata, jstate, jtype, jsource, 
        jobid, jparent_jobid, jdestination, jpriority) 
VALUES('__ROOT__', 'N-0', '0', '   M3', 
    GEN_RANDOM_UUID(), NULL, '   M3', 0);

UPDATE job_scheduler 
SET jparent_jobid = jobid 
WHERE jidx = 1;

ALTER TABLE job_scheduler 
ALTER COLUMN jparent_jobid
SET NOT NULL;
