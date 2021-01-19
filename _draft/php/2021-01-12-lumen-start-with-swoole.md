---
layout: post
title: "lumen整合使用swoole发布"
tagline: ""
date: '2021-01-12 16:00:04 +0800'
category: php
tags: php lumen整合使用swoole发布
keywords: php,lumen整合使用swoole发布
description: php,lumen整合使用swoole发布
---
> lumen整合使用swoole发布
# 引言
公司还在使用传统的php+fpm模式发布项目，无法紧跟当下PHP最新的技术栈，故实践安装使用swoole发布项目

<!-- more -->

# 软件环境

```sh
[root@ip-172-31-0-176 ~]# rpm -q centos-release
centos-release-6-10.el6.centos.12.3.x86_64
[root@ip-172-31-0-176 ~]# phpv
-bash: phpv: command not found
[root@ip-172-31-0-176 ~]# php -version 
PHP 7.1.33 (cli) (built: Oct 26 2019 11:22:12) ( NTS )
Copyright (c) 1997-2018 The PHP Group
Zend Engine v3.1.0, Copyright (c) 1998-2018 Zend Technologies
    with Zend OPcache v7.1.33, Copyright (c) 1999-2018, by Zend Technologies
[root@ip-172-31-0-176 ~]# nginx -v
nginx version: nginx/1.10.2
[root@ip-172-31-0-176 ~]# make -v
GNU Make 3.81
Copyright (C) 2006  Free Software Foundation, Inc.
This is free software; see the source for copying conditions.
There is NO warranty; not even for MERCHANTABILITY or FITNESS FOR A
PARTICULAR PURPOSE.
[root@ip-172-31-0-176 ~]# autoconf -V
autoconf (GNU Autoconf) 2.68
Copyright (C) 2010 Free Software Foundation, Inc.
License GPLv3+/Autoconf: GNU GPL version 3 or later
<http://gnu.org/licenses/gpl.html>, <http://gnu.org/licenses/exceptions.html>
This is free software: you are free to change and redistribute it.
There is NO WARRANTY, to the extent permitted by law.

Written by David J. MacKenzie and Akim Demaille.
```
# step 1 安装swoole
swoole官方文档 [docs](https://wiki.swoole.com/#/environment?id=%e5%ae%89%e8%a3%85%e5%87%86%e5%a4%87)
根据官方文档，安装swoole之前需要准备环境
- php-7.1 或更高版本
- gcc-4.8 或更高版本
- make
- autoconf
查看gcc版本
```sh
[root@ip-172-31-0-176 ~]# gcc -v
Using built-in specs.
Target: x86_64-redhat-linux
Configured with: ../configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info --with-bugurl=http://bugzilla.redhat.com/bugzilla --enable-bootstrap --enable-shared --enable-threads=posix --enable-checking=release --with-system-zlib --enable-__cxa_atexit --disable-libunwind-exceptions --enable-gnu-unique-object --enable-languages=c,c++,objc,obj-c++,java,fortran,ada --enable-java-awt=gtk --disable-dssi --with-java-home=/usr/lib/jvm/java-1.5.0-gcj-1.5.0.0/jre --enable-libgcj-multifile --enable-java-maintainer-mode --with-ecj-jar=/usr/share/java/eclipse-ecj.jar --disable-libjava-multilib --with-ppl --with-cloog --with-tune=generic --with-arch_32=i686 --build=x86_64-redhat-linux
Thread model: posix
gcc version 4.4.7 20120313 (Red Hat 4.4.7-23) (GCC) 
```
当前gcc版本为4.4.7需要先升级到gcc-4.8
## 升级gcc到4.8
根据需要我们执行如下命令：
```sh
wget http://people.centos.org/tru/devtools-2/devtools-2.repo -O /etc/yum.repos.d/devtoolset-2.repo
yum -y install devtoolset-2-gcc devtoolset-2-gcc-c++ devtoolset-2-binutils
scl enable devtoolset-2 bash
```
查看Gcc版本
```sh
[root@ip-172-31-0-176 php.d]# gcc --version
gcc (GCC) 4.8.2 20140120 (Red Hat 4.8.2-15)
Copyright (C) 2013 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
```
## 安装swoole
我们使用源码安装，源码下载地址
[https://github.com/swoole/swoole-src/releases](https://github.com/swoole/swoole-src/releases)
```sh
git clone https://github.com/swoole/swoole-src.git
cd swoole-src && \
phpize && \
./configure && \
make && sudo make install
```
这里swoole线上最新版本为4.6.1，但是需要PHP7.2以上，而测试环境为PHP7.1，所以我们需要安装稍老版本的swoole，这里我们选择v4.4.x
所以需要在源码目录执行：
```sh
git checkout v4.4.x
```
>swoole从4.6.0版本开始不再支持PHP7.1
>![image-20210113112743730](http://static.kanter.cn/uPic/2021/01/13/image-20210113112743730.png)
## 添加swoole到php.ini
```sh
[root@ip-172-31-0-176 ~]# php --ini 
Configuration File (php.ini) Path: /etc
Loaded Configuration File:         /etc/php.ini
Scan for additional .ini files in: /etc/php.d
[root@ip-172-31-0-176 php.d]# cat swoole.ini 
; Enable swoole extension module
extension=swoole.so
```
添加完swoole.ini后重启PHP,可看到swoole扩展已经装好了
```sh
[root@ip-172-31-0-176 php.d]# php -m | grep swoole
swoole
```
## docker内安装swoole
由于swoole编译的时候需要配置enable-xxx，所以在docker镜像内不能采用**pecl install swoole**，我们可以参考官方镜像，使用源码编译的方式安装。[swoole官方docker镜像](https://hub.docker.com/r/phpswoole/swoole)
```sh
  mkdir /usr/src/php/ext/swoole && \
  curl -sfL https://github.com/swoole/swoole-src/archive/master.tar.gz -o swoole.tar.gz && \
  tar xfz swoole.tar.gz --strip-components=1 -C /usr/src/php/ext/swoole && \
  docker-php-ext-configure swoole \
  --enable-http2   \
  --enable-mysqlnd \
  --enable-openssl \
  --enable-sockets --enable-swoole-curl --enable-swoole-json && \
  docker-php-ext-install -j$(nproc) swoole && \
  rm -f swoole.tar.gz $HOME/.composer/*-old.phar && \
  docker-php-source delete && \
```
alpine下，swoole源码安装依赖以下环境
```sh
>apk add --no-cache  g++ gcc libc-dev make pkgconf file dpkg-dev dpkg autoconf curl-dev openssl-dev pcre-dev pcre2-dev
```
# Step2 调整代码
lumen和laravel集成使用swoole在github上有很多项目如：
- [laravel-swoole](https://github.com/swooletw/laravel-swoole)
- [laravel-s](https://github.com/hhxsv5/laravel-s)
这里我们使用laravel-swoole
## 安装laravel-swoole
```php
$ composer require swooletw/laravel-swoole
```
##配置providers
laravel在**config/app.php**内添加
```php
[
    'providers' => [
        SwooleTW\Http\LaravelServiceProvider::class,
    ],
]
```
使用命令生成配置
```php
$ php artisan vendor:publish --tag=laravel-swoole
```
lumen在**bootstrap/app.php**内添加
```php
$app->register(SwooleTW\Http\LumenServiceProvider::class);
```
config下新增**swoole_http.php** 和 **swoole_websocket.php**，并在
**bootstrap/app.php**内添加
```php
$app->configure('swoole_http');
$app->configure('swoole_websocket');
```
> swoole_http.php和swoole_websocket.php的配置项可参考[laravel-swoole文档](https://github.com/swooletw/laravel-swoole/wiki/5.-Configuration)

## 启动
完成以上步骤后，可使用命令启动或关闭项目，在放弃php-fpm的道路上走最坚实的一步。
```php
$ php artisan swoole:http start/restart/stop/reload/infos
```
## 测试
以下是在本地情况下相同项目使用不同方式部署的测试结果：
Nginx+ php-fpm模式
```sh
[13:44:27][justcy:local-php → master]$ wrk -t4 -c10 http://test.knifeskillw.com/
Running 10s test @ http://test.knifeskillw.com/
  4 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.93s     0.00us   1.93s   100.00%
    Req/Sec     0.35      0.93     4.00     95.00%
  21 requests in 10.10s, 10.66KB read
  Socket errors: connect 0, read 0, write 0, timeout 20
Requests/sec:      2.08
Transfer/sec:      1.06KB
```
Nginx+ swoole模式
```sh
[13:45:05][justcy:local-php → master]$ wrk -t4 -c10 http://swoole.skillw.com/
Running 10s test @ http://swoole.skillw.com/
  4 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency    37.67ms   31.02ms 349.40ms   92.08%
    Req/Sec    58.81     21.03   111.00     68.88%
  2335 requests in 10.08s, 1.01MB read
Requests/sec:    231.60
Transfer/sec:    102.45KB
```
## 后记
之前使用docker安装的php镜像是属于php+fpm整合的镜像，实际在使用swoole发布php项目之后，不再需要php-fpm，docker镜像可考虑使用php-cli版本的镜像作为基础镜像。实际上，swoole官方也正是这么做的。

---
参考：
- [为CentOS 6、7升级gcc至4.8、4.9、5.2、6.3、7.3等高版本](https://www.vpser.net/manage/centos-6-upgrade-gcc.html)
- [CentOS完美升级gcc版本方法](https://blog.whsir.com/post-4975.html)
- [swoole官方文档](https://wiki.swoole.com/#/)
- [swoole官方镜像](https://hub.docker.com/r/phpswoole/swoole)
- [实用镜像库](https://hub.docker.com/repository/docker/justcy/php)
