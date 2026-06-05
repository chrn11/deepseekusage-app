# DeepSeek Usage Tracker — iOS 客户端

纯本地 App，不依赖任何后端服务器。

## 安装（TrollStore）

1. Push 到 GitHub
2. Actions 自动编译
3. 下载 `DeepSeekUsage-unsigned.ipa`
4. 传到 iPhone → TrollStore 安装

详情见 [Actions 页面](https://github.com/chrn11/deepseekusage-app/actions)

## 使用

1. 打开 App → **设置** 标签页
2. 填入 DeepSeek API Key（从 [platform.deepseek.com/api_keys](https://platform.deepseek.com/api_keys) 获取）
3. 点 **测试连接** 验证
4. 回到 **仪表盘** → 下拉刷新
5. 多看几次刷新，数据多了就能看到消费趋势图

## 原理

```
你的 API Key（存钥匙串）
    ↓
GET https://api.deepseek.com/user/balance
    ↓
余额存本地 (SwiftData)
    ↓
对比前后余额差值 = 消费
    ↓
趋势图
```

## 数据安全

- API Key 存在 iOS 系统钥匙串（Keychain），加密存储
- 余额快照存在 App 私有目录（SwiftData）
- 全程不走任何第三方服务器
- 直接调用 DeepSeek 官方 API

## 用 Mac 开发

```bash
brew install xcodegen
xcodegen generate --spec project.yml
open DeepSeekUsage.xcodeproj
# ⌘R 运行
```

## 依赖

- iOS 16.0+
- 零第三方库
