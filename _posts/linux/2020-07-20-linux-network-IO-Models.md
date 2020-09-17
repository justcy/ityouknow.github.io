---
layout: post
title: "linux的I/O模型解析"
tagline: ""
date: '2020-07-20 23:42:45 +0800'
category: linux
tags: linux I/O模型
keywords: linux,select,poll,epoll,kqueue,I/O models,linux的I/O模型解析
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
在linux系统中，默认情况下所有的socket都是blocking的，一个典型的读流操作如下:
![graphics/06fig01.gif](http://static.kanter.cn/uPic/2020/07/22_06fig01.gif)
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
    在I/O multiplexing model中，对于每个socket，一般都设置成为non-blocking,但是如上图所示，这个用户的process其实一直被block 的。只不过process是被select这个函数block而不是被 socket I/O给block的。
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

blocking和non-blocking的区别：blocking 在整个I/O过程中阻塞进程，non-blocking在准备数据阶段是不阻塞进程的(会立即返回error)。

synchronous IO和asynchronous IO的区别：synchronous IO会阻塞进程，虽然non-blocking I/O在数据准备过程中并没有被block，但是当执行recvfrom这个system call的时候，这个过程是被block了的。而asynchronous I/O则不一样，当进程发起I/O操作之后就不再理睬，直到kernel发送一个信号，告诉进程说I/O完成了。整个过程中进程是没有被block的。

# 扩展
## select、poll、epoll、kqueue简介

Epoll跟select都能提供多路I/O复用的解决方案。在现在的linux系统里面都能够支持。其中epoll是linux特有，select则是POSIX所规定，一般操作系统均有实现。

### select

select函数本身是阻塞的，它与socket是否阻塞没有关系。无论socket是阻塞还是非阻塞，都可以使用阻塞的select函数。不过，当select执行完后，不同的socket会有不同操作：

1. 阻塞套接字，会让read阻塞，直到读到所需要的所有字节；
2. 非阻塞套接字，会让read读完fd中的数据后就返回，但如果你原本要求要读10个数据，这里只读了8个，如果你不再次使用select来判断是否可读，而是直接read,很可能返回EAGAIN=EWOULDBLOCK(BSD风格)，此错误由于在非阻塞套接字上发起不能立即完成的操作返回。例如，当套接字上没有排队数据可读时调用了recv()函数，此错误不是严重错误，相应操作应该稍后重试。对于在非阻塞SOCK_STREAM套接字上调用connect()函数来说，报告EWOULDBLOCK是正常的，因为建立一个连接必须花费一些时间。
> EWOULDBLOCK的意思是如果你不把socket设成非阻塞(即阻塞)模式时，这个读操作将阻塞，也就是说数据还未准备好(但系统知道数据来了，所以select告诉你那个socket可读)。使用非阻塞模式做I/O操作的细心的人会检查errno是不是EAGAIN、EWOULDBLOCK、EINTR，如果是就应该重读，一般是用循环。如果你不是一定要用非阻塞就不要设成这样，这就是为什么系统的默认模式是阻塞。
select 函数原型


```c
int select(int n,fd_set * readfds,fd_set * writefds,fd_set * exceptfds,struct timeval * timeout);
/** n代表文件描述词加1；参数readfds、writefds 和exceptfds 称为描述词组，是用来回传该描述词的读，写或例外的状况。
```

下面的宏提供了处理这三种描述词组的方式：

```c
FD_CLR(inr fd,fd_set* set); //用来清除描述词组set中相关fd 的位
FD_ISSET(int fd,fd_set *set); //用来测试描述词组set中相关fd 的位是否为真
FD_SET(int fd,fd_set*set); //用来设置描述词组set中相关fd的位
FD_ZERO(fd_set *set); //用来清除描述词组set的全部位
```

参数timeout为结构timeval，用来设置select()的等待时间，其结构定义如下
```c
struct timeval
{
    time_t tv_sec;
    time_t tv_usec;
};
```



select的本质上是通过设置和检查存放fd标志位的数据结构来进行下一步处理。这样所带来的的缺点是：

1. 单个进程可监视的fd数量被限制，即能监听端口的大小有限制，一般来说，这个数据和系统的内存关系很大，具体数据可以用以下命令查看。32位机器默认是1024个。64位机器默认是2048个。
2. 对socket进行的扫描是线性扫描，即采用轮询的方法，效率较低。当socket比较多的时候，每次select()都要通过遍历FD_SETSIZE个socket来完成调度，不管哪个socket是活跃的，都遍历一遍。这会浪费很多CPU时间。如果能给每个套接字注册某个回调函数，当他们活跃时，自动完成相关操作，那就避免了轮询，这正是epoll与kqueue做的。
3. 需要维护一个用来存放大量fd的数据结构，这样会使得用户空间和内核空间在传递数据结构时复制开销大。

### poll

poll本质上和select()没有差别，它将用户传入的数组拷贝到内核空间，然后查询每个fd对应的设备状态，如果设备就绪则在设备等待队列中加入一项并继续遍历，如果遍历完所有fd后没有发现就绪设备，则blocking当前进程，直到设备就绪或者主动超时，被唤醒后它又要再次遍历fd。这个过程经历了多次无谓的遍历。

poll没有最大连接数限制，原因是它是基于链表来存储的，但是同样有一个缺点

1. 大量的fd的数组被整体复制于用户态和内核地址空间之间，而不管这样的复制是不是有意义。
2. poll还有一个特点是"水平触发"，如果报告了fd后，没有被处理，那么下次再poll时会再次报告该fd。

### epoll

epoll支持水平触发(LT,level triggered)和边缘触发(ET,edge Triggered)，最大的特点在于边缘触发，它只告诉进程哪些fd刚变为就绪态，并且只会通知一次。另外，epoll使用”事件“的就绪通知方式，通过epoll_ctl注册fd，一旦该fd就绪，内核会采用类似callback的回调机制来激活该fd，epoll_wait便可收到通知。epoll的特点如下：

1. 没有最大并发连接的限制，能打开fd的上线远大于1024，通常1G的内存上能监听10个端口；

2. 效率提升，不采用轮询方式，不会随着fd数目的增加而效率下降。只有活跃可用的fd才会调用callback函数。epoll最大的有点在于，只管活跃的连接，而跟连接总数无关，因此在实际网络环境中，epoll的效率远远高于select和poll

3. 内存拷贝，利用mmap()文件银蛇内存加速内与内核空间的消息传递，即epoll使用mmap()减少复制开销。
> ET：边缘触发。仅当状态发生变化时才会通知，epoll_wait返回。换句话说，就是对于一个事件，只通知一次，且支持非阻塞的socket。
> LT: 水平触发。是epoll默认的工作方式。类似select/poll,只要还有没有处理的事件就会一直通知。以LT方式调用epoll接口，就相当于一个速度比较快的poll，LT同时支持阻塞和不阻塞的socket。

### kqueue
kqueue是UNIX上比较高效的I/O复用技术。与epoll类似，不过比epoll更易用。

### select、poll、epoll 区别总结

| 模式   | 最大连接数 | FD剧增后带来的I/O效率问题 | 消息传递方式 |
| :----: | :--------: | :-------------------: | :-------------------: |
| select | 单个进程所能打开的最大连接数有FD_SETSIZE宏定义，其大小是32个整数的大小（在32位的机器上，大小就是32*32，同理64位机器上FD_SETSIZE为32*64），当然我们可以对进行修改，然后重新编译内核，但是性能可能会受到影响，这需要进一步的测试。 | 因为每次调用时都会对连接进行线性遍历，所以随着FD的增加会造成遍历速度慢的“线性下降性能问题”。 | 内核需要将消息传递到用户空间，都需要内核拷贝动作 |
| poll   | poll本质上和select没有区别，但是它没有最大连接数的限制，原因是它是基于链表来存储的 | 同上 | 同上 |
| epoll   | 虽然连接数有上限，但是很大，1G内存的机器上可以打开10万左右的连接，2G内存的机器可以打开20万左右的连接 | 因为epoll内核中实现是根据每个fd上的callback函数来实现的，只有活跃的socket才会主动调用callback，所以在活跃socket较少的情况下，使用epoll没有前面两者的线性下降的性能问题，但是所有socket都很活跃的情况下，可能会有性能问题。 | epoll通过内核和用户空间共享一块内存来实现的 |

综上所述，选择select，poll，epoll时要根据具体的使用场合以及这三种方式的自身特点。表面上看epoll的性能最好，但是在连接数少并且连接都十分活跃的情况下，select和poll的性能可能比epoll好，毕竟epoll的通知机制需要很多函数回调。select低效是因为每次它都需要轮询。但低效也是相对的，视情况而定，也可通过良好的设计改善。


---
参考：
- [6.2 I/O Models](http://www.masterraghu.com/subjects/np/introduction/unix_network_programming_v1.3/ch06lev1sec2.html)
- [Linux下5种IO模型以及阻塞/非阻塞/同步/异步区别](https://blog.csdn.net/yxtxiaotian/article/details/84068839)
- [I/O 模型如何演进及 I/O 多路复用是什么？](https://www.imooc.com/article/290770)
- [I/O模型浅析](cnblogs.com/MnCu8261/p/6265972.html)
