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
```
发送消息的三种方式：
- 发送并忘记(fire-and-forget):直接调send()发送，发送后不关心是否正常到达。
- 同步发送:调用send()发送后，接着调用get()进行等待，确保发送成功。
- 异步发送:调用send(record,new Callback())指定回调函数，服务器在返回响应时调用该函数。
## 序列化器
> 不建议使用自定义序列化器，而是使用已有的序列化器和反序列化器，如:JSON、Avro、Thrift、Protobuf

Apache Avro序列化是一种与编程语言无关的序列化格式。Avro通过schema来定义，而schema通过JSON来描述，数据被序列化为二进制文件或JSON文件，通常是二进制文件。Avro在读写文件时会用到schema，所以一般schema会被内嵌在数据文件里。

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
