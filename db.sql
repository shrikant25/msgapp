
-- launch every second
SELECT pgcron.schedule('* * * * * *', 'call_jobs;');
-- call jobs function yet to be written


CREATE TABLE receivers_comms (rcid SERIAL PRIMARY KEY, 
                              mdata text NOT NULL, 
                              destination int NOT NULL DEFAULT 1);

CREATE TABLE connections_receiving (orid SERIAL PRIMARY KEY, 
                                    fd int NOT NULL, 
                                    ipaddr bigint NOT NULL, 
                                    rcstatus int NOT NULL);

CREATE TABLE senders_comms (scid SERIAL PRIMARY KEY, 
                            mdata text NOT NULL, 
                            destination int NOT NULL DEFAULT 1);

CREATE TABLE connections_sending (osid SERIAL PRIMARY KEY, 
                                  fd int NOT NULL,
                                  ipaddr bigint NOT NULL, 
                                  scstatus int NOT NULL);

CREATE TABLE raw_data (fd int PRIMARY KEY, 
                       data text NOT NULL, 
                       data_size int NOT NULL,
                       priority int NOT NULL);


CREATE TABLE query (queryid int PRIMARY KEY,
                    query text);



CREATE TABLE sysinfo (system_name char(2) PRIMARY key,
                        ipaddress bigint,
                        receiving_capacity int);

CREATE TABLE log (lgid serial PRIMARY KEY,
                  msgid text,
                  mstatus text);


CREATE TRIGGER tr_extract_msg_info 
AFTER INSERT ON new_msg 
FOR EACH ROW EXCUTE extract_msg_info();

CREATE TRIGGER tr_extract_receivers_comms 
AFTER INSERT ON receivers_comms 
FOR EACH ROW EXCUTE extract_receivers_comms();

CREATE FUNCTION extract_receivers_comms () 
RETURNS void AS
'
DECLARE
    l_msgtype int;
BEGIN

    IF NEW.destination = 1 THEN        
        
        SELECT SUBSTRING(new.mdata, 1, 4)::int 
        INTO l_msgtype;
        
        IF msgtype = 1 THEN
            
            INSERT INTO connections_receiving(fd, ipaddr, rcstatus)
            VALUES (SUBSTRING(NEW.mdata, 5, 4)::int, 
            SUBSTRING(NEW.mdata, 9, 8)::bigint, 
            STATUS = 1);
        
        ELIF msgtype = 2 THEN
        
            UPDATE connections_receiving 
            SET rcstatus = 2 
            WHERE fd = SUBSTRING(NEW.mdata, 5, 4)::int;
        
        ENDIF;

        DELETE FROM receivers_comms 
        WHERE rcid = new.rcid;   
    
    ENDIF;
END;
'
LANGUAGE 'PLPGSQL';


CREATE TRIGGER tr_extract_senders_comms 
AFTER INSERT ON senders_comms 
FOR EACH ROW EXCUTE extract_senders_comms();

CREATE FUNCTION extract_senders_comms() 
RETURNS void AS
'
DECLARE
    l_msgtype int;
    l_msgstatus int;
BEGIN

    IF NEW.destination = 1 THEN        
        
        SELECT SUBSTRING(new.mdata, 1, 4)::int, 
        SUBSTRING(new.mdata, 5, 4)::int 
        INTO l_msgtype, l_msgstatus;
        
        IF msgtype = 3 THEN
            
            IF l_msgstatus = 3 THEN

                UPDATE connections_sendign 
                SET scstatus = l_msgstatus,
                fd = SUBSTRING(17, 4)::int
                WHERE ipaddr = SUBSTRING(new.mdata, 9, 8)::bigint;
            
            ELIF l_msgstatus = 1 THEN 

                UPDATE connections_sending 
                SET scstatus = l_msgstatus,
                WHERE ipaddr = SUBSTRING(new.mdata, 9, 8)::bigint;

            ENDIF;           

        ELIF msgtype = 4 THEN
        
            UPDATE send_data 
            SET status = l_msgstatus 
            WHERE sdid = SUBSTRING(NEW.mdata, 9, 4)::int;
        
        ENDIF;

        DELETE FROM senders_comms 
        WHERE scid = new.scid;   
    
    ENDIF;
END;
'
LANGUAGE 'PLPGSQL';


CREATE FUNCTION build_msg() 
RETURNS void AS
'
DECLARE
    lfd int;
    ldata text;
    ldata_size int;
    ldata_read int;
    lmdata_size int;
BEGIN
    
    SELECT fd, data, data_size FROM raw_data into lfd, ldata, ldata_size;
    ldata_read := 0;

    LOOP UNTIL ldata_size - ldata_read >= 40
      
        SELECT into lmdata_size SUBSTRING(ldata, 1, 4);
        IF ldata_size - ldata_read >= lmdata_size THEN
            
            INSERT INTO new_msg (nmdata_size, nmdata) 
            VALUES lmdata_size, (SUBSTRING(ldata, ldata_read+1, lmdata_size));

            ldata_read := ldata_read + lmdata_size;
    END LOOP;

    IF ldata_read > 0 THEN
        
        UPDATE raw_data 
        SET data = SUBSTRING(data, ldata_read+1, ldata_size - ldata_read),
        ldata_size = ldata_read, 
        priority = 10
        WHERE fd = lfd;

    ENDIF;

END;
'
LANGUAGE 'PLPGSQL';


CREATE FUNCTION extract_msg_info() 
RETURNS void AS
'
DECLARE
    l_nmdata text;
    l_nmid int;
    l_query text;
    
BEGIN
    
    SELECT nmdata, nmgid 
    INTO l_nmdata, l_nmid 
    FROM new_msg 
    WHERE status = 2 
    LIMIT 1;

    SELECT query 
    FROM query_table 
    WHERE queryid = SUBSTRING(l_nmdata, 5, 4)::int 
    INTO l_query;

    EXECUTE query;

    DELETE FROM new_msg 
    WHERE nmgid = l_nmid;

END;
'
LANGUAGE 'PLPGSQL';


CREATE TRIGGER tr_merge_msg
AFTER INSERT, UPDATE ON msg_info
FOR EACH ROW EXECUTE merged_msg();

CREATE FUNCTION merge_msg()
RETURN void AS
'
DECLARE 
    msg text;
    invalid_chunks int[];
BEGIN

    IF new.total_parts > 0 and new.parts_recieved = new.total_parts THEN

        SELECT array_agg(C.chunk_number)
        INTO invalid_chunks 
        FROM (
            SELECT row_number() over() 
            as row_numb, md5_elem
            FROM unnset(NEW.md5_list) 
            AS md5_elem
        ) AS M
        JOIN msg_chunk AS C
        ON C.chunk_number = M.row_num
        WHERE C.md5_hash <> M.md5_elem;

        IF array_length(invalid_chunkd) > 0 THEN
        
            SELECT handle_invalid_chunks(invalid_chunks);
        
        ELSE
        
            INSERT INTO msg (msgid, source, size, mdata) 
            SELECT NEW.original_msgid, 
                NEW.source,
                NEW.total_size,
                string_agg(m.mdata, ''''), 
            FROM msg_chunk as m 
            WHERE NEW.original_msgid = m.original_msgid
            group by m.original_msgid
            order by m.chunk_number;

        ENDIF;
    ENDIF;
END;
'
LANGUAGE 'PLPGSQL';

--todo : write function for  handle_invalid_chunks
--CREATE FUNCTION handle_invalid_chunks(chunk_ids text[])
--RETURN void AS
--'
--BEGIN
    -- create a message that is consist of list of ids
    -- insert that message in send_data with destination
    -- same as senders destinatoin for these ids

    -- update the msg info table reduce the count of 
    -- messages

    -- remove the chunks from msg_chunk
--END
--' 
--LANGUAGE 'PLPGSQL';

CREATE TRIGGER tr_update_chunk_count 
AFTER INSERT ON msg_chunk
FOR EACH ROW EXECUTE update_chunk_count();

CREATE OR REPLACE FUNCTION update_chunk_count()
RETURNS void AS
'
BEGIN
    INSERT INTO msg_info (original_msgid, parts_received)
    VALUES (new.original_msgid, 1) 
    ON CONFLICT (original_msgid)
    DO UPDATE
    SET parts_received = parts_received + 1;  
END;
'
LANGUAGE 'PLPGSQL'; 


INSERT INTO query VALUES (1, 'INSERT INTO msg_chunk VALUES(
                            SUBSTRING( l_nmdata, 9, 16),
                            SUBSTRING( l_nmdata, 25, 8)::bigint,
                            SUBSTRING( l_nmdata, 33, 8)::bigint,
                            SUBSTRING( l_nmdata, 41, 4)::int,
                            SUBSTRING( l_nmdata, 5, 4)::int,
                            SUBSTRING( l_nmdata, 45, 16),
                            SUBSTRING( l_nmdata, 61, 4)::int,
                            SUBSTRING( l_nmdata, 65, 4)::int,
                            SUBSTRING( l_nmdata, 69, 4)::int,
                            SUBSTRING( l_nmdata, 73, SUBSTRING(l_mdata, 1, 4)::int - 72)
                            )'
                        );


INSERT INTO query VALUES (2, 'INSERT INTO msg_info VALUES(
                            SUBSTRING( l_nmdata, 9, 16),
                            SUBSTRING( l_nmdata, 25, 8)::bigint,
                            SUBSTRING( l_nmdata, 33, 8)::bigint,
                            SUBSTRING( l_nmdata, 41, 4)::int,
                            SUBSTRING( l_nmdata, 5, 4)::int,
                            SUBSTRING( l_nmdata, 45, 16),
                            SUBSTRING( l_nmdata, 61, 4)::int,
                            SUBSTRING( l_nmdata, 65, 4)::int,
                            SUBSTRING( l_nmdata, 69, 4)::int
                            )'
                        );

INSERT INTO query VALUES (3, 'INSERT INTO get_info VALUES(
                            SUBSTRING( l_nmdata, 9, 16),
                            SUBSTRING( l_nmdata, 25, 4)::int,
                            SUBSTRING( l_nmdata, 29, 4)::int,
                            SUBSTRING( l_nmdata, 32, SUBSTRING(l_mdata, 1, 4)::int - 72)
                            )'
                        );

INSERT INTO query VALUES (4, 'INSERT INTO get_info VALUES(
                            SUBSTRING( l_nmdata, 9, 16),
                            SUBSTRING( l_nmdata, 33, 8)::int,
                            SUBSTRING( l_nmdata, 1, 4)::int,
                            l_nmdata
                            )'
                        );

