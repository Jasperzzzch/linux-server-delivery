# linux-server-delivery

运维实战的学习仓库：从零搭建服务器、监控体系、备份机制，并沉淀完整的排障文档。

## 内容

### docs/ — 深度讲解文档（16 篇）
按天记录的实战过程，每篇包含：每一步在做什么、为什么这么做、排障实录（真实报错原文与排查过程）、知识总结。

覆盖：Ubuntu 服务交付、防火墙与 Web 服务、日志与备份、cron 定时任务、Windows Server AD 域控与组策略、Zabbix 7.0 监控告警、MySQL 备份恢复、Redis 部署、LVM 磁盘扩容。

### scripts/ — 实用脚本
- **mysql-backup.sh**：MySQL 每日全量备份（mysqldump + gzip 压缩 + 本地保留 7 天自动清理 + scp 异地容灾 + 失败日志告警）

## 环境
- 虚拟化：VMware Workstation（NAT 网络）
- 系统：Ubuntu Server 24.04.4 × 2、Windows Server 2022
- 服务：Zabbix 7.0.30 / MySQL 8.0.46 / Redis 7.x / Nginx

## 亮点
- **Zabbix**：3 主机混合监控（2 Linux + 1 Windows 域控），350+ 监控项，5 类故障告警闭环实测
- **MySQL 备份**：cron 自动化 + gzip 压缩（1.3M→274K）+ 异地容灾 + 失败日志告警，并完成删库恢复演练
- **排障文档**：每个故障都有完整记录——现象 → 根因 → 解法 → 复盘
