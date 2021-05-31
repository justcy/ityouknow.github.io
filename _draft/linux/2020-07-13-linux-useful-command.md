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
# find 命令
格式 find path -option [-print] [-exec -ok command] {} \;
find 命令默认是递归的。
```sh
# 删除当前目录下所有.开头的文件
> find . -type f -name .\* -exec rm {} \;
# 删除当前目录下所有.abc开头的文件
> find . -type f -name .abc\* -exec rm {} \;

# 删除yourdir目录下所有.abc开头的文件
> find yourdir -type f -name .abc\* -exec rm {} \;

# 删除yourdir目录下所有.html结尾的文件
find yourdir -type f -name "*.html" -exec rm {} \;

# 统计yourdir目录下所有文件名包含res的文件的文件个数
find . -type f -name '*res*' | wc -l

# 找到yourdir目录下所有文件名包含res的文件，并批量移动到../imgRes中
find . -type f -name '*res*' -exec mv {} ../imgRes  \;

```
## 显示过滤注释( # ; 开头) 和空行后的配置信息
```
$ grep -Ev "^$|^[#;]" server.conf
```
## 删除指定长度文件名文件

```
 rm -rf $(ls | awk '{if(length($0)==32){print $0}}')
```
# awk命令
```sh
awk '$9>1900'|awk '{print $1}'
```
## 文件内容过滤
文件A
```
a,b,c,d
1,2,3,4
2,2,3,4
3,2,3,4
4,2,3,4
5,2,3,4
6,2,3,4
```
文件B
```
a
1
2
6
```
目标：得到文件C
```
1,2,3,4
2,2,3,4
6,2,3,4
```
命令：
```sh
for i in `cat B.txt`;do awk -F ","  '{if(NR=="'$i'") print $0}' A.txt;done > C.txt 
for i in `cat B.txt`;do awk -F "," v val="$i" '{if($1==val) print $0}' A.txt;done >  C.txt 
for i in `cat B.txt`;do i=$[i+1];awk -F ","  '{if(NR=="'$i'") print $0}' A.txt;done > C.txt 

for seed in `cat seed.txt`; do
	# cat result_test.txt | awk  -F "," '{if($1=="$seed") print $0}'  
	awk  -F "," -v val="$seed" '{if($1==val) print $0}' result.csv >> result_filter.txt
done
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
# Centos6安装php7.2
```sh
# yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm
# yum install http://rpms.remirepo.net/enterprise/remi-release-6.rpm
# yum install yum-utils
# yum-config-manager --enable remi-php72   [Install PHP 7.2]
# yum-config-manager --enable remi-php70   [Install PHP 7.0]
# yum-config-manager --enable remi-php71   [Install PHP 7.1]
# yum install php php-mcrypt php-cli php-gd php-curl php-mysql php-ldap php-zip php-fileinfo php-fpm php-swoole php-redis
# php -v
```
# vi 批量注释和解注释
## 方法一：可视块模式
批量注释
>Ctrl+v进入VISUAL BLOCK（可视块）模式，按 j （向下选取列）或者 k （向上选取列）
按Shift + I 进入编辑模式，输入你想要插入的字符（任意字符）
按两次Esc就可以实现批量插入字符，不仅仅实现批量注释而已。

批量解注释
>Ctrl+v进入VISUAL BLOCK（可视块）模式，按 j （向下选取列）或者 k （向上选取列）
按 x 或者 d 批量删除字符

## 方法二：末行模式替换
批量注释
>命令行模式下，输入 " : 首行号，尾行号s /^/字符/g "实现批量插入字符。
如 输入:5,10s/^/#/g，在5到10行首插入#
如 输入:5,10s/$/#/g，在5到10行尾追加#

批量解注释
>命令行模式下，输入 " : 首行号，尾行号s /^字符//g "实现批量删除字符。
如 输入:5,10s/^#//g，在5到10行首删除#
如 输入:5,10s/#$/?/g，在5到10行尾将#替换成?

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
