#!/bin/bash
#author:justcy
#desc: create a new post articles with template
CATEGORY=$1
TITLE=$2
TITLE_ZH=$3
TEMPLATE=_draft/temp/draft_template.md
DATE=`date "+%Y-%m-%d"`
TIME=`date "+%H:%M:%S"`
# echo $DATE $TIME

DIR=`pwd`

if [ ! -d "$DIR/_draft/$CATEGORY" ]; then
        mkdir $DIR/_draft/$CATEGORY
else
        echo "dir exists"
fi
# file path generate
FILE_NAME="$DATE-`echo $TITLE|sed 's/[ ][ ]*/-/g'`.md"
echo "file name:" _posts/$CATEGORY/$FILE_NAME

# template content
CONTENT=`cat $TEMPLATE`

# fill title
POST_TITLE=$TITLE
if [ -n "$TITLE_ZH" ]; then
    POST_TITLE=$TITLE_ZH
fi
CONTENT=`echo "${CONTENT}" | sed "s/{title}/${POST_TITLE}/g"`

# fill time
CONTENT=`echo "${CONTENT}" | sed "s/{time}/${DATE} ${TIME}/g"`

# fill time
CONTENT=`echo "${CONTENT}" | sed "s/{category}/${CATEGORY}/g"`

# output file (check exists)
if [ ! -e "$DIR/_draft/$CATEGORY/$FILE_NAME" ]; then
    echo "${CONTENT}" > _draft/$CATEGORY/$FILE_NAME
else
    echo "file exists..." 
fi

# edit file with vim
vim _draft/$CATEGORY/$FILE_NAME