# App Store 与 TestFlight 发布

这个仓库保持上游的 Bundle ID 不变。TestFlight 上传是 `.github/workflows/release.yml` 的最后一步：
构建 job 用 `Tools/build-testflight.sh` 把刚构建好的 release IPA 转成 App Store 专用 Bundle ID 的未签名 IPA，
GitHub Release 发布后，`testflight` job 用 `Tools/sign-ipa.sh` 签名并上传。仓库里的文件不会被修改，所以不需要长期维护 App Store 分支。

## 为什么这样做

- 仓库、`swiftui` 分支、普通 CI 仍然使用上游 Bundle ID（`com.chouchiu.micyou`）；
- 只有构建出的包里是 `com.nagishirazu.micyou`，`xtool.yml` 和提交的 App Intents 索引都不动；
- 上游更新时直接拉取即可，不存在“App Store 分支和主线同步”的问题；
- `build-testflight.sh` 同时改写两个 bundle 的 Info.plist 和两份 App Intents 索引，并校验没有残留；
  还会补上 xtool 不写、App Store Connect 会检查的 `DTXcode`、`DTSDKName` 等字段，详见 `docs/DEVELOPMENT.md` 的“TestFlight 包”一节。

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

`APPSTORE_ENABLED` 不是 `true` 时 `testflight` job 直接跳过，GitHub Release 照常发布，fork 和缺少 secrets 时也不会失败。

### 3. GitHub Environment：`appstore`

Settings → Environments → New environment → 名称 `appstore`。

- **Deployment branches and tags**：`v*` tag，以及手动上传用的 `swiftui` 分支；
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

### 发布版本时（tag）

推送 `v*` tag 后，Release workflow 依次检查、构建、发布 GitHub Release，最后上传 TestFlight：

```bash
git tag -s v1.2.0 -m "MicYou 1.2.0"
git push origin v1.2.0
```

- 预发布 tag（如 `v1.2.0-beta.1`）同样会上传；
- GitHub Release 发布失败时不会上传；上传失败时只需重跑 `testflight` job；
- 上传到 App Store Connect 后，在 **TestFlight** 里等处理完成。

### 手动

Actions → **Release** → Run workflow，选 `swiftui` 分支并勾选 “Also upload this build to TestFlight”：

- 不发布 GitHub Release，版本号取 `Support/App-Info.plist`；
- 每次上传都需要 environment 审批（如果配置了 required reviewers）。

## 构建过程

1. `build` job（macOS）：设置版本号和构建号，`Tools/build-livecontainer.sh` 构建 release IPA，`Tools/verify-ipa.sh` 检查；
2. 同一个 job 里 `Tools/build-testflight.sh` 以 `APPSTORE_BUNDLE_ID` 把 `xtool/MicYou.ipa` 转成未签名的 `MicYou-TestFlight.ipa`，
   并写入构建它的 Xcode 和 SDK 信息，作为单独的 artifact 上传（不进 GitHub Release）；
3. `publish` job 发布 GitHub Release；
4. `testflight` job（macOS，`appstore` environment，唯一能读取签名 secrets 的 job）：下载该 artifact，
   解出 p12、两份 profile、p8，`Tools/sign-ipa.sh` 签名为 `MicYou-AppStore.ipa`，`altool --validate-app` 后 `--upload-app`，最后删除签名材料。

## 版本号和构建号

- `CFBundleShortVersionString` 取 tag 里的 `MAJOR.MINOR.PATCH`；`CFBundleVersion` 是提交数（`git rev-list --count HEAD`），和 GitHub Release 里的 IPA 一致；
- 同一个版本不能重复使用相同的构建号，所以同一个提交只能上传一次，要重新上传就先推一个新提交；
- TestFlight 构建 90 天后过期，需要重新上传；
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

- 私钥、p12、p8 只放 `signing/`（已在 `.gitignore` 中忽略）和 GitHub environment secrets；
- 不要提交、聊天发送或上传到网盘；
- 证书或描述文件过期后更新 secrets；
- 合作结束：删除 environment secrets、吊销证书、轮换 API Key。

## 本地签名

CI 之外也可以在 Mac 上手动构建并签名（`sign-ipa.sh` 依赖 `security` 和 `codesign`，只能在 macOS 上运行），再用 Transporter 上传：

```bash
Tools/build-testflight.sh        # TESTFLIGHT_BUILD=123 可覆盖构建号
CERT_P12=signing/distribution.p12 \
MAIN_PROFILE=signing/profiles/MicYou-AppStore.mobileprovision \
WIDGET_PROFILE=signing/profiles/MicYouWidget-AppStore.mobileprovision \
Tools/sign-ipa.sh                # 不设 P12_PASSWORD 时会提示输入
```

`IPA_IN` 默认是 `xtool/MicYou-TestFlight.ipa`，`IPA_OUT` 默认是 `xtool/MicYou-AppStore.ipa`。
