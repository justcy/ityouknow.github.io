---
layout: post
title: mac下自带的Apache开启关闭
category: toos
tags: [apach,mac,web]
keywords: mac,apache,web
---
#在使用mac os 进行web开发时，会遇到80端口已经被占用的情况。解决这个问题可以通过以下几个步骤。

1、使用lsof -i:80查看当前占用80端口的进程，如果有就kill掉。
2、关闭mac自带apache的启动。



```
sudo launchctl unload -w /System/Library/LaunchDaemons/org.apache.httpd.plist
```


如果哪天你想让它开机启动了,则将unload 改为 load:


```
sudo launchctl load -w /System/Library/LaunchDaemons/org.apache.httpd.plist
```