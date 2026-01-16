# 阻止 Microsoft Edge 使用 IPv6（仅限 Edge，不影响系统）

## 📌 背景

本方法适用于在 **不禁用整个系统 IPv6** 的前提下，**阻止 Microsoft Edge 浏览器使用 IPv6**。尤其适合对 IPv6 网络有精细控制需求的场景，例如：

- 保持本机其他服务使用 IPv6（如远程桌面、Ping 等）
- 单独限制 Edge 浏览器走 IPv6
- 不影响局域网或系统级 DNS

---

## ⚠️ 为什么需要同时阻止 TCP 和 UDP？

现代浏览器（Edge、Chrome）支持 **QUIC 协议**（HTTP/3 的底层传输协议），它基于 **UDP** 而非传统的 TCP。

如果只阻止 TCP：

- 普通 HTTPS 连接（TCP 443）会被阻止 ✅
- QUIC 连接（UDP 443）会绕过防火墙规则 ❌

因此必须 **同时阻止 TCP 和 UDP**，才能完全阻止 Edge 的 IPv6 连接。

> 💡 你也可以在 Edge 中关闭 QUIC：访问 `edge://flags/#enable-quic` 设为 Disabled。但防火墙层面同时阻止两种协议是更可靠的做法。

---

## ✅ 方法概述

通过 **Windows Defender 高级防火墙 + PowerShell** 设置 6 条规则，分别阻止 Edge 对三类 IPv6 地址段的 TCP 和 UDP 访问。

| 地址段      | 说明                      | 协议      |
| ----------- | ------------------------- | --------- |
| `2000::/3`  | 全球单播地址（公网 IPv6） | TCP + UDP |
| `fe80::/10` | 链路本地地址              | TCP + UDP |
| `fc00::/7`  | 唯一本地地址（ULA）       | TCP + UDP |

---

## 🛠 操作步骤

### 1. 以管理员身份打开 PowerShell

开始菜单 → 搜索 PowerShell → 右键 → **“以管理员身份运行”**

---

### 2. 执行以下 6 条命令

```powershell
# 屏蔽 Edge 使用公网 IPv6 (TCP)
New-NetFirewallRule -DisplayName "Block Edge IPv6 - global TCP" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol TCP `
  -RemoteAddress "2000::/3" `
  -Profile Any

# 屏蔽 Edge 使用公网 IPv6 (UDP/QUIC)
New-NetFirewallRule -DisplayName "Block Edge IPv6 - global UDP" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol UDP `
  -RemoteAddress "2000::/3" `
  -Profile Any

# 屏蔽 Edge 使用链路本地地址 (TCP)
New-NetFirewallRule -DisplayName "Block Edge IPv6 - link local TCP" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol TCP `
  -RemoteAddress "fe80::/10" `
  -Profile Any

# 屏蔽 Edge 使用链路本地地址 (UDP/QUIC)
New-NetFirewallRule -DisplayName "Block Edge IPv6 - link local UDP" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol UDP `
  -RemoteAddress "fe80::/10" `
  -Profile Any

# 屏蔽 Edge 使用唯一本地地址 (TCP)
New-NetFirewallRule -DisplayName "Block Edge IPv6 - ULA TCP" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol TCP `
  -RemoteAddress "fc00::/7" `
  -Profile Any

# 屏蔽 Edge 使用唯一本地地址 (UDP/QUIC)
New-NetFirewallRule -DisplayName "Block Edge IPv6 - ULA UDP" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol UDP `
  -RemoteAddress "fc00::/7" `
  -Profile Any
````

---

### 3. 验证规则是否创建成功

```powershell
Get-NetFirewallRule -DisplayName "Block Edge IPv6*" | 
  ForEach-Object { 
    [PSCustomObject]@{
      Name = $_.DisplayName
      Protocol = ($_ | Get-NetFirewallPortFilter).Protocol
      RemoteAddr = ($_ | Get-NetFirewallAddressFilter).RemoteAddress
    }
  } | Format-Table -AutoSize
```

应输出 6 条规则，TCP 和 UDP 各 3 条：

```
Name                                  Protocol RemoteAddr
----                                  -------- ----------
Block Edge IPv6 - global TCP          TCP      2000::/3
Block Edge IPv6 - global UDP          UDP      2000::/3
Block Edge IPv6 - link local TCP      TCP      fe80::/10
Block Edge IPv6 - link local UDP      UDP      fe80::/10
Block Edge IPv6 - ULA TCP             TCP      fc00::/7
Block Edge IPv6 - ULA UDP             UDP      fc00::/7
```

---

## 🔍 测试是否生效

### 打开 Microsoft Edge 访问：

> [https://test-ipv6.com](https://test-ipv6.com)

若设置成功，应显示：

```
Your browser has no IPv6 connectivity
```

---

## 🧠 常见补充说明

* 不建议使用 `::/0`，某些地区语言系统会报“地址前缀无效”。
* `::1`（回环）和 `ff00::/8`（多播）会触发异常，Windows 不允许用于 `RemoteAddress`。
* 若 Edge 开启了 **加密 DNS（DoH）**，仍可能解析 AAAA 记录，但不会走 IPv6 连接。
* 此方法也适用于其他浏览器，只需将路径替换为对应 `chrome.exe` 或 `firefox.exe` 即可。

---

## 🧹 取消规则（可选）

如果将来想恢复 IPv6 使用，执行：

```powershell
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - global TCP"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - global UDP"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - link local TCP"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - link local UDP"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - ULA TCP"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - ULA UDP"
```
或使用通配符一次性删除：

```powershell
Remove-NetFirewallRule -DisplayName "Block Edge IPv6*"
```




