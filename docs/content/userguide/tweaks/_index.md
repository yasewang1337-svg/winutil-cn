---
title: 优化项
weight: 4
prev: /userguide/application/
next: /userguide/features/
---

{{< image src="images/tweaks-tab-new" alt="优化项标签页截图" >}}

在「优化项（Tweaks）」标签页里，你可以套用推荐的 Windows 改动、查看可选预设，并调整少量辅助设置（如 DNS 和电源计划）。除非你已经清楚想要哪些单独的优化项，否则建议从预设开始。

### 推荐选择
用「优化项」标签页顶部的快速选择按钮来加速配置：

* **Standard（标准）**：为大多数用户选中推荐的基线优化项集合。
* **Minimal（精简）**：选中一组更小、影响更低的常见优化项。
* **Advanced（高级）**：选中一组经过筛选、相对更安全的高级优化项。此预设特意跳过了创建还原点和清理任务，以避免运行时间过长。
* **Clear（清除）**：清空当前所有已选中的优化项。
* **Get Installed Tweaks（获取已应用优化项）**：尽力检测你系统上已经套用的优化项。

### 运行优化项
* **打开优化项标签页**：切换到应用中的 **Tweaks（优化项）** 标签页。
* **选择优化项**：勾选你想套用的优化项。为方便起见，你可以使用顶部提供的预设。
* **运行优化项**：选好后，点击屏幕底部的 **Run Tweaks（运行优化项）**。

> [!NOTE]
> 想知道每个预设包含哪些内容，请查看 [preset.json](https://github.com/ChrisTitusTech/winutil/blob/main/config/preset.json)。

> [!IMPORTANT]
> 有些优化项会立即生效，另一些则可能需要重启资源管理器（Explorer）、注销，或完全重启才行。

### 撤销优化项
* **打开优化项标签页**：进入位于 **Install（安装）** 旁边的 **Tweaks（优化项）** 标签页。
* **选择要移除的优化项**：勾选你想禁用或移除的优化项。
* **撤销优化项**：点击屏幕底部的 **Undo Selected Tweaks（撤销所选优化项）** 以套用改动。

### 基础优化项
基础优化项是大多数系统最安全的起点。它们聚焦于低风险的改动，提升可用性、减少干扰，并避开高级选项里那些更具侵入性的改动。

### 高级优化项（谨慎使用）
高级优化项面向那些理解更深层 Windows 改动副作用的用户。请先创建还原点，逐项审阅，不要把整份高级列表当作一键式基线来套用。

### O&O ShutUp10++
[O&O ShutUp10++](https://www.oo-software.com/en/shutup10) 可以在 Winutil 里一键启动。它是一款面向 Windows 的免费隐私工具，帮助用户管理遥测、更新行为和应用权限设置。

{{< youtube id=3HvNr8eMcv0 loading=lazy >}}


### DNS

用 DNS 区域，无需手动编辑网卡设置，即可切换 IPv4 和 IPv6 的 DNS 提供商。根据你的优先级——速度、过滤还是隐私——选择最匹配的选项。

* **Default（默认）**：使用你的 ISP 或网络配置的默认 DNS 设置。
* **DHCP**：自动从 DHCP 服务器获取 DNS 设置。
* [**Google**](https://developers.google.com/speed/public-dns?hl=en)：由 Google 提供的可靠而快速的 DNS 服务。
* [**Cloudflare**](https://developers.cloudflare.com/1.1.1.1/)：以速度和隐私著称，Cloudflare DNS 是提升上网性能的热门之选。
* [**Cloudflare_Malware**](https://developers.cloudflare.com/1.1.1.1/setup/#:~:text=Use%20the%20following%20DNS%20resolvers%20to%20block%20malicious%20content%3A)：通过屏蔽恶意站点提供额外保护。
* [**Cloudflare_Malware_Adult**](https://developers.cloudflare.com/1.1.1.1/setup/#:~:text=Use%20the%20following%20DNS%20resolvers%20to%20block%20malware%20and%20adult%20content%3A)：同时屏蔽恶意软件和成人内容，提供更全面的过滤。
* [**Open_DNS**](https://www.opendns.com/setupguide/#familyshield)：提供可自定义的过滤和增强的安全功能。
* [**Quad9**](https://quad9.net/)：专注安全，屏蔽已知的恶意域名。
* [**AdGuard_Ads_Trackers**](https://adguard-dns.io/en/welcome.html)：AdGuard DNS 屏蔽广告、追踪器及其他不需要的 DNS 请求。访问其网站并登录，可获得仪表盘、统计数据和更多服务端自定义。
* [**AdGuard_Ads_Trackers_Malware_Adult**](https://adguard-dns.io/en/welcome.html)：AdGuard DNS 屏蔽广告、追踪器、恶意软件和成人内容，并在可能的情况下启用安全搜索（Safe Search）和安全模式（Safe Mode）。

### 个性化偏好

对于那些不适合放进主要优化项预设的、较小的外观和行为改动，用「个性化偏好（Customize Preferences）」。

### 性能计划

用「性能计划（Performance Plans）」来启用或移除「卓越性能（Ultimate Performance）」电源配置。

#### 添加并激活卓越性能配置：
* 启用并激活卓越性能配置，通过降低延迟、提升效率来增强系统性能。
#### 移除卓越性能配置：
* 停用卓越性能配置，将系统切换回「平衡（Balanced）」配置。
