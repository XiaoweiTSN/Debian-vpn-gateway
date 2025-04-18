# Debian VPN Gateway + DNS Proxy

> 🧱 基于 Debian 的轻量级翻墙网关搭建指南，用于将主机 VPN 共享到局域网设备（如 Steam Deck / 手机），并提供 DNS 干净解析服务。

---

## 🌐 环境说明

- 系统：Debian 12 (Minimal)
- 虚拟平台：VMware（双网卡）
- VPN工具：LetsTAP（或其他具有 TAP 设备输出的 VPN）
- 网卡分配：
  - `ens33`（Host-only，连接主机 VPN ICS 网络）
  - `ens37`（桥接，连接本地局域网）

---

## 📐 网络结构

```text
局域网设备（Steam Deck / 手机）
  ↳ 默认网关：192.168.0.123
  ↳ DNS服务器：192.168.0.123
       ↓
Debian 虚拟机（双网卡）
  ↳ ens33: 192.168.137.100 → 主机 VPN 共享网络
  ↳ ens37: 192.168.0.123 → 局域网桥接接口
       ↓
主机 VPN（如 LetsTAP）
  ↳ 分配内网 IP：26.26.26.1/29
  ↳ DNS服务器：26.26.26.53
```

---

## 🔧 安装步骤

### 0.环境配置

#### 0.1 报错修复
```bash
cxw@DebianVPN:~$ sudo ls
[sudo] password for cxw: 
cxw is not in the sudoers file.
```
首先进变为root用户
```bash
su
```
然后赋予权限
```bash
usermod -aG sudo cxw
```
重启系统

### 1. 设置静态 IP

#### 如果未安装NetworkManager
编辑 `/etc/network/interfaces`：

```ini
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
```

#### 如果已安装NetworkManager

删除旧有DHCP配置
```bash
nmcli connection show
```

```bash
nmcli connection delete "Wired connection 1"
nmcli connection delete "Wired connection 2"
```

创建静态IP

```bash
nmcli connection add type ethernet con-name lan ifname ens37 ipv4.method manual ipv4.addresses 192.168.0.123/24
nmcli connection add type ethernet con-name vpnout ifname ens33 ipv4.method manual \
  ipv4.addresses 192.168.137.100/24 \
  ipv4.gateway 192.168.137.1 \
  ipv4.dns 26.26.26.53
```

启用连接
```bash
nmcli connection up lan
nmcli connection up vpnout
```

查看服务状态
```bash
nmcli connection show
ifconfig
```

### 2. 开启 IP 转发

```bash
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p
```

### 3. 配置 NAT 转发（iptables）

```bash
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o ens33 -j MASQUERADE
iptables -A FORWARD -i ens37 -o ens33 -j ACCEPT
iptables -A FORWARD -i ens33 -o ens37 -m state --state RELATED,ESTABLISHED -j ACCEPT
apt install iptables-persistent -y
iptables-save > /etc/iptables/rules.v4
```

### 4. 安装并配置 dnsmasq

```bash
apt install dnsmasq -y
```

编辑 `/etc/dnsmasq.conf`：

```ini
listen-address=127.0.0.1,192.168.0.123
server=26.26.26.53
no-resolv
cache-size=500
```

启动服务：

```bash
systemctl restart dnsmasq
systemctl enable dnsmasq
```

---

## 🧪 验证测试

```bash
# DNS 查询是否正常
dig @192.168.0.123 www.google.com

# 外网出口是否为 VPN IP
curl ifconfig.me

# NAT 转发规则是否存在
iptables -t nat -L -n -v
```

---

## 🚀 一键部署脚本

保存为 `vpn-gateway-setup.sh`，并执行：

```bash
sudo bash vpn-gateway-setup.sh
```

```bash
#!/bin/bash

# 静态 IP 设置
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

# 开启转发
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p

# 安装软件
apt update
apt install iptables dnsmasq iptables-persistent -y

# iptables 规则
iptables -t nat -F
iptables -F
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -o ens33 -j MASQUERADE
iptables -A FORWARD -i ens37 -o ens33 -j ACCEPT
iptables -A FORWARD -i ens33 -o ens37 -m state --state RELATED,ESTABLISHED -j ACCEPT
iptables-save > /etc/iptables/rules.v4

# dnsmasq 配置
cat > /etc/dnsmasq.conf <<EOF
listen-address=127.0.0.1,192.168.0.123
server=26.26.26.53
no-resolv
cache-size=500
EOF

systemctl restart dnsmasq
systemctl enable dnsmasq

echo "✅ VPN 网关配置完成，建议重启系统"
```

---

## ✅ 文件备份建议

```bash
/etc/network/interfaces
/etc/iptables/rules.v4
/etc/sysctl.conf
/etc/dnsmasq.conf
```

---

## 🧭 可选扩展

- dnsmasq 添加 DHCP 支持，实现自动 IP 分发
- 使用 nftables 替代 iptables（未来兼容）
- 添加日志记录 & 防火墙规则限制接入设备

---

## 🛟 作者备注

此项目基于真实场景配置，由 ChatGPT 协助生成完整文档与脚本，适合开发者在家用路由器或虚拟环境中实现 **干净解析 + 局域网代理**。欢迎复用 & 修改！

