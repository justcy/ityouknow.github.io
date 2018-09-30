---
layout: post
title: Mysql 升级过后错误
category: mysql
tags: [mysql]
keywords: mysql,upgrade,docker
---
## 问题

docker启动官方mysql镜像后，发现数据库版本与之前建库版本不一致，导致了navicat 等工具连接后只显示information_schema

网上一查[navicat premium连接上mysql后只能看到information_schema库](https://blog.csdn.net/qq_22557809/article/details/79638778)，说是权限问题
于是
```
select * from mysql.user where user='root'
```
在显示列表中，root用户的权限都为Y，不是权限问题。
查看mysql启动日志
```
2018-09-30T01:06:48.651000Z 0 [ERROR] Incorrect definition of table mysql.db: expected column 'User' at position 2 to have type char(32), found type char(16).
2018-09-30T01:06:48.651018Z 0 [ERROR] mysql.user has no `Event_priv` column at position 28
2018-09-30T01:06:48.651836Z 0 [ERROR] Event Scheduler: An error occurred when initializing system tables. Disabling the Event Scheduler.
```

## 原因&修复
这是因为mysql软件包升级了，导致管理数据库的表结构发生了变化，以前老版本上建立的数据库需要升级才能够显示。命令如下

```
> mysql_upgrade -u root -p
```

注意：命令要在mysql的宿主机上执行，而不是mysql命令行下
修复完成后，重启数据库，问题解决，消失的表又回来了
