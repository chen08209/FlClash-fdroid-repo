<div>

[**English**](README.md)

</div>

## FlClash F-Droid Repo

FlClash 官方 F-Droid 仓库。

## Usage

将你所需要的内容粘贴到你的 F-Droid 客户端中：

|          |                                                                                |
| -------- | ------------------------------------------------------------------------------ |
| 直接链接 | `https://chen08209.github.io/flclash-fdroid-repo/repo?fingerprint=789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD` |
| 仓库名   | FlClash                                                                        |
| 地址     | `https://chen08209.github.io/FlClash-fdroid-repo/repo`                         |
| 指纹     | `789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD`                                                                  |

你也可以扫描下方二维码来添加：
![二维码](https://chen08209.github.io/flclash-fdroid-repo/repo/index.png)

## 发布 Release APK

FlClash 每个正式版会把 Android arm64 APK 推到 `tmp/`，触发 deploy workflow。workflow 不依赖 APK 文件名：取 `tmp/` 里唯一的 `*.apk`，用 `aapt` 确认包名是 `com.follow.clash` 且带 arm64 原生库，再以 `FlClash-<versionName>-android-arm64.apk` 发布。仓库保留 `versionCode` 最高的 5 个 APK。

手动发布某个版本时，带上版本号运行 deploy workflow，它会在 GitHub Release 里找 arm64 APK，并用同一 Release 的校验文件核对：

```bash
gh workflow run deploy -R chen08209/FlClash-fdroid-repo -f version=0.9.4
```

也可以先把 APK 下载到 `tmp/`（`tmp/` 里其他 APK 会被删掉），再提交并推送：

```bash
scripts/fetch-flclash-release-apk.sh 0.9.4
git add -A tmp
git commit -m "Update from v0.9.4"
git push origin main
```
