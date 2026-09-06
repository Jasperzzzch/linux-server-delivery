#!/bin/bash
# 功能：备份 /etc 配置目录，保留 7 天
set -euo pipefail
BK=/home/jasper/backups
mkdir -p $BK
tar -czf $BK/etc_$(date +%Y%m%d).tar.gz /etc
find $BK -name "*.tar.gz" -mtime +7 -delete
echo "backup done at $(date)" >> $BK/backup.log
