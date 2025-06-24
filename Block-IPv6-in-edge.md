# 阻止 Microsoft Edge 使用 IPv6（仅限 Edge，不影响系统）

## 📌 背景

本方法适用于在 **不禁用整个系统 IPv6** 的前提下，**阻止 Microsoft Edge 浏览器使用 IPv6**。尤其适合对 IPv6 网络有精细控制需求的场景，例如：

- 保持本机其他服务使用 IPv6（如远程桌面、Ping 等）
- 单独限制 Edge 浏览器走 IPv6
- 不影响局域网或系统级 DNS

---

## ✅ 方法概述

我们通过 **Windows Defender 高级防火墙 + PowerShell** 精确设置三条规则，屏蔽 Edge 对常用 IPv6 地址段的访问。

---

## 🛠 操作步骤

### 1. 以管理员身份打开 PowerShell

开始菜单 → 搜索 PowerShell → 右键 → **“以管理员身份运行”**

---

### 2. 执行以下 3 条命令（分别添加规则）

```powershell
# 屏蔽 Edge 使用公网 IPv6
New-NetFirewallRule -DisplayName "Block Edge IPv6 - global" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol TCP `
  -RemoteAddress "2000::/3" `
  -Profile Any

# 屏蔽 Edge 使用链路本地地址（如 fe80::1）
New-NetFirewallRule -DisplayName "Block Edge IPv6 - link local" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol TCP `
  -RemoteAddress "fe80::/10" `
  -Profile Any

# 屏蔽 Edge 使用唯一本地地址（如 fc00::/7）
New-NetFirewallRule -DisplayName "Block Edge IPv6 - ULA" `
  -Program "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" `
  -Direction Outbound `
  -Action Block `
  -Protocol TCP `
  -RemoteAddress "fc00::/7" `
  -Profile Any
````

---

### 3. 验证规则是否创建成功

```powershell
Get-NetFirewallRule -DisplayName "Block Edge IPv6*" | Get-NetFirewallAddressFilter
```

应输出：

```
RemoteAddress : 2000::/3
RemoteAddress : fe80::/10
RemoteAddress : fc00::/7
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
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - global"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - link local"
Remove-NetFirewallRule -DisplayName "Block Edge IPv6 - ULA"
```





