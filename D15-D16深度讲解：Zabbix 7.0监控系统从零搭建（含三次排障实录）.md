# D15-D16 深度讲解：Zabbix 7.0 监控系统从零搭建（含三次排障实录）

> 日期：2026-09-05（18:00 – 21:05）｜环境：VMware NAT `192.168.207.0/24`
> 参与机器：sv02（Zabbix Server `192.168.207.30`，Ubuntu 24.04.4 LTS，2核4G）
> 版本：Zabbix **7.0.30** / MySQL 8.0 / nginx / PHP 8.3.6
> 状态：**Web 界面可登录，`Zabbix server is running: Yes`，356 个监控项在采集**

---

## 开篇：先搞清楚 Zabbix 到底是什么

在读任何技术细节之前，先把"这东西为什么存在"想明白。否则后面所有命令都只是死记硬背。

### 一句话定义

**Zabbix 是一个开源的企业级监控系统**——它替你 7×24 小时盯着服务器、网络设备和应用，一旦发现异常，第一时间通知你。

### 它解决什么问题：从"没有监控"说起

假设你是某公司唯一的运维，管着 50 台服务器。**没有监控的时候，你怎么知道机器出问题了？**

```
早上 9:00  你到公司，一切正常
早上 9:15  某台机器的磁盘悄悄满了，数据库开始写入失败
早上 9:30  网站开始报错 500
早上 9:45  用户忍无可忍，打电话投诉："网站打不开了！"
早上 9:50  你才第一次听说这件事，开始手忙脚乱地排查
```

**这就是"被动救火"**——永远比事故慢半拍，而且是通过**最丢脸的方式**（用户投诉）才知道出了事。

更可怕的三种情况：

| 场景 | 没有监控时 | 后果 |
|---|---|---|
| 磁盘慢慢写满 | 不知道 | 某天数据库突然写崩，数据丢失 |
| 内存泄漏（程序 bug 慢慢吃内存） | 不知道 | 凌晨 3 点 OOM 宕机，睡梦中被告警电话吵醒 |
| 服务器被入侵拿去挖矿 | 不知道 | CPU 长期 90%+，月底电费/账单才发现 |

**这三件事的共同点：都是"慢性病"，不是"突发事故"。** 慢性病的特点是——在你发现之前，它已经悄悄恶化很久了。

### 它的核心价值：把"事后救火"变成"事前预警"

| | 没有监控 | 有监控 |
|---|---|---|
| 故障怎么发现 | 等用户投诉 | 30 秒内自动告警 |
| 磁盘满 | 满了才知道 | **剩余 15% 时提前告警**，你有几天时间处理 |
| 故障追溯 | "不知道什么时候开始的" | 有完整历史曲线，精确到分钟 |
| 扩容决策 | 拍脑袋 | 看三个月增长趋势，数据说话 |
| 你的状态 | 永远在救火 | 主动发现问题，从容处理 |

> 运维圈有句话：**没有监控的系统，等于没有上线。** 因为你根本不知道它是死是活。

### 它能盯什么（能力清单）

| 类别 | 具体例子 |
|---|---|
| **服务器指标** | CPU 使用率、内存占用、磁盘剩余空间、网络流量、进程数、系统负载 |
| **服务存活** | nginx 还在跑吗？MySQL 能连上吗？80 端口还开着吗？ |
| **应用健康** | 网站响应多快？接口返回 200 还是 500？ |
| **网络设备** | 交换机端口流量、路由器状态（走 SNMP 协议） |
| **日志** | 日志里出现 "ERROR" 或 "OutOfMemory" 了吗？ |
| **云资源** | 阿里云/腾讯云上的机器状态 |

**一句话概括：只要能用数字或状态描述的，Zabbix 几乎都能监控。**

### 打三个比方（选一个你最有感觉的）

**① 大楼的消防监控系统**
- 每个房间的烟雾传感器 = **agent**（分布在各处，负责感知）
- 中控室的主机 = **server**（收集所有信号）
- 报警铃 = **告警动作**（发现异常就响）

**② 体检中心**
- 定期抽血拍片 = **采集监控项**
- 血压 >140 判定异常 = **触发器**
- 医生打电话通知你 = **告警动作**

**③ 汽车仪表盘**
- 速度表/油表/水温表 = **监控项**
- 油量低于警戒线亮灯 = **触发器**
- 亮灯 = **告警**

三个比方说的是同一件事：**感知 → 判断 → 通知**。这就是所有监控系统的本质。

### 它在整个 IT 体系里的位置

```
  ┌──────────────────────────────────────┐
  │   你公司的业务系统（网站/APP/内部系统）    │
  │   跑在服务器、网络设备、数据库上           │
  └──────────────────────────────────────┘
                    ↑ 被盯着
  ┌──────────────────────────────────────┐
  │          Zabbix 监控系统               │
  │   采集 → 存储 → 画图 → 判断 → 告警      │
  └──────────────────────────────────────┘
                    ↓ 异常时
              邮件 / 钉钉 / 短信 / 微信 → 运维人员
```

**Zabbix 不参与业务，它只是站在旁边看着，出事就喊人。** 它是"旁观者 + 报警器"，不是"参与者"。

### 同类产品对比（知道自己学的东西在什么位置）

| 产品 | 特点 | 谁在用 |
|---|---|---|
| **Zabbix** | 老牌、功能齐全、自带 Web 界面和数据库，**传统企业装机量大** | 制造业、政府、教育、中小企业；**国内运维岗招聘常客** |
| **Prometheus** | 云原生时代主流，Kubernetes 环境标配 | 互联网公司、容器化环境 |
| **Nagios** | 更古老，插件生态丰富 | 老系统维护 |
| **Datadog / 云监控** | 商业 SaaS，开箱即用但收费 | 不差钱的公司 |

**为什么你学 Zabbix 而不是 Prometheus？**

1. **国内传统企业（制造业、政企、教育、中小公司）Zabbix 装机量巨大**——你要投的就是这类岗位
2. 招聘信息里 "Zabbix" 的出现频率远高于 Prometheus（后者多要求有 K8s 经验）
3. Zabbix 是**传统运维**的代表工具，和"企业 IT 运维"这个方向高度匹配
4. 它把"采集、存储、展示、告警"全包了，学一套就理解监控的完整闭环

> 当然，学会 Zabbix 后转 Prometheus 很容易——**概念是通用的**（采集/存储/触发/告警），只是工具不同。

### 在你这套实验环境里，它扮演什么角色

```
    sv02（192.168.207.30）              sv01（192.168.207.128）
    ┌─────────────────────┐            ┌─────────────────────┐
    │   Zabbix Server     │   盯着 →    │   nginx Web 服务器    │
    │   + MySQL           │ ← 上报数据  │   + zabbix-agent2   │
    │   + nginx (Web界面)  │            │                     │
    └─────────────────────┘            └─────────────────────┘
         监控机（1 台）                    被监控机（1 台）
```

**这就是一个最小化的企业监控场景：一台监控机 + 一台被监控机。**

真实企业里可能是 **1 台监控机 : 200 台被监控机**，但**原理完全一样**——多加一台 agent、Web 上多建一条主机记录而已。

> 面试官看重的不是你管过多少台机器，而是**你理解了这套架构**。你能在两台机器上把它跑通、讲清，他就相信你能扩展到两百台——**规模是经验问题，架构是能力问题**。

---

## 0. 这一天的产出总览

| 项 | 结果 |
|---|---|
| sv02 装机 | Ubuntu Server 24.04.4 LTS，静态 IP `192.168.207.30`，主机名 `sv02` |
| 源 | 主源 + security 源**双段换阿里云**；Zabbix 源换 `mirrors.aliyun.com/zabbix` |
| 时间 | 时区 `Asia/Shanghai`，NTP 换 `ntp.aliyun.com`（**预防性复用 sv01 教训**） |
| SSH | `ssh.socket` socket activation 机制确认；Windows SSH 连通，**告别控制台手打** |
| Zabbix 仓库 | 官方源包装入后生成 `zabbix.sources` + `zabbix-tools.sources`（DEB822 格式） |
| 数据库 | MySQL 8.0，库 `zabbix`（utf8mb4），用户 `zabbix@localhost`，**导入 203 张表** |
| 组件 | server-mysql / frontend-php / nginx-conf / sql-scripts / **agent2** 五个包全部 `ii` |
| Web | nginx 实际监听 **80**（非教程常说的 8080），`Admin/zabbix` 登录成功 |
| 运行态 | 10051（server）、10050（agent2）、3306（mysql）、80（nginx）全部在监听 |
| 快照 | `sv02-clean-before-zabbix`（Zabbix 安装前）已拍 |

**一句话总结**：从一台空机器开始，装出了企业级监控系统的完整服务端，**并且亲手踩过、也亲手解决了三个真实故障**。手册给 D15-D16 的预算是 5–6 小时，实际 1.5 小时通关。

---

## 1. 概念地基：Zabbix 到底由什么组成

很多人以为"装 Zabbix"就是装一个软件。**不是。** 它是一套四件套，四个部分各司其职、缺一不可。

### ① 四件套与数据流

```
┌─────────────┐   采集    ┌──────────────┐   写入   ┌──────────┐
│   agent2    │ ────────> │    server    │ ───────> │  MySQL   │
│ (被监控机)   │  10051    │  (核心进程)   │          │  (存储)   │
└─────────────┘           └──────────────┘          └──────────┘
     10050                        ↑                       │
        ↑                         │ 读取                   │ 读取
        │ 拉取                     │                       ↓
        │                   ┌──────────────┐        ┌──────────┐
        └────────────────── │  nginx+PHP   │ <───── │ 浏览器    │
             (被动模式)      │  (frontend)  │        └──────────┘
                            └──────────────┘          80 端口
```

| 组件 | 包名 | 干什么 | 端口 |
|---|---|---|---|
| **服务端** | `zabbix-server-mysql` | 收数据、算触发器、发告警 | **10051** |
| **代理端** | `zabbix-agent2` | 装在被监控机上，采集本机指标 | **10050** |
| **数据库** | `mysql-server` | 存配置 + 历史数据 | 3306 |
| **前端** | `zabbix-frontend-php` | Web 界面 | 80 / 8080 |

> **两个端口要背下来**：**10051 是 server 的，10050 是 agent 的**。面试问"Zabbix 用哪些端口"，答不上这两个基本就凉了。

### ② 主动模式 vs 被动模式（面试高频）

| | 被动模式（默认） | 主动模式 |
|---|---|---|
| 谁发起 | **server 主动连** agent 的 10050 | **agent 主动连** server 的 10051 |
| 配置字段 | `Server=<server IP>`（**白名单**：允许谁来问我） | `ServerActive=<server IP>`（**目标**：我送给谁） |
| 防火墙要求 | agent 侧要放行 **10050 入站** | agent 侧只需**出站** |
| 适用 | 小规模、同网段 | **大规模、跨机房、穿透 NAT** |
| 缺点 | 机器多了 server 轮询压力大 | 实时性略差 |

对应配置（本次在 sv01 上要改的三行）：

```ini
Server=192.168.207.30        # 被动：允许这个 IP 来问我
ServerActive=192.168.207.30  # 主动：我主动把数据送给这个 IP
Hostname=sv01                # 必须和 Web 里填的主机名一模一样
```

> ⚠️ **`Hostname` 必须和 Web 界面里填的"主机名"完全一致**，这是"agent 装了但 Web 上一直不出数据"的**头号原因**。agent 上报时会带上自己的 Hostname，server 拿它去和数据库里的主机记录对号，对不上就丢弃。

### ③ 数据模型六层关系（面试必考）

```
Host group（主机群组，如 Linux servers）
    └── Host（主机，如 sv01）
            └── Template（模板，如 Linux by Zabbix agent）
                    ├── Item（监控项，如 system.cpu.util）        ← 一个具体指标
                    ├── Trigger（触发器，如 CPU idle < 10% 持续5分钟）← 判断条件
                    └── Action（动作，触发后发邮件/执行脚本）
```

**一句话串起来**：模板套到主机上 → 主机获得一堆监控项 → 监控项的数据喂给触发器 → 触发器条件满足 → 动作执行（发告警）。

| 概念 | 类比 |
|---|---|
| Template | 体检套餐（一揽子检查项） |
| Item | 单项检查（血压） |
| Trigger | 诊断标准（血压 > 140 判定为异常） |
| Action | 医生打电话通知你 |

### ④ 为什么用 agent2 而不是 agent

| | `zabbix-agent` | `zabbix-agent2` |
|---|---|---|
| 语言 | C | **Go** |
| 架构 | 单进程 | **插件化**，并发能力强 |
| 中间件监控 | 要靠自定义脚本 | 官方插件（`zabbix-agent2-plugin-mongodb` 等） |

新一代官方推荐，本次直接用 agent2。

---

## 2. 完整步骤回顾（六阶段）

| 阶段 | 动作 | 通过标准 |
|---|---|---|
| 1 加仓库 | wget zabbix-release deb → `dpkg -i` → 换阿里云 → `apt update` | `apt-cache policy` 出现 `Candidate: 7.0.30` |
| 2 装数据库 | `apt install mysql-server` → 建库建用户 → 开 `log_bin_trust_function_creators` | `SHOW DATABASES` 里能看到 `zabbix` |
| 3 装组件 | 五个包一起装（nginx / php-fpm 作为依赖自动带上） | `dpkg -l \| grep zabbix` 五行全 `ii` |
| 4 导 schema | `zcat server.sql.gz \| mysql` （3–8 分钟，无输出） | `SHOW TABLES \| wc -l` = **204**（203 张表 + 表头） |
| 5 改配置 | server.conf 填 DBPassword → php.ini 设时区 → 删 nginx 默认站点 → 重启 | 四个服务全 `active` |
| 6 Web 向导 | 浏览器 `http://192.168.207.30` → 环境检查 → 填数据库 → 完成 | `Admin/zabbix` 登录成功 |

> **关键决策：先用默认端口跑通再谈改端口。** 原计划用 8080，实测发现 24.04 的 `zabbix-nginx-conf` 实际监听 80——如果一上来就按教程改 80，一旦出问题就分不清是 Zabbix 的锅还是端口的锅。**先证明核心功能活着，再做优化**，这条原则在排障时价值极高。

---

## 3. 排障实录（三个坑，全是真金白银）

### 排障一：`sed` 静默失败——http 与 https 的一字之差

**现象**

```bash
sudo sed -i 's#http://repo.zabbix.com#https://mirrors.aliyun.com/zabbix#g' /etc/apt/sources.list.d/zabbix.sources
# 执行无任何输出，看起来成功了
```

但回看配置：

```
URIs: https://repo.zabbix.com/zabbix/7.0/ubuntu    ← 纹丝未动
```

**根因**：源文件里写的是 **`https://`**，而我给的 sed 匹配的是 **`http://`**——少了个 `s`，一个字符都匹配不上。

> **这个错误的源头是我**：我参考的教程比较老，那会儿 Zabbix 官方源还是 http，现在早已全站 https，我照搬了过来。

**核心教训（可推广到所有 sed 操作）**

> **`sed` 匹配不到时，不报错、不警告、退出码还是 0——它只是什么都不做。**

这类"静默失败"是运维里最难查的一类问题：你以为改了，其实没改，而且**没有任何信号告诉你失败了**。等发现时，症状已经变成"为什么这么慢"这种难以归因的问题。

**防御动作（写进肌肉记忆）**

```bash
# 改之前先备份
sudo cp xxx.sources xxx.sources.bak
# 改之后必须 grep 回看
grep URIs /etc/apt/sources.list.d/zabbix*.sources
```

**任何 sed 改配置文件，改完必须回看一眼。** 这一步 3 秒，能省下后面半小时。

---

### 排障二：MySQL `ERROR 1045` —— `-p` 后面那个空格

**现象**

```bash
mysql -uzabbix -p 'Zabbix@2026' -e "USE zabbix; SHOW TABLES;" | wc -l
# ERROR 1045 (28000): Access denied for user 'zabbix'@'localhost'
```

用户当时的第一反应是："这里要输入我 jasper 账户的密码对吧？"

**两个根因，缺一不可**

**根因 A：MySQL 的 `-p` 参数陷阱**

| 写法 | 实际含义 | 结果 |
|---|---|---|
| `-p'密码'` | 密码内联（**紧贴，无空格**） | ✅ 直接连，不提示 |
| `-p 密码` | `-p` 无值 + **位置参数** | ❌ **MySQL 把"密码"当成数据库名** |
| `-p` | 只要一个 `-p` | ✅ 交互式提示输入密码 |
| `-p zabbix` | `-p` 无值 + 数据库名 | ✅ 提示输密码，连 zabbix 库 |

**`-p` 后面紧贴是密码，隔个空格就变成数据库名**——这是 MySQL 命令行里少见的"贴不贴空格语义完全不同"的参数。

**根因 B：概念误解——两套账号体系**

当时的提问暴露了一个更根本的误解：以为提示输密码时该输 Linux 的 `jasper` 密码。

| 密码 | 属于谁 | 用在哪 |
|---|---|---|
| jasper 的密码 | **Linux 系统用户** | SSH 登录、sudo 提权 |
| `Zabbix@2026` | **MySQL 数据库用户** | zabbix 账号连接数据库 |

**MySQL 有自己完全独立的一套账号体系，和 Linux 的 /etc/passwd 毫无关系。** 数据库用户 `zabbix` 只存在于 MySQL 内部，即使 Linux 上根本没有这个系统用户，它也能正常连库。

> 附带知识：输入密码时**屏幕上一个字符都不显示**（连 `***` 都没有），这是 Unix 的安全设计，需盲打回车。

---

### 排障三：`ERR_CONNECTION_REFUSED` —— 配置文件说的 vs 进程干的

**这是本次含金量最高的一次排障。**

**现象**

浏览器访问 `http://192.168.207.30:8080` 报：

```
无法访问此网站，192.168.207.30 拒绝了我们的连接请求
ERR_CONNECTION_REFUSED
```

**第一步：读懂报错（缩小范围）**

| 报错 | 含义 | 问题在哪 |
|---|---|---|
| **Connection refused** | 主机找得到，但**那个端口上没有服务在听** | 服务没起 / 没监听该端口 |
| Connection timed out | 数据包石沉大海 | 网络不通 / 防火墙丢弃 |

是 **refused** 不是 timeout → **网络是通的、防火墙没问题**（后续 `ufw status` 确实返回 `inactive`），纯粹是 8080 端口上没东西。**第一分钟就排除了网络和防火墙两个大方向。**

**第二步：出现矛盾**

```bash
sudo nginx -T | grep -i listen
# 输出里有：listen          8080;      ← 配置文件说：我监听 8080

sudo ss -tlnp | grep 8080
# 什么都没有                            ← 进程说：我没有监听 8080
```

配置文件和进程状态**打架了**。

**第三步：找到矛盾根源**

再仔细看 `nginx -T` 的原始输出：

```nginx
#               listen     localhost:110;
#               listen     localhost:143;
#        listen          8080;
```

**`listen 8080;` 前面有 `#`——它是注释！**

> **关键知识：`nginx -T` 输出的是配置文件的原始文本，注释 `#` 会原样打印出来。** 所以 grep 到的"listen 8080"只是一个长得像配置的注释行，根本不起作用。

**第四步：铁证出面**

```bash
sudo ss -tlnp
LISTEN   0   511   0.0.0.0:80   0.0.0.0:*   users:(("nginx",pid=15242...))
```

**nginx 实际监听在 80。**

**核心原则（本次最大收获）**

> **配置文件说的不算，进程实际干的才算。**

| 命令 | 看的是什么 | 比喻 |
|---|---|---|
| `nginx -T` / 直接 cat 配置文件 | **磁盘上的文件**（连注释一起打印） | 婚礼策划书 |
| `ss -tlnp` | **内核里真实的 socket 状态** | 婚礼现场实况 |

策划书写了 8080，现场摆的是 80——**信现场**。

**推广价值**：凡是"配置改了却没生效"的排查，**第一件事不是反复看配置文件，而是查进程的实际状态**：
- `ss -tlnp` 看端口
- `ps aux` 看进程
- `systemctl status` 看服务

配置改对了但没 reload/restart，是新手最常见的错觉，而且会让人在错误的方向上越查越深。

---

## 4. 知识结晶：七颗钉子

1. **Zabbix 四件套 + 两个端口**：server(10051) / agent(10050) / database / frontend。端口必须背下来。
2. **主动模式 vs 被动模式**：`Server=` 是被动白名单，`ServerActive=` 是主动目标，两者含义完全不同。
3. **`Hostname` 必须和 Web 里填的一致**——这是"agent 装了但不出数据"的头号原因。
4. **`sed` 静默失败**：匹配不到不报错。改配置文件后**必须 grep 回看**，改之前先备份。
5. **配置文件 vs 进程实际状态**：`nginx -T` 会打印注释，`ss -tlnp` 才是铁证。矛盾时信进程。
6. **MySQL `-p` 陷阱**：紧贴是密码，空格后是数据库名；且 **MySQL 账号与 Linux 账号是两套独立体系**。
7. **`Connection refused` ≠ `timeout`**：前者=端口无服务，后者=网络不通/防火墙。读懂报错能在一分钟内砍掉一半排查方向。

---

## 5. 面试话术（2 分钟版，口述用）

> "我在自己搭的实验环境里装了一套 Zabbix 7.0.30 监控服务端，操作系统是 Ubuntu 24.04，数据库用 MySQL 8.0，Web 用 nginx + PHP 8.3。
>
> 架构上它是四件套：zabbix-server 是核心，负责收数据和判断告警，监听 10051；zabbix-agent2 装在被监控机器上采集数据，监听 10050；MySQL 存配置和历史数据；前端是 PHP 写的 Web 界面。我把 agent2 也装在 server 本机上，所以它一装完就有 356 个监控项在自动采集。
>
> 安装过程中踩了三个坑。第一个是换源的时候，我用 sed 把官方源替换成阿里云镜像，命令执行完没有任何报错，但后来 grep 发现根本没替换成功——因为官方源现在是 https，我的匹配串写的是 http，sed 匹配不到的时候不报错，只是静默什么都不做。从那以后我改配置文件一定改完 grep 回看。
>
> 第二个是 MySQL 报 1045 权限拒绝，原因是我`-p`参数后面多打了一个空格——MySQL 的 -p 紧贴着写才是密码，隔个空格就变成数据库名了。顺带纠正了一个概念：MySQL 的账号和 Linux 系统账号是完全独立的两套，不是一回事。
>
> 第三个最有意思。装完之后浏览器访问报 Connection refused，我首先判断这是端口上没有服务在监听，不是网络不通也不是防火墙——因为 timeout 才是网络问题。然后出现一个矛盾：nginx -T 显示配置里有 listen 8080，但 ss 查出来 8080 根本没在监听。最后发现那行 listen 8080 是被井号注释掉的，nginx -T 会把注释也原样打印出来，而 nginx 实际监听的是 80 端口。
>
> 这次之后我给自己定了条规矩：**配置文件说的不算，进程实际干的才算**。排查'配置改了没生效'这类问题，第一件事是查进程和端口的实际状态，而不是反复看配置文件。"

### 高频追问 8 条

1. **Zabbix 由哪些组件组成？** → server(10051) / agent(10050) / database / web frontend 四件套。
2. **主动模式和被动模式有什么区别？** → 被动是 server 连 agent 的 10050 拉取，agent 侧要开 10050 入站；主动是 agent 连 server 的 10051 上报，只需出站，适合大规模和跨 NAT。配置项分别是 `Server` 和 `ServerActive`。
3. **agent 装好了但 Web 上不出数据，怎么排查？** → ① 先查 Hostname 是否和 Web 里填的一致（头号原因）；② `zabbix_get -s <IP> -k agent.ping` 测试连通；③ 看 agent 日志和 10050 端口；④ 确认模板已关联。
4. **10051 和 10050 分别是什么？** → 10051 是 server 端口，10050 是 agent 端口。
5. **导入 schema 要注意什么？** → 必须先 `SET GLOBAL log_bin_trust_function_creators = 1`，否则 MySQL 禁止创建存储函数，导入会失败。
6. **Connection refused 和 timeout 有什么区别？** → refused=主机可达但端口无服务监听；timeout=网络不通或防火墙丢包。
7. **怎么确认一个服务真的在监听某端口？** → `ss -tlnp`（看内核 socket 状态），比看配置文件可靠。
8. **MySQL 账号和 Linux 账号是一回事吗？** → 不是，两套完全独立的账号体系。MySQL 用户可以不存在对应的系统用户。

---

## 6. 命令速查表

```bash
# —— 仓库与换源 ——
wget https://mirrors.aliyun.com/zabbix/zabbix/7.0/ubuntu/pool/main/z/zabbix-release/zabbix-release_latest_7.0+ubuntu24.04_all.deb
sudo dpkg -i zabbix-release_latest_7.0+ubuntu24.04_all.deb
ls /etc/apt/sources.list.d/                    # 确认生成的是 .list 还是 .sources
sudo sed -i 's#https://repo.zabbix.com#https://mirrors.aliyun.com/zabbix#g' /etc/apt/sources.list.d/zabbix.sources
grep URIs /etc/apt/sources.list.d/zabbix*.sources   # 必看！防 sed 静默失败
apt-cache policy zabbix-server-mysql           # Candidate 出现即成功

# —— 数据库 ——
sudo mysql -u root                             # root 走 socket 认证，免密
# CREATE DATABASE zabbix CHARACTER SET utf8mb4 COLLATE utf8mb4_bin;
# CREATE USER 'zabbix'@'localhost' IDENTIFIED BY 'Zabbix@2026';
# GRANT ALL PRIVILEGES ON zabbix.* TO 'zabbix'@'localhost';
# SET GLOBAL log_bin_trust_function_creators = 1;
mysql -uzabbix -p'Zabbix@2026' -e "SHOW DATABASES;"      # -p 紧贴！
zcat /usr/share/zabbix-sql-scripts/mysql/server.sql.gz | mysql --default-character-set=utf8mb4 -uzabbix -p'Zabbix@2026' zabbix

# —— 装组件 ——
sudo apt install -y zabbix-server-mysql zabbix-frontend-php zabbix-nginx-conf zabbix-sql-scripts zabbix-agent2
dpkg -l | grep zabbix                          # 五个 ii

# —— 配置 ——
sudo sed -i 's/^# DBPassword=/DBPassword=Zabbix@2026/' /etc/zabbix/zabbix_server.conf
sudo sed -i 's/^;date.timezone =/date.timezone = Asia\/Shanghai/' /etc/php/8.3/fpm/php.ini
sudo rm -f /etc/nginx/sites-enabled/default
sudo systemctl restart zabbix-server zabbix-agent2 nginx php8.3-fpm
sudo systemctl enable  zabbix-server zabbix-agent2 nginx php8.3-fpm

# —— 排障三板斧 ——
sudo ss -tlnp                                  # 看真实监听（铁证）
sudo nginx -T | grep -i listen                 # 看配置文件（含注释，别全信）
sudo tail -40 /var/log/zabbix/zabbix_server.log
sudo tail -20 /var/log/nginx/error.log
sudo ufw status                                # 预期 inactive
```

---

## 7. 遗留与下一步

| 项 | 状态 |
|---|---|
| **D17 加主机 + Agent** | 下一步：在 sv01 装 agent2 并接入（约 30 分钟） |
| **D18 告警闭环（项目灵魂）** | 告警媒介 + 磁盘<15%触发器 + `dd` 写 3GB 造故障 + `stress` 造 CPU 高峰 |
| **D19 MySQL 备份 + Redis** | 备份账号 bk、mysqldump 全库、删库恢复演练 |
| sv01 watchdog 过夜验证 | 睡前起黑匣子，明早看时间戳是否连续（卡死案结案判据） |
| 8080 vs 80 | **已定论**：24.04 的 zabbix-nginx-conf 实际监听 80，访问地址 `http://192.168.207.30` |
| 截图素材 | 按用户 2026-09-05 明确：**降级为个人留档，简历不放截图**，能口述即可 |

**收工规范**：sv02 拍快照 `D16-完成-Zabbix主体装成`（当前只有装前快照，**建议补拍一个装后快照**）。
