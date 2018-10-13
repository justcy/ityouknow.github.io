---
layout: post
title: 解决php-version不能安装
category: php
tags: [php]
keywords: php,php-version
---
##什么是PHP-Version

做过PHP开发的都知道，要在本地存在多个php版本环境并且随意切换是比较麻烦的。
php-version 是一个在mac/linux系统下快捷切换php版本的工具。
传送   [php-version](https://github.com/wilmoore/php-version)

## 事件
自从home
'''
Mac Cannot tap homebrew/php invalid syntax in tap
'''
网上找了很多方法都不能解决。

最后在项目 issus 中找到了答案

[issues](https://github.com/wilmoore/php-version/issues/67)

issuse 里面说，该 formulae 在一次提交中被删除了，具体的commit 地址[Delete more formulae](https://github.com/Homebrew/homebrew-php/commit/3a1e85d0f2b1278df225622acf8766d6686eaea1#diff-39a34f604b24e0756f9d8eaed00c088e)



