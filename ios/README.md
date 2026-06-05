# iOS 客户端

## 安装

```bash
brew install xcodegen
cd deepseekusage-app/
xcodegen generate --spec project.yml
open DeepSeekUsage.xcodeproj
# 选择真机或模拟器 → ⌘R
```

## 数据结构

```
DeepSeekUsage/
├── App/DeepSeekUsageApp.swift      — @main
├── Models/
│   ├── BalanceInfo.swift            — DeepSeek API 响应模型
│   └── BalanceSnapshot.swift        — 本地余额快照 + JSON 持久化
├── Services/
│   ├── DeepSeekAPI.swift            — 调用 DeepSeek 官方 API
│   └── KeychainManager.swift        — API Key 安全存储
├── ViewModels/
│   └── DashboardViewModel.swift     — 消费统计 & 趋势计算
└── Views/
    ├── ContentView.swift            — TabView 主容器
    ├── DashboardView.swift          — 余额卡片 + 趋势图
    └── SettingsView.swift           — API Key 输入 & 连接测试
```

## 要求

- iOS 16.0+
- 零第三方依赖
