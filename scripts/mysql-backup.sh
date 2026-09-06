#!/bin/bash
#MySQL everyday_allbackup + 7days exist
set -e
set -o pipefail
BKDIR=/home/jasper/dbbackup
DATE=$(date +%Y%m%d)
LOG=/home/jasper/dbbackup/backup.log


/usr/bin/mysqldump -u bk -p'Backup123!' --all-databases | gzip > $BKDIR/all_$DATE.sql.gz
find $BKDIR -name "all_*.sql.gz" -mtime +7 -delete
scp $BKDIR/all_$DATE.sql.gz jasper@192.168.207.30:~/dbbackup/ >/dev/null 2>&1 || echo "$(date '+%F %T') WARN:remote copy failed" >> $LOG
echo "$(date '+%F %T') backup ok: all_$DATE.sql.gz" >> $LOG
