Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RealInj {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[RealInj]::SetProcessDPIAware() | Out-Null

function Show-Hwnd([IntPtr]$hwnd) {
  [RealInj]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
  [RealInj]::ShowWindow($hwnd, 9) | Out-Null
  [RealInj]::BringWindowToTop($hwnd) | Out-Null
  [RealInj]::SetForegroundWindow($hwnd) | Out-Null
  [RealInj]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 400
}

function Save-Shot([IntPtr]$hwnd, [string]$name) {
  Show-Hwnd $hwnd
  Start-Sleep -Milliseconds 400
  $r = New-Object RealInj+RECT
  [RealInj]::GetWindowRect($hwnd, [ref]$r) | Out-Null
  $w = $r.Right - $r.Left
  $h = $r.Bottom - $r.Top
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
  . (Join-Path $PSScriptRoot "_repo-root.ps1")
  $out = Join-Path $script:TwaRepoRoot "scripts\$name"
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "SHOT=$out $($w)x$($h)"
}

$chromeProc = Get-Process chrome | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
if (-not $chromeProc) { throw "NO_CHROME" }
$hwnd = $chromeProc.MainWindowHandle
Write-Output "TITLE=$($chromeProc.MainWindowTitle)"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [RealInj]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
}
Show-Hwnd $hwnd

$root = [System.Windows.Automation.AutomationElement]::RootElement
$winCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم|Extensions|LinkedIn') { $chrome = $w }
}
if (-not $chrome) { throw "NO_UIA" }
Write-Output "UIA=$($chrome.Current.Name)"

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$box = $null
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -match 'Address|search|عنوان|بحث|Omnibox') { $box = $e; break }
}
if (-not $box) { throw "NO_OMNIBOX" }
$box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("https://www.linkedin.com/feed/")
$box.SetFocus()
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Write-Output "GOTO_FEED"
Start-Sleep -Seconds 8

$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم|LinkedIn') { $chrome = $w }
}
Write-Output "UIA2=$($chrome.Current.Name)"

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$twa = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'TWA Reply Assist') {
    Write-Output "FOUND=$($b.Current.Name)"
    $twa = $b
  }
}
if (-not $twa) { throw "NO_TWA_BTN" }
$twa.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
Write-Output "CLICKED_TWA"
Start-Sleep -Seconds 2
Save-Shot $hwnd "real-04-after-twa-click.png"

# Close popup with Escape then shot the feed
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 600
Save-Shot $hwnd "real-05-feed-after-inject.png"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [RealInj]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
}
Write-Output "DONE"
