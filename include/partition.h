#ifndef _PARTN_H
#define _PARTN_H

#define TOTAL_PARTITIONS 10
#define PARTITION_SIZE 2097168
#define BLOCK_SIZE 20971682
                   
// 1024 * 1024 * 10 + 160 + 2
// (keeping 16 bytes extra for every partition, assuming there are 10 partations)
// 2 bytes extra for bitmap   __
//                           ('')
//                         _/|__|\_
//                           |  |                        
//


#ifndef GT_PTNS
#define GT_PTNS
int get_partition(char *, int, int);
#endif

#endif