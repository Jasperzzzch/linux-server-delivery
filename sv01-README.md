# sv01 服务器交付文档

> 交付日期：2026-09-03    交付人：jasper
> 用途：个人 Linux 运维实验环境（Web 服务 + 定时备份）

## 一、服务器信息
| 项目 | 值 |
|---|---|
| 主机名 | sv01 |
| 系统 | Ubuntu Server 24.04 LTS |
| IP | 192.168.207.128（VMware NAT） |
| 账号 | jasper（sudo 组）、ops（运维测试账号，密钥登录、密码已禁用） |

## 二、交付内容清单
- [x] Ubuntu Server 24.04 安装 + 系统补丁更新
- [x] SSH 加固：密钥登录，禁用密码认证
- [x] UFW 防火墙：仅放行 22/80
- [x] Nginx Web 服务（默认页，80 端口）
- [x] 备份脚本：每日 02:00 自动备份 /etc，保留 7 天
- [x] 时区 Asia/Shanghai + NTP 校时

## 三、常用操作
| 操作 | 命令 |
|---|---|
| 登录 | ssh jasper@192.168.207.128 |
| 看 Nginx 状态 | systemctl status nginx |
| 看访问日志 | tail -f /var/log/nginx/access.log |
| 手动备份 | sudo ~/scripts/backup.sh |
| 看备份任务 | sudo crontab -l |

## 四、备份与恢复
- 脚本位置：/home/jasper/scripts/backup.sh
- 备份位置：/home/jasper/backups/（每日 02:00，保留 7 天）
- 恢复方法：tar -xzf 备份包 -C /tmp，从 /tmp 拷贝需要的文件

## 五、排障记录（遇到过的问题与解法）
1. 软件源 403 → 换阿里云镜像
2. sshd 配置被 sshd_config.d/cloud-init 覆盖 → 清理后用 sshd -T 验证实际生效值
3. 时区为 UTC → set-timezone Asia/Shanghai；Nginx 需 reload 才感知新时区
