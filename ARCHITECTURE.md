# DeepSeek Usage Tracker — 架构设计

## 系统概览

```
┌─────────────────────────────┐     ┌──────────────────────────────────┐
│     iOS App (SwiftUI)        │     │     Vapor Backend (Linux)         │
│                              │     │                                   │
│  ┌──────────────────────┐    │     │  ┌────────────────────────────┐   │
│  │  Dashboard View      │    │     │  │  Routes                    │   │
│  │  • 今日消费卡片       │    │     │  │  GET /api/balance          │   │
│  │  • 本月消费卡片       │    │  HTTP  │  GET /api/usage/daily      │   │
│  │  • 账户余额卡片       │◄───┼─────┼─►│  GET /api/usage/monthly    │   │
│  │  • 消费趋势图         │    │     │  │  POST /api/proxy/chat/... │   │
│  └──────────────────────┘    │     │  │  GET /api/proxy/calls      │   │
│                              │     │  └──────────┬─────────────────┘   │
│  ┌──────────────────────┐    │     │             │                     │
│  │  Call History View   │    │     │  ┌──────────▼─────────────────┐   │
│  │  • 调用记录列表       │    │     │  │  Services                  │   │
│  │  • 按模型筛选         │    │     │  │  • BalancePollingService   │   │
│  └──────────────────────┘    │     │  │  • ProxyService            │   │
│                              │     │  │  • UsageStatsService       │   │
│  ┌──────────────────────┐    │     │  └──────────┬─────────────────┘   │
│  │  Settings View       │    │     │             │                     │
│  │  • API Key 配置       │    │     │  ┌──────────▼─────────────────┐   │
│  │  • 后端地址配置       │    │     │  │  FluentDB (SQLite)         │   │
│  └──────────────────────┘    │     │  │  • BalanceRecord            │   │
│                              │     │  │  • DailyUsage               │   │
└─────────────────────────────┘     │  │  • ProxyCallRecord          │   │
                                    │  └────────────────────────────┘   │
                                    │                                   │
                                    │           ┌───────────────────────┤
                                    │           │  DeepSeek API          │
                                    │  ┌────────│  /user/balance         │
                                    │  │        │  /chat/completions     │
                                    └──┼────────┼───────────────────────┘
                                       │        │
                                       └────────┘
```

## 数据流

### 1. 余额监控（自动）
```
[定时器每小时触发]
    → BalancePollingService
    → GET https://api.deepseek.com/user/balance
    → 存入 balance_records 表
    → 计算差值 → 更新 daily_usage 表
```

### 2. 代理转发（用户主动）
```
[iOS App] → POST /api/proxy/chat/completions
    → ProxyService 转发到 DeepSeek API
    → 从响应中提取 usage (prompt_tokens, completion_tokens)
    → 存入 proxy_call_records 表
    → 返回给 iOS App
```

### 3. 用量查询
```
[iOS App] → GET /api/usage/daily?date=2026-06-05
    → UsageStatsService 查询 daily_usage 表
    → 返回 { date, spending, calls, tokens }
```

## 数据库模型

### BalanceRecord
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| timestamp | DateTime | 采集时间 |
| totalBalance | Decimal | 总余额 |
| grantedBalance | Decimal | 赠送余额 |
| toppedUpBalance | Decimal | 充值余额 |
| currency | String | CNY / USD |

### DailyUsage  
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| date | Date | 日期 |
| estimatedSpending | Decimal | 估算消费（余额差值） |
| proxyTokenCount | Int | 代理记录的 token 总量 |
| proxyCallCount | Int | 代理记录的调用次数 |

### ProxyCallRecord
| 字段 | 类型 | 说明 |
|------|------|------|
| id | UUID | 主键 |
| timestamp | DateTime | 调用时间 |
| model | String | 模型名 |
| promptTokens | Int | 输入 token 数 |
| completionTokens | Int | 输出 token 数 |
| estimatedCost | Decimal | 估算费用 |
| requestHash | String | 请求哈希（去重用） |

## iOS App 架构 (MVVM)

```
App/
├── App.swift              — 入口
├── Models/
│   ├── Balance.swift
│   ├── DailyUsage.swift
│   └── ProxyCallRecord.swift
├── ViewModels/
│   ├── DashboardViewModel.swift
│   └── CallHistoryViewModel.swift
├── Views/
│   ├── DashboardView.swift      — 仪表盘主页
│   ├── CallHistoryView.swift    — 调用记录
│   └── SettingsView.swift       — 设置
├── Services/
│   └── APIClient.swift          — 网络请求
└── Assets/
    └── ...
```

## API 设计

### GET /api/balance
获取当前余额（实时从 DeepSeek 拉取）
```json
{
  "currency": "CNY",
  "total_balance": "110.00",
  "granted_balance": "10.00",
  "topped_up_balance": "100.00"
}
```

### GET /api/usage/daily?from=2026-06-01&to=2026-06-05
获取每日用量统计
```json
[
  { "date": "2026-06-05", "estimated_spending": "12.50", "call_count": 45, "token_count": 120000 },
  { "date": "2026-06-04", "estimated_spending": "8.30", "call_count": 30, "token_count": 80000 }
]
```

### POST /api/proxy/chat/completions
代理转发聊天请求（请求体和 DeepSeek API 完全一致）
```json
// Request (same as DeepSeek /chat/completions)
// Response (same as DeepSeek, plus our tracking header)
```

### GET /api/proxy/calls?page=1&per=20
获取代理调用记录

### POST /api/balance/poll
手动触发一次余额抓取
