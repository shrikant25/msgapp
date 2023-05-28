DROP TRIGGER IF EXISTS msg_for_sender1 ON job_scheduler;
DROP TRIGGER IF EXISTS msg_for_sender2 ON senders_comms;
DROP TRIGGER IF EXISTS msg_for_receiver ON receivers_comms;
DROP TRIGGER IF EXISTS create_msg_receiver ON sysinfo;
DROP TABLE IF EXISTS logs, receivers_comms, receiving_conns, job_scheduler, sysinfo, 
                        senders_comms, sending_conns, files, selfinfo;
DROP FUNCTION IF EXISTS send_noti1(), send_noti2(), send_noti3(), create_comms(), create_message(bytea, text, bytea, bytea, text, text, text, int);
UNLISTEN noti_1sys;
UNLISTEN noti_1initial;
UNLISTEN noti_1receiver;

CREATE TABLE job_scheduler (jobid UUID PRIMARY KEY, 
                            jobdata bytea NOT NULL,
                            jstate CHAR(5) NOT NULL DEFAULT 'N-1',
                            jtype TEXT NOT NULL DEFAULT '1',
                            jsource TEXT NOT NULL,
                            jparent_jobid UUID 
                                REFERENCES job_scheduler(jobid) 
                                ON UPDATE CASCADE 
                                ON DELETE CASCADE,
                            jdestination TEXT NOT NULL DEFAULT 0,
                            jpriority  TEXT NOT NULL DEFAULT '10',
                            jcreation_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP);


CREATE TABLE receivers_comms (rcomid SERIAL PRIMARY KEY, 
                              rdata1 BIGINT NOT NULL,
                              rdata2 BIGINT NOT NULL);

CREATE TABLE receiving_conns (rfd INTEGER PRIMARY KEY, 
                              ripaddr BIGINT NOT NULL, 
                              rcstatus INTEGER NOT NULL,
                              rctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE sending_conns (sfd INTEGER PRIMARY KEY,
                            sipaddr BIGINT NOT NULL, 
                            scstatus INTEGER NOT NULL,
                            sctime TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE senders_comms (scommid SERIAL PRIMARY KEY, 
                            mdata1 BIGINT NOT NULL,
                            mdata2 INTEGER NOT NULL, 
                            mtype INTEGER NOT NULL);

CREATE TABLE logs (logid SERIAL PRIMARY KEY,
                   log TEXT NOT NULL,
                   lgtime TIMESTAMP DEFAULT CURRENT_TIMESTAMP);

CREATE TABLE sysinfo (system_name CHAR(10),
                      ipaddress BIGINT UNIQUE,
                      dataport INTEGER,
                      comssport INTEGER NOT NULL,
                      system_capacity INTEGER,
                      CONSTRAINT pk_sysinfo PRIMARY KEY(system_name, ipaddress));

CREATE TABLE selfinfo (system_name CHAR(10) NOT NULL,
                      ipaddress BIGINT UNIQUE NOT NULL,
                      dataport INTEGER NOT NULL,
                      comssport INTEGER NOT NULL,
                      system_capacity INTEGER NOT NULL);


CREATE TABLE files (file_id UUID PRIMARY KEY, 
                        file_name TEXT UNIQUE NOT NULL,  
                        file_data oid NOT NULL, 
                        creation_time TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP); 


CREATE OR REPLACE FUNCTION create_message(
    uuid_data bytea,
    message_type text,
    subheader bytea,
    messaget bytea,
    message_source text,
    message_destination text,
    message_priority text,
    max_capacity int
) RETURNS bytea
AS
$$
DECLARE   
    hnmessage bytea;
    fixed_type text;
    fixed_source text;
    fixed_destination text;
    fixed_priority text;
    extra_pad text;
    size_difference int;
BEGIN
    fixed_type := lpad(message_type, 5, ' ');
    fixed_source := lpad(message_source, 5, ' ');
    fixed_destination := lpad(message_destination, 5, ' ');
    fixed_priority := lpad(message_priority, 5, ' ');
    
    hnmessage := uuid_data || fixed_type::bytea || 
                fixed_source::bytea || fixed_destination::bytea || 
                fixed_priority::bytea ||  to_char(now(), 'YYYY-MM-DD HH24:MI:SS.US')::bytea || subheader || messaget;

    extra_pad := '';
    size_difference := (max_capacity - 32) - length(hnmessage);

    IF size_difference > 0 THEN
        extra_pad := lpad(extra_pad, size_difference, ' ');  
        hnmessage := hnmessage || extra_pad::bytea;
    END IF;
    
    return md5(hnmessage)::bytea || hnmessage;

END;
$$
LANGUAGE 'plpgsql';


INSERT INTO 
    selfinfo 
VALUES(
        lpad('M3', 5, ' '), 
        2130706433, 
        6001,
        6000, 
        1024*32
);


INSERT INTO 
    job_scheduler(jobdata, jstate, jtype, jsource, 
    jobid, jparent_jobid, jdestination, jpriority) 
VALUES (
        '__ROOT__', 
        'N-0', 
        '0', 
        lpad('M3', 5, ' '), 
        GEN_RANDOM_UUID(), 
        NULL, 
        lpad('M3', 5, ' '), 
        0
);


UPDATE 
    job_scheduler 
SET 
    jparent_jobid = jobid 
WHERE 
    jobdata = '__ROOT__';


ALTER TABLE 
    job_scheduler 
ALTER COLUMN 
    jparent_jobid
SET NOT NULL;


CREATE OR REPLACE FUNCTION send_noti3()
RETURNS TRIGGER AS
$$
BEGIN
    PERFORM pg_notify('noti_1receiver', 'get_data');
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE TRIGGER
    msg_for_receiver
AFTER INSERT ON
    receivers_comms
FOR EACH ROW 
EXECUTE FUNCTION
    send_noti3();


CREATE OR REPLACE FUNCTION create_comms ()
RETURNS TRIGGER AS
$$
BEGIN
    INSERT INTO receivers_comms(rdata1, rdata2) VALUES (NEW.ipaddress, NEW.system_capacity);
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE TRIGGER
    create_msg_receiver
AFTER INSERT OR UPDATE ON
    sysinfo
FOR EACH ROW
WHEN
    (NEW.system_capacity != 0)
EXECUTE FUNCTION
    create_comms();


CREATE OR REPLACE FUNCTION send_noti1()
RETURNS TRIGGER AS 
$$
BEGIN
    PERFORM pg_notify('noti_1sys', 'get_data');
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;


CREATE TRIGGER 
    msg_for_sender1
AFTER UPDATE ON 
    job_scheduler
FOR EACH ROW 
WHEN 
    (NEW.jstate = 'S-4')
EXECUTE FUNCTION 
    send_noti1();


CREATE TRIGGER 
    msg_for_sender2
AFTER INSERT ON 
    senders_comms
FOR EACH ROW 
WHEN 
    (NEW.mtype = 1)
EXECUTE FUNCTION 
    send_noti1();



CREATE OR REPLACE FUNCTION send_noti2()
RETURNS TRIGGER AS 
$$
BEGIN
    RAISE NOTICE 'hello';
    PERFORM pg_notify('noti_1initial', 'get_data');
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;



CREATE TRIGGER 
    msg_for_initial_sender
AFTER INSERT ON 
    job_scheduler
FOR EACH ROW 
WHEN 
    (NEW.jstate = 'S-5')
EXECUTE FUNCTION 
    send_noti2();




