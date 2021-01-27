---
layout: post
title: "linux常用命令-待续"
tagline: ""
date: '2020-07-13 20:49:44 +0800'
category: linux
tags: linux 
keywords: linux,linux常用命令
description: linux,linux常用命令
---
> linux常用命令

# Linux批量清空当前目录中的日志文件
```
for i in `find . -name "*.log"`; do cat /dev/null >$i; done
for i in `find . -name "*.log"`;do >$i; done
for i in `find . -name "*.log" -o -name "*.out" -o -name "*.sql"`;do >$i; done
```
# docker安装
docker安装需要centos7以上
```sh
$rpm -q centos-release 
```
安装脚本：
```sh
#!/bin/bash

sudo yum remove docker docker-client docker-client-latest docker-common docker-latest docker-latest-logrotate docker-logrotate docker-selinux docker-engine-selinux docker-engine
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo  https://download.docker.com/linux/centos/docker-ce.repo
dnf install https://download.docker.com/linux/centos/7/x86_64/stable/Packages/containerd.io-1.2.6-3.3.el7.x86_64.rpm
sudo yum -y install docker-ce docker-ce-cli containerd.io
sudo systemctl start docker
# 安装docker-compose
yum -y install gcc gcc-c++ python-pip && pip install docker-compose
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
