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

# I/O发生时涉及的对象和阶段
对于一个network I/O（这里以read举例），它会涉及到两个系统对象，一个是调用这个I/O的process(or thread)，另一个就是系统内核（kernel）。当一个read操作发生时，它会经历两个阶段：
1. 等待数据准备(Waiting for the data to be ready)

2. 将数据从内核拷贝到进程中(Copying the data from the kernel to the process)
    记住这两点很重要，因为这些I/O Model的区别就在于两个阶段上各有不同的情况。

# 阻塞I/O模型（blocking I/O）
在linux系统中，默认情况下所有的socket都是blocking的，一个典型的读流操作如下:![graphics/06fig01.gif](http://static.kanter.cn/uPic/2020/07/22_06fig01.gif)
    当用户进程调用了recvfrom这个系统调用，kernel就开始了I/O的第一个阶段：准备数据。对于network io来说，很多时候数据一开始还没到达（比如，还没有收到完整的UDP包），这个时候kernel就要等待足够的数据到来。而在用户进程这边，整个进程被阻塞。当kernel一直等到数据准备好了，它就会将数据从kernel的系统缓冲区拷贝到用户内存，然后kernel 返回结果，用户进程收到后，解除block状态，重新运行起来。所以，blocking I/O的特点就是在I/O执行的两个阶段都被block了。
    当使用socket()函数和WSASocket()函数来创建套接字时，默认的套接字都是阻塞的。这意味着当windows socket API 不能立即完成时，线程处于等待状态，直到操作完成。
    并不是所有的Windows sockets API以阻塞socket为参数调用都会发生阻塞。例如，以阻塞模式的socket为参数的bind()、listen()函数时，函数会立即返回。将可能阻塞socket的Windows sockets API调用分为以下四种：
1. 输入操作：recv()、recvfrom()、WSARecv()和WSARecvfrom()函数。以阻塞套接字为参数调用这类函数接收数据。如果此时套接字缓冲区内没有数据可读，则调用线程在数据到来之前一直阻塞。
2. 输出操作：send()、sendto()、WSASend()和WSASendto()函数。以阻塞套接字为单数调用这类函数发送数据。如果套接字缓冲区没有可用空间，则线程会一直阻塞，直到有空间。
3. 接受连接：accept()和WSAAccept()函数。以阻塞套接字为参数调用该函数，等待接收对方的连接请求。如果此时没有连接请求，则线程会进入阻塞状态。
4. 外出链接: connect()和WSAConnet()函数。对于TCP链接，客户端以阻塞套接字为参数，调用该函数向服务器发起连接。该函数在收到服务器的应答前，不会返回。这意味着TCP链接总会等待至少到服务器的第一次往返时间。
    使用阻塞模式套接字，开发网络程序比较简单，容易实现。当希望能够立即发送和接收数据，且处理的套接字数量比较少的情况下。使用阻塞模式来开发网络程序比较合适。
    阻塞模式套接字不足表现为，在大量建立好的套接字线程之间进行通信比较困难。当使用“生产者-消费者”模型开发网络程序时，为每个套接字都分配一个读线程，一个处理数据线程和一个用于同步的事件无疑会加大系统开销。阻塞模式最大的缺点就是当需要同时处理大量套接字时，将无从下手，扩展性能很差。
> 在socket程序中 Socket和WSASocket的区别:WSASocket是windows专用，支持异步操作，Socket是unix 标准，只支持同步操作。socket 可采用多线程实现非阻塞。
# 非阻塞I/O模型（non-blocking I/O）
    linux下，可以通过设置socket使其变为non-blocking。当对一个non-blocking socket进行读写操作时，流程如下：
![graphics/06fig02.gif](http://static.kanter.cn/uPic/2020/07/22_06fig02.gif)
    从图中可以看出，当用户进程发出read操作的时候，如果kernel中的数据还没有准备好，并不会block用户进程，而是立刻返回一个error。从用户进程角度来讲，它发起一个read操作后，不需等待，马上得到了一个结果，尽管此时的结果并不是数据已经准备好，而仅仅是个错误。用户判断结果是一个error时，它可以再发送read操作。一旦kernel中的数据准备好了，并且又再一次收到用户进程的read请求，它马上就将数据拷贝到了用户内存，然后返回。所以，用户进程其实需要不断地主动询问kernel数据好了没有。
    我们把一个socket接口设置为非阻塞，就是告诉内核，当所请求I/O操作无法完成时，不要将进程阻塞，而是返回一个错误。这样我们的I/O操作函数将不断地测试数据是否已经准备好，直到数据准备好为止。这个不断测试的过程中，会大量占用CPU的时间。
    当使用socket()和WSASocket()函数创建套接字时，默认都是阻塞的。在创建套接字后，通过调用ioctlsocket()函数，将该套接字设置为非阻塞模式。linux下的函数是：fcntl()。
    套接字设置为非阻塞模式之后，在调用window Socket API函数时，调用函数会立即返回。大多数情况下，这些函数调用都会”失败“，并返回WSAWOULDBLOCK错误。说明请求操作在调用期间内没有完成。通常，应用程序需要反复调用该函数，直到获得成功返回代码。
    需要说明的是并非所有的Windows Socket API在非阻塞模式下调用，都会返回WSAEWOULDBLOCK。例如，以非阻塞模式套接字为参数调用bind()函数时，就不会会返回该错误代码。当然，在调用WSAStartup()函数时更不会返回该错误码，因为该函数是应用程序第一调用的函数，当然不会返回这样的错误码。
    设置套接字为非阻塞模式，除了ioctlsocket()函数外，还可以使用WSAAsyncselect()和WSAAsyncselect()函数。
    由于使用非阻塞套接字在调用函数时，会经常返回WSAEWOULDBLOCK错误。因此在任何时候，都应仔细检查返回代码，并做好”失败“准备。应用程序应该不断调用这个函数，直到它返回成功标示。常用做法，在while循环内，不断调用recv()函数，以读入1024字节的数据。实际上这种做法很浪费系统资源。
# I/O复用模型（I/O multiplexing）
    I/O复用模型，也就是通常所说的，select、poll、epoll。有些地方也叫做 event driven I/O(事件驱动模型)，它是实际使用最多的一种I/O模型。我们都知道，select/epoll的好处就在于单个process就可以处理多个网络连接的I/O。它的基本原理就是select/epoll这个function会不断轮训所负责的所有socket,当某个select有数据到达了，就通知用户进程。它的流程图如下:
![graphics/06fig03.gif](http://static.kanter.cn/uPic/2020/07/23_06fig03.gif)	
    当用户调用了select，那么整个进程就被block，而同时，kernel会”监视“所有select负责的socket，当有任何socket中的数据准备好了，select就会返回。再由用户进程将数据从kernel拷贝到用户进程。
    上图和Blocking I/O的图其实并没有太大不同，事实上，效率还更差一些。因为这里需要两次system call(select和recvfrom)，而blocking I/O只调用了一个system call(recvfrom)。但是，用select的优势在于它可以同时处理多个connection。所以，若处理的连接数并不是很高的话，使用select/epoll的web server不一定比multi-threading + blocking I/O的web server性能更好，相反，可能延迟还要更大。select/epoll的优势并不在于对单个链接处理更快，而是在于能够处理更多的链接。
    在I/O multiplexing model中，对于每个socket，一般都设置成为non-blocking,但是如上图所示，真个用户的process其实一直被block 的。只不过process是被select这个函数block而不是被 socket I/O给block的。
# 信号驱动模型（Signal-driven I/O）
首先我们允许套接口进行信号驱动I/O,并安装一个信号处理函数，进程继续运行并不阻塞。当数据准备好时，进程会收到一个SIGIO信号，可以在信号处理函数中调用I/O操作函数处理数据。(signal driven I/O在实际中并不常用)

![graphics/06fig04.gif](http://static.kanter.cn/uPic/2020/07/23_06fig04.gif)

# 异步I/O模型（Asynchronous I/O）

linux下的asynchronous IO其实用得很少。先看一下它的流程：

![graphics/06fig05.gif](http://static.kanter.cn/uPic/2020/07/23_06fig05.gif)
    用户进程发起read操作之后，立刻就可以开始去做其它的事。而另一方面，从kernel的角度，当它受到一个asynchronous read之后，首先它会立刻返回，所以不会对用户进程产生任何block。然后，kernel会等待数据准备完成，然后将数据拷贝到用户内存，当这一切都完成之后，kernel会给用户进程发送一个signal，告诉它read操作完成了。

# 五中I/O模型比较

![graphics/06fig06.gif](http://static.kanter.cn/uPic/2020/07/23_06fig06.gif)
经过上面的介绍，会发现non-blocking I/O和asynchronous I/O的区别还是很明显的。在non-blocking I/O中，虽然进程大部分时间都不会被block，但是它仍然要求进程去主动的check，并且当数据准备完成以后，也需要进程主动的再次调用recvfrom来将数据拷贝到用户内存。而asynchronous I/O则完全不同。它就像是用户进程将整个I/O操作交给了他人（kernel）完成，然后他人做完后发信号通知。在此期间，用户进程不需要去检查I/O操作的状态，也不需要主动的去拷贝数据。

| 非阻塞I/O模型 | 主动check                       | 主动调用recvfrom拷贝准备好的数据   |
| ------------- | ------------------------------- | ---------------------------------- |
| 异步I/O模型   | 不需要check，只需要等待完成信号 | 不需要拷贝数据，只需要等待完成信号 |

> 同步I/O与异步I/O
> 同步I/O操作会导致请求被block，直到I/O操作完成
> 异步I/O操作不引起请求进程被block。

# 结语
我们回到开篇的几个问题
> blocking和non-blocking的区别在哪？
> synchronous IO和asynchronous IO的区别在哪？
是不是很简单了呢？

# 扩展
## select、poll、epoll简介
### select
### poll
### epoll
### select、poll、epoll 区别总结

---
参考：
- [6.2 I/O Models](http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/ch06lev1sec2.html)
- [Linux下5种IO模型以及阻塞/非阻塞/同步/异步区别](https://blog.csdn.net/yxtxiaotian/article/details/84068839)
- [I/O 模型如何演进及 I/O 多路复用是什么？](https://www.imooc.com/article/290770)
- [I/O模型浅析](cnblogs.com/MnCu8261/p/6265972.html)
