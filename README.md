<div>

[**简体中文**](README_zh_CN.md)

</div>

## FlClash F-Droid Repo

The official F-Droid repository for FlClash.

## Usage

Copy what your need to your F-Droid client:

|             |                                                                                |
| ----------- | ------------------------------------------------------------------------------ |
| Direct Link | `https://chen08209.github.io/FlClash-fdroid-repo/repo?fingerprint=789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD` |
| Repo name   | FlClash                                                                      |
| URL         | `https://chen08209.github.io/FlClash-fdroid-repo/repo`                         |
| fingerprint | `789D6D32668712EF7672F9E58DEEB15FBD6DCEEC5AE7A4371EA72F2AAE8A12FD`                                                                  |

Also you can scan the QR Code to add this repo:

![QR Code](https://chen08209.github.io/FlClash-fdroid-repo/repo/index.png)

## Publish a Release APK

Each stable FlClash release pushes its Android arm64 APK into `tmp/`, which triggers the deploy workflow. The workflow
does not rely on the APK file name: it takes the only `*.apk` in `tmp/`, checks with `aapt` that it is
`com.follow.clash` with arm64 native code, and publishes it as `FlClash-<versionName>-android-arm64.apk`. The five
APKs with the highest `versionCode` stay in the repo.

To publish a release by hand, run the deploy workflow with its version. It finds the arm64 APK in the GitHub release
and verifies it against the release's checksum file:

```bash
gh workflow run deploy -R chen08209/FlClash-fdroid-repo -f version=0.9.4
```

Or fetch the APK into `tmp/` (any other APK there is removed), then commit and push it:

```bash
scripts/fetch-flclash-release-apk.sh 0.9.4
git add -A tmp
git commit -m "Update from v0.9.4"
git push origin main
```
