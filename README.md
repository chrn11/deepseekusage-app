# DeepSeek Usage Tracker

全栈 DeepSeek API 用量追踪工具：**Vapor 4 后端** + **iOS SwiftUI 原生客户端**

```
┌────────────────────┐         ┌──────────────────────┐
│   iOS App          │  HTTP   │   Vapor Backend       │       ┌─────────────────┐
│   (SwiftUI)        │◄───────►│   (Swift)             │◄─────►│  DeepSeek API   │
│   TrollStore 安装   │         │   余额轮询 + 代理转发   │       │  /user/balance  │
│                    │         │   SQLite 数据库         │       │  /chat/...      │
└────────────────────┘         └──────────────────────┘       └─────────────────┘
```

## 快速开始

### 1. 启动后端

```bash
cd backend
export DEEPSEEK_API_KEY="sk-your-deepseek-api-key"
swift run
# → http://localhost:8080
```

Docker 方式：
```bash
cd backend
docker build -t deepseek-tracker .
docker run -p 8080:8080 -e DEEPSEEK_API_KEY="sk-your-key" deepseek-tracker
```

### 2. 安装 iOS App

**不需要 Mac！** Push 到 GitHub 后，Actions 自动编译 unsigned `.ipa`，下载后用 [TrollStore](https://github.com/opa334/TrollStore) 安装。

详见 [ios/README.md](ios/README.md)

## 项目结构

```
deepseekusage-app/
├── README.md
├── ARCHITECTURE.md               ← 系统架构设计
├── project.yml                   ← XcodeGen 配置（生成 Xcode 项目）
├── .github/workflows/build.yml   ← GitHub Actions 自动编译 IPA
│
├── backend/                      ← Vapor 4 后端
│   ├── Package.swift
│   ├── Dockerfile
│   └── Sources/App/
│       ├── main.swift
│       ├── configure.swift
│       ├── Routes/Routes.swift
│       ├── Models/               ← 3 个数据模型
│       ├── Migrations/           ← 数据库迁移
│       └── Services/             ← 余额轮询 / 代理转发 / 定价
│
└── ios/                          ← iOS SwiftUI 客户端
    ├── README.md
    ├── Info.plist
    └── DeepSeekUsage/
        ├── App/DeepSeekUsageApp.swift
        ├── Models/               ← 3 个模型
        ├── Services/APIClient.swift
        ├── ViewModels/           ← MVVM ViewModels
        └── Views/                ← 仪表盘 / 调用记录 / 设置
```

## API

| 方法 | 路径 | 说明 |
|------|------|------|
| `GET` | `/api/balance` | 实时余额 |
| `POST` | `/api/balance/poll` | 手动抓取余额 |
| `GET` | `/api/usage/daily` | 每日用量统计 |
| `POST` | `/api/proxy/chat/completions` | 代理转发 |
| `GET` | `/api/proxy/calls` | 调用记录 |

## 两种数据来源

| 来源 | 方式 | 能看到什么 |
|------|------|-----------|
| 🔄 余额差值 | 后端每小时查一次 DeepSeek 余额 | 每天花了多少钱 |
| 📝 代理记录 | 代码通过后端转发 API 请求 | 每次调用的 Token、模型、费用 |

两种可以同时使用，互相补充。

## License

MIT
