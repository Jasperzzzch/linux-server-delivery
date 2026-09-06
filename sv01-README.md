# sv01 服务器交付文档

> 交付日期：2026-09-03　　交付人：jasper
> 用途：个人 Linux 运维实验环境（Web 服务 + 定时备份 + GitHub 代码托管）

## 一、服务器信息

| 项目 | 值 |
|---|---|
| 主机名 | sv01 |
| 系统 | Ubuntu Server 24.04 LTS（内核 6.8.0） |
| IP | 192.168.207.128/24（VMware NAT） |
| 账号 | jasper（sudo 组，SSH 密钥登录）、ops（运维测试账号） |
| SSH | 仅密钥登录，密码认证已禁用 |

## 二、交付内容清单

- [x] Ubuntu Server 24.04 安装 + 系统补丁更新
- [x] SSH 加固：ed25519 密钥登录，禁用密码认证
- [x] UFW 防火墙：默认拒绝入站，仅放行 22 (OpenSSH) / 80 (HTTP)
- [x] Nginx Web 服务：默认页部署于 /var/www/html，开机自启
- [x] 备份脚本：每日 02:00 自动备份 /etc，保留 7 天（cron）
- [x] 时区 Asia/Shanghai + NTP 校时
- [x] 交付文档与脚本版本化管理（GitHub）

## 三、常用操作

| 操作 | 命令 |
|---|---|
| 登录 | ssh jasper@192.168.207.128 |
| 看 Nginx 状态 | systemctl status nginx |
| 看访问日志 | tail -f /var/log/nginx/access.log |
| 看系统日志 | sudo journalctl -xe |
| 手动备份 | sudo ~/scripts/backup.sh |
| 看备份任务 | sudo crontab -l |
| 验证备份包 | tar -tzf ~/backups/备份包名 |

## 四、备份与恢复

- 备份脚本：/home/jasper/scripts/backup.sh
- 备份位置：/home/jasper/backups/（每日 02:00，保留 7 天，root crontab 触发）
- 执行记录：/home/jasper/backups/backup.log
- **恢复方法**：
  1. 查看包内容：tar -tzf ~/backups/etc_YYYYMMDD.tar.gz
  2. 提取单个文件：sudo tar -xzf 备份包 -C /tmp etc/文件名
  3. 确认无误后拷回原位置
- 注意：脚本以 root 运行（需读全 /etc），备份包属主为 root

## 五、排障记录（已解决的问题）

1. **软件源 403 Forbidden**：清华镜像 noble 仓库 InRelease 同步异常 → 更换为阿里云镜像（sed 替换 /etc/apt/sources.list.d/ubuntu.sources）
2. **SSH 密码登录禁用不生效**：/etc/ssh/sshd_config.d/50-cloud-init.conf（cloud-init 自动生成）含 PasswordAuthentication yes，因 sshd 按 first-match 解析且 Include 优先，覆盖了主配置末尾的 no → 清理该行后用 `sudo sshd -T` 验证实际生效值为 no
3. **系统时区为 UTC**：安装时默认未设置本地时区 → `sudo timedatectl set-timezone Asia/Shanghai`；时区修改后 Nginx 进程仍使用缓存的旧时区写日志 → `systemctl reload nginx` 使其感知
4. **locale 时间显示为 12 小时制**：LC_TIME 跟随 en_US → `sudo update-locale LC_TIME=C.UTF-8` 改为 24 小时制

## 六、已知事项

- 内核有已安装待重启的更新（6.8.0-100 → 6.8.0-138），下次维护窗口 reboot
- /var/log/nginx/access.log 中 2026-09-03 当天存在 +0000 与 +0800 混排条目（时区变更所致，次日条目起统一为 +0800）
