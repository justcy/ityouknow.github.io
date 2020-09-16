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
若确定需要退出，需要通过另一个线程调用consumer.wakeup()方法。若循环运行在主线程里，可以在ShutdownHook方法中调用consumer.wakeup(),consumer.wakeup()是唯一一个可以从其他线程安全调用的方法。
# 深入Kafka
Kafka使用zookeeper来维护集群成员的信息。每个broker都有一个唯一标识符(自动生成或配置文件指定)。在broker启动的时候，它通过**临时节点**把自己的ID注册到Zookeeper。kafka组件订阅了Zookeeper的/brokers/ids路径，当集群有变化时，这些组件就可以获得通知了。
脑裂：两个节点同时认为自己是当前的控制器。使用epoch来避免“脑裂”
## 复制
复制是kafka架构的核心。当个别节点失效下，复制能够保证Kafka的可用性和持久性。kafka的每个分区有多个副本，副本被保存在broker上，每个broker可以保存成百上千个属于不同主题和分区的副本。副本分为首领副本和跟随者副本。
- 首领副本，每个分区有一个，所有生产者和消费者的请求都会经过这个副本。首领副本会记录同步副本信息，新首领只能从同步副本中选取。
- 跟随者副本，首领以外的副本都是跟随者副本。跟随者副本不处理来自客户端的请求，他们唯一的任务就是从首领那里复制消息，保持与首领一致的状态，一旦首领发生崩溃，其中一个跟随者会被提升为新首领。
## 处理消息
broker的主要工作是处理客户端、分区副本和控制器发送给分区首领的请求。Kafka基于TCP提供了一个二进制协议，指定了请求消息的格式，以及broker的响应格式。broker按照请求到达顺序来处理消息，这种顺序保证了消息是有序的，并且让Kafka具有消息队列的特性。
所有请求消息都包含一个标准消息头：
```
//API key
Request type: xx
//版本
Request version: xx
//具有唯一性的数字
Correlation ID: xx
//客户端标示
Client ID: xx
```
Broker会在监听的端口上运行一个Acceptor线程，这个线程会创建一个连接，并交个Processor(网络线程，数量可配置)线程去处理。
- 元数据请求，通过客户端感兴趣的主题列表获取主题包含的分区、每个分区的副本，以及谁是副本首领。元数据请求可以发给任意broker，因为broker都缓存了这些信息。
- 生产请求，产生消息，根据acks执行不同程度的写入检查。消息被写入到本地磁盘(文件系统缓存)。
- 获取请求，向broker请求带有分区及偏移量的消息数据。
- 其他请求，除以上三种之外的其他消息，如：新首领被选出后，控制器发送LeaderAndIsr给新首领和跟随者。OffsetCommitRequest、OffsetFetchRequest、ListOffsetRequest、CreateTopicRequest、ApiVersionRequest
## 物理存储
Kafka的基本存储单元是分区。分区的大小受单个挂载点可用空间的限制(一个挂载点由单个磁盘或多个磁盘组成，如果配置了JBOD，就是单个磁盘，如果配置了RAID，就是多个磁盘)
log.dirs参数指定了一个用于存储分区的目录清单。


> kafka零复制技术：直接把消息从Linux文件系统缓存中发送到网络通道，而不经过任何中间缓冲区。零复制避免了字节复制，不需要管理内存缓冲区，从而获得更好的性能。

### 分区分配
在创建主题时，Kafka首先会决定如何在broker间分配分区。分区分配目标：
- 在所有broker之间平均分布分区副本。
- 确保每个分区的每个副本分布在不同的broker上。
- 若broker指定了机架信息，那么尽可能把每个分区的副本分配到不同的机架上的broker上。
### 文件管理
默认情况下，每个片段文件包含1GB或一周的数据，如果达到片段上限制，就关闭当前文件，并打开一个新文件。当前正在写入的数据片段叫做**活跃片段**。活跃片段永远不会被删除。Broker会为分区里每个片段打开一个文件句柄，哪怕片段不是活跃的。这样会导致打开过多的句柄，操作系统必须根据实际情况做一些调优。
### 索引
消费者可以从kafka任意可用偏移量位置开始读取消息。为了更快定位到指定的偏移量，Kafka为每个分区维护了一个索引。索引把偏移量映射到片段文件和偏移量在文件里的位置。索引也被分成片段，删除消息时，也可以删除相应的索引。kafka并不维护索引校验和，若索引损坏，Kafka会通过重新读取消息并录制偏移量位置来重做索引。
### 清理
一般情况下，kafka会根据设置的时间保留数据，把超过时效的旧数据删掉。如果kafka启用了清理功能，通过log.cleaner.enabled参数配置，默认为true，每个broker会启动一个清理管理器线程和多个清理线程，它们负责执行清理任务。这些线程会选择污浊率(污浊消息占比)较高的分区进行清理。
清理线程会读取分区的污浊部分，在内存创建一个map。map里每个元素包含了消息键的散列值和消息的偏移量，键的散列值是16B，加上偏移量总共24B。如果要清理一个1GB的日志片段，并假设每个消息大小1KB，那么这个片段就包含100w个消息，而我们只需要24M(在不考虑重复键重用散列值的情况)的map就可以清理这个片段，很显然，这是非常高效的。
kafka清理策略：0.10.0和更早的版本，Kafka会在包含脏记录的主题数量达到50%时进行清理。这样既避免了频繁清理，也避免了存在太多脏记录。
# 可靠的数据传递
## kafka可靠性保证
- kafka可以保证分区消息的顺序。
- 只有当消息被写入分区的所有同步副本时(不一定是磁盘)，它才被认为是“已提交”的。
- 只要还有一个副本是活跃的，那么提交的消息就不会丢失。
- 消费者只能读取已经提交的消息。
以上基本的保证机制可以用来构建可靠系统，但仅仅依赖它们是无法保证系统完全可靠的。构建一个可靠的系统需要在数据可靠性、一致性、可用性、高吞吐量、低延迟和硬件成本等之间权衡。
## 复制
Kafka的复制机制和分区的多副本架构是Kafka可靠性保证的核心。把消息写入多个副本可以使Kafka在发生崩溃时仍能保证消息的持久性。
kafka分区首领是同步副本，对于跟随者副本来说，需要满足以下条件，才能被认为是同步的。
- 与zookeeper之间有一个活跃的会话，也就是说，6s(可配置)内有心跳
- 在10s(可配置)从首领那里获取过消息
- 在过去的10s内从首领那里获取过最新消息。
如果一个或多个副本在同步和非同步之间快速切换，说明集群内部出现了问题，通常是Java不恰当的垃圾回收配置导致的。不恰当的垃圾回收配置会导致几秒钟的停顿，从而让broker与zookeeper之间断开连接，最后变成不同步的，进而发生状态切换。一个滞后的同步副本会导致生产者和消费者变慢。
## Broker配置
Broker有三个配置参数可影响kafka的可靠性
1. 复制系数，主题级别replication.factor，Broker级别可通过default.replication.factor类配置自动创建的主题。Kafka默认的复制系数是3。
2. 不完全首领选举，unclean.leader.election只能在broker级别（实际上是在集群范围内）进行配置，它的默认值是true。如果在分区首领不可用时，所有的其他副本都是不同步的，这时候我们必须要做出一个两难的选择。
- 如果不同步的副本不能被提升为新首领，那么分区在旧首领(最后一个同步副本)恢复之前是不可用的。
- 如果不同步的副本可以被提升为新首领，那么在这个副本变为不同步之后写入旧首领的消息会全部丢失，导致数据不一致。简而言之，若允许不同步副本成为首领，就需要承担丢书数据和出现数据不一致的风险。若不允许他们成为首领，那么久要接受较低的可用性。
- 最小同步副本，在主题级别和broker级别上，这个参数都叫min.insync.replicas。表示至少存在min.insync.replicas个副本才能向分区写入数据，否者抛出NotEnoughReplicasException异常。
## 在可靠系统里使用生产者
1. 使用发送确认参数acks
2. 配置生产者重试参数，处理错误，重试可重试的错误，如LEADER_NOT_AVAILABLE，放弃不可重试错误，如INVALID_CONFIG。
3. 额外错误处理，根据不同业务需求，记录或回调另一个应用程序。
## 在可靠系统里使用消费者
消费者的可靠性配置
1. group.id，如果多个消费者有相同的group.id，并且订阅了同一主题，那么每个消费者只能读到所有消息的一个子集，所有子集之和是该主题的全集。如果你希望消费者可以看到主题的所有消息，那么只需要给他设置唯一的group.id
2. auto.offset.reset。这个参数指定了在没有偏移量提交时，或请求的偏移量在broker上不存在时，消费者的操作，可参见消费者配置参数说明。
3. enable.auto.commit。设置消费者基于任务调度自动提交偏移量。
4. auto.commit.interval.ms。设置自动提交后，此配置设置提交的频率。
如果希望能够更多地控制偏移量提交的时间点，可通显式提交偏移量的方法，显式提交需要注意以下几点：
1. 总是在处理完事件后再提交偏移量。
2. 提交频度是性能和重复消息数量之间的权衡。
3. 确保对提交的偏移量心里有数。
4. 再均衡。
5. 消费者可能需要重试。
6. 消费者可能需要维护状态。
7. 长时间处理。
8. 仅一次传递。
## 验证系统可靠性
一般需要做三个层面的验证: 配置验证、应用程序验证、生产环境的应用程序监控。
- 配置验证: Kafka提供了两个重要的工具用于验证配置，分别是：org.apache.kafka.tools包里的VerifiableProducer和VerifiableConsumer两个类。可以通过命令行或嵌入到自动化测试框架中去验证。一般配置测试需要关注以下几点：1.首领选举 2.控制器选举 3.依次重启 4.不完全首领选举
- 应用程序验证: 应用程序验证包括：检查自定义错误处理代码、偏移量提交方式、再均衡监听器以及其他使用了kafka客户端的地方。建议测试的故障：1.客户端从服务端断开 2.首领选举 3.依次重启broker 4.依次重启生产者 5.依次重启消费者
- 生产环境监控可靠性。 1.监控集群健康状况。2.监控Kafka客户端的JMX度量指标，这些指标用于监控客户端的状态和事件。生产者：error-rate和retry-rate，指标上升，说明系统出现问题。此外，还要监控生产者日志，发送消息的错误日志被设置为WARN级别。对于消费者，最重要的指标是consumer-lag，该指标表明了消费者的处理速度与最近提交的分区里的偏移量之间还有多少差距。理想情况下总为0，代表消费者总能读到最新消息。不过实际情况中，因为poll()方法会返回很多消息，消费者在获取更多数据之前需要花一些时间来处理它们，所以该指标会有些波动。
# 构建数据管道
在使用kafka构造数据管道时，通常有两种使用场景，1.把kafka作为数据管道的两个端点之一 2.把kafka作为数据管道两个端点中间的媒介。
Kafka为数据管道带来的主要价值在于，它可以作为数据管道各个数据段之间的大型缓冲区，有效地解耦管道数据的生产者和消费者。Kafka的解耦嫩李以及在安全和效率方面的可靠性，使它成为构建数据管道的最佳选择。
## 构建数据管道需要考虑的问题
1. 及时性。Kafka扮演一个大型缓冲区角色，降低生产者和消费者之间的时间敏感度。
2. 可靠性。源系统的每一个事件都必须到达目的地，不允许丢失，也不允许重复。
3. 高吞吐量和动态吞吐量。协调生产者和消费者的吞吐量，适当的时候进行伸缩，以满足持续变化的需求。
4. 数据格式。数据管道需要协调各种数据格式和数据类型，这是数据管道一个非常重要的因素。数据类型取决与不同的数据库和数据存储系统。
5. 转换。数据管道的构成可以分为两大阵营，即ETL和ELT，ETL表示：提取-转换-加载，也就是说，当数据流经数据管道时，数据管道会负责处理它们。这种方式为我们节省了时间和存储空间，但是会给数据管道下游的应用造成一些限制。ELT标示：提取-加载-转换，这种模式下，数据管道只做少量的转换(主要数数据类型)，确保达到数据池的数据尽可能地与数据源保持一致。被称作高保真数据管道，或数据湖。
6. 安全性。Kafka支持加密传输数据，从数据源到kafka，再从kafka到数据池，它还支持认证(通过SASL来实现)和授权。Kafka还提供国审计日志用于跟踪访问记录。
7. 故障处理能力。Kafka会长时间保留数据，可以在适当的时候回过头来重新处理错误的数据。
8. 耦合性和灵活性。数据管道最重要的作用之一是解耦数据源和数据池。他们在很多情况下可能发生耦合。如，临时数据管道将数据管道与特定的端点耦合起来，创建了大量的集成点，需要额外部署、维护和监控。元数据丢失，如果数据管道没有保留schema元数据，而且不允许schema发生变更，那么会最终导致生产者和消费者之间发生紧密耦合。没有了schema,生产者和消费者需要额外的信息来解析数据。末端处理。尽量保留原始数据的完整性，让下游的应用自己决定如何处理聚合数据。
## 如何在Connect API和客户端API之间做出选择
connect是kafka的一部分，它为kafka和外部数存储系统之间移动数据提供了一种可靠的伸缩方式。启动connect
```sh
bin/connect-distributed.sh config/connect-distributed.properties
```
connect的主要配置参数
```sh
//与connect协同工作的broker服务器
bootstrap.servers :xx
//具有相同group.id的worker属于同一个connect集群
group.id
//消息键转换器，默认使用JSONConverter
key.converter
//消息值转换器，默认使用JSONConverter
value.converter
```
## 深入理解connect
connect组件
- 连接器和任务。连接器和任务负责数据移动。连接器插件实现了Connector API,API包含了两个部分：连接器，连接器主要负责三件事，1.决定需要运行多少个任务 2.按照任务来拆分数据复制。 3. 从worker进程获取任务配置并将其传递下去。任务,任务负责将数据移入或移出Kafka。任务在初始化时会得到worker进程分配的一个上下文：源系统上下文(source context)包含了一个对象，可将源系统记录的偏移量保存在上下文中。
- worker进程，worker进程负责REST API、配置管理、可靠性、高可用性、伸缩性和负载均衡。worker进程是连接器和任务的容器。它们负责处理http请求，这些请求用于定义连接器和连接器的配置。worker还负责保存连接器配置、启动连接器和连接器任务，并把配置信息传递给任务。
- 转化器和connect数据模型。用户在配置worker进程时，可以选择使用合适的转化器，用于将数据保存到kafka。目前可用的转化器有Avro、JSON、String。Connect API可以支持多种数据类型的数据，数据类型与连接器的实现是相互独立的--只要有可用的转化器，连接器和数据类型可以自由组合。
- 偏移量管理，worker进程的REST API提供了部署和配置管理服务，除此之外，worker进程还提供了偏移量管理服务。连接器只要知道哪些数据是已经被处理过的，就可以通过kafka提供的API来维护偏移量。
## connect之外的选择
### 用于其他数据存储的摄入框架
Kafka之外其他的数据摄入框架，Hadoop使用Flume,ELasticSearch使用了Logstash或Fluentd。
### 基于图形界面的ETL工具
Informatica、Talend、Pentaho、Apache NiFi、StreamSets这些ETL解决方案都支持将kafka作为数据源和数据池。
### 流式处理框架
几乎所有的流式处理框架都具备从Kafka读取数据并将数据写入外部系统的能力。使用流式处理框架可以不需要保存来自kafka的数据，而是直接从kafka读取数据然后写到其他系统，不过在发生数据丢失或者出现脏数据时，诊断问题变得很困难。
# 跨集群数据镜像
集群节点之间的数据复制叫做，镜像，kafka内置跨集群复制工具MirrorMaker。以下是几个使用跨集群镜像的场景。
- 区域集群和中心集群，集群分布在不同的地理区域,不同城市，甚至不同大洲。区域集群的数据会镜像到中心集群。
- 冗余，集群冗余可保证系统高度可用。
- 云迁移，将本地数据中心镜像到云端。
## 多集群架构
### 跨数据中心通信的一些现实问题
1. 高延迟，集群间的网络跳转所带来的的缓冲和堵塞会增加通信延迟。
2. 有限带宽，单个数据中心的外网带宽一般都很低，此外，高延迟让如何利用这些带宽变得更加困难。
3. 高成本，集群间的通信需要更高的成本。
kafka集群架构原则
- 每个数据中心至少需要一个集群
- 每两个数据中心之间的数据复制要做到每个事件仅复制一次
- 如果有可能，尽量从远程数据中心读取数据，而不是写入
### Hub和Spoke架构
一个中心集群对应多个本地Kafka集群。最简单的，只有一个本地集群。这种结构优点在于，数据只会在本地数据中心生成，而且每个数据中心的数据只会背镜像到中央数据中心一次。只处理单个数据中心数据的应用可以被部署在本地数据中心，需要处理多个数据中心的应用程序则需要被部署在中央数据中心里。因为数据复制是单向的，而且消费者总是从一个集群读取数据，所以这种架构易于部署、配置和监控。这种结构的缺点：一个数据中心的应用程序无法访问另一个数据中心的数据。
### 双活架构
当有两个或多个数据中心需要共享数据，并且每个数据中心都可以生产和读取数据时，可以使用双活(Active-Active)架构。这是一种最简单、最透明的失效备援方案。双活架构的主要问题在于，如何在进行多个位置的数据异步读取和异步更新时避免冲突。另外，我们还要避免循环镜像，相同的事件不能无止境地来回镜像。
### 主备架构
为了达到灾备的目的，你可能在同一个数据中心安装了两个激情，他们包含相同的数据，平常只使用其中一个，另一个拥有所有应用程序和数据的非活跃复制。这种架构易于实现，并且可以用于任何一种场景。缺点在于，它浪费了一个集群，Kafka集群间的失效备援比我们想象的要难得多。
失效备援包括内容如下：
- 数据丢失和不一致性，kafka各种镜像解决方案都是异步的，灾备集群总是无法及时获取主集群的最新数。我们需要监控两者间的距离，保证不出现太大的差距。
- 失效备援之后的起始偏移量，在切换到灾备集群的过程中，最具挑战性的事情莫过于如何让应用程序知道该从什么地方开始处理数据。可以使用以下方法：1.偏移量自动重置，kafka消费者有一个配置项，用于指定在没有上一个提交偏移量的情况下，如何处理，要么从起始，要么从末尾开始读取数据。2.复制偏移量主题，kafka0.9或以上版本，消费者会把偏移量提交到_consumer_offsets主题上。需要接受一定程度的数据重复。
- 基于时间的失效备援，kafka0.10.0以上，消费者的每个消息都包含一个时间戳，这个时间戳指明消息发送给Kafka的时间，broker提供了一个索引和一个API，用于根据时间戳查找偏移量。
- 偏移量外部映射，使用外部数据存储（如Apache cassandra）来保存集群之间的偏移量映射。
- 正常失效备援之后，需要清理旧的主集群，删掉所有的数据和偏移量，然后从新的主集群上把数据镜像回来。
- 集群发现，发生失效备援之后，应用程序需要知道如何与灾备集群发生通信。可采用：DNS别名、服务发现工具，zookeeper、Etcd、Consul等
### 延展集群
在整个数据中心发生故障时，可以使用延展集群(stretch cluster)来避免kafka集群失效，延展集群就是跨多个数据中心安装的单个Kafka集群。优点：同步复制。缺点：所能应对的灾难类型有限，只能应对数据中心故障，无法应对应用程序或者kafka故障。此外，该结构运维复杂，所需要的物理基础设施成本昂贵。
## Kafka的MirrorMaker
MirrorMaker用于在两个数据中心之间镜像数据。它包含了一组消费者，这些消费者属于同一个群组，并且从主题上读取数据。每个MirrorMaker进程都有一个单独生产者。镜像过程很简单：MirrorMaker为每个消费者分配一个线程，消费者从源集群的主题和分区上读取数据，然后通过公共生产者将数据发送到目标集群上。默认情况下，消费者每隔60s通知生产者发送所有数据到kafka，并等待kafka确认。然后消费者再通知源集群提交这些事件相应的偏移量。这样可以保证数据不丢失。而且如果MirrorMaker进程发生崩溃，最多只会出现60s的重复数据。
MirrorMaker是高度可配置的。它使用了生产者消费者，意味着对生产者消费者的配置对MirrorMaker通用，其他配置如下
```sh
//指定消费者配置文件
consumer.confg
//指定生产者配置文件
producer.config
```
MirrorMaker一般部署在目标数据中心，因为：无法连接到数据中心的消费者比无法连接到数据中心的生产者安全得多，远程读取比远程生成更安全。但是，若要对数据进行加密传输，那么最好部署在源端。此外，可以在不同机器上运行至少两个MirrorMaker，以保证镜像能够成功。
MirrorMaker部署后，最好针对以下指标进行监控
- 延迟监控，监控目标集群落后于源集群的偏移量。
- 度量指标监控，主要针对消费者和生产者。
### MirrorMaker调优
MirrorMaker集群的大小取决于对吞吐量的需求和对延迟的接受程度。使用kafka-performance-producer工具，通过修改消费者线程数num.streams配置不同的数字(如：1，2，4，8，16)，并观察性能在哪个点开始下降，然后将num.streams的值设置为一个小于当前点的整数。
系统优化
增加TCP的缓冲区大小：net.core.rmem_default、net.core.rmem_max、net.core.wmem_default、net.core.wmem_max、net.core.optmem_max、
启动时间窗口自动伸缩：
```sh
sysctl -w net.ipv4.tcp_window_scaling=1 / /echo net.ipv4.tcp_window_scaling=1 >  /etc/sysctl.conf
```
减少TCP慢启动时间: 设置/proc/sys/net/ipv4/tcp_slow_start_after_idle=0
## 其他跨集群镜像方案
### uber的uReplicator
MirrorMaker会有再均衡延迟，并且难以增加新的主题等问题，uReplicator使用Apache Helix作为中心控制器，控制器管理着主题列表和分配给每个uReplicator实例的分区。管理员通过REST API添加新主题，uReplicator负责将分区分配给不同的消费。uber使用Helix Consumer替换MirrorMaker里的kafka Consumer。Helix Consumer接受由Helix控制器分配的分区，而不是在消费者间再均衡。
### Confluent的Replicator
Replicator为Confluent的企业用户解决了他们在MirrorMaker进行多集群部署时所遇到的问题。Replicator里，每个任务包含一个消费者，一个生产者。connect根据实际情况将不同的任务分配给不同的worker节点，因此单个服务器上会有多个任务，或者任务被分散在多个服务器上，这样就避免了手动去配置每个MirrorMaker实例需要多少个线程，以及每台服务器需要多少个MirrorMaker实例。此外，Replicator不仅可以从kafka上复制数据，还可以从zookeeper上复制主题的配置信息。
# 管理Kafka
## 主题操作
kafka-topic.sh可执行大部分的主题操作。如：创建、修改、删除、和查看主题。
```sh
#kafka-topic.sh --zookeeper localhost:2181/kafka-cluster --create --topic my-topic --replication-factor 2 --partitions 8

#kafka-topic.sh --zookeeper localhost:2181/kafka-cluster --alert --topic my-topic --replication-factor 2 --partitions 16

#kafka-topic.sh --zookeeper localhost:2181/kafka-cluster --delete --topic my-topic

#kafka-topic.sh --zookeeper localhost:2181/kafka-cluster --list

//topic为可选，指定topic后只会显示指定topic的详情 --under-replicated-partitions列出所有包含不同步副本的分区。
#kafka-topic.sh --zookeeper localhost:2181/kafka-cluster --describe --topic xxx
```
## 消费者群组
旧版本的消费者信息保存在zookeeper上，新版本的消费者信息保存在broker上。可以使用kafka-consumer-groups.sh工具查看，旧版本带--zookeeper，新版本带--bootstrap-server。
```sh
# kafka-consumer-groups.sh --zookeeper localhost:2181/kafka-cluster --list

# kafka-consumer-groups.sh --zookeeper localhost:2181/kafka-cluster --describe --group testgroup

//--topic 从消费者中删除指定的topic
# kafka-consumer-groups.sh --zookeeper localhost:2181/kafka-cluster --delete --group testgroup

//导出偏移量
# kafka-run-classh.sh kafka.tools.ExportZKOffsets --zkconnect localhost:2181/kafka-cluster --group testgroup --output-file offsets
//导入偏移量
# kafka-run-classh.sh kafka.tools.ImportZKOffsets --zkconnect localhost:2181/kafka-cluster --group testgroup --input-file offsets
```
## 动态配置变更
```sh
# kafka-configs.sh --zookeeper localhost:2181/kafka-cluster --alter --entity-type topics --entity-name test --add-config key=value,key1=value1

# kafka-configs.sh --zookeeper localhost:2181/kafka-cluster --alter --entity-type client --entity-name client-id --add-config key=value,key1=value1

//列出可被覆盖的配置，不包括默认配置
# kafka-configs.sh --zookeeper localhost:2181/kafka-cluster --describe --entity-type topic --entity-name topic-name
//列出可被覆盖的配置，不包括默认配置
# kafka-configs.sh --zookeeper localhost:2181/kafka-cluster --describe --entity-type topic --entity-name topic-name --delete-config retention.ms
```
## 分区管理
kafka提供两个脚本用于管理分区，一个用于重新选举首领，另一个用于将分区分配给broker。
```sh
//启动集群的首领选举，若节点元数据小于1M，节点会被写到zookeeper上，大于1M使用json文件
# kafka-preferred-replica-election.sh --zookeeper localhost:2181/kafka-cluster

# kafka-preferred-replica-election.sh --zookeeper localhost:2181/kafka-cluster --path-to-json-file partitions.json
//修改分区副本,为topics.json文件里的主题生成迁移步骤，将这些主题迁移到broker0和broker1上
# kafka-reassign-partitons.sh --zookeeper localhost:2181/kafka-cluster --topic-to-move-json-file topics.json --broker-list 0,1
//执行迁移
# kafka-reassign-partitons.sh --zookeeper localhost:2181/kafka-cluster --execute --reassignment-json-file reassign.json
//验证
# kafka-reassign-partitons.sh --zookeeper localhost:2181/kafka-cluster --verify --reassignment-json-file reassign.json

//验证分区副本一致性
# kafka-replica-verification.sh --broker-list localhost:9001,localhost:9002 --topic-with-list 'my-.*'
```
## 消费和生产
利用脚本kafka-console-consumer.sh和kafka-console-producer.sh可以手动生成或消费消息。
## 客户端ACL
命令工具kafaka-acls.sh可以用于处理客户端访问控制相关的问题。

# 监控Kafka
## broker度量指标
### 非同步分区
该指标指明了作为首领的broker有多少个分区处于非同步状态。若指标一直保持不变，那么说明集群中的某个broker已经离线。整个集群非同步分区的数据量等于离线broker的数量。若指标波动，或者虽然数量稳定，但是没有broker离线，说明集群出现了性能问题。需要确认问题与单个broker有关还是与整个集群有关。
集群级别的问题一般分为两类：1.不均衡的负载。2.资源过度消耗
其中不均衡问题负载定位需要用到以下指标
- 分区的数量
- 首领分区的数量
- 主题流入字节速率
- 主题流入消息速率
在均衡的集群中，这些度量指标的数值在整个集群范围是均等的。也就是说，所有的broker几乎处理相同的流量。假设在运行了默认的副本选举后，这些度量指标出现了很大的偏差，那说明集群的流量出现了不均衡。
资源过度消耗问题可以通过以下指标监控
- CPU使用
- 网络输入吞吐量
- 王路输出吞吐量
- 磁盘平均等待时间
- 磁盘使用百分比
上述任何一种资源出现过度消耗，都表现为分区的不同步。
主机级别的问题
如果性能问题不是出现在集群上，而是出现在一两个broker里，那么就要检查broker所在的主机。主机级别问题可分为以下几类：
- 硬件问题，使用硬件检测工具检测。
- 进程冲突，其他应用程序的运行消耗系统资源，给Kafka带来压力。
- 本地的配置不一致，broker配置或者系统配置与其他不一致。
### broker度量指标
除了非同步分区外，还有很多其他指标需要监控，包括：
- 活跃控制器数量，0或者1。任何时候只有一个控制器，若出现两个，说明有一个本该退出的控制器线程被阻塞了，这会导致管理任务无法正常执行，比如移动分区。
- 请求处理器空闲率，Kafka使用两个线程来处理客户端请求，网络处理器线程池、请求处理器线程池。前者负责通过网络读入和写出数据，后者负责处理来自客户端的请求，包括：从磁盘读取消息和写入消息。若boker负载增长，会对该指标造成很大影响。空闲低于20%会有潜在问题，低于10%说明出现了性能问题。
- 主题流入字节，该指标可以用于确定何时该对集群进行扩展或开展其他与规模增长相关的工作。它也可以用于评估一个broker是否比集群里的其他broker接收了更多的流量，如果出现这种情况，就需要对分区进行再均衡。
- 主题流出字节，与主题流入字节类似，是另一个与规模增长有关的度量指标。
- 主题流入的消息，以每秒生成的消息个数来度量流量，不考虑消息大小。
- 分区数量，分区总数，一般不会改变。
- 首领数量，应该在整个集群的broker上保持均等。
- 离线分区，离线分区数量。
- 请求度量指标，每个kafka请求，都有相应的度量指标。
### 主题和分区的度量指标
#### 主题实例的度量指标
#### 分区实例的度量指标
### java虚拟机监控
除了broker外，还应该对服务器提供的一些标准进行监控，包括JVM虚拟机。如果JVM频繁发生垃圾回收，就会影响broker的性能。
- 垃圾回收，对JVM来说最需要监控的就是GC，CollectionCount垃圾回收次数，CollectionTime垃圾回收时间(ms)，LastGcInfo里，duration以ms为单位，表示最后一次GC花费的时间。
- java操作系统监控，这些指标中有两个比较有用，但是在操作系统中难以收集到，分别是：MaxFileDescriptorCount和OpenFileDescriptorCount，分别表示，JVM能够打开的文件描述符(FD)最大数量和已打开的文件描述符数量。
### 操作系统监控
对操作系统，需要监控CPU使用、内存使用、磁盘使用、磁盘I/O和网络使用情况。
对于CPU us: 用户空间使用时间 sy: 内核空间使用时间 ni: 低优先级进程使用时间 id: 空闲时间 wa: 磁盘等待时间 hi: 处理硬件中断时间 si: 处理软件中断时间 st: 等待管理程序时间
对于内存，需监控内存空间和可用交换内存空间，确保内存交换空间不会被占用。
对于磁盘，需监控磁盘空间和索引节点进行监控，确保磁盘空间不被用光。此外磁盘I/O反应了磁盘的运行效率，需要监控磁盘的读写速度、读写平均队列大小、平均等待时间和磁盘使用百分比。
对于网络，需要监控流入和流出的网络流量。
### 日志
将kafka.controller、kafka.server.ClientQuotaManager 设为INFO级别，并与broker主日志文件分开存放。
将kafka.request.logger、kafka.log.LogCleaner、kafka.log.Cleaner和kafka.log.LogCleanerManager设为DEBUG
## 客户端监控
### 生产者度量指标
### 消费者度量指标
### 配额
## 延时监控
## 端到端监控

---
参考：
- []()
- []()
