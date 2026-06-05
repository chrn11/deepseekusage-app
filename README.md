# DeepSeek Usage Tracker

<p align="center">
  <img src="ios/AppIcon.png" alt="DeepSeek Whale" width="120">
</p>

<p align="center">
  <strong>iOS 原生 App — 追踪你的 DeepSeek API 消费</strong>
  <br>
  SwiftUI · 零依赖 · 本地隐私优先
</p>

<p align="center">
  <a href="https://github.com/chrn11/deepseekusage-app/actions"><img src="https://github.com/chrn11/deepseekusage-app/actions/workflows/build.yml/badge.svg" alt="CI"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <img src="https://img.shields.io/badge/iOS-16.0%2B-lightgrey.svg" alt="iOS 16+">
</p>

---

## 是什么

一个 iPhone App，帮你随时看一眼 DeepSeek API 花了多少钱。

打开就能看余额，下拉刷新查最新数据，累积多几次刷新就能看到每日消费趋势图。

**不依赖任何服务器。** App 直接用你的 API Key 调用 DeepSeek 官方接口，数据只存在你手机上。

## 截图

| 仪表盘 | 设置 |
|:---:|:---:|
| 余额卡片 + 消费趋势 | API Key 管理 |

## 怎么装

### 方式一：TrollStore（推荐，无需 Mac）

去 [Actions](https://github.com/chrn11/deepseekusage-app/actions) 页面下载最新的 `DeepSeekUsage.ipa`，传到 iPhone 用 TrollStore 打开即可。永久签名，无需续签。

### 方式二：Xcode 编译

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open DeepSeekUsage.xcodeproj
# ⌘R
```

## 怎么用

1. 打开 App → 设置标签页
2. 填入 [DeepSeek API Key](https://platform.deepseek.com/api_keys)
3. 点「测试连接」验证
4. 回到仪表盘，下拉刷新
5. 多刷新几次攒够数据，趋势图就会出来

## 能看什么

| 数据 | 说明 |
|------|------|
| 实时余额 | 充值余额 + 赠送余额，精确到分 |
| 今日/本周/本月消费 | 通过两次余额快照的差值推算 |
| 30 天消费趋势 | 柱状图，直观看到哪天花得多 |

## 工作原理

```
App 打开 → 点刷新 → 调用 DeepSeek 官方 /user/balance 接口
→ 结果写入手机本地 JSON 文件
→ 对比历史快照，差值就是消费金额
→ Swift Charts 画成趋势图
```

全程数据流向只有两个地址：

> **你的 iPhone ⇄ api.deepseek.com**

## 隐私 & 安全

- API Key 存在 iOS 系统钥匙串中，硬件级加密
- 余额快照存在 App 私有沙盒目录，其他 App 无法访问
- 不做任何网络请求到第三方服务
- 没有埋点、没有遥测、没有数据收集

## 技术栈

| 层 | 技术 |
|------|------|
| UI | SwiftUI |
| 图表 | Swift Charts |
| 存储 | 本地 JSON |
| 加密 | Security (Keychain Services) |
| 网络 | URLSession (async/await) |
| 构建 | XcodeGen + GitHub Actions |

零第三方依赖。iOS 16.0+ 即可运行。

## 文件结构

```
├── ios/DeepSeekUsage/
│   ├── App/               # @main 入口
│   ├── Models/            # BalanceInfo, BalanceSnapshot
│   ├── Services/          # DeepSeekAPI, KeychainManager
│   ├── ViewModels/        # DashboardViewModel
│   └── Views/             # ContentView, DashboardView, SettingsView
├── project.yml            # XcodeGen 配置
├── .github/workflows/     # CI 自动编译 unsigned IPA
└── ios/AppIcon.png        # DeepSeek 鲸鱼图标
```

## License

MIT

---

*非 DeepSeek 官方产品，由社区维护。*
