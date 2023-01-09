#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "shared_memory.h"
#include "partition.h"
#include <semaphore.h>
#include "bitmap.h"
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>
#include <libpq-fe.h>

#define BUFSIZE 50000


typedef struct idata{
    int msgtype;
    int msgid;
    int substrid;
}idata;

typedef struct mdata{
    int msgtype;
    int msgid;
}mdata;

typedef struct mupdate{
    int msgtype;
    int msgid;
    int total;
}mupdate;


idata idataobj[1160];
mdata mdataobj[9];
mupdate mupdateobj[9];


void do_exit(PGconn *conn) {

    PQfinish(conn);
    exit(1);
}


void get_data(){

    int j,k = 0;
    char query[100];
    char id[10];
	int rows;

    PGconn *connection = PQconnectdb("user=shrikant dbname=shrikant");

    if (PQstatus(connection) == CONNECTION_BAD) {

        fprintf(stderr, "Connection to database failed: %s\n",
            PQerrorMessage(connection));
        do_exit(connection);
    }


	for(int i =0; i<9; i++){
		memset(query, 0, 100);
		memset(id, 0, 10);
		
		strcpy(query, "select * from substrings where msgid = ");
		sprintf(id, "%d", i+1);
		strcat(query, id);
			
		PGresult *result = PQexec(connection, query);
		rows = PQntuples(result);

		if (PQresultStatus(result) != PGRES_TUPLES_OK) {

			printf("No data retrieved\n");
			PQclear(result);
			do_exit(connection);
		}
			
		mupdateobj[i].msgtype = 3;
		mupdateobj[i].msgid = atoi(PQgetvalue(result, 0, 2));
		mupdateobj[i].total = rows;

		mdataobj[i].msgtype = 2; 
		mdataobj[i].msgid = atoi(PQgetvalue(result, 0, 2));


		for(j=0; j<rows; j++){
			idataobj[k].msgid = atoi(PQgetvalue(result, 0, 2));
			idataobj[k].msgtype = 1;
			idataobj[k].substrid = atoi(PQgetvalue(result, j, 0));
			k++;
    	}
	
		PQclear(result);
		printf("%d\n",i);
	}
	
    PQfinish(connection);
   
}


void randomize(){

	int i;
	idata temp;
	
	for(i = 0; i<1160/2; i++){
		memcpy(&temp, &idataobj[i], sizeof(idata));
		memcpy(&idataobj[i], &idataobj[i+3], sizeof(idata));
		memcpy(&idataobj[i+3], &temp, sizeof(idata));
	}
	
	mupdate temp2;
	memcpy(&temp2, &mupdateobj[5], sizeof(mupdate));
	memcpy(&mupdateobj[5], &mupdateobj[2],sizeof(mupdate));
	memcpy(&mupdateobj[2], &temp2, sizeof(mupdate));
	
}


void get_string(int id, int substrid, char *blkptr){
	
	int i,j;
    char query[100];
    char mid[10];
    char msubid[10];
	char *value = NULL;

    PGconn *connection = PQconnectdb("user=shrikant dbname=shrikant");

    if (PQstatus(connection) == CONNECTION_BAD) {

        fprintf(stderr, "Connection to database failed: %s\n",
            PQerrorMessage(connection));
        do_exit(connection);
    }

	sprintf(mid, "%d", id);
	sprintf(msubid, "%d", substrid);
		
	strcpy(query, " select substring from substrings where msgid = ");
	strcat(query, mid);
	strcat(query, " and substrid = ");
	strcat(query, msubid);
	
	 
    PGresult *result = PQexec(connection, query);

    if (PQresultStatus(result) != PGRES_TUPLES_OK) {

		printf("No data retrieved\n");
		PQclear(result);
		do_exit(connection);
    }

	value =  PQgetvalue(result, 0, 0);
	strncpy(blkptr+12, value, 1024*1024);
	
	PQclear(result);
    PQfinish(connection);
}


int main(void){

    int i, j = 0;
	int start_pos = 0;
	int empty_partition_position = -1;
    char *blkptr = NULL;
	
    char *block = attach_memory_block(FILENAME, BLOCK_SIZE);
	if(block == NULL) {
        printf("unable to create a shared block");
        return -1;
    }
	

	get_data();
	
	sem_t *sem = sem_open(SEM_LOCK, O_CREAT, 0777, 1);
	if(sem ==  SEM_FAILED){
        printf("unable to create a semaphore");
        return -1;
    }
	
	sem_wait(sem);
	unset_all_bits(block);
	sem_post(sem);
printf("offf");
	start_pos = -1;
	for(i = 0; i<9;){
		
		sem_wait(sem);
		empty_partition_position = get_partition(block, 0, start_pos);
	
		if(empty_partition_position >= 0){
			start_pos = empty_partition_position;
			blkptr = block + (empty_partition_position*PARTITION_SIZE);
			memcpy(blkptr, &mdataobj[i].msgtype, 4);
			memcpy(blkptr+4, &mdataobj[i].msgid, 4);
			toggle_bit(empty_partition_position, block);
			i++;
			
		}
		empty_partition_position = -1;
		sem_post(sem);
	}
	
	blkptr = NULL;
	int flag = 0;
	start_pos = -1;
	
	for(i=0; i<1160; ){
	
	sem_wait(sem);
		empty_partition_position = get_partition(block, 0, start_pos);
		
	
		if(empty_partition_position >= 0){
			start_pos = empty_partition_position;
			blkptr = block +(empty_partition_position*PARTITION_SIZE);
				
			if(j<9 && (i%10==0) && !flag){
				flag  = 1;
				
				memcpy(blkptr, &mupdateobj[j].msgtype, 4);
				memcpy(blkptr+4, &mupdateobj[j].msgid, 4);
				memcpy(blkptr+8, &mupdateobj[j].total, 4);
				j++;

			}else{
				
				memcpy(blkptr, &idataobj[i].msgtype, 4);
				memcpy(blkptr+4, &idataobj[i].msgid, 4);
				memcpy(blkptr+8, &idataobj[i].substrid, 4);
				get_string(idataobj[i].msgid, idataobj[i].substrid, blkptr);
				flag = 0;
				i++;
			}

			toggle_bit(empty_partition_position, block);
		
		}
		blkptr = NULL;
		empty_partition_position = -1;
		sem_post(sem);
		
	}
	
    detach_memory_block(block);
    
    return 0;
}
