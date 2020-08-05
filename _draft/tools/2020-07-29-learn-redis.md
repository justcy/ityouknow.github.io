---
layout: post
title: "redis学习笔记"
tagline: ""
date: '2020-07-29 16:26:58 +0800'
category: tools
tags: tools redis
keywords: tools,redis学习笔记,redis
description: tools,redis学习笔记
---
> redis学习笔记
# 引言
Redis是你做软件开发不可能避开的中间件

# Redis的数据结构与对象
redis的key始终为string，value存在5种数据结构。redis string 在底层以简单动态字符串(simple dynamic string SDS)存在。
SDS结构
```c
struct sdshdr{
	//buf中已使用的字节数量-SDS所保存的字符串长度
	int len;
	//buf中未使用的字节数量
	int free;
	//字节数组，用于保存字符串
	char buf[];
}
```
利用此结构SDS实现了空间预分配和惰性空间释放。
1. 空间预分配，SDS变化后长度小于1M，且空间不足需要分配，SDS会分配与当前长度相等的空间。若SDS变化后大于1M,程序会自动分配1M未使用空间。
2. 惰性空间释放，字符串变短后，不会立即释放空间，而是将空闲空间长度存于free中，等待将来使用。
## 数据结构
### 链表
链表键、发布订阅、慢查询、监视器等地方用到了链表。
listNode双向链表结构
```c
typedef struct listNode{
  //前置节点
	struct listNode * prev;
	//后置节点
	struct listNode * next;
	//节点值
	void * value;
}listNode;
```
list
```c
typedef struct list{
	//表头
	listNode * head;
	//表尾
	listNode * tail;
	//节点数
	unsigned long len;
	//节点值复制函数
	void *(*dup)(void * ptr);
	//节点值释放函数
	void (*free)(void * ptr);
	//节点值对比函数
	int (*mathc)(void *ptr,void *key);
}list;
```
### 字典
字典，又称为符号表(symbol table)、哈希表(hashtable)、关联数组(associative array)映射(map)，是一种用于保存键值对(key->Value)的抽象数据结构。Redis使用字典作为hash键的底层实现。当字典被用作数据库的底层实现，或者哈希键的底层实现，Redis使用[MurmurHash2](http://code.google.com/p/smhasher)算法来计算哈希值。
```c
typedef struct dictht{
	//hash表数组
	dictEntry ** table;
	//hash表大小
	unsigned long size;
	//hash表大小掩码，用于计算索引值，总是等于size-1
	unsigned long sizemask;
	//hash表已有节点数量
	unsigned long used;
}dictht;
```
dictEntry
```c
typedef struct dictht{
	//键
	void *key;
	//值
	union{
		void * val;
		uint64_tu64;
		int64_ts64;
	}
	struct dictEntry *next;
}dictEntry;
```
字典dict
```c
typedef struct dict{
  //类型特定函数
	dictType *type;
	//私有数据
	void * privdata;
	//哈希表
	dictht ht[2]
	//rehash索引，当rehash不再进行时值-1
	int trehashidx;
}dict;
```
dictType
```c
typedef struct dictType{
	//计算hash值的函数
	unsigned int (*hashFunction)(const void *key)
	//复制键函数
	void *(*keyDup)(void * privdate,const void *key);
	//复制值函数
	void *(*valDup)(void * privdate,const void *obj);
	//对比键的函数
	int (*keyCompare) (void * privdata,const void * key1,const void * key2);
	//销毁键的函数
	void (*keyDestructor)(void *privdata,void *key);
	//销毁值的函数
	void (*valDestructor)(void *privdata,void *obj);
}dictType;
```
### 跳跃表
跳跃表(skiplist)是一种有序的数据结构，它通过在每个节点中维持多个指向其他节点的指针，从而达到快速访问节点的目的。跳跃表支持平均O(logN)、最坏O(N)复杂度的节点查找，还可以通过顺序性操作来批处理节点。大多数情况下，跳跃表的效率可以和平衡树相媲美，并且因为跳跃表的实现比平衡树更简单，所以有不少程序都使用跳跃表来替代平衡树。
Redis底层使用跳跃表作为有序集合键的底层实现之一。如果一个有序集合包含的元素数量比较多，又或者有序集合中元素成员是比较长的字符串时，redis就会使用跳跃表来作为有序集合键的底层实现。
跳跃表节点
```c
typedef struct zskiplistNode{
	//层
	struct zskiplistLevel{
		struct zskiplistNode *forward;
		unsigned int span;
	}level[];
	//后退指针
	struct zskiplistNode * backward;
	//分值
	double score;
	//成员对象
	robj *obj;
}zskiplistNode;
```
跳跃表
```c
typedef struct zskiplist{
	//表头节点和表尾节点
	struct zskiplistNode * header,* tail;
	//表中节点的数量
	unsigned long length;
	//表中层数最大的节点层数
	int level;
}zskiplist;
```
### 整数集合
整数集合(intset)是集合键的底层实现之一，当一个集合只包含整数值元素，并且这个集合的元素数量不多时，Redis就会使用整数集合作为集合键的底层实现。
```c
typedef struct intset{
	//编码方式
	uint32_t encoding;
	//集合包含的元素数量
	uint32_t length;
	//保存元素的数组
	int8_t contents[];
}intset;
```
### 压缩列表
压缩列表(ziplist)是列表键的底层实现方式之一。当一个列表键只包含少量列表项，并且每个列表项要么就是小整数值，要么就是长度比较短的字符串，那么Redis就会使用压缩列表来做列表键的实现。
1. 压缩表是一种为节约内存而开发的顺序型数据结构。
2. 压缩表被用作列表键和哈希键的底层实现方式之一。
3. 压缩表可以包含多个节点，每个节点可以存储一个字节数组或者整数值。
4. 压缩表添加删除节点，可能会引发连锁更新操作，但是这种操作出现的几率不高。
## 对象
Redis基于以上数据结构创建了一个对象系统，这个对象系统包含字符串对象、列表对象、哈希对象、集合对象和有序集合对象，每种对象都至少用到了一种上面的数据结构。Redis的对象系统还实现了基于引用计数技术的内存回收机制，当程序不再使用某个对象的时候，对象所占用的内存会被自动释放。另外，通过引用计数技术实现了对象共享机制，这一机制可以在适当的条件下，通过让多个数据库键共享同一个对象来节约内存。Redis对象带有访问时间记录信息，该信息可以用于计算数据库键的空转时长，在服务器启用了maxmemory功能的情况下，空转时长较大的那些键可能会优先被服务器删除。
Redis的每个对象都是由redisObject结构表示。
```c
typedef struct redisObject{
	…………
	//类型
	unsigned type:4;
	//编码
	unsigned encoding:4;
	//指向底层实现数据结构的指针
	void *ptr;
	//  引用计数     
	int refcount;
	//对象最后一次被命中的时间
	unsigned lru:22;
	…………
}robj;
//type记录了对象的类型，可以是以下常量其中一个
//REDIS_STRING 字符串对象
//REDIS_LIST   列表对象
//REDIS_HASH   哈希对象
//REDIS_SET    集合对象
//REDIS_ZSET   有序集合对象
```
### 字符串(String)对象
字符串对象可以为int、raw、embstr。

- Int，当对象保存的是整数值，并且这个整数值可以用long来表示。
- raw，当对象保存的是一个字符串值，并且这个字符串值的长度大于32字节。
- embstr，当对象保存的是一个字符串值，并且这个字符串的长度小于32字节。

> embstr是专门用于保存短字符串的一种优化编码方式。相比raw方式(需要调用两次内存分配来分别创建redisObject和sdshdr)，embstr只调用一次内存分配来获得一块连续的空间，空间依次包含redisObject和sdshdr两个结构。基于此，内存分配少一次，内存释放少一次。此外内存连续相比内存不连续能够更好地利用缓存带来的优势(linux系统内存调用逻辑会读取当前命中的页的数据)。
- int转raw:向对象执行了一些命令，如APPEND使得对象不再是整数值；
- embstr转raw:对象执行了修改命令后(embstr对象实际上是只读的,Redis实际上并未实现embstr的任何修改程序)

### 列表(list)对象
列表对象的编码可以是ziplist或者linkedlist。
ziplist编码的列表对象使用压缩列表作为底层实现，每个压缩列表节点保存了一个列表元素。另一方面，linkedlist编码的列表对象使用双端链表作为底层实现，每个双端链表节点都保存了一个字符串对象，而每个字符串对象都保存了一个列表元素。
当列表对象可以同时满足以下两个条件时，列表对象使用ziplist编码:
- 列表对象保存的所有字符串长度都小于64字节
- 列表对象保存的元素数量小于512个
不满足这两个条件的列表对象都要使用linkedlist编码。
> 上限值可在配置文件中修改
> list-max-ziplist-value
> list-max-ziplist-entries

### 哈希(hash)对象
哈希对象的编码可以是ziplist或者Hashtable。
ziplist编码的哈希对象使用压缩列表作为底层实现，每当有新的键值对要假如到哈希对象时，程序会先将保存了键的压缩列表节点推入到压缩列表表尾，然后再将保存了值的压缩列表节点推入到压缩列表表尾，因此：
1. 保存同一键值对的两个节点总是紧挨在一起，保存键的节点在前，保存值的节点在后；
2. 先添加到哈希对象中的键值对会被放在压缩列表的表头方向，后添加的在表尾方向。
当哈希对象可以同时满足以下两个条件，哈希对象使用ziplist编码。
- 哈希对象保存的所有键值对的字符串长度都小于64字节；
- 哈希对象保存的键值对数量小于512个；
不能满足这两个条件的哈希对象要使用hashtable编码。
> 上限值可在配置文件中修改
> hash-max-ziplist-value
> hash-max-ziplist-entries

### 集合(set)对象
集合对象的编码可以是intset或者hashtable。
intset编码的集合对象使用整数集合作为底层实现，集合对象包含的所有元素都被保存在整数集合里面。
hashtable编码的集合对象使用字典作为底层实现，字典的每个键都是一个字符串对象，每个字符串对象包含了一个集合元素，而字典的值则全部被设置为null。
当集合对象可以同时满足以下两个条件时，对象使用intset编码。
- 集合对象保存所有元素都是整数值。
- 集合对象保存的元素数量不超过512个
不能满足这两条件的对象需要使用hashtable编码。

### 有序集合对象
有序集合的编码可以是ziplist或者skiplist。
ziplist编码的压缩列表对象，使用压缩表作为底层实现，每个集合元素使用两个紧挨在一起的压缩列表节点来保存，第一个节点保存元素的成员(member)，而第二个元素保存元素的分值(score)
压缩列表内的集合元素按分值从小到大依次排序，分值比较小的元素被放置在靠近表头的方向，而分值较大的元素则被放置在靠近表尾的方向。
skiplist编码的有序集合对象使用zset结构作为底层实现，一个zset同时包含一个字典和一个跳跃表。虽然zsett同时使用一个字典和一个跳跃表，但这两种数据结构都会通过指针来共享相同元素的成员和分值，所以同时使用跳跃表和字典来保存集合元素不会产生任何重复成员或者分值，也不会因此而浪费额外内存。
```c
typedef struct zset{
	zskiplist * zsl;
	dict * dict;
}zset;
```

> 为什么有序集合要同时使用跳跃表和字典来实现？
> 理论上，有序集合可以单独使用其中任意一种来实现，但是在性能上对比二者同时使用会有所降低。

当有序集合对象同时满足以下两个条件时，对象使用ziplist编码。
- 有序集合保存元素数量小于128个
- 有序集合保存的所有元素长度小于64字节
不能满足以上条件的，使用skiplist编码。
> 上限值可在配置文件中修改
> zset-max-ziplist-value
> zset-max-ziplist-entries

# 数据持久化
Redis是内存数据库，数据是存在内存的，如果不将内存中存放的数据库状态保存到磁盘，那么一旦服务器进程退出，服务器中的数据库数据也会丢失。为解决这一问题，Redis提供了两种数据库持久化功能
## RDB数据库持久化
RDB既可手动执行，也可以根据服务器配置选项定期执行，它可将某个时间点上的数据库状态保存到RDB文件中，RDB文件是一个压缩的二进制文件，通过该文件可还原数据库。
RDB文件创建可使用SAVE和BGSAVE两个命令，前者会阻塞Redis进程，阻塞期间服务器不能处理任何请求。BGSAVE会派生一个子进程，由子进程负责创建RDB文件，服务器进程继续处理命令请求。
RDB文件载入是在服务器启动时自动执行，并没有专门载入RDB文件的命令。
需要注意的是AOF和RDB都开启的情况下，会默认先使用AOF。
## RDB文件结构

一个完整的RDB文件结构如下:

![image-20200731103714938](http://static.kanter.cn/uPic/2020/07/31_image-20200731103714938.png)

> rdbcompression 配置决定了RDB文件是否压缩，redis的压缩使用[LZF算法](http://liblzf.plan9.de)

## AOF数据库持久化

AOF(Append only file)持久化，AOF持久化是通过保存Redis服务器所执行的写命令来记录数据库的状态(类似mysql的binlog日志)。AOF持久化功能的实现，可以分为命令追加(Append)、文件写入、文件同步(Sync)三个步骤。

1. 命令追加，服务器执行完命令后，会以协议格式将命令追加到aof_buf缓冲区的末尾。
2. 文件写入与同步，Redis服务器进程就是一个事件循环(loop)这个循环中的文件事件负责接收客户端命令，以及向客户端发送回复，而时间事件则负责执行像serverCron函数这样需要定时运行的函数。服务器在每次结束一个事件循环之前，会调用flushAppendOnlyFile函数，flushAppendOnlyFile函数会判断(根据appendfsync选项，一共有三个：always(写入立即同步)、everysec(默认,写入后由一个线程负责同步)、no(写入不同步，同步时机由操作系统决定))是否需要将aof_buf中的内容写入和保存到AOF文件里面。文件写入后，再对AOF文件进行同步
# redis事件
Redis服务器本身就是一个事件驱动程序，主要处理文件事件(file event)和时间事件(time event)。Redis基于reactor模式开发了自己的网络事件处理器。这个处理器被称为文件事件处理器(file event handler)。文件事件处理器使用I/O多路复用(multiplexing)程序来同时监听多个套接字，并根据套接字目前执行的任务来为套接字关联不同的事件处理器。
## 文件事件
文件事件是对套接字操作的抽象，当被监听的套接字准备好执行连接应答(accept)、读取(read)、写入(write)、关闭(close)等操作时，与操作相对应的文件事件就会产生，这时文件事件处理器就会调用套接字之前关联好的事件处理器来处理这些事件。
文件事件分为AE_READABLE事件(读事件)和AE_WRITABLE事件(写事件)两类。
## 时间事件
Redis的时间事件分为以下两类
- 定时时间：让程序在指定时间后执行一次。
- 周期性时间：让一段程序每隔指定时间执行一次。
一个时间事件由三个属性组成
- id: 服务器为时间事件创建全局唯一ID。
- when: 毫秒精度的UNIX时间戳，记录时间事件到达的时间。
- timeProc: 时间事件处理器，一个函数。
目前版本的Redis只使用周期性时间事件，没有使用定时事件。
>无序列表不影响时间事件处理器的性能
>在目前版本，redis正常模式服务器只会用serverCron一个时间事件，而在benchmark模式下，服务器也只使用了两个时间事件。在这种情况下，服务器几乎将无序链表退化成一个指针来使用，所以使用无序列表来保存时间事件，并不影响事件执行性能。
时间事件的应用实例，serverCron函数。Redis以周期性事件运行serverCron函数，默认每秒运行10次，也就是每100ms运行一次。它的主要工作是：
- 更新服务器各个类统计信息，比如：时间、内存占用、数据库占用等。
- 清理数据库中的过期键值对。
- 关闭和清理连接失效的客户端。
- 尝试进行AOF和RDB的持久化操作。
- 如果处于集群模式，对集群进行定期同步和连接测试(集群保活)。

文件事件和时间事件的处理都是同步、有序、原子地执行的，服务器不会中断或者抢占。时间事件是在文件事件之后执行，所以通常会比实际到达时间晚一些。
# redis服务端
redis一次命令执行过程
![image-20200803205541530](http://static.kanter.cn/uPic/2020/08/03_image-20200803205541530.png)
redis的serverCron函数主要功能
- 更新时间缓存，redisServer中会缓存秒级和毫秒级的当前时间戳，serverCron会以100ms一次的频率更新这两个值，服务器在打印日志、更新服务器LRU时钟、决定是否执行持久化操作、计算服务器上线时间这类对时间精度要求不高的功能上。而对键设置过期时间、添加慢查询日志等，服务器会再次执行系统调用，获取准确时间。
- 更新LRU时钟，服务器状态中的lrulock属性保存了服务器的LRU时钟，每个Redis对象都会有一个lru属性，用以保存该对象最后一次被命令访问的时间，对象空转时间=lrulock-lru。
- 更新服务器每秒执行命令次数，serverCron函数中的trackOperationsPerSecond函数会以每100一次的频率执行，这个函数的功能是以抽样计算的方式，估算并记录服务器在最近一秒钟处理的命令请求数量。trackOperationsPerSecond函数每次运行，都会根据ops_sec_last_sample_time记录上一次抽样时间和服务器当前时间，以及ops_sec_sample_ops记录上一次抽样的已执行命令数量和服务器当前已执行命令数量，计算出两次trackOperationsPerSecond调用之间，服务器平均每一毫秒处理了多少个命令请求，然后将这个平均值乘以1000，换算得到服务器一秒钟内能处理多少个命令请求估计值。这个估计值会被作为一个新的数组项放到ops_sec_samples环形数组中。
- 更新服务器内存峰值记录，服务器中的stat_peak_memory记录了服务器的内存峰值大小，每次serverCron执行时，程序会查看服务器当前使用的内存数量，并将Max(stat_peak_memory,now)保存到stat_peak_memory。
- 处理SIGTERM信号，在启动服务器时，Redis会为服务器进程的SIGTERM信号关联处理器sigtermHandler函数，这个信号处理器负责在接到SIGTERM信号时，打开服务器状态的Shutdown_asap标示。每次执行serverCron函数，程序都会对shutdown_asap属性进行检查，并根据属性的值决定是否关闭服务器。与一接到SIGTERM信号就关闭不同，这样做是为了确保能够执行持久化操作。
- 管理客户端资源，serverCron每次执行，都会调用clientsCron函数，clientsCron函数会对一定数量的客户端进行检查，如果客户端与服务器之间的连接已超时，那么程序将释放这个客户端。如果客户端在上一次命令请求之后，输入缓冲区的大小超过了一定长度，程序会释放客户端当前输入缓冲区，并重新创建一个默认大小的输入缓冲区，从而防止客户端输入缓冲区浪费过多内存。
- 管理数据库资源，serverCron每次执行，都会调用databasesCron函数，作用是检查部分数据库，删除其中的过期键，并在有需要的时候，对字典进行收缩操作。
- 执行被延迟的BGREWRITEAOF，在服务器执行BGSAVE期间，如果客户端向服务器发来BGREWRITEAOF命令，服务器会将BGREWRITEAOF的执行时间延迟到BGSAVE命令执行完毕之后。每次serverCron执行时，都会检查BGSAVE和BGWRITEAOF是否在执行，如果都没有执行，并且aof_rewrite_scheduled属性值为1，服务器就会执行之前被延迟的BGREWRITEAOF。
- 检查持久化操作的运行状态，服务器状态使用rdb_child_pid属性和aof_child_pid属性记录执行BGSAVE和BGREWRITEAOF命令的子进程ID，这两个也可以用于检查命令是否正在执行。
- 将AOF缓冲内容写入AOF文件，若服务器开启了AOF，并且AOF缓冲区有待写入数据，那么ServerCron会调用相关程序，将AOF缓冲区内容写到AOF文件里面。
- 关闭异步客户端，当客户端的输出缓冲区大小超出了限制，serverCron会关闭这些客户端。
- 增加Cronloops计数，服务器的cronloops记录了serverCron函数的执行次数。cronloops目前在服务器唯一作用就是子啊复制模块中实现“每执行serverCron函数N次，就执行一次指定代码”

redis服务器初始化过程
![image-20200804110050309](http://static.kanter.cn/uPic/2020/08/04_image-20200804110050309.png)
# Redis多机数据库实现
## 复制
Redis中使用SLAVEOF命令设置从库复制主服务器，如 在B上执行SLAVEOF A 则B将复制A，B作为从服务器，A作为主服务器。进行复制的主从双方数据库将保存相同的数据，称作“数据库状态一致性”
Redis旧版本的复制功能分为同步(Sync)和命令传播(command propagate)两个操作。
- 同步用于将从服务器的数据库状态更新到主服务器所处的数据库状态。
- 命令传播则用于在主服务器状态被修改，导致主从不一致时，让从服务器的数据库执行相同命令，保证主从数据库重新回到一致状态。
![image-20200804112049867](http://static.kanter.cn/uPic/2020/08/04_image-20200804112049867.png)
旧版本复制功能的缺陷，当断线后重新复制，效率非常低。原因：断线重连后会重新发送SYNC命令，整体重新同步。
为了解决旧版复制功能在处理断线重复情况的低效率问题，Redis从2.8开始使用PSYNC命令替代了SYNC命令。PSYNC具有完整同步(full resynchronization)和部分同步(partial resynchronization)两种模式。完整同步用于初次复制的情况。部分同步则用于处理断线后重复复制的情况：当从服务器断线后重新连上主服务器，如果条件允许，主服务器可以将主从服务器断开期间的写命令发送给从服务器，从服务器执行后，主从数据恢复一致。
![image-20200804113555232](http://static.kanter.cn/uPic/2020/08/04_image-20200804113555232.png)
Redis新版复制功能，部分同步的实现主要依靠主从服务器分别维护一个同步偏移量，以及主服务器维护的复制积压缓冲区来实现。主服务器每次命令传播后，会将当前传播的命令记录在复制积压缓冲区(默认1M大小，先入先出)，当断线后，主从偏移量不一致，从服务器重连后，发送PSYNC命令，主服务器会判断 1.当前服务器ID是否为断线前ID，不相同，直接执行完整同步方式。2.当前从服务器的偏移量是否还在复制积压缓冲区内，若存在则执行部分同步，与客户端同步两个偏移量之间的差。如果不存在，则需要采取完整同步方式。
复制积压缓冲区可根据second*write_size_per_second;来估算，其中second为从服务器断线后重新连上服务器所需的平均时间，而write_size_per_second则是主服务器平均每秒产生的写命令的数量。复制积压缓冲区大小建议设置为：2*second*write_size_per_second
# Redis 哨兵机制(Sentinel)
Sentinel是Redis高可用性的解决方案：由一个或多个Sentinel实例组成的Sentinel系统可以监视任意多个主服务器，以及这些主从服务器下的所有从服务器，并在被监视的主服务器进入下线状态时，自动将下线主服务器属下的某个从服务器升级为新的主服务器，然后由新的主服务器代替已经下线的主服务器继续处理命令请求。
下图是哨兵启动过程
![image-20200804145834277](http://static.kanter.cn/uPic/2020/08/04_image-20200804145834277.png)
Sentinel会创建两个到主服务器的链接，一个为命令连接，一个为订阅信息连接。不同的Sentinel之间也会创建相互之间的命令连接。
## Sentinel主观下线
Sentinel根据配置文件中的down-after-milliseconds选项指定Sentinel判断实例进入主观下线所需的时长: 如果一个实例在down-after-milliseconds毫秒内，连续向Sentinel返回无效回复，那么Sentinel会修改这个实例对应的实例结构的flags属性为SRI_S_DOWN标示，以此来表示这个实例已进入主观下线状态。
## Sentinel客观下线
当一个实例被Sentinel判定为主观下线，为了确定这个实例是否真的下线了，它会向同样监视这个主服务器的其他Sentinel询问(发送is-master-down-by-addr命令)，若收到足够量(超过Sentinel配置中的quorun参数值)的下线回复后，Sentinel就会判定该服务器客观下线，并对主服务器执行故障转移。

当一个主服务器被判定为客观下线后，监视这个主服务器的各个Sentinel会进行协商，选举一个领头Sentinel，由领头Sentinel对下线服务器执行故障转移操作。
Redis的头领选举算法是[Raft算法](http://v.youku.com/v_show/id_XNjQxOTk5MTk2.html)的领头算法的实现，选举领头Sentinel的规则和方法如下:
- 所有在线的Sentinel都可以参选。
- 参选的Sentinel无论是否中选，Sentinel的配置纪元(configuration epoch)都会自增一次。
- 在一个配置纪元中，所有的Sentinel都有一次将某个Sentinel设置为局部头领的机会，并且局部头领一旦设置，在这个配置纪元就不能再更改。(每个Sentinel在同一个配置纪元中可投票一次，投票后不能更改)
- 每个发现主服务器进入客观下线的Sentinel都会要求其他Sentinel将自己设置为局部领头Sentinel
- 当一个Sentinel向另一个Sentinel发送SENTINEL is-master-down-by-addr命令，并且命令中的runid不是*，而是源Sentinel的运行ID时，这表示源Sentinel要求目标Sentinel将自己设置为局部领头Sentinel
- Sentinel设置局部领头的规则是先到先得，最先向目标Sentinel发送的源Sentinel将成为目标Sentinel的局部领头Sentinel，之后的请求会被拒绝。
- 目标Sentinel受到SENTINEL is-master-down-by-addr命令之后，将向源Sentinel返回一条命令回复，回复中的leader_runid参数和leader_epoch参数分别记录了目标Sentinel的局部领头Sentinel的运行ID和配置纪元
- 源Sentinel在接收到回复后，会检查回复中的leader_epoch和自己的配置纪元是否相同，如果相同的话，那么源Sentinel继续取出恢复中的leader_runid参数，如果leder_runid和源Sentinel的运行ID一致，那么表示目标Sentinel已经将源Sentinel设置为局部领头Sentinel
- 如果有某个Sentinel被半数以上的Sentinel设置为了局部领头Sentinel，那么这个Sentinel成为Sentinel。 
>配置纪元，实际就是一个计数器，可以理解为某一届选举。
## 故障转移
选举出来的领头Sentinel将对已下线的主服务器执行故障转移操作。
- 挑选新的主服务器，发送SLAVEOF no one
- 让已下线的主服务器的所有从服务器改为复制新的主服务器，对剩余的从服务器发送SLAVEOF 新主。
- 将已下线的主服务器设置为新的主服务器的从服务器，当老的主服务器重新上线后，生效。
>新的主服务器怎样挑选出来？
>领头Sentinel会从已下线的主服务器得到所有从服务器的列表，然后按照以下规则，挑选新的主服务器
>1.删除已处于下线或者断线的服务器，保证剩余的都是正常在线的
>2.删除最近5秒内没有回复过领头Sentinel的INFO命令的从服务器，保证剩余的从服务器都是最近成功通信的。
>3.删除所有与已下线主服务器连接断开超过down-after-milliseconds*10毫秒的从服务器，保证列表中的从服务器都没有过早与主服务器断开连接，换句话说，列表中的从服务器保存的数据都是比较新的。
>4.根据优先级排序，选取优先级最高的。若优先级相同，选取偏移量最大的从服务器(保证数据最新)，若优先级、偏移量都相同，将按照运行ID排序，选取运行ID最小的。

# 集群
Redis集群节点就是一个运行在集群模式下的redis服务器，Redis会在启动的时候根据cluster-enabled配置选项是否为yes来决定是否开启服务器的集群模式。
查看集群节点信息
```sh
>CLUSTER NODES
```
在A节点，将某个节点加入到集群
```sh
>CLUSTER MEET ip port
```
加入集群后，A节点会和新的节点握手，之后会通过Gossip协议将新节点介绍给集群里面的其他节点，让其他节点与新节点握手，一段时间后，新节点将被集群其他所有节点认识。
## 槽指派
Redis集群通过分片的方式来保存数据库中的键值对: 集群的整个数据库被分为16384个槽(slot)，数据库中的每个键都属于这16384个槽中的一个，集群中每个节点最多可以处理0-16384个槽。
当数据库的所有槽都有节点在处理的时候，集群处于上线状态(OK)，否则处于下线状态(fail)。
```sh
# 指派槽操作
>CLUSTER ADDSLOTS <slot> [slot ...]
```
clusterState.solts记录了所有槽指派的信息，clusterNode.slots记录了当前clusterNode结构所代表的节点的槽指派信息。
## 集群中执行命令
当客户端向集群节点发送与数据库键有关的命令，接收命令的节点会计算出命令要处理的键属于哪个槽，若槽指派给自己了，则执行命令，否则返回moved错误，指引客户端转向正确的节点。
```python
def slot_number(key):
	return CRC16(key) & 16383
```
## 重新分片
Redis集群的重新分片操作，可以将任意数量已经指派给某个节点(源节点)的槽改为指派给另一个节点(目标节点)，并且相关槽所属的键值对也会从源节点被移动到目标节点。
若向正在转移的槽发送操作命令，将会返回ASK错误。
ASK与MOVED区别:ASK相当于301，临时。MOVED相当于302，永久。
## 复制与故障转移
Redis集群的节点分为主节点(master)和从节点(slave)，其中主节点用于处理槽，从节点用户复制某个主节点，并在被复制的主节点下线的时候，代替主节点继续处理命令请求。
选举新的节点的方法
1. 集群配置纪元是一个自增计数器，初始值0
2. 当集群里某个节点开始一次故障转移操作时，集群配置纪元值+1
3. 对于每个配置纪元，集群里每个主节点都有一次投票机会，而第一个向主节点要求投票的从节点将获得主节点的投票。
4. 当从节点发现自己正在复制的主节点已经进入下线状态，会向集群广播一条4）当从节点发现自己正在复制的主节点进入已下线状态时，从节点会向集群广播一条CLUSTERMSG_TYPE_FAILOVER_AUTH_REQUEST消息，要求所有收到这条消息、并且具有投票权的主节点向这个从节点投票。
5. 如果一个主节点具有投票权，并且尚未投票给其他从节点，那么该节点将向要求投票的节点返回一条CLUSTERMSG_TYPE_FAILOVER_AUTH_ACK消息，表示这个主节点支持从节点成为新的主节点。
6. 每个参与选举的节点都会收到CLUSTERMSG_TYPE_FAILOVER_AUTH_ACK消息，并根据自己收到了多少条这样的消息来统计自己获得多少主节点的支持。
7. 当得到半数以上的同意时，这个从节点当选新的主节点。
8. 若选举失败，则集群进入新的配置纪元，再次进行选举，直到选举成功。
> 以上选举算法和领头Sentinel方法肥肠相似，都是基于Raft算法的领头选举来实现的。

## 消息
节点发送的消息主要有5种
- MEET消息：收到CLUSTER MEET命令时，发送者会向接收者发送MEET消息，请求接收者加入集群。
- PING消息: 集群内每个节点默认每隔1s就会从已知节点列表中随机选出5个节点，然后对这5个节点中最长时间没有发送过PING消息的节点发送PING消息，以检测该节点是否在线。此外，若节点A最后一次收到节点B的PONG消息的时间，距离当前时间已经超过A节点的cluster-node-timeout设置的值的一半，节点A也会向B发送PING消息，这是为了防止A长时间没有随机选中B作为PING消息的发送对象而导致对节点B的信息更新滞后。
- PONG消息：接收者收到MEET消息或者PING消息时，为了确认消息已经收到，接收者将会发送一条PONG消息。另外，一个节点也可以通过集群广播自己的PONG消息，以便其他节点能立即刷新关于这个节点的认识。
- FAIL消息: 当一个主节点A判断另一个主节点B进入FAIL状态时，A会向集群广播一条关不B的FAIL消息，所有收到这条消息的节点都会立即将B标记为下线。
- PUBLISH消息：当节点接收到一个PUBLISH命令时，节点会执行这个命令，并向集群广播一条PUBLISH消息，所有接收到这条PUHLISH消息的节点都会执行相同的PUBLISH命令。
一条消息由消息头(header)、消息正文(data)组成。

#Redis事务
Redis通过MULTI、EXEC、WATCH等命令来实现事务(transaction)功能。事务提供了一种将多个命令打包，然后一次性、按顺序地执行多个命令的机制，在事务执行期间，服务器不会中断事务而改去执行其他客户端的命令请求，它会将事务中所有的命令都执行完毕，然后再去处理其他客户端的命令请求。
```sh
redis>MULTI
redis>命令1
redis>命令2
…………
redis>EXEC
```
# 扩展
## 为什么Redis对象共享不包含字符串对象？
当服务器考虑将一个共享对象设置为键的值对象时，程序需要先检查给定的共享对象和键想创建的目标对象是否完全相同，只有在共享对象和目标对象完全相同的情况下，程序才会将共享对象用作键的值对象，而一个共享对象保存的值越复杂，验证共享对象和目标对象是否相同所需的复杂度就会越高，消耗的CPU时间也会越多：
- 如果共享对象是保存整数值的字符串对象，那么验证操作的复杂度为O（1）； 
- 如果共享对象是保存字符串值的字符串对象，那么验证操作的复杂度为O（N）； 
- 如果共享对象是包含了多个值（或者对象的）对象，比如列表对象或者哈希对象，那么验证操作的复杂度将会是O（N 2）。
因此，尽管共享更复杂的对象可以节约更多的内存，但受到CPU时间的限制，Redis只对包含整数值的字符串对象进行共享。
## 过期键删除策略
- 定时删除:通过使用定时器，该策略可保证过期键会尽可能快地被删除，并释放内存，即对内存友好，但是，它是对CPU时间不友好的:在内存不紧张，CPU时间非常紧张的情况下，将CPU时间用在删除过期键上，会影响服务器的响应时间和吞吐量。此外，创建一个定时器需要用到Redis服务器中的时间事件，而当前时间事件的实现方式是无序链表，查找一个事件的时间复杂度为O(N)。
- 惰性删除:程序只会在取出键的时候才检查是否过期，这可以保证删除过期键操作只会在非做不可的情况下进行，惰性删除对CPU时间是友好的，但是对内存不友好。如果一个键已经过期，而这个键又不再使用，那么这个过期键就不会被删除，所占内存也不会被释放(除非FLUSHDB)。严重的，甚至会造成内存泄露。
- 定期删除：定期删除策略是对以上两个策略的折中。定期删除策略每隔一段时间进行一次删除过期键操作，并通过限制删除操作执行时长和频率来减少删除对CPU时间的影响。该策略的难点是根据业务确定删除操作的时长和频率。

redis实际使用的是惰性删除和定期删除两种策略，通过配合使用这两种策略，服务器可以很好地在合理使用CPU时间和避免浪费内存之间取得平衡。
## 数据库通知
Redis2.8版本后，新加了数据库通知。主要分为两种
1. 键空间通知(key-space notification)，关注某个键执行了什么命令。
2. 键事件通知(key-event notification)，关注某个命令被什么执行了。
>服务器配置的notify-keyspace-events选项决定了服务器所发送通知的类型：
>键空间+键事件  AKE
>键空间       AK
>键事件   AE
>只发送字符串油管的键空间   K$
>只发送列表有关的键事件   El


---
参考：
- [黄健宏 著. Redis设计与实现 (数据库技术丛书) (Kindle Locations 1517-1525). 机械工业出版社. Kindle Edition. ]()
- []()
