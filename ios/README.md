# DeepSeek Usage Tracker — iOS 客户端

原生 iOS SwiftUI 应用，配合 Vapor 后端使用，追踪 DeepSeek API 的用量和消费。

## 安装方式：TrollStore（无需 Mac）

你**不需要** Mac 或 Xcode 来安装这个 App。流程如下：

```
你改代码 → git push → GitHub Actions 自动编译 → 下载 .ipa → TrollStore 安装
```

### 具体步骤

#### 1. 确保 iPhone 已安装 TrollStore
- iOS 15.0 - 17.0 的设备可通过 TrollStore 安装
- 如未安装，参考 [TrollStore 官方指南](https://github.com/opa334/TrollStore)

#### 2. Fork 或推送代码到 GitHub
```bash
git remote add origin https://github.com/你的用户名/deepseekusage-app.git
git push -u origin main
```

#### 3. 等 GitHub Actions 编译完
1. 打开你的 GitHub 仓库页面
2. 点击 **Actions** 标签
3. 找到最新一次运行的 workflow
4. 往下滚动到 **Artifacts** 区域
5. 点击 **DeepSeekUsage-unsigned.ipa** 下载

#### 4. 用 TrollStore 安装
1. 把 `.ipa` 传到 iPhone（AirDrop / 隔空投送 / iCloud / Telegram 都可以）
2. 在 iPhone 上点击 `.ipa` 文件 → 选择 TrollStore 打开
3. TrollStore 会自动安装为永久签名的 App

#### 5. 配置后端地址
- 打开 App → 设置标签页
- 填入后端地址（如 `http://192.168.1.100:8080` 或 `https://你的域名.com`）
- 点击「测试连接」验证

---

## 手动触发构建

在 GitHub 仓库页面：
1. **Actions** → **Build iOS IPA (TrollStore)** → **Run workflow**
2. 可选填入版本号
3. 点击绿色 **Run workflow** 按钮

---

## 发布版本（打 Tag 自动创建 Release）

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions 会自动编译并在 Releases 页面发布 `.ipa`。

---

## 项目结构

```
DeepSeekUsage/
├── App/
│   └── DeepSeekUsageApp.swift      — @main 入口
├── Models/
│   ├── BalanceInfo.swift            — 账户余额模型
│   ├── DailyUsageItem.swift         — 每日用量模型
│   └── ProxyCallItem.swift          — 调用记录模型
├── Services/
│   └── APIClient.swift              — 网络层（与后端通信）
├── ViewModels/
│   ├── DashboardViewModel.swift     — 仪表盘逻辑
│   └── CallHistoryViewModel.swift   — 调用记录逻辑
└── Views/
    ├── ContentView.swift            — TabView 主容器
    ├── DashboardView.swift          — 仪表盘（余额/趋势图）
    ├── CallHistoryView.swift        — 调用记录列表
    └── SettingsView.swift           — 设置页
```

## 如果用 Mac 本地开发

```bash
# 1. 安装 XcodeGen
brew install xcodegen

# 2. 生成 Xcode 项目
cd deepseekusage-app/
xcodegen generate --spec project.yml

# 3. 打开项目
open DeepSeekUsage.xcodeproj

# 4. 选择模拟器 → ⌘R 运行
```

> iOS 模拟器已允许本地 HTTP 连接（Info.plist 中配置了 `NSAllowsLocalNetworking`）

## 功能

| 页面 | 功能 |
|------|------|
| 📊 仪表盘 | 实时余额、今日用量、本月统计、30 天消费趋势图 |
| 📋 调用记录 | 代理转发历史、按模型筛选、分页加载 |
| ⚙️ 设置 | 后端地址配置、连接测试、版本信息 |

## 依赖

- iOS 16.0+
- Swift 5.9+
- Swift Charts（内置于 iOS 16+）
- **零第三方依赖**（纯原生 SwiftUI 实现）
