当希望使用ssh或远程桌面连接某个主机时，被连接的主机很可能没有公网ip，或被防火墙阻断，这个时候可以使用反向ssh的方法

首先在被连接的主机上，确认拥有ssh
```bash
ssh -v
```
若没有ssh，则一键安装
```powershell
Add-WindowsFeature -Name OpenSSH.Client
```
若希望连接的是ssh，则
```bash
ssh -fN -R 0.0.0.0:[RemotePort]:localhost:22 user@[RemoteHost]
```
比如：
```bash
ssh -fN -R 0.0.0.0:37192:localhost:22 -p 37454 Administrator@125.38.xx.xx
```
- -f表示后台运行
- -N表示不连接中断
- -R表示建立反向ssh

若希望连接的是RDP，则
```bash
ssh -fN -R 0.0.0.0:[RemotePort]:localhost:3389 user@[RemoteHost]
```
比如：
```bash
ssh -fN -R 0.0.0.0:37192:localhost:3389 -p 37454 Administrator@125.38.xx.xx
```