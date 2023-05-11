CC = gcc
FS_DIR = $(shell pwd)
LOCAL_INCLUDE_DIR = $(FS_DIR)/include
PSQL_INCLUDE_DIR = /usr/include/postgresql

CFLAGS = -I$(LOCAL_INCLUDE_DIR) -I$(PSQL_INCLUDE_DIR) -lpq -g -lpthread -std=c99 -mcmodel=large

processor_r_target = processor_r
processor_r_files := processor_r.c shared_memory.c partition.c 

processor_s_target = processor_s
processor_s_files := processor_s.c shared_memory.c partition.c 

sender_notif_target = sender_notif
sender_notif_files := sender_notif.c 

sender_target = sender
sender_files := sender.c shared_memory.c partition.c 

initial_receiver_target = initial_receiver
initial_receiver_files := initial_receiver.c 

initial_sender_target = initial_sender
initial_sender_files := initial_sender.c

receiver_target = receiver
receiver_files := receiver.c shared_memory.c partition.c 

launcher_target = launcher
launcher_files := launcher.c

user_program_target = user_program
user_program_files := user_program.c

launcher:
	$(CC) $(processor_r_files) -o $(processor_r_target) $(CFLAGS)
	$(CC) $(processor_s_files) -o $(processor_s_target) $(CFLAGS) 
	$(CC) $(sender_notif_files) -o $(sender_notif_target) $(CFLAGS)
	$(CC) $(sender_files) -o $(sender_target) $(CFLAGS)
	$(CC) $(receiver_files) -o $(receiver_target) $(CFLAGS)
	$(CC) $(initial_receiver_files) -o $(initial_receiver_target) $(CFLAGS)
	$(CC) $(initial_sender_files) -o $(initial_sender_target) $(CFLAGS)
	$(CC) $(launcher_files) -o $(launcher_target) $(CFLAGS)
	$(CC) $(user_program_files) -o $(user_program_target) $(CFLAGS)

clean:
	rm processor_r processor_s receiver sender sender_notif launcher user_program