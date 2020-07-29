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
嘻嘻嘻

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
## 链表
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
## 字典
字典，又称为符号表(symbol table)、关联数组(associative array)映射(map)，是一种用于保存键值对(key->Value)的抽象数据结构。Redis使用字典作为hash键的底层实现。当字典被用作数据库的底层实现，或者哈希键的底层实现，Redis使用[MurmurHash2](http://code.google.com/p/smhasher)算法来计算哈希值。
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




# 代码清单
行内代码应用 `code`
``\`bash
ls -alh
``\`

# 图片
![](){:width="100%"}
# 扩展
关于该问题的扩展
---
参考：
- []()
- []()
