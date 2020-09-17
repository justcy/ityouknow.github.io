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
