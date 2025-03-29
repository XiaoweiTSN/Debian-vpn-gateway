# 🧱 Debian VPN Gateway + DNS Proxy 部署文档

本部署文档基于你亲手完成的系统搭建过程，记录了如何将 Debian 配置为一个基于主机 VPN 的 NAT 转发网关 + DNS 代理服务器，供备份或复用使用。

------

## 🖥️ 系统环境

- 系统版本：Debian 12 (Minimal)
- 虚拟机平台：VMware（双网卡：Host-only + 桥接）
- 主机 VPN 工具：LetsTAP（提供 IP：26.26.26.1/29，DNS：26.26.26.53）

------

## ⚙️ 网络接口规划

| 接口  | IP 地址           | 用途                                   |
| ----- | ----------------- | -------------------------------------- |
| ens33 | `192.168.137.100` | VPN 出口网卡，连接主机 ICS (VMnet1)    |
| ens37 | `192.168.0.123`   | 局域网网卡，桥接本地网络，提供网关功能 |

------

## 🧩 核心配置步骤

### 1️⃣ 设置静态 IP

编辑 `/etc/network/interfaces`：

```ini
# 回环接口
auto lo
iface lo inet loopback

# VPN 出口接口（VMnet1）
auto ens33
iface ens33 inet static
    address 192.168.137.100
    netmask 255.255.255.0
    gateway 192.168.137.1
    dns-nameservers 26.26.26.53

# 局域网接口（桥接）
auto ens37
iface ens37 inet static
    address 192.168.0.123
    netmask 255.255.255.0
```

------

### 2️⃣ 启用 IP 转发

```bash
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p
```

------

### 3️⃣ 配置 NAT 转发（iptables）

```bash
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o ens33 -j MASQUERADE
iptables -A FORWARD -i ens37 -o ens33 -j ACCEPT
iptables -A FORWARD -i ens33 -o ens37 -m state --state RELATED,ESTABLISHED -j ACCEPT
```

保存规则：

```bash
sudo apt install iptables-persistent -y
iptables-save > /etc/iptables/rules.v4
```

------

### 4️⃣ 安装并配置 dnsmasq

```bash
sudo apt install dnsmasq -y
```

编辑 `/etc/dnsmasq.conf`：

```ini
listen-address=127.0.0.1,192.168.0.123
server=26.26.26.53
no-resolv
cache-size=500
```

重启服务并设置为开机启动：

```bash
systemctl restart dnsmasq
systemctl enable dnsmasq
```

------

## 🧪 局域网设备配置（如 Steam Deck、手机）

- IP 地址：192.168.0.x（手动指定）
- 子网掩码：255.255.255.0
- 默认网关：192.168.0.123
- DNS 服务器：192.168.0.123

------

## ✅ 验证 checklist

-  Debian 启动后 IP 保持为 `137.100` / `0.123`
-  `iptables -t nat -L` 显示 MASQUERADE 转发规则
-  `dig @192.168.0.123 www.google.com` 正确返回 IP
-  `curl ifconfig.me` 显示为 VPN 出口 IP（香港等）
-  局域网设备上网正常，DNS 干净无污染

------

## 📦 建议备份的配置文件

```bash
/etc/network/interfaces
/etc/sysctl.conf
/etc/iptables/rules.v4
/etc/dnsmasq.conf
```

------

## 🏁 可选扩展

- 开启 dnsmasq DHCP 功能，实现即插即翻墙
- 增加访问控制（仅允许特定 IP 或 MAC）
- 添加日志记录（DNS 查询 / NAT 转发日志）
- 使用 `dnscrypt-proxy` 加密 DNS 查询流量

------

## 🚀 一键部署脚本（root 用户运行）

```sh
#!/bin/bash

# 设置静态 IP
cat > /etc/network/interfaces <<EOF
auto lo
iface lo inet loopback

auto ens33
iface ens33 inet static
    address 192.168.137.100
    netmask 255.255.255.0
    gateway 192.168.137.1
    dns-nameservers 26.26.26.53

auto ens37
iface ens37 inet static
    address 192.168.0.123
    netmask 255.255.255.0
EOF

# 启用 IP 转发
sed -i '/^net.ipv4.ip_forward/d' /etc/sysctl.conf
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# 安装必要软件
apt update
apt install iptables dnsmasq iptables-persistent -y

# 添加 iptables 规则
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o ens33 -j MASQUERADE
iptables -A FORWARD -i ens37 -o ens33 -j ACCEPT
iptables -A FORWARD -i ens33 -o ens37 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# 配置 dnsmasq
cat > /etc/dnsmasq.conf <<EOF
listen-address=127.0.0.1,192.168.0.123
server=26.26.26.53
no-resolv
cache-size=500
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq

echo "✅ 部署完成，建议重启系统"
```

> 保存为 `vpn-gateway-setup.sh`，执行：`sudo bash vpn-gateway-setup.sh`

------

📘 文档由 ChatGPT 根据你当前环境自动生成，适用于将本机作为 VPN 网关 / DNS 中继使用。 如需一键部署脚本或迁移到其他 Debian 实体机，请继续联系我协助 🙌