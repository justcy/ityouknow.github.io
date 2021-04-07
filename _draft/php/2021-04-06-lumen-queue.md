---
layout: post
title: "lumen队列在项目中的应用"
tagline: ""
date: '2021-04-06 16:45:09 +0800'
category: php
tags: php lumen队列在项目中的应用
keywords: php,lumen队列在项目中的应用
description: php,lumen队列在项目中的应用
---
> lumen队列在项目中的应用
# 引言


由于项目需要，公司游戏服务端对于异步，延时有越来越大的需求。所以考虑使用lumen的队列来实现。
在一切开始之前，我们先考虑以下几种情形：
- 邮件或短信发送。
- 游戏开局10s后没有提交分数，自动判定为0分。
- 一定时间后没有真实用户匹配，考虑增加假的匹配信息，保证用户的正常游戏体验，比如，5分钟。
- 增加假匹配后，假如和提交分数不能固定时间，否则很容易被玩家看出来。

# 开始之前
由于公司一直使用到的是PHP语言作为休闲游戏的服务端，并且使用php-fpm部署，并不能实现长连接。所以在有些业务场景下并不适用。比如，当玩家的任务状态发生变化的时候，并不能及时有效的通知到客户端。
之前的项目采用的是，在每次有需要通知客户端的时候使用message，或者notification两种情况通知客户端。逻辑如下：

- message方式：在message表中插入一条消息数据，并且标示：有消息，客户端每次请求的时候会检查标示：是否有消息，若有，则客户端重新发起请求，拉取message消息列表，得到消息列表后，根据不同的消息类型处理不同的逻辑，如：召回活动，获取某种奖励等等。客户端处理完消息后调用标记接口，将该消息标记为已读。
- notification方式：若有消息需要通知客户端，则在当前请求过程当中将通知的key和通知的value放到Controller(实际：代码内存中)，在消息返回之前检查是否有notification需要发送，如果有，则在返回的消息体里面增加notification的结构。
```
"notification":[
	{"key"=>"xxx_notification","value"=>["实际返回的结果"]}
]
```
以上两种方式都是在服务端不支持长连接的情况下，为保证服务端及时将信息下发到客户端所做的设计。与长连接相比，弊端在于，数据的下发都是基于客户端的请求，若客户端长时间没有任何需要与服务端交互的请求，那么，
- message数据将会积压在message表，直到下一次客户端正常请求，并且随后请求了message列表。而且，一旦客户端并未按照流程处理，就会出现意想不到的问题，比如，在有消息标示的时候，不及时获取消息列表，导致消息堆积，或者在消息展示处理之后未及时调用消息标记列表，导致消息重复处理。

- Notification消息只能在当前请求会话内下发，并不能持久缓存。在实际应用中，遇到有回调类型或者处理有延迟的情况，就不能及时下发当前状态改变，而且，这种消息也不能放置到下次请求当中。例如：充值完成后将用户标示为充值用户，以便用户在活动中能够获得额外的奖励。由于充值成功与否基于第三方回调，第三方回调时机并不确定，服务端无法将充值成功与否的状态及时告知客户端。此外，原有方式只能够给当前用户发送notification，并不能给对手，或其他人发送。

  基于以上两种问题，新版的无长连接通信方式决定采用notification，暂时弃用message。并且在原有notification的基础上做调整，使之支持消息持久化，并支持给任意其他用户发送notification

  ```php
  //设置
  static function clientNotification($name, $data)
  {
    self::$notification_to_client[] = ["name" => $name,"value" => $data];
  }
  
  //下发
  if(!empty(self::$notification_to_client)){
     $ret['notification'] = self::$notification_to_client;
  }
           
  ```
  调整为:
  ```php
  //设置
  static function clientNotification($user_id, $name, $data)
  {
        $cache_Key = 'xxx_' . $user_id;
        RedisService::center()->lpush($cache_Key, serialize(["name" => $name, "value" => $data]),12);
        RedisService::center()->expire($cache_Key,600);//设置notification队列的有效时间，以最后一条消息添加时设置的过期时间为准
  }
  
  //下发
 try {
     $user_auth = Auth::user();
     $cache_Key = 'xxx_' . $user_auth['user_id'];
     if (RedisService::center()->exists($cache_Key)) {
       $notification = RedisService::center()->rpop($cache_Key);
       while ($notification) {
         $ret['notification'][] = unserialize($notification);
         $notification = RedisService::center()->rpop($cache_Key);
       }
     }
   } catch (\Exception $e) {
   }
           
  ```
> 以上是在php发布方式不改变，继续使用php-fpm的状况下的权宜之计，从长远看，应该及时使用长连接，如PHP+swoole，具体可参考 [lumen整合使用swoole发布](https://blog.kanter.cn/php/2021/01/12/lumen-start-with-swoole/)，或者使用golang或java等常驻内存支持长连接的语言。
# lumen队列配置
## step1. 在项目目录**confg/**下新增配置queue.php配置文件，内容如下：
```php
<?php
return [
    'default' => env('QUEUE_CONNECTION', 'sync'),//默认队列方式 sync：同步方式 redis:redis队列方式 database:数据库存储记录方式。
    'connections' => [
        'sync' => [
            'driver' => 'sync',
        ],
        'database' => [
            'driver' => 'database',//数据库方式，如 mysql pgsql
            'table' => 'jobs',//表名
            'queue' => 'default',//队列名称
            'retry_after' => 90,//重试等待时间
        ],
        'redis' => [
            'driver' => 'redis',//redis方式
            'connection' => env('QUEUE_REDIS_CONNECTION', 'center'),//redis连接配置，由database.php里面的redis配置决定
            'queue' => 'default',//队列名称
            'retry_after' => 90,//重试等待时间
            'expire' => 7200,//超时时间
            'block_for' => null,//驱动在将任务重新放入 Redis 数据库以及处理器轮询之前阻塞的时间
        ],
    ],
    'failed' => [
        'database' => env('DB_CONNECTION', 'mysql'),//失败处理驱动
        'table' => env('QUEUE_FAILED_TABLE', 'failed_jobs'),//失败记录存放的表名
    ],
];
```
lumen还支持更多的驱动配置方式，完整的配置文件及配置项可参考文件[config/queue.php](https://github.com/laravel/lumen-framework/blob/8.x/config/queue.php)
lumen支持的驱动方式
- sync,同步方式，无需额外插件扩展
- database,数据库方式，需新建jobs数据库表，需对应的数据库驱动程序，如mysql，jobs表新建参考命令行: 
```sh
>php artisan queue:table
```

- redis,redis方式，需要安装redis扩展**predis/predis ~1.0**
- beanstalkd,一种简单快速的工作队列，需要安装扩展**pda/pheanstalk ~4.0**，官网[beanstalkd](https://beanstalkd.github.io/)
- sqs,需要安装**aws/aws-sdk-php ~3.0**，Amazon Simple Queue Service (SQS) 是一种完全托管的消息队列服务，可让您分离和扩展微服务、分布式系统和无服务器应用程序。[sqs官网](https://aws.amazon.com/cn/sqs/)

## Step2 测试
1.在项目app/Jobs目录下找到ExampleJob.php更改如下：
```php
<?php

namespace App\Jobs;

class ExampleJob extends Job
{
    private $id;
    private $name;
    /**
     * Create a new job instance.
     *
     * @return void
     */
    public function __construct($id,$name)
    {
        $this->id = $id;
        $this->name = $name;
    }
    /**
     * Execute the job.
     *
     * @return void
     */
    public function handle()
    {
        echo "this is example job ".$this->id.' '.$this->name;
    }
}
```
2. 启动队列监听
```sh
> php artisan queue:work 
```
> 关于队列有其他的命令可通过 php artisan list | grep queue 查看
>  queue
  queue:failed                 List all of the failed queue jobs
  queue:failed-table           Create a migration for the failed queue jobs database table
  queue:flush                  Flush all of the failed queue jobs
  queue:forget                 Delete a failed queue job
  queue:listen                 Listen to a given queue
  queue:restart                Restart queue worker daemons after their current job
  queue:retry                  Retry a failed queue job
  queue:table                  Create a migration for the queue jobs database table
  queue:work                   Start processing jobs on the queue as a daemon
3. 在合适的地方提交待处理的job
```php
$id = 111;
$name = "1111";
dispatch(new ExampleJob($id,$name));
```
可以看到，页面打印出如下信息，说明队列配置成功可正常使用:
```sh
this is example job 111 1111[2021-04-07 07:557][7iTpcJ2Ho1IKA4p8RzTbrG1iNNK0aZpA] Processed:  App\Jobs\ExampleJob
```
以上，lumen中的queue已经配置完成，你可以在适当的地方dispatch出指定的任务，再由对应的任务处理器处理(handle)。

队列监听如果使用命令行queue:work并不是以守护进程方式运行，可在启动的命令中使用 --daemon参数设置守护进程方式。在实际项目应用中建议使用Supervisor创建守护进程的方式启动。另外，一旦使用守护进程方式启动后，在项目代码有更新，特别是涉及到队列文件更新的时候，需要重新启动任务队列，否则，新的代码不会生效。

除了Supervisor之外还可视情况而定选择合适的启动方式。由于笔者项目使用docker-compose 编排，所以，队列守护使用的是启动一个docker镜像
```yaml
php7-cli:
    image: justcy/php:7.2.23-fpm-alpine
    container_name: php7.2.23-cli
    restart: always
    command: 
      - /bin/sh
      - -c
      - |
        php artisan queue:work  --sleep=3 --tries=1 --daemon
```
# 延时队列
lumen的队列可以在创建的时候设置延时，也可以在XXXJob类中设置 $delay属性实现延时。
如：
```php
$auto_match_job = new AutoMatchJob();
$delay = 30;
dispatch($auto_match_job->delay($delay));

//以上代码与等价
class AutoMatchJob extends Job
{
    private $delay  =30 ;
    ......
}
```
与延时队列类似，队列分发的时候可使用以下这些方法，实现自定义配置
- onConnection,指定分发链接，如reids sqs
- onQueue 指定分发队列。
# 实际应用
基于lumen的消息队列，在团队新项目Solitaire中实现了如下业务
- 用户一旦开始游戏，10分钟未提交分数，则分数自动判定为0分。
- 用户开始匹配后，若一段时间内未匹配到玩家，则自动添加一个已有对局，并在之后随即一个时间提交玩家匹配分。
- 游戏中对局的玩家都完成游戏后，先进行结算，修改没有奖励的游戏数据。

鉴于代码保密，此处就不提供项目源码了，此处只是为了抛砖引玉。
# 扩展
本项目中由于项目整体比较小，并不涉及复杂逻辑下的业务功能，所以，对于队列的时候可以说只是浅尝辄止。关于laravel的队列还有很多高级用法，比如工作链，重试，失败处理，队列优先级等主题，此处就不一一深入了。若有兴趣，可以参考laravel官方文档。

---



参考：
- [laravel队列](https://learnku.com/docs/laravel/5.8/queues/3923#customizing-the-queue-and-connection)
