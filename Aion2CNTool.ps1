﻿# -*- coding: utf-8 -*-
# AION 2 (Steam / PURPLE 正式版) 简繁双语一键汉化与还原工具
# 作者: B站@吃素的佩奇
# 開源主頁: https://github.com/duoluoyuji/Aion2-Steam-CN

param(
    [switch]$Install,
    [switch]$Restore,
    [string]$Lang = ""
)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ToolDir        = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$ZhDir          = Join-Path $ToolDir 'zh'
$ZhTwDir        = Join-Path $ToolDir 'zh-TW'
$LangName       = '简体中文'
$ActiveSourceDir = $ZhDir
if ($Lang -eq 'zh-TW' -or $Lang -eq 'tw' -or $Lang -eq 'cht') {
    $ActiveSourceDir = $ZhTwDir
    $LangName = '繁體中文'
}
$CurrentVersion = '1.3.0'
# 3393110 為 Steam 正式服 AppID，4972320 為 Steam Playtest 測試服 AppID
$AppIds         = @('3393110', '4972320')
$RemoteVersionUrl   = 'https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'
$FallbackVersionUrl = 'https://ghp.ci/https://raw.githubusercontent.com/duoluoyuji/Aion2-Steam-CN/main/version.json'

# ==================== 控制臺作者署名橫幅 ====================
function Show-Banner {
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host "      AION 2 (Steam / PURPLE 正式版) 繁體中文一鍵漢化工具 v$CurrentVersion" -ForegroundColor Cyan
    Write-Host "      開源主頁: https://github.com/duoluoyuji/Aion2-Steam-CN" -ForegroundColor Gray
    Write-Host "      【聲明】本工具完全免費分享，僅供交流學習，嚴禁倒賣牟利！" -ForegroundColor Red
    Write-Host "========================================================================" -ForegroundColor Magenta
    Write-Host ""
}

# ==================== 在線版本檢測與自動更新提醒 ====================
function Check-Update {
    Write-Host "[0/4] 正在檢查最新版本更新與公告..." -ForegroundColor DarkGray
    $remoteJson = $null
    $urls = @($RemoteVersionUrl, $FallbackVersionUrl)
    
    foreach ($u in $urls) {
        try {
            $req = [System.Net.HttpWebRequest]::Create($u)
            $req.Timeout = 3000
            $req.UserAgent = "Aion2CNTool"
            $resp = $req.GetResponse()
            $sr = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
            $txt = $sr.ReadToEnd()
            $sr.Close()
            $resp.Close()
            if ($txt) {
                $remoteJson = ConvertFrom-Json $txt
                break
            }
        } catch {}
    }

    if ($remoteJson) {
        $shouldUpdate = $false
        try {
            $rv = [System.Version]$remoteJson.version
            $lv = [System.Version]$CurrentVersion
            if ($rv -gt $lv) {
                $shouldUpdate = $true
            }
        } catch {
            # 容錯：若版本號非標準四段/三段數字，則僅當非自身且非舊版本時處理
            if ($remoteJson.version -and ($remoteJson.version -ne $CurrentVersion) -and ($remoteJson.version -ne '1.1.1') -and ($remoteJson.version -ne '1.1.0')) {
                $shouldUpdate = $true
            }
        }

        if ($shouldUpdate) {
            Write-Host ">>> 發現新版本: v$($remoteJson.version)！" -ForegroundColor Yellow
            $tip = "發現 AION 2 漢化工具最新版本：v$($remoteJson.version)`n`n公告內容：`n$($remoteJson.announcement)`n`n是否立即打開下載頁面？"
            $box = [System.Windows.Forms.MessageBox]::Show($tip, "版本更新提示 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
            if ($box -eq [System.Windows.Forms.DialogResult]::Yes) {
                try {
                    Start-Process "https://github.com/duoluoyuji/Aion2-Steam-CN/releases"
                } catch {
                    try {
                        [System.Diagnostics.Process]::Start((New-Object System.Diagnostics.ProcessStartInfo("https://github.com/duoluoyuji/Aion2-Steam-CN/releases") -Property @{UseShellExecute=$true}))
                    } catch {}
                }
            }
        } else {
            Write-Host "-> 當前已是最新正式版本 (v$CurrentVersion)。" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "-> 網絡檢測超時，使用離線模式繼續運行。" -ForegroundColor DarkGray
    }
}

# ==================== 掃描全盤所有已安裝的 AION 2 版本 ====================
function Get-AllGameRoots {
    $detected = @()
    $fixedDrives = (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -ne $null -and $_.Root }).Root
    
    # ---------------- 1. 掃描 Steam 游戲庫 ----------------
    $steamRoots = @()
    foreach ($d in $fixedDrives) {
        $candidates = @(
            (Join-Path $d 'SteamLibrary\steamapps'),
            (Join-Path $d 'steamapps'),
            (Join-Path $d 'Program Files (x86)\Steam\steamapps'),
            (Join-Path $d 'Program Files\Steam\steamapps'),
            (Join-Path $d 'Steam\steamapps')
        )
        foreach ($c in $candidates) {
            if (Test-Path $c) { $steamRoots += $c }
        }
    }
    
    try {
        $reg = Get-ItemProperty -Path "HKCU:\Software\Valve\Steam" -ErrorAction SilentlyContinue
        if ($reg -and $reg.SteamPath) {
            $regApps = Join-Path $reg.SteamPath 'steamapps'
            if (Test-Path $regApps) { $steamRoots += $regApps }
        }
    } catch {}

    $steamRoots = $steamRoots | Select-Object -Unique

    foreach ($r in $steamRoots) {
        foreach ($aid in $AppIds) {
            $acf = Join-Path $r "appmanifest_$aid.acf"
            if (Test-Path $acf) {
                try {
                    $txt = Get-Content $acf -Raw -ErrorAction SilentlyContinue
                    if ($txt -match '"installdir"\s+"([^"]+)"') {
                        $gameAbs = Join-Path (Join-Path $r 'common') $matches[1]
                        if (Test-Path (Join-Path $gameAbs 'Aion2\Content\Paks\L10N')) {
                            $label = if ($aid -eq '3393110') { "Steam 國際正式版" } else { "Steam 測試服版" }
                            if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $gameAbs.ToLower() })) {
                                $detected += [PSCustomObject]@{
                                    Platform = $label
                                    Path     = $gameAbs
                                    Type     = "Steam"
                                }
                            }
                        }
                    }
                } catch {}
            }
        }

        $common = Join-Path $r 'common'
        if (Test-Path $common) {
            $hits = Get-ChildItem $common -Directory -ErrorAction SilentlyContinue | Where-Object {
                Test-Path (Join-Path $_.FullName 'Aion2\Content\Paks\L10N')
            }
            foreach ($h in $hits) {
                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $h.FullName.ToLower() })) {
                    $detected += [PSCustomObject]@{
                        Platform = "Steam 游戲庫 ($($h.Name))"
                        Path     = $h.FullName
                        Type     = "Steam"
                    }
                }
            }
        }
    }

    # ---------------- 2. 三重增強：掃描 NCSoft PURPLE (紫P) 客戶端 ----------------
    # 增強 1：從 plaync 官方注冊表枚舉 BaseDir
    $playncRegKeys = @(
        "HKLM:\SOFTWARE\plaync",
        "HKLM:\SOFTWARE\WOW6432Node\plaync",
        "HKCU:\SOFTWARE\plaync"
    )
    foreach ($rk in $playncRegKeys) {
        try {
            if (Test-Path $rk) {
                $subKeys = Get-ChildItem -Path $rk -ErrorAction SilentlyContinue
                foreach ($sk in $subKeys) {
                    $props = Get-ItemProperty -Path $sk.PSPath -ErrorAction SilentlyContinue
                    if ($props -and $props.BaseDir) {
                        $bPath = $props.BaseDir.ToString().TrimEnd('\')
                        if (Test-Path (Join-Path $bPath 'Aion2\Content\Paks\L10N')) {
                            if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $bPath.ToLower() })) {
                                $detected += [PSCustomObject]@{
                                    Platform = "NCSoft PURPLE 國際服 (注冊表定位)"
                                    Path     = $bPath
                                    Type     = "PURPLE"
                                }
                            }
                        }
                    }
                }
            }
        } catch {}
    }

    # 增強 2：從 Windows 軟件卸載列表中精確匹配 AION 2 / PURPLE 安裝目錄
    $uninstallRegKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($uk in $uninstallRegKeys) {
        try {
            if (Test-Path $uk) {
                $subKeys = Get-ChildItem -Path $uk -ErrorAction SilentlyContinue
                foreach ($sk in $subKeys) {
                    $props = Get-ItemProperty -Path $sk.PSPath -ErrorAction SilentlyContinue
                    if ($props) {
                        $dName = $props.DisplayName
                        $iLoc = $props.InstallLocation
                        if ($dName -and ($dName -like "*AION*" -or $dName -like "*Purple*") -and $iLoc) {
                            $cleanLoc = $iLoc.ToString().TrimEnd('\')
                            if (Test-Path (Join-Path $cleanLoc 'Aion2\Content\Paks\L10N')) {
                                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $cleanLoc.ToLower() })) {
                                    $detected += [PSCustomObject]@{
                                        Platform = "NCSoft PURPLE 國際服 (系統識別)"
                                        Path     = $cleanLoc
                                        Type     = "PURPLE"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } catch {}
    }

    # 增強 3：全盤常見默認路徑深度匹配池
    foreach ($d in $fixedDrives) {
        $purpleCandidates = @(
            (Join-Path $d 'AION 2'),
            (Join-Path $d 'Aion2'),
            (Join-Path $d 'Games\AION 2'),
            (Join-Path $d 'Games\Aion2'),
            (Join-Path $d 'PurpleGames\AION 2'),
            (Join-Path $d 'PurpleGames\Aion2'),
            (Join-Path $d 'Purple\Games\AION 2'),
            (Join-Path $d 'NC\AION 2'),
            (Join-Path $d 'NCSOFT\AION 2'),
            (Join-Path $d 'NCSOFT\Purple\Games\AION 2'),
            (Join-Path $d 'Program Files\NCSOFT\Purple\AION 2'),
            (Join-Path $d 'Program Files (x86)\NCSOFT\Purple\AION 2')
        )
        foreach ($pc in $purpleCandidates) {
            if (Test-Path (Join-Path $pc 'Aion2\Content\Paks\L10N')) {
                if (-not ($detected | Where-Object { $_.Path.ToLower() -eq $pc.ToLower() })) {
                    $detected += [PSCustomObject]@{
                        Platform = "NCSoft PURPLE 國際服 (磁盤掃描)"
                        Path     = $pc
                        Type     = "PURPLE"
                    }
                }
            }
        }
    }

    return $detected
}

# 手動選擇游戲目錄保底
function Select-GameFolder {
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = "未自動檢測到游戲安裝位置。`n請手動選擇 AION 2 游戲根目錄（包含 Aion2 文件夾的那一層，名字通常為 AION 2 或 AION 2 Playtest）："
    $dlg.ShowNewFolderButton = $false
    if ($dlg.ShowDialog() -eq 'OK') {
        $sel = $dlg.SelectedPath
        if (Test-Path (Join-Path $sel 'Aion2\Content\Paks\L10N')) {
            return $sel
        } else {
            [System.Windows.Forms.MessageBox]::Show("所選目錄不是有效的 AION 2 游戲根目錄！`n該目錄下必須包含 Aion2 文件夾。", "錯誤 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            return $null
        }
    }
    return $null
}

# ==================== 智能版本決策與多版本選擇窗口 ====================
function Select-TargetGameRoots {
    param([string]$ActionName = "漢化")

    $all = @(Get-AllGameRoots)

    # 場景 0: 全盤未搜到任何版本 -> 彈窗手動選擇
    if ($all.Count -eq 0) {
        Write-Host "未能自動定位到游戲安裝路徑，請在彈出的窗口中手動指定..." -ForegroundColor Yellow
        $manual = Select-GameFolder
        if ($manual) {
            return @($manual)
        }
        return @()
    }

    # 場景 1: 只檢測到 1 個版本 -> 直接自動采用，無需用戶費神多點一次
    if ($all.Count -eq 1) {
        Write-Host "-> 檢測到唯一安裝版本: $($all[0].Platform) [$($all[0].Path)]" -ForegroundColor Green
        return @($all[0].Path)
    }

    # 場景 2: 檢測到 2 個或以上不同版本 (例如同時存在 Steam 與 PURPLE) -> 彈出交互窗口讓用戶勾選
    Write-Host ">>> 檢測到電腦中安裝了多個不同版本的 AION 2 ($($all.Count) 個)，正在彈出選擇窗口..." -ForegroundColor Cyan

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AION 2 游戲版本選擇 - B站@吃素的佩奇"
    $formHeight = 310 + ($all.Count * 45)
    $form.Size = New-Object System.Drawing.Size(650, $formHeight)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(24, 24, 28)
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)

    # 頂部橫幅
    $banner = New-Object System.Windows.Forms.Panel
    $banner.Dock = 'Top'
    $banner.Height = 70
    $banner.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 45)
    $form.Controls.Add($banner)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = "檢測到多個游戲版本，請選擇要【$ActionName】的目標："
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 12, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 255)
    $title.Location = New-Object System.Drawing.Point(20, 14)
    $title.AutoSize = $true
    $banner.Controls.Add($title)

    $subtitle = New-Object System.Windows.Forms.Label
    $subtitle.Text = "您可以在下方選擇其中一個版本，或選擇「同時處理全部版本」"
    $subtitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)
    $subtitle.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 190)
    $subtitle.Location = New-Object System.Drawing.Point(22, 42)
    $subtitle.AutoSize = $true
    $banner.Controls.Add($subtitle)

    # 中部列表單選區
    $body = New-Object System.Windows.Forms.Panel
    $body.Dock = 'Fill'
    $body.Padding = New-Object System.Windows.Forms.Padding(25, 15, 25, 10)
    $form.Controls.Add($body)
    $form.Controls.SetChildIndex($body, 0)

    $radioList = @()
    $y = 15

    for ($i = 0; $i -lt $all.Count; $i++) {
        $rb = New-Object System.Windows.Forms.RadioButton
        $rb.Text = "$($all[$i].Platform)  |  $($all[$i].Path)"
        $rb.Location = New-Object System.Drawing.Point(25, $y)
        $rb.Size = New-Object System.Drawing.Size(580, 36)
        $rb.ForeColor = [System.Drawing.Color]::FromArgb(235, 235, 240)
        $rb.Tag = @($all[$i].Path)
        if ($i -eq 0) { $rb.Checked = $true } # 默認高亮排在第一順位的版本
        $body.Controls.Add($rb)
        $radioList += $rb
        $y += 42
    }

    # 選項：同時處理全部版本 (兩端均生效)
    $rbAll = New-Object System.Windows.Forms.RadioButton
    $rbAll.Text = "★ 同時${ActionName}以上全部版本 (推薦，兩端都享受中文)"
    $rbAll.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10, [System.Drawing.FontStyle]::Bold)
    $rbAll.Location = New-Object System.Drawing.Point(25, $y)
    $rbAll.Size = New-Object System.Drawing.Size(580, 36)
    $rbAll.ForeColor = [System.Drawing.Color]::FromArgb(255, 215, 0)
    $allPaths = @($all | ForEach-Object { $_.Path })
    $rbAll.Tag = $allPaths
    $body.Controls.Add($rbAll)
    $radioList += $rbAll

    # 底部按鈕欄
    $btnRow = New-Object System.Windows.Forms.Panel
    $btnRow.Dock = 'Bottom'
    $btnRow.Height = 60
    $btnRow.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 36)
    $form.Controls.Add($btnRow)

    $btnOk = New-Object System.Windows.Forms.Button
    $btnOk.Text = "確認執行"
    $btnOk.DialogResult = 'OK'
    $btnOk.BackColor = [System.Drawing.Color]::FromArgb(70, 130, 180)
    $btnOk.ForeColor = [System.Drawing.Color]::White
    $btnOk.FlatStyle = 'Flat'
    $btnOk.Location = New-Object System.Drawing.Point(390, 14)
    $btnOk.Size = New-Object System.Drawing.Size(110, 32)
    $btnRow.Controls.Add($btnOk)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = "取消"
    $btnCancel.DialogResult = 'Cancel'
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 70)
    $btnCancel.ForeColor = [System.Drawing.Color]::White
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.Location = New-Object System.Drawing.Point(515, 14)
    $btnCancel.Size = New-Object System.Drawing.Size(95, 32)
    $btnRow.Controls.Add($btnCancel)

    $form.AcceptButton = $btnOk
    $form.CancelButton = $btnCancel

    $dialogRes = $form.ShowDialog()
    if ($dialogRes -eq 'OK') {
        foreach ($rb in $radioList) {
            if ($rb.Checked) {
                return $rb.Tag
            }
        }
    }

    Write-Host "用戶已取消版本選擇。" -ForegroundColor Yellow
    return @()
}

# ==================== 專屬定制免責聲明彈窗 ====================
function Show-Disclaimer {
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "AION 2 正式版漢化工具 - 制作: B站@吃素的佩奇"
    $form.Size = New-Object System.Drawing.Size(580, 480)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(24,24,28)

    # 頂部橫幅
    $banner = New-Object System.Windows.Forms.Panel
    $banner.Dock = 'Top'
    $banner.Height = 65
    $banner.BackColor = [System.Drawing.Color]::FromArgb(35,35,45)
    $form.Controls.Add($banner)

    $icon = New-Object System.Windows.Forms.Label
    $icon.Text = '!'
    $icon.Font = New-Object System.Drawing.Font('Arial', 24, [System.Drawing.FontStyle]::Bold)
    $icon.ForeColor = [System.Drawing.Color]::FromArgb(255,165,0)
    $icon.Location = New-Object System.Drawing.Point(16,12)
    $icon.Size = New-Object System.Drawing.Size(36,40)
    $icon.TextAlign = 'MiddleCenter'
    $banner.Controls.Add($icon)

    $title = New-Object System.Windows.Forms.Label
    $title.Text = '重要操作風險說明 (Steam / PURPLE 通用)'
    $title.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 15, [System.Drawing.FontStyle]::Bold)
    $title.ForeColor = [System.Drawing.Color]::FromArgb(255,165,0)
    $title.Location = New-Object System.Drawing.Point(58,16)
    $title.AutoSize = $true
    $banner.Controls.Add($title)

    # 中部說明文字區
    $body = New-Object System.Windows.Forms.Panel
    $body.Dock = 'Fill'
    $body.BackColor = [System.Drawing.Color]::FromArgb(28,28,34)
    $body.Padding = New-Object System.Windows.Forms.Padding(20,12,20,0)
    $form.Controls.Add($body)
    $form.Controls.SetChildIndex($body, 0)

    $items = @(
        '1. 本工具會向游戲目錄釋放漢化數據文件，并備份原版英文語言包。',
        '2. 任何客戶端修改都可能違反游戲服務條款，相關風險由使用者自行承擔。',
        '3. 執行過程中請勿啟動游戲或中斷任務，避免客戶端文件損壞。',
        '4. 本工具操作前會先自動備份原文件，可用「一鍵還原英文」隨時恢復。'
    )
    $y = 12
    foreach ($it in $items) {
        $l = New-Object System.Windows.Forms.Label
        $l.Text = $it
        $l.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10)
        $l.ForeColor = [System.Drawing.Color]::FromArgb(220,220,225)
        $l.AutoSize = $false
        $l.Location = New-Object System.Drawing.Point(16,$y)
        $l.Size = New-Object System.Drawing.Size(515,50)
        $l.TextAlign = 'TopLeft'
        $body.Controls.Add($l)
        $y += 56
    }

    # 聲明欄
    $authorBanner = New-Object System.Windows.Forms.Label
    $authorBanner.Text = "★ 本補丁支持 Steam / PURPLE 正式版 | 免費分享嚴禁倒賣"
    $authorBanner.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9, [System.Drawing.FontStyle]::Bold)
    $authorBanner.ForeColor = [System.Drawing.Color]::FromArgb(160,130,240)
    $newY = $y + 4
    $authorBanner.Location = New-Object System.Drawing.Point(16, $newY)
    $authorBanner.Size = New-Object System.Drawing.Size(515,22)
    $authorBanner.TextAlign = 'MiddleLeft'
    $body.Controls.Add($authorBanner)

    # 底部勾選確認欄
    $checkRow = New-Object System.Windows.Forms.Panel
    $checkRow.Dock = 'Bottom'
    $checkRow.Height = 56
    $checkRow.BackColor = [System.Drawing.Color]::FromArgb(20,20,26)
    $form.Controls.Add($checkRow)

    $chk = New-Object System.Windows.Forms.CheckBox
    $chk.Text = '我已充分了解修改客戶端的潛在風險，并確認當前游戲已經完全關閉。'
    $chk.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)
    $chk.ForeColor = [System.Drawing.Color]::FromArgb(200,200,205)
    $chk.Location = New-Object System.Drawing.Point(18,16)
    $chk.AutoSize = $true
    $checkRow.Controls.Add($chk)

    # 按鈕欄
    $btnRow = New-Object System.Windows.Forms.Panel
    $btnRow.Dock = 'Bottom'
    $btnRow.Height = 64
    $btnRow.BackColor = [System.Drawing.Color]::FromArgb(32,32,38)
    $form.Controls.Add($btnRow)

    $btnCancel = New-Object System.Windows.Forms.Button
    $btnCancel.Text = '取消退出'
    $btnCancel.BackColor = [System.Drawing.Color]::FromArgb(55,55,62)
    $btnCancel.ForeColor = [System.Drawing.Color]::FromArgb(200,200,200)
    $btnCancel.FlatStyle = 'Flat'
    $btnCancel.Location = New-Object System.Drawing.Point(20,15)
    $btnCancel.Size = New-Object System.Drawing.Size(100,34)
    $btnRow.Controls.Add($btnCancel)

    $btnBili = New-Object System.Windows.Forms.Button
    $btnBili.Text = '作者B站主頁'
    $btnBili.BackColor = [System.Drawing.Color]::FromArgb(45,85,125)
    $btnBili.ForeColor = [System.Drawing.Color]::White
    $btnBili.FlatStyle = 'Flat'
    $btnBili.Location = New-Object System.Drawing.Point(150,15)
    $btnBili.Size = New-Object System.Drawing.Size(110,34)
    $btnBili.Add_Click({ [System.Diagnostics.Process]::Start("https://space.bilibili.com/3379443") })
    $btnRow.Controls.Add($btnBili)

    $btnGo = New-Object System.Windows.Forms.Button
    $btnGo.Text = '已了解，繼續'
    $btnGo.BackColor = [System.Drawing.Color]::FromArgb(90,70,200)
    $btnGo.ForeColor = [System.Drawing.Color]::White
    $btnGo.FlatStyle = 'Flat'
    $btnGo.Location = New-Object System.Drawing.Point(410,15)
    $btnGo.Size = New-Object System.Drawing.Size(130,34)
    $btnGo.Enabled = $false
    $btnRow.Controls.Add($btnGo)

    $btnGo.Add_Click({ $form.DialogResult = 'OK'; $form.Close() })
    $btnCancel.Add_Click({ $form.DialogResult = 'Cancel'; $form.Close() })
    $chk.Add_CheckedChanged({ $btnGo.Enabled = $chk.Checked })

    $form.AcceptButton = $btnGo
    $form.CancelButton = $btnCancel
    return $form.ShowDialog()
}

# ==================== 主流程 ====================
Show-Banner

if ($Install) {
    $res = Show-Disclaimer
    if ($res -ne 'OK') {
        Write-Host "用戶已取消操作。" -ForegroundColor Yellow
        exit 0
    }

    Check-Update

    Write-Host "[1/4] 正在全盤掃描檢測 AION 2 游戲版本 (Steam / PURPLE)..." -ForegroundColor Cyan
        # 自動安全解除游戲和啟動器進程占用，防止文件被鎖死導致無法替換
    Write-Host "[1.5/4] 正在檢查沖突進程并釋放文件鎖..." -ForegroundColor Cyan
    $conflictList = @("Aion2", "Aion2-Win64-Shipping", "NCLauncher", "NCLauncher2", "Purple", "PurpleApp")
    foreach ($proc in $conflictList) {
        $p = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($p) {
            Write-Host "-> 檢測到運行中的進程: $proc，正在安全解除占用..." -ForegroundColor Yellow
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 600
        }
    }
    $selectedRoots = @(Select-TargetGameRoots -ActionName "安裝漢化")
    if ($selectedRoots.Count -eq 0) {
        Write-Host "未選擇有效游戲目錄，操作已終止。" -ForegroundColor Red
        exit 1
    }

    $processedCount = 0
    foreach ($gameRoot in $selectedRoots) {
        $processedCount++
        Write-Host ""
        Write-Host "========================================================================" -ForegroundColor DarkCyan
        Write-Host ">>> 正在處理目標游戲目錄 [$processedCount/$($selectedRoots.Count)]: $gameRoot" -ForegroundColor Green
        Write-Host "========================================================================" -ForegroundColor DarkCyan

        $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
        $enUsL10nDir = Join-Path $gameRoot "Aion2\Content\L10N\Text\en-US"
        $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"

        Write-Host "[2/4] 正在建立官方原版英文語言備份..." -ForegroundColor Cyan
        if (-not (Test-Path $backupDir)) {
            New-Item -ItemType Directory -Path $backupDir -Force | Out-Null
            $curPak = Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.pak"
            if ((Test-Path $curPak) -and ((Get-Item $curPak).Length -gt 1000)) {
                Copy-Item "$enUsPaksDir\*" $backupDir -Force
                Write-Host "-> 官方原版英文文件已安全備份至: $backupDir" -ForegroundColor Green
            }
        } else {
            Write-Host "-> 本地已存在安全備份，跳過覆蓋。" -ForegroundColor Gray
        }

        Write-Host "[3/4] 正在釋放中文數據表 (L10NString.dat)..." -ForegroundColor Cyan
        New-Item -ItemType Directory -Path $enUsL10nDir -Force | Out-Null
        if (Test-Path (Join-Path $enUsL10nDir "L10NString.dat")) { Set-ItemProperty -Path (Join-Path $enUsL10nDir "L10NString.dat") -Name IsReadOnly -Value $false -ErrorAction SilentlyContinue }
        Copy-Item (Join-Path $ActiveSourceDir "L10NString.dat") (Join-Path $enUsL10nDir "L10NString.dat") -Force

        Write-Host "[4/4] 正在注入虛幻5回退機制 Stub..." -ForegroundColor Cyan
        $sigFiles = @(
            (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.sig"),
            (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.ucas"),
            (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.utoc")
        )
        foreach ($sf in $sigFiles) {
            if (Test-Path $sf) {
                Clear-Content -Path $sf -Force -ErrorAction SilentlyContinue
                Remove-Item $sf -Force -ErrorAction SilentlyContinue
                if (Test-Path $sf) {
                    [System.IO.File]::WriteAllBytes($sf, @()) 2>$null
                }
            }
        }
        Copy-Item (Join-Path $ActiveSourceDir "pakchunk502000-Windows_0_P.pak") (Join-Path $enUsPaksDir "pakchunk502000-Windows_0_P.pak") -Force
        Write-Host "-> 該目錄漢化部署完成！" -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ">>> 恭喜！AION 2 $($LangName)漢化全部安裝成功 (共處理 $processedCount 個客戶端)！" -ForegroundColor Green
    Write-Host ">>> 【核心提示】游戲內語言請保持默認的英文（English），進游戲即可直接顯示中文！" -ForegroundColor Yellow
    Write-Host ">>> 制作與維護：B站@吃素的佩奇 | 歡迎關注獲取公測最新漢化！" -ForegroundColor Magenta
    Write-Host "========================================================================" -ForegroundColor Green
    [System.Windows.Forms.MessageBox]::Show("AION 2 $($LangName)補丁安裝成功 (共處理 $processedCount 個客戶端)！`n`n【提示】：游戲內語言保持默認英文（English）即可直接享受中文！`n`n制作：B站@吃素的佩奇`n歡迎關注獲取最新漢化動態！", "漢化成功 - B站@吃素的佩奇", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}
elseif ($Restore) {
    Write-Host "[1/3] 正在全盤掃描檢測 AION 2 游戲版本 (Steam / PURPLE)..." -ForegroundColor Cyan
        # 自動安全解除游戲和啟動器進程占用，防止文件被鎖死導致無法替換
    Write-Host "[1.5/4] 正在檢查沖突進程并釋放文件鎖..." -ForegroundColor Cyan
    $conflictList = @("Aion2", "Aion2-Win64-Shipping", "NCLauncher", "NCLauncher2", "Purple", "PurpleApp")
    foreach ($proc in $conflictList) {
        $p = Get-Process -Name $proc -ErrorAction SilentlyContinue
        if ($p) {
            Write-Host "-> 檢測到運行中的進程: $proc，正在安全解除占用..." -ForegroundColor Yellow
            Stop-Process -Name $proc -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 600
        }
    }
    $selectedRoots = @(Select-TargetGameRoots -ActionName "還原英文")
    if ($selectedRoots.Count -eq 0) {
        Write-Host "未選擇有效游戲目錄，操作已終止。" -ForegroundColor Red
        exit 1
    }

    $processedCount = 0
    foreach ($gameRoot in $selectedRoots) {
        $processedCount++
        Write-Host ""
        Write-Host "========================================================================" -ForegroundColor DarkCyan
        Write-Host ">>> 正在還原目標游戲目錄 [$processedCount/$($selectedRoots.Count)]: $gameRoot" -ForegroundColor Green
        Write-Host "========================================================================" -ForegroundColor DarkCyan

        $backupDir   = Join-Path $gameRoot "Aion2_English_Backup_Safe"
        $enUsPaksDir = Join-Path $gameRoot "Aion2\Content\Paks\L10N\Text\en-US"

        Write-Host "[2/3] 清理漢化數據表..." -ForegroundColor Cyan
        $l10nRoot = Join-Path $gameRoot "Aion2\Content\L10N"
        if (Test-Path $l10nRoot) {
            Remove-Item $l10nRoot -Recurse -Force -ErrorAction SilentlyContinue
        }

        Write-Host "[3/3] 還原官方原版英文語言包..." -ForegroundColor Cyan
        if (Test-Path $backupDir) {
            Copy-Item "$backupDir\*" $enUsPaksDir -Force
            Write-Host "-> 還原成功！已完整恢復官方原版英文狀態。" -ForegroundColor Green
        } else {
            Write-Host "-> 未檢測到本地備份，已為您清理漢化數據，建議檢驗文件完整性。" -ForegroundColor Yellow
        }
    }

    Write-Host ""
    Write-Host "========================================================================" -ForegroundColor Green
    Write-Host ">>> 全部還原操作已完成 (共恢復 $processedCount 個客戶端)！" -ForegroundColor Green
    Write-Host "========================================================================" -ForegroundColor Green
    [System.Windows.Forms.MessageBox]::Show("已成功還原為官方原版英文客戶端 (共恢復 $processedCount 個版本)！`n`n制作：B站@吃素的佩奇", "還原成功", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
}


