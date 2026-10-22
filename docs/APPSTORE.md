# App Store 与 TestFlight 发布

这个仓库保持上游的 Bundle ID 不变。App Store 版本由 `.github/workflows/appstore.yml`
在构建前用 `Tools/appstore/apply_bundle_id.py` 把 Bundle ID 改成 App Store 专用 ID，
然后签名并上传 TestFlight。构建产物和 ID 修改都不会提交，所以不需要长期维护 App Store 分支。

## 为什么这样做

- 仓库、`swiftui` 分支、普通 CI 仍然使用上游 Bundle ID（`com.chouchiu.micyou`）；
- 只有 App Store workflow 在当前 runner 的工作区里改成 `com.nagishirazu.micyou`；
- 上游更新时直接拉取即可，不存在“App Store 分支和主线同步”的问题；
- Bundle ID 出现在 `xtool.yml`、App Intents 元数据生成器和两份已提交的索引里，
  `apply_bundle_id.py` 会一次性改完并校验没有残留。

## 一次性配置

### 1. Apple 侧（已完成）

- App Store Connect App 记录：Bundle ID `com.nagishirazu.micyou`；
- 两个 App ID：`com.nagishirazu.micyou`、`com.nagishirazu.micyou.MicYouWidget`；
- Apple Distribution 证书（`.p12`）；
- 两份 **App Store** 描述文件；
- App Store Connect API Key（角色 **App Manager**），拿到 Key ID、Issuer ID 和 `.p8`；
- TestFlight 内部测试者。

### 2. GitHub 仓库变量

Settings → Secrets and variables → Actions → **Variables**：

| 变量 | 值 |
|---|---|
| `APPSTORE_ENABLED` | `true` |
| `APPSTORE_BUNDLE_ID` | `com.nagishirazu.micyou` |

`APPSTORE_ENABLED` 不存在时 workflow 会直接跳过，避免早期 tag 因缺少 secrets 失败。

### 3. GitHub Environment：`appstore`

Settings → Environments → New environment → 名称 `appstore`。

- **Deployment branches and tags**：只允许 `v*` tag（如果要在分支上手动测试，再加上 `swiftui`）；
- **Required reviewers**：建议先加上你自己；稳定后再去掉，实现 tag 推送后自动上传；
- **Secrets**（全部放 environment，不放 repo 级）：

| Secret | 内容 | 来源 |
|---|---|---|
| `APPSTORE_CERT_P12_BASE64` | `base64 -i signing/distribution.p12 \| tr -d '\n'` | `signing/` |
| `APPSTORE_CERT_PASSWORD` | p12 导出密码 | Keychain/密码管理器 |
| `APPSTORE_MAIN_PROFILE_BASE64` | `base64 -i signing/profiles/MicYou-AppStore.mobileprovision \| tr -d '\n'` | `signing/` |
| `APPSTORE_WIDGET_PROFILE_BASE64` | widget 描述文件的 base64 | `signing/` |
| `APPSTORE_API_KEY_P8_BASE64` | `base64 -i signing/api/AuthKey_XXXX.p8 \| tr -d '\n'` | App Store Connect |
| `APPSTORE_API_KEY_ID` | API Key 的 Key ID | App Store Connect |
| `APPSTORE_API_ISSUER_ID` | Issuer ID | App Store Connect |

### 4. 保护签名能力

- 给 `v*` tag 加 ruleset，只允许你创建/删除；
- `.github/workflows/` 加 CODEOWNERS，App Store workflow 的改动必须由你审批；
- `appstore` environment 的 secret 只给这个 workflow 使用；
- 协作者即使能改 workflow，也需要 environment 审批才能拿到 secrets。

## 运行

### 自动（tag）

推送 `v*` tag 后触发（需要 `APPSTORE_ENABLED=true`）：

```bash
git tag -s v1.2.0 -m "MicYou 1.2.0"
git push origin v1.2.0
```

- tag 符合 `vMAJOR.MINOR.PATCH` 时，`CFBundleShortVersionString` 会设成对应版本；
- `CFBundleVersion` 默认使用 workflow run number，也可以在手动运行时覆盖；
- 上传到 App Store Connect 后，在 **TestFlight** 里等处理完成。

### 手动

Actions → **App Store** → Run workflow：

- `build_number` 留空 = 用 run number；
- 分支上手动测试时，environment 的部署规则要允许该分支；
- 每次上传都需要 environment 审批（如果配置了 required reviewers）。

## 构建过程

1. checkout 当前 commit/tag；
2. 安装 xtool、选择最新稳定 Xcode（复用 `.github/actions/setup-xtool`）；
3. 运行 `Tools/appstore/apply_bundle_id.py "$APPSTORE_BUNDLE_ID"`；
4. tag 构建时设置版本号；
5. `Tools/build-livecontainer.sh` 构建并生成两个 IPA；
6. `Tools/verify-ipa.sh` 检查 widget、SDK、隐私清单、App Intents 索引；
7. 从 environment secrets 解出 p12、两份 profile、p8；
8. `Tools/sign-ipa.sh` 用 `Apple Distribution` 证书签名并重新打包；
9. `altool --validate-app` 后 `--upload-app` 上传 TestFlight。

## 版本号和构建号

- TestFlight 构建 90 天后过期，需要重新上传；
- 同一个 `CFBundleShortVersionString` 不能重复使用相同的 `CFBundleVersion`；
- 手动重传时在 Run workflow 的 `build_number` 里填一个比上次大的数字；
- 以后提交 App Store 时，构建的 `CFBundleShortVersionString` 要和 App Store 版本一致；
  当前仓库版本是 1.2.0，App Store 记录是 1.0，提交前统一即可。

## 以后上架 App Store 还差什么

这个 workflow 只负责构建、签名和 TestFlight 上传，**不处理**：

- App Store 截图（6.9"/6.5"）、描述、关键词、支持 URL、隐私政策 URL；
- 年龄分级、App 隐私标签；
- App Store 审核提交；
- App Store 版本专属代码改动（例如关闭 GitHub 更新提示）。

这些准备好后，用同一个构建或重新上传一个构建提交审核即可。

## 安全

- 私钥、p12、p8 只放 `signing/`（已 git 忽略）和 GitHub environment secrets；
- 不要提交、聊天发送或上传到网盘；
- 证书或描述文件过期后更新 secrets；
- 合作结束：删除 environment secrets、吊销证书、轮换 API Key。

## 本地签名

CI 之外也可以手动签名：

```bash
CERT_P12=signing/distribution.p12 \
P12_PASSWORD='...' \
MAIN_PROFILE=signing/profiles/MicYou-AppStore.mobileprovision \
WIDGET_PROFILE=signing/profiles/MicYouWidget-AppStore.mobileprovision \
IPA_IN=xtool/MicYou.ipa \
IPA_OUT=xtool/MicYou-AppStore.ipa \
BUILD_NUMBER=123 \
Tools/sign-ipa.sh
```
