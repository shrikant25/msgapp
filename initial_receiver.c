#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <syslog.h>
#include <fcntl.h>
#include <sys/socket.h> // contains important fucntionality and api used to create sockets
#include <sys/types.h>  // contains various types required to create a socket   
#include <netinet/in.h> // contains structures to store address information
#include <arpa/inet.h>
#include <sys/types.h>
#include <libpq-fe.h>
#include "initial_receiver.h"

server_info s_info;
PGconn *connection;


void store_data_in_database(int client_socket, char *data) {

    PGresult *res;

    char fd[11];
    sprintf(fd, "%d", client_socket);
   
    const char *const param_values[] = {fd, data};
    const int paramLengths[] = {sizeof(fd), strlen(data)};
    const int paramFormats[] = {0, 1};
    int resultFormat = 0;
    
    res = PQexecPrepared(connection, dbs[1].statement_name, dbs[1].param_count, param_values, paramLengths, paramFormats, 0);
    if (PQresultStatus(res) != PGRES_COMMAND_OK) {
        storelog("%s%s", "Message storing failed in initial receiver : ", PQerrorMessage(connection));
    }

    PQclear(res);
}


void run_server() {
    
    int client_socket, data_read, total_data_read, network_status;
    char data[MESSAGE_SIZE+1];
    struct sockaddr_in server_address; 
    struct sockaddr_in client_address;
    socklen_t addr_len = sizeof(client_address);

    if ((s_info.servsoc_fd = socket(AF_INET, SOCK_STREAM, 0)) == -1) {
        storelog("%s%s", "intial receiver failed to create a socket for listening : ", strerror(errno));
        return;
    }
    
    server_address.sin_family = AF_INET;    
    server_address.sin_port = htons(s_info.port);  
    server_address.sin_addr.s_addr = htonl(s_info.ipaddress); 

    if (bind(s_info.servsoc_fd, (struct sockaddr *)&server_address, sizeof(server_address)) == -1) {
        storelog("%s%s", "initial receiver failed to bind : ", strerror(errno));
        return;
    }

    if (listen(s_info.servsoc_fd, 100) == -1) {
        storelog("%s%s", "initial receiver failed to listen : ", strerror(errno));
        return;
    }  

    while (1) {
        

        client_socket = accept(s_info.servsoc_fd, (struct  sockaddr *)&client_address, &addr_len);
       
        if (client_socket >= 0) {
            
            memset(data, 0, sizeof(data));
            data_read = total_data_read = 0;

            do {    

                data_read = read(client_socket, data+total_data_read, MESSAGE_SIZE);     
                total_data_read += data_read;

            } while(total_data_read < MESSAGE_SIZE && data_read > 0);

            if (total_data_read != MESSAGE_SIZE) {
                storelog("%s%d%s%d", "data receiving failure size : ", total_data_read, ", fd : ",client_socket);
            }
            else {
                store_data_in_database(client_socket, data);
            }
            close(client_socket);
        }
        else {
            sprintf("%s%s", "inital receiver failed to accept client connection : ", strerror(errno));
        }
    }
    
    close(s_info.servsoc_fd);
    
}


int connect_to_database(char *conninfo) 
{   
    connection = PQconnectdb(conninfo);
    if (PQstatus(connection) != CONNECTION_OK) {
        syslog(LOG_NOTICE, "Connection to database failed: %s\n", PQerrorMessage(connection));
        return -1;
    }

    return 0;
}


int prepare_statements() 
{    
    int i, status = 0;

    for (i = 0; i<statement_count; i++){

        PGresult* res = PQprepare(connection, dbs[i].statement_name, dbs[i].statement, dbs[i].param_count, NULL);
        if (PQresultStatus(res) != PGRES_COMMAND_OK) {
            syslog(LOG_NOTICE, "Preparation of statement failed: %s\n", PQerrorMessage(connection));
            status = -1;
            PQclear(res);
            break;
        }

        PQclear(res);
    }
    
    return status;
}


int main(int argc, char *argv[]) 
{
    int status = -1;
    int conffd = -1;
    char buf[100];
    char db_conn_command[100];
    char username[30];
    char dbname[30];

    if (argc != 2) {
        syslog(LOG_NOTICE,"invalid arguments");
        return -1;
    }
   
    if ((conffd = open(argv[1], O_RDONLY)) == -1) {
        syslog(LOG_NOTICE, "failed to open configuration file");
        return -1;
    }

    memset(buf, 0, sizeof(buf));
    if (read(conffd, buf, sizeof(buf)) > 0) {
       
        sscanf(buf, "USERNAME=%s\nDBNAME=%s\nPORT=%d\nIPADDRESS=%lu", username, dbname, &s_info.port, &s_info.ipaddress);
    }
    else {
        syslog(LOG_NOTICE, "failed to read configuration file");
        return -1;
    }

    close(conffd);

    memset(db_conn_command, 0, sizeof(db_conn_command));
    sprintf(db_conn_command, "user=%s dbname=%s", username, dbname);

    if (connect_to_database(db_conn_command) == -1) { return -1; }
    if (prepare_statements() == -1) { return -1; }     

    run_server();
    PQfinish(connection);

    return 0;
}
