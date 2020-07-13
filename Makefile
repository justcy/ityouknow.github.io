.PHONY : create
define template
---
layout: post
title: "{title}"
tagline: ""
date: '$(shell date +'%Y-%m-%d %H:%M:%S') +0800'
category: {category}
tags: {category} 
keywords: {category},{title}
description: {category},{title}
---
> {title}

# 标题
内容

# 代码清单
行内代码应用 `code`
``\`bash
$ ls -alh
``\`

# 图片
![](){:width="100%"}
# 扩展
关于该问题的扩展
---
参考：
- []()
- []()
endef
export template

# alias blog='_a(){ cd /Users/justcy/Documents/Develop/justcy/justcy.github.io; make CAT=$1 TITLE="$2" TITLEZH="$3" ; subl .; };_a'
# make CAT=$1 TITLE="$2" TITLEZH="$3"
create:
	@FILE_NAME=_draft/$(CAT)/$(shell echo `date +'%Y-%m-%d'`)-$(shell echo  `echo $(TITLE)|sed 's/[ ][ ]*/-/g'`).md
	@mkdir -p _draft/$(CAT)
	@touch _draft/$(CAT)/$(shell echo `date +'%Y-%m-%d'`)-$(shell echo  `echo $(TITLE)|sed 's/[ ][ ]*/-/g'`).md
	@echo "$$template" | sed "s/{title}/${TITLEZH}/g" | sed "s/{category}/${CAT}/g"> _draft/$(CAT)/$(shell echo `date +'%Y-%m-%d'`)-$(shell echo  `echo $(TITLE)|sed 's/[ ][ ]*/-/g'`).md
deploy:
	git add . && git commit -am"deploy" && git push origin master
pb:
	make rsync && make deploy
rsync:
	rsync -avrz --delete-excluded _draft/* _posts/
clean:
	rm -rf _draft/*
