#ifndef H_HASH_TABLE
#define H_HASH_TABLE

typedef struct datanode {
    unsigned int key;
    unsigned int value;
    struct datanode *next;
} datanode;

typedef struct hashtable {
    datanode **table;
    datanode *nodepool;
    unsigned int available_node_count;
    unsigned int table_size;
    unsigned int hash_seed;
} hashtable;

int hdel (hashtable *_htable_name, int _hkey);
int hcreate_table(hashtable *_hhtable, int _hsize, int _hhash_seed);
int hget (hashtable *_htable_name, int _hkey);
int hput (hashtable *_htable_name, int _hkey, int _hvalue);
int hget_hash (hashtable *_htable_name, int _hkey);

//1009 is prime close to 1000 use it
#endif // H_HASH_TABLE