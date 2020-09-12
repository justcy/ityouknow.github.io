---
layout: post
title: "《kafka权威指南》读书笔记"
tagline: ""
date: '2020-09-11 11:28:27 +0800'
category: java
tags: java 《kafka权威指南》读书笔记
keywords: java,《kafka权威指南》读书笔记
description: java,《kafka权威指南》读书笔记
---
> 《kafka权威指南》读书笔记
# 引言
kafka最初是LinkIn的一个内部基础设施系统。kafka一开始被用在社交网站的实时应用和数据流中，如今，kafka已经成为下一代数据架构的基础。kafka一般被称为"分布式提交日志"或“分布式流平台”
<!-- more -->

# Kafka生产者
生产者属性
```java
//指定broker地址清单，格式：host:port,建议至少提供两个broker
bootstap.servers=localhost:2300,localhost:2301
//设置一个实现了org.apache.kafka.common.serialization.Serializer接口的类，生产者会使用这个类把键对象序列化为字节数组，kafka默认提供：ByteArraySerializer、StringSerializer、IntegerSerializer
key.serializer=XXXSerializer
//与key.serialiser类似，序列化value
value.serializer=XXXSerializer

//以下是生产者非必要参数
/* 0:生产者写入消息后不等待任何来自服务器的响应
 * 1:只要集群首领节点收到消息，服务器就会响应生产者成功,否则，生产者需要尝试重发。
 * all:所有参与复制的节点全部收到消息，服务器才会响应生产者成功，由于需要等待多个服务器节点响应，所以延时比acks=1更高。
*/
acks=0/1/all
//设置生产内存缓冲区大小，若空间不足，根据block.on.buffer.full(0.9.0.0版本替换为了max.block.ms,表示在抛出异常之前可以阻塞一段时间)参数，要么阻塞send(),要么抛出异常。
buffer.memory
//指定消息发送broker之前使用的压缩方式，可选：snappy、gzip、lz4，默认情况下不压缩
compression.type=xxx
//生产者重发消息次数，超过则放弃重试，返回错误。默认情况下，生产者会在每次重试之间等待100ms，该值可通过:retry.backoff.ms设置。
retries
//重试等待时间
retry.backoff.ms
//指定一个批次可使用内存大小，单位：字节，当批次被填满，批次内所有消息被发送出去，设置较大不会造成延迟，只占用内存，设置较小，会频繁发送消息，增加额外开销。
batch.size
//生产者在发送批次之前等待更多消息加入该批次的时间。
linger.ms
//客户端唯一标示，用来识别消息来源
client.id
//生产者在收到服务器响应之前可发送多少个消息，设为1可保证消息即使发生重试也会按照发送顺序写入。
max.in.flight.requests.per.connection
//broker同步返回消息确认时间，若指定时间内没有收到同步副本确认，那么broker会返回一个错误
timeout.ms
//发送数据等待响应超时时间
request.timeout.ms
//生产者在获取元数据(如首领是谁)时等待服务器响应的时间，若等待超时，要么重试，要么抛出异常或回调。
retadata.fetch.timeout.ms
//调用send()方法或使用partitionsFor()方法获取元数据时生产则阻塞时间。超时，生产者抛出异常
max.block.ms
//发送请求的大，最好与broker的message.max.bytes相等
max.request.size
//TCP socket接收数据包缓冲区大小，-1:使用操作系统默认值
receive.buffer.bytes
//TCP socket发送数据包缓冲区大小，-1:使用操作系统默认值
send.buffer.bytes

//schema的存储位置
schema.registry.url
```
发送消息的三种方式：
- 发送并忘记(fire-and-forget):直接调send()发送，发送后不关心是否正常到达。
- 同步发送:调用send()发送后，接着调用get()进行等待，确保发送成功。
- 异步发送:调用send(record,new Callback())指定回调函数，服务器在返回响应时调用该函数。
## 序列化器
> 不建议使用自定义序列化器，而是使用已有的序列化器和反序列化器，如:JSON、Avro、Thrift、Protobuf

Apache Avro序列化是一种与编程语言无关的序列化格式。Avro通过schema来定义，而schema通过JSON来描述，数据被序列化为二进制文件或JSON文件，通常是二进制文件。Avro在读写文件时会用到schema，所以一般schema会被内嵌在数据文件里。
# Kafka消费者
kafka的消费者从属于消费者群组。一个群组里面的消费者订阅同一个主体，每个消费者接收主题的一部分分区消息。若消费者数量大于分区数量，则多余部分的消费者闲置。不同的消费者群组相互不影响。一般为了安全，一个消费者使用一个线程。
当消费者数量变化时(新加入或退出),或者主题发生变化，会导致分区重新分配。分区的所有权从一个消费者转移到另一个消费者的行为被称为**再均衡**。在再均衡期间，消费者无法读取消息，整个小组一段时间内不可用。
消费者通过向指派为**群组协调器**的broker(不同的群组可以有不同的协调器)发送心跳来维持他们和群组的从属关系以及他们对分区的所有权关系。
消费者属性:
```java
//kafka集群连接串
bootstrap.servers
//指定key反序列化类
key.deserializer
//指定value反序列化类
value.deserializer
//指定所属群组
group.id
//消费者从服务器获取记录的最小字节数，若数据量小，消费者CPU使用率高，需设置得比默认值大。若消费者数量多，将该值设置大点可降低broker的工作负载
fetch.min.bytes
//broker等待时间，默认500ms
fetch.max.wait.mx
//服务器从每个分区返回给消费者的最大字节数，默认1M,需比max.message.size大，否则可能导致消费者无法读取消息，一直挂起重试。
max.partition.fetch.bytes
//消费者在被认为死亡之前可以与服务器断开的连接的时间，默认3s,超时无心跳，协调器触发再均衡
session.timeout.ms
//心跳频率，一般为session.timeout.ms的三分之一
heartbeat.interval.ms
//偏移量无效情况下如何处理？默认:latest,表示从最新记录开始读取，earliest,表示从起始位置开始读取
auto.offset.reset
//是否自动提交偏移量,默认true
enable.auto.commit
//自动提交间隔，默认5s
auto.commit.interval.ms
//分区分配策略,range,连续分配；RoundRobin,逐个分配，尽量保证平均
partition.assignment.strategy
//字符串，broker用来标示从客户端发来的信息，通常被用在日志、度量指标和配额里面
client.id
//单次call()最多返回的记录数量
max.poll.records
//TCP socket接收数据包缓冲区大小，-1:使用操作系统默认值
receive.buffer.bytes
//TCP socket发送数据包缓冲区大小，-1:使用操作系统默认值
send.buffer.bytes
```
## 提交
提交：更新分区当前位置的操作。
消费者通过向_consumer_offset的特殊主题发送消息，消息里包含每个分区的偏移量。偏移量保证率再均衡后，每个消费者能够根据每个分区的偏移量继续之前的工作。
若提交的偏移量小于客户端最后一个消息的偏移量，那么处于两个偏移量之间的消息就会被重复处理。若提交的偏移量大于客户端最后一个消息的偏移量，那么两个偏移量之间的消息将会丢失。
提交方式
- 自动提交，enable.auto.commit=true
- 手动提交，enable.auto.commit=false,调用commitSync()函数提交，会阻塞。
- 异步提交，enable.auto.commit=false,调用commitAsync()函数提交，不阻塞，支持回调，不会重试。
再均衡监听器
消费者调用subscribe()方法时传入一个ConsumerRebalanceListener实例，该实例实现两个方法
onPartitionsRevoked(),onpartitionsAssigned()。onPartitionsRevoked在再均衡开始之前和消费者停止读取消息之后被调用。onpartitionsAssigned()会在重新分配分区之后和消费者开始读取消息之前被调用。
## 退出


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
