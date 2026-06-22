# PowerShell Git Release Automation Tool

這是一個可公開的 PowerShell Git Release Automation Tool，示範如何用 PowerShell 封裝既有 Git Release 流程，降低手動建立 Release Branch、Tag 與 Push 的操作風險。

本專案適合作為作品集展示：PowerShell 腳本模組化、Git CLI 自動化、設定檔驅動流程、錯誤處理與執行紀錄。

## 功能特色

- 讀取 `Config.json` 管理 Git 路徑、Log 目錄、遠端名稱、主分支名稱、Commit Message、Branch Prefix、Tag Prefix 與專案路徑。
- 驗證目前目錄是否為 Git Repository。
- 檢查 Working Tree 是否乾淨。
- 限制必須從指定 Feature Branch Prefix 執行。
- 依版本號自動產生 Release Branch 與 Release Tag。
- 依既有流程執行 Pull、Fetch、Create Branch、Commit、Rebase、Push、Tag。
- 支援參數化執行，方便自動化或 CI/CD 整合。
- 支援 dry-run 預覽模式，不執行 Git 寫入操作。
- 支援自訂版本號驗證規則。
- 支援可選的 Release Note Markdown 產生。
- 使用 `Start-Transcript` 產生執行紀錄。
- 發生錯誤時停止流程並輸出錯誤訊息。

## 專案架構

```text
ReleaseTool/
├── Release.ps1     # Main release workflow
├── Git.ps1         # Git command helper functions
├── Utils.ps1       # Console output and validation helpers
├── Config.json     # Public sample configuration
├── README.md       # Project documentation
├── LICENSE         # MIT License
└── .gitignore      # Ignore local logs and temporary files
```

## 安裝方式

1. 安裝 Git for Windows。
2. 確認 Git 執行檔路徑，例如：

```powershell
C:\Program Files\Git\bin\git.exe
```

3. 下載或 clone 此專案。
4. 編輯 `Config.json`，設定本機 Git 路徑、Log 目錄、remote、主分支與要操作的專案目錄。

## Config 說明

公開版範例：

```json
{
    "GitExe": "C:\\Program Files\\Git\\bin\\git.exe",
    "LogDirectory": ".\\Log",
    "Remote": "origin",
    "MainBranch": "master",
    "CommitMessage": "Sample Release",
    "DefaultProject": "sample",
    "VersionPattern": "^\\d+\\.\\d+\\.\\d+$",
    "VersionExample": "1.0.0",
    "FeaturePrefix": "feature/",
    "ReleaseBranchPrefix": "RB",
    "ReleaseTagPrefix": "REL",
    "DryRun": false,
    "ConfirmBeforePush": true,
    "ReleaseNotes": {
        "Enabled": false,
        "Directory": ".\\ReleaseNotes"
    },
    "Projects": {
        "sample": "C:\\Git\\SampleProject"
    }
}
```

欄位說明：

- `GitExe`：Git 執行檔完整路徑。
- `LogDirectory`：執行 log 輸出目錄。可使用相對路徑，例如 `.\\Log`，或絕對路徑。
- `Remote`：Git remote 名稱，例如 `origin`。
- `MainBranch`：Release 要推送的主要分支名稱，例如 `master` 或 `main`。
- `CommitMessage`：Release commit 與 annotated tag 使用的訊息。
- `DefaultProject`：未輸入 project 時使用的預設專案代號。
- `VersionPattern`：版本號驗證用 regular expression。
- `VersionExample`：畫面顯示用版本範例。
- `FeaturePrefix`：允許執行 Release 的 Feature Branch prefix。
- `ReleaseBranchPrefix`：Release Branch prefix。
- `ReleaseTagPrefix`：Release Tag prefix。
- `DryRun`：設定為 `true` 時只顯示 release branch、tag 與流程，不執行 Git 寫入操作。
- `ConfirmBeforePush`：設定為 `true` 時，push 到 main branch 前要求再次確認。
- `ReleaseNotes`：設定為 enabled 時，release 完成後輸出 Markdown release note。
- `Projects`：專案代號與本機 repository 路徑對應表。

## Release 流程

工具會依序執行以下流程：

1. Load Modules
2. Read Config
3. Input Project
4. Verify Repository
5. Ensure Clean Working Tree
6. Ensure Feature Branch
7. Input Version
8. Pull Current Feature Branch
9. Fetch Origin
10. Create Release Branch from configured remote main branch
11. Replace Working Tree by configured remote main branch
12. Commit if needed
13. Rebase Release Branch with configured remote main branch
14. Push Release Branch to configured remote main branch
15. Create Release Tag
16. Push Release Tag
17. Create Release Note if enabled
18. Show Release Result

## 使用方式

在 PowerShell 中進入專案目錄：

```powershell
cd C:\Git\ReleaseTool
```

執行：

```powershell
.\Release.ps1
```

參數化執行：

```powershell
.\Release.ps1 -Project sample -Version 1.0.0
```

Dry-run 預覽：

```powershell
.\Release.ps1 -Project sample -Version 1.0.0 -DryRun
```

非互動模式：

```powershell
.\Release.ps1 -Project sample -Version 1.0.0 -NonInteractive
```

輸入專案代號：

```text
Project Name (ex:sample): sample
```

輸入版本號：

```text
Version (ex:1.0.0): 1.0.0
```

工具會自動產生：

```text
Release Branch : RB-sample-1.0.0
Release Tag    : REL-sample-1.0.0
Dry Run        : False
```

Push 到設定的 remote main branch 前會再次要求確認。

## 執行畫面範例

```text
==========================================
        Release Tool Ver1.0
==========================================

Project Name (ex:sample): sample
Repository : C:\Git\SampleProject

Version (ex:1.0.0): 1.0.0

Release Branch : RB-sample-1.0.0
Release Tag    : REL-sample-1.0.0

Flow:
  STEP1  Feature Pull
  STEP2  Fetch Origin
  STEP3  Create Release Branch from origin/master
  STEP4  Replace by origin/master
  STEP5  Commit if needed
  STEP6  Rebase origin/master
  STEP7  Push RB -> Remote master
  STEP8  Create Tag
  STEP9  Push Tag
```

## Log

執行時會依 `Config.json` 的 `LogDirectory` 自動建立目錄並輸出 transcript log。

`Log/` 可能包含本機路徑、使用者名稱、remote URL、branch/tag 名稱與 Git 輸出，因此公開 repository 預設透過 `.gitignore` 排除。

## Release Notes

將 `ReleaseNotes.Enabled` 設為 `true` 後，工具會在 release 完成後輸出 Markdown release note。

```json
"ReleaseNotes": {
    "Enabled": true,
    "Directory": ".\\ReleaseNotes"
}
```

`ReleaseNotes/` 屬於本機執行產物，預設不提交到 Git。

## 後續可擴充功能

- 支援 dry-run 前的 Git 指令預覽強化。
- 支援多 remote 或多環境 release profile。
- 加入 Pester 測試。
- 加入 GitHub Release API 整合。

## License

MIT License

