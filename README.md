# DeepSeek Usage Tracker

纯 iOS 原生 App — 追踪 DeepSeek API 用量和消费。

**不需要后端服务器，不需要注册账号，App 直接调用 DeepSeek 官方 API。**

## 怎么装

1. Push 到 GitHub → Actions 自动编译 unsigned `.ipa`
2. 下载后 TrollStore 安装
3. 打开 App → 设置 → 填入 DeepSeek API Key
4. 回仪表盘 → 下拉刷新 → 余额就出来了

## 能看什么

| 数据 | 来源 |
|------|------|
| 💰 实时余额 | `GET /user/balance` |
| 📊 今日/本周/本月消费 | 余额差值推算 |
| 📈 30 天趋势图 | 本地快照对比 |

## 原理

```
App 直接调 DeepSeek 官方 API 查余额
      ↓
存到手机本地 (SwiftData)
      ↓
对比上次查到的余额 → 差值就是消费
      ↓
柱状图展示每天花了多少钱
```

**全程不走任何第三方服务器。**

## 文件结构

```
deepseekusage-app/
├── ios/
│   ├── Info.plist
│   ├── README.md
│   └── DeepSeekUsage/
│       ├── App/DeepSeekUsageApp.swift
│       ├── Models/
│       │   ├── BalanceInfo.swift
│       │   └── BalanceSnapshot.swift
│       ├── Services/
│       │   ├── DeepSeekAPI.swift
│       │   └── KeychainManager.swift
│       ├── ViewModels/
│       │   └── DashboardViewModel.swift
│       └── Views/
│           ├── ContentView.swift
│           ├── DashboardView.swift
│           └── SettingsView.swift
├── project.yml
├── .github/workflows/build.yml
└── README.md
```

## 用到的框架

- SwiftUI
- SwiftData（本地存储）
- Swift Charts（趋势图）
- Security（Keychain 加密存储）
- **零第三方依赖**

## 许可证

MIT
