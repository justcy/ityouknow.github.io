---
layout: post
title: "ngixn学习笔记"
tagline: ""
date: '2020-07-25 11:13:04 +0800'
category: linux
tags: linux 
keywords: linux,ngixn学习笔记,docker
description: linux,ngixn学习笔记
---
> ngixn学习笔记
# 引言
Nginx是俄罗斯人Igor Sysoev编写的一款高性能的HTTP和反向代理服务器。Nginx选择了epoll(Linux 2.6内核)、kqueue(Fress BSD)和eventport(Solaris 10)作为网络I/O模型。Nginx是Apache服务器不错的替代品，它能够支持高达5000个并发连接数响应，而内存、CPU等系统资源消耗非常低。

# nginx安装
## 源码安装
系统平台: Centos release 6.6 
### 安装编译工具及库文件
其中PCER必须安装，nginx 需要依靠该扩展实现Rewrite功能
```sh
yum -y install make zlib zlib-devel gcc-c++ libtool openssl openssl-devel pcre pcre-devel
```
### 安装nginx
从nginx 官网选择所需要版本下载，最新版：[nginx-1.19.1](http://nginx.org/download/nginx-1.19.1.tar.gz)
```sh
# wget http://nginx.org/download/nginx-1.19.1.tar.gz
# tar -xzvf nginx-1.19.1.tar.gz
# cd nginx-1.19.1
# ./configure --prefix=/usr/local/nginx-1.9 --with-pcre \
> --with-http_stub_status_module --with-http_ssl_module \
> --with-http_gzip_static_module --with-http_realip_module \
> --add-module=../nginx_upstream_check_module-0.3.0
# make && make install 
```
nginx大部分常用模块，编译时./configure --help以--without开头的都默认安装。其中常用的编译选项说明如下
> --prefix=PATH ： 指定nginx的安装目录。默认 /usr/local/nginx
> --conf-path=PATH ： 设置nginx.conf配置文件的路径。nginx允许使用不同的配置文件启动，通过命令行中的-c选项。默认为prefix/conf/nginx.conf
> --user=name： 设置nginx工作进程的用户。安装完成后，可以随时在nginx.conf配置文件更改user指令。默认的用户名是nobody。--group=name类似
> --with-pcre ： 设置PCRE库的源码路径，如果已通过yum方式安装，使用--with-pcre自动找到库文件。使用--with-pcre=PATH时，需要从PCRE网站下载pcre库的源码（版本4.4 – 8.30）并解压，剩下的就交给Nginx的./configure和make来完成。perl正则表达式使用在location指令和 ngx_http_rewrite_module模块中。
> --with-zlib=PATH ： 指定 zlib（版本1.1.3 – 1.2.5）的源码解压目录。在默认就启用的网络传输压缩模块ngx_http_gzip_module时需要使用zlib 。
> --with-http_ssl_module ： 使用https协议模块。默认情况下，该模块没有被构建。前提是openssl与openssl-devel已安装
> --with-http_stub_status_module ： 用来监控 Nginx 的当前状态
> --with-http_realip_module ： 通过这个模块允许我们改变客户端请求头中客户端IP地址值(例如X-Real-IP 或 X-Forwarded-For)，意义在于能够使得后台服务器记录原始客户端的IP地址
> --add-module=PATH ： 添加第三方外部模块，如nginx-sticky-module-ng或缓存模块。每次添加新的模块都要重新编译（Tengine可以在新加入module时无需重新编译）

以下是另外一种编译方案

```sh
# ./configure \
> --prefix=/usr \
> --sbin-path=/usr/sbin/nginx \
> --conf-path=/etc/nginx/nginx.conf \
> --error-log-path=/var/log/nginx/error.log \
> --http-log-path=/var/log/nginx/access.log \
> --pid-path=/var/run/nginx/nginx.pid \
> --lock-path=/var/lock/nginx.lock \
> --user=nginx \
> --group=nginx \
> --with-http_ssl_module \
> --with-http_stub_status_module \
> --with-http_gzip_static_module \
> --http-client-body-temp-path=/var/tmp/nginx/client/ \
> --http-proxy-temp-path=/var/tmp/nginx/proxy/ \
> --http-fastcgi-temp-path=/var/tmp/nginx/fcgi/ \
> --http-uwsgi-temp-path=/var/tmp/nginx/uwsgi \
> --with-pcre=../pcre-7.8
> --with-zlib=../zlib-1.2.3
```
## yum安装
yum安装rpm包会比编译安装简单很多，默认会安装许多模块，但缺点是无法安装第三方模块，并且通常安装都不是最新版本的nginx，如果需要新版本的新特性，建议还是源码安装。
```sh
# vi /etc/yum.repo.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/$releasever/$basearch/
gpgcheck=0
enabled=1
```
接着执行 yum install nginx 即可。
## docker安装
docker安装我一般使用alpine版本，安装docker后使用docker pull nginx 拉取镜像。接着启动nginx即可。附上ngixn官方的docker文件：[nginx1.9.1:alpine Dockerfile](https://github.com/nginxinc/docker-nginx/blob/793319d7251c03eccecbf27b60e0cfbbd2d1f400/mainline/buster/Dockerfile)
使用官方镜像优点是安装方便配置简单。但是官方镜像只是安装了  此外，对于国内使用来说，服务器时间并不是北京时间，而是格林威治时间，其次，nginx配置通常都是默认配置，所以通常我会自己打一个自己的镜像，修改系统时间。附上我的Dockerfile，该镜像基于官方基础镜像构建。
```
FROM nginx:alpine
MAINTAINER justcy(https://github.com/justcy)
RUN sed -i 's/dl-cdn.alpinelinux.org/mirrors.aliyun.com/g' /etc/apk/repositories && apk update \ 
&& apk add --no-cache ca-certificates tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
COPY ./nginx/nginx.conf /etc/nginx/
```
其中nginx.conf如下
```
user  nginx;
worker_processes  auto;
worker_rlimit_nofile 65535;
error_log  /var/log/nginx/error.log warn;
pid        /var/run/nginx.pid;
events {
    worker_connections  10240;
}
http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for" "$upstream_response_time"';
    access_log  /var/log/nginx/access.log  main;

    sendfile        on;
    #tcp_nopush     on;
    server_names_hash_bucket_size 512;
    client_max_body_size 1024m;

    keepalive_timeout  65;

    #gzip  on;
    include /etc/nginx/conf.d/*.conf;
}
```
启动如下
```sh
# docker run --name my-custom-nginx-container -v /host/path/nginx.conf:/etc/nginx/nginx.conf:ro -p 8080:80 -d nginx
```
也可以使用docker-compose
```yaml
nginx:
    image: justcy/nginx:latest
    container_name: nginx
    volumes:
      - /your/project/path:/var/www/html
      - /your/nginx/log/path:/var/log/nginx
      - /your/nginx/vhost/config:/etc/nginx/conf.d
    restart: always
    ports:
      - "80:80
```

# nginx配置详解
基本的nginx配置构成
```
……
events{}
http{
……
	server{……}
	server{……}
……
}
```
ngixn完整配置示例
```
# 使用的用户组
user www www;
# 指定工作衍生进程数（一般为CUP总核数或总核数的2倍，例如两个四核CPU，可设置为 8 或 16）
worker_processes 8;
error_log logs/error.log;
pid logs/nginx.pid;
events {
  use epoll;
  worker_connections 2048;
}
http{
  include mime.types;
  default_type application/octet-stream;
  sendfile on;
  keepalive_timeout 65;
  # gzip压缩功能设置
  gzip on;
  gzip_min_length 1k;
  gzip_buffers 4 16k;
  gzip_http_version 1.0;
  gzip_comp_level 6;
  gzip_types text/html text/plain text/css text/javascript application/json application/javascript application/x-javascript application/xml;
  gzip_vary on;

  # http_proxy 设置
  client_max_body_size 10m;
  client_body_buffer_size 128k;
  proxy_connect_timeout 75;
  proxy_send_timeout 75;
  proxy_read_timeout 75;
  proxy_buffer_size 4k;
  proxy_buffers 4 32k;
  proxy_busy_buffers_size 64k;
  proxy_temp_file_write_size 64k;
  proxy_temp_path /usr/local/nginx/proxy_temp 1 2;
  # 设定负载均衡后台服务器列表
  upstream backend {
    #ip_hash;
    server 192.168.10.100:8080 max_fails=2 fail_timeout=30s ;
    server 192.168.10.101:8080 max_fails=2 fail_timeout=30s ;
  }
  
# 很重要的虚拟主机配置
server {
  listen 80;
  server_name itoatest.example.com;
  # 配置SSL
  #listen       443 ssl;
  #ssl_certificate     /usr/local/etc/nginx/ssl/uc.51xiyou.com.crt;
  #ssl_certificate_key /usr/local/etc/nginx/ssl/uc.51xiyou.com.key;
  root /apps/oaapp;
  charset utf-8;
  access_log logs/host.access.log main;
  #对 / 所有做负载均衡+反向代理
  location / {
    root /apps/oaapp;
    index index.jsp index.html index.htm;
    proxy_pass http://backend;
    proxy_redirect off;
    # 后端的Web服务器可以通过X-Forwarded-For获取用户真实IP
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504;
    # 允许全局跨域
    add_header Access-Control-Allow-Origin *;
    add_header Access-Control-Allow-Methods 'GET,POST';
    add_header Access-Control-Allow-Headers 'DNT,X-Mx-ReqToken,Keep-Alive,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Authorization';
  }

  #静态文件，nginx自己处理，不去backend请求tomcat
  location ~* /download/ {
    root /apps/oa/fs;
  }
  location ~ .*\.(gif|jpg|jpeg|bmp|png|ico|txt|js|css)$
  {
    root /apps/oaapp;
    expires 7d;
  }
  location /nginx_status {
    stub_status on;
    access_log off;
    allow 192.168.10.0/24;
    deny all;
  }

  location ~ ^/(WEB-INF)/ {
    deny all;
  }
  #error_page 404 /404.html;
  # redirect server error pages to the static page /50x.html
  error_page 500 502 503 504 /50x.html;
  location = /50x.html {
  	root html;
  }
  }
}


```



# 扩展
## NGINX负载均衡
1. 用户手动选择，通过在主页提供不同的线路，不同服务器的链接方式，根据用户的选择来实现负载均衡。这种方式在一些下载业务的网站中比较常用。

2. DNS轮询，针对同一个域名提供多条A记录解析，DNS服务器将解析请求按照A记录的顺序，随机分配到对应的IP上，优点：成本低，实现方便。缺点:首先，DNS轮询可靠性低，由于DNS在宽带接入商会有缓存，通常一个DNS解析要完全生效需要几个小时，甚至更久。如果，其中一台机子故障，对应的DNS解析并不能及时删除，会导致一段时间到该服务器的请求都不会有响应。其次，DNS轮询方案存在负载分配不均衡。DNS轮询是简单的负载，不能区分服务器的差异，不能反映服务器当前运行的状态，不能做到为性能好的服务器多分配请求，甚至会出现用户请求集中在一台服务器上的情况。另外由于本地DNS服务器会缓冲已经解析的域名到IP的映射。意味着同一用户在一段时间内的访问都是到同一台web服务器，导致web服务器之间负载不均衡。最终，DNS轮询的负载均衡，可能导致某几台服务器负载很低，而另外几台负载很高、处理缓慢；配置高的服务器分配到的请求少，配置低的服务器分配到的请求多。因此，DNS轮询常用在一些可靠性不高的服务器集群，如图片服务器、纯静态网页服务器集群等。

3. 四/七负载均衡设备，第四层负载均衡将一个Internet上合法注册的IP地址映射为多个内部服务器的IP地址，对每次的TCP连接请求动态使用其中一个内部IP地址来处理连接请求，达到负载均衡的目的。第七层负载均衡控制应用层的服务内容，提供一种对访问流量的高层控制方法，适合对HTTP服务器群的应用。第七层负载均衡技术通过检查流经的HTTP报头，根据报头的信息来执行负载均衡任务。硬件实现主要为交换机，代表的有：F5 BIG-IP。软件四层负载均衡代表作为LVS（linux virtual server）LVS集群采用IP负载均衡技术和基于内容请求分发技术。软件七层负载均衡大多基于HTTP反向代理方式，代表有nginx、L7SW(Layer 7 Switching)、HAProxy等。Nginx的反向代理负载均衡能够很好地支持虚拟主机，可配置性好，可以按照轮询、IP哈希、URL哈希、权重等多种方式对后端服务器做负载均衡，同时还支持后端服务器健康检查。

4. 多线多地区智能DNS解析与混合负载均衡方式，智能DNS解析能够根据用户本地设置的DNS服务器线路和地区，将对同一个域名请求到不同的IP上。新浪网首页(www.sina.com.cn)的负载均衡就同时用到了多线多地区智能DNS解析、DNS轮询、四/七层负载均衡交换机等的技术。
## ngixn负载均衡双机高可用

1. 一台主服务器+一台热备服务器，域名解析到公网虚拟IP1，正常情况下主服务器绑定IP1，提供负载均衡，热备处于空闲，当主服务器故障，热备服务器接管绑定主服务器虚拟IP1，提供服务，接管后发送ARPing包给IDC公网网关刷新MAC地址。

2. 两台负载均衡服务器均绑定虚拟IP，分别为IP1,IP2,其中一台故障，由另一台接管故障机器的虚拟IP，接管后发送ARPing包给IDC公网网关刷新MAC地址。

## nginx rewrite
>last break的区别，last在本条rewrite执行完后会对其所在的server{……}重新发起请求，而break标记则在本条规则匹配后，终止匹配，不再匹配后面的规则。一般在根location中（即location/{……}）或直接在server标签中编写rewrite规则，推荐使用last，在非根location中（l例如location /cms/{……}）使用break;

## 完整的nginx配置参考
```
user www www;
worker_processes 10;
error_log /path/to/error/log/nginx_error.log crit;
pid /usr/local/webserver/nginx/nginx.pid;
worker_rlimit_nofile 51200;

events
{
  # freeBSD 系统下为 use kqueue;
	use epoll;
	worker_connections 52100;
}
http
{
	include mime.types;
	default_type application/octet-stream;
	#charset utf-8;
	
	server_names_has_bucket_size 128;
	client_header_buffer_size 32k;
	large_client_header_buffers 4 32k;
	sendfile on;
	#tcp_nopush on;
	keepalive_timeout 65;
	tcp_nodelay on;
	
	# fastcgi 部分
	fastcgi_connect_timeout 300;
	fastcgi_send_timeout 300;
	fastcgi_read_timeout 300;
	fastcgi_huffer_size 64k;
	fastcgi_buffers 64k;
	fastcgi_busy_buffers_size 128k;
	fastcgi_temp_file_write_size 128k;
	
	# gzip部分
	gzip on;
	gzip_min_length 1k;
	gzip_buffers 4 16k;
	gzip_http_version 1.1;
	gzip_comp_level 2;
	gzip_types text/plain application/x-javascript text/css application/xml;
	gzip_vary on;
	
	#limit_zone crawler $binary_remote_addr 10m;
	# 允许客户端请求的最大单个文件字节数
	client_max_body_size 300m;
	# 缓冲区代理缓冲区用户端请求的最大字节数，可以理解为先保存到本地再传给用户
	client_body_buffer_size 128k;
	# 跟后端服务器连接的超时时间_发起握手等候响应超时时间
	proxy_connect_timeout 600;
	# 连接成功后，等待后端服务器响应时间_其实已经进入后端的排队之中等候处理
	proxy_read_timeout 600;
	# 后端服务器数据回传时间_就是子啊规定时间内后端服务器必须传完所有的数据
	proxy_send_timeout 600;
	#代理请求缓存区_这个缓存区会保存用户的头信息以供nginx进行规则处理_一般只要能保存下头信息即可
	proxy_buffer_size 16k;
	# 同上 告诉nginx保存单个用的几个buffer 最大用多大的空间
	proxy_buffers 4 32k;
	# 如果系统很忙的时候可以申请更大的 proxy_buffers 官方推荐 *2
	proxy_busy_buffers_size 64k;
	# proxy缓存临时文件的大小
	proxy_temp_file_write_size 64k;
  upstream php_server_pool{
  	server 192.168.1.10:80 weight=4 max_fails=2 fail_timeout=30s;
  	server 192.168.1.11:80 weight=4 max_fails=2 fail_timeout=30s;
  	server 192.168.1.12:80 weight=2 max_fails=2 fail_timeout=30s;
  }
  upstream message_server_pool{
  	server 192.168.1.13:3245;
  	server 192.168.1.14:3245 down;
  }
   upstream bbs_server_pool{
  	server 192.168.1.15:80 weight=1 max_fails=2 fail_timeout=30s;
  	server 192.168.1.16:80 weight=1 max_fails=2 fail_timeout=30s;
  	server 192.168.1.17:80 weight=1 max_fails=2 fail_timeout=30s;
  	server 192.168.1.18:80 weight=1 max_fails=2 fail_timeout=30s;
  }
  # 第一个虚拟主机，反向代理 php_server_pool 这组服务器
	server{
		listen 80;
		server_name www.yourdomain.com;
		location / {
			#如果后端服务器返回502、504、执行超时等错误，自动将请求转发到upstream负载均衡池中的另一台服务器，实现故障转移
			proxy_next_upstream http_502 http_504 error timeout invalid_header;
			proxy_pass http://php_server_pool;
			# 添加请求头 Host:www.yourdomain.com
			proxy_set_header Host www.yourdomain.com;
			proxy_set_header X-Forwarded-For $remote_addr;
		}
		access_log /path/to/access/www.yourdomain.com_access.log;
		error_log /path/to/error/www.yourdomain.com_error.log;
	}
	# 第二个虚拟主机
	server{
		listen 80;
		server_name www.yourdomain2.com;
		# 访问 http://www.yourdomain2.com/message/****地址，反向代理 message_server_pool 这组服务器
		location /message/ {
			proxy_pass http://message_server_pool;
			proxy_set_header Host $host;
		}
		# 访问 除/message/ 外的其他地址 http://www.yourdomain2.com/****地址，反向代理 php_server_pool 这组服务器
		location / {
			proxy_pass http://php_server_pool;
			proxy_set_header Host $host;
			proxy_set_header X-Forwarded-For $remote_addr;
		}
		access_log /path/to/access/www.yourdomain2.com_access.log;
		error_log /path/to/error/www.yourdomain2.com_error.log;
	}
	# 第三个虚拟主机
	server{
		listen 80;
		server_name bbs.yourdomain.com *.bbs.yourdomain.com;
		location / {
			proxy_pass http://bbs_server_pool;
			proxy_set_header Host $host;
			proxy_set_header X-Forwarded-For $remote_addr;
		}
		access_log off;
		error_log /dev/null;
	}
}
```
---
参考：
- [张宴的博客](http://zyan.cc/)
- [nginx documentation](http://nginx.org/en/docs/)
- [docker nginx](https://hub.docker.com/_/nginx)
