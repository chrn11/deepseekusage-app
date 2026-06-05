# DeepSeek Usage Tracker — 架构

## 系统概览：纯 iOS App

```
┌─────────────────────────────────────┐
│         iOS App (SwiftUI)           │
│                                     │
│  ┌──────────────────────────┐      │
│  │  DeepSeekAPI.swift        │──────┼──→ GET /user/balance
│  │  直接调官方 API            │      │   api.deepseek.com
│  └──────────┬───────────────┘      │
│             │                       │
│  ┌──────────▼───────────────┐      │
│  │  KeychainManager.swift    │      │
│  │  API Key 安全存储          │      │
│  └──────────────────────────┘      │
│                                     │
│  ┌──────────────────────────┐      │
│  │  SwiftData (本地数据库)    │      │
│  │  BalanceSnapshot 余额快照  │      │
│  └──────────┬───────────────┘      │
│             │                       │
│  ┌──────────▼───────────────┐      │
│  │  差值计算 → 每日/每周/每月  │      │
│  │  消费趋势图 (Swift Charts) │      │
│  └──────────────────────────┘      │
│                                     │
│  无后端服务器 · 无第三方依赖          │
└─────────────────────────────────────┘
```

## 数据流

```
用户输入 API Key → Keychain 加密存储
     │
     ▼
点击刷新 / 下拉刷新
     │
     ▼
DeepSeekAPI.fetchBalance()
  → GET https://api.deepseek.com/user/balance
  → Authorization: Bearer sk-xxx
     │
     ▼
返回 { total_balance: "100.00", ... }
     │
     ├──→ 更新 UI（余额卡片）
     │
     └──→ 存入 SwiftData (BalanceSnapshot)
              │
              ▼
         对比昨天余额 vs 今天余额 = 今日消费
         对比月初余额 vs 当前余额 = 本月消费
              │
              ▼
         Swift Charts 柱状图
```

## iOS App 架构 (MVVM + SwiftData)

```
DeepSeekUsage/
├── App/DeepSeekUsageApp.swift     — @main 入口，初始化 SwiftData
├── Models/
│   ├── BalanceInfo.swift           — DeepSeek API 返回的余额结构
│   └── BalanceSnapshot.swift       — SwiftData 本地存储模型
├── Services/
│   ├── KeychainManager.swift       — API Key 安全存储（钥匙串）
│   └── DeepSeekAPI.swift           — 直接调 DeepSeek 官方 API
├── ViewModels/
│   └── DashboardViewModel.swift    — 余额 / 消费统计 / 趋势数据
└── Views/
    ├── ContentView.swift           — TabView（仪表盘 + 设置）
    ├── DashboardView.swift         — 余额卡片 + 趋势图
    └── SettingsView.swift          — API Key 管理 + 测试连接
```

## 依赖

- iOS 16.0+（Swift Charts）
- 零第三方库（纯原生 SwiftUI + SwiftData）
- 不需要任何服务器
