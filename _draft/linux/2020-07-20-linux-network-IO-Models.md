---
layout: post
title: "linux的I/O模型解析"
tagline: ""
date: '2020-07-20 23:42:45 +0800'
category: linux
tags: linux,I/O
keywords: linux,I/O models,linux的I/O模型解析
description: linux,linux的I/O模型解析
---
> linux的模型解析

# 引言

同步（synchronous） I/O和异步（asynchronous） I/O，阻塞（blocking） I/O和非阻塞（non-blocking）I/O分别是什么，到底有什么区别？这个问题讨论这个问题的时候上下文(context)不同，会得到不同的答案，因此，本文所讨论的背景是Linux环境下的network I/O。
Linux 下的I/O模型一共有5种，分别是
1. 阻塞I/O(blocking I/O)
2. 非阻塞I/O(nonblocking I/O)
3. I/O复用(Select和poll)(I/O multiplexing)
4. 信号驱动I/O(signal driven I/O(SIGIO))
5. 异步I/O(asynchronous I/O)(the POSIX aio_functions)
> 前四种都是同步，只有第五种是异步I/O


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
- [6.2 I/O Models](http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/ch06lev1sec2.html)
- [Linux下5种IO模型以及阻塞/非阻塞/同步/异步区别](https://blog.csdn.net/yxtxiaotian/article/details/84068839)
- [I/O 模型如何演进及 I/O 多路复用是什么？](https://www.imooc.com/article/290770)
- [I/O模型浅析](cnblogs.com/MnCu8261/p/6265972.html)
