Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class ExLive {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern void mouse_event(uint dwFlags, int dx, int dy, uint dwData, UIntPtr dwExtraInfo);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[ExLive]::SetProcessDPIAware() | Out-Null

function Show-Hwnd([IntPtr]$hwnd) {
  Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
    [ExLive]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
  }
  [ExLive]::ShowWindow($hwnd, 3) | Out-Null
  [ExLive]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
  [ExLive]::BringWindowToTop($hwnd) | Out-Null
  [ExLive]::SetForegroundWindow($hwnd) | Out-Null
  [ExLive]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 400
}

function Save-Shot([IntPtr]$hwnd, [string]$name) {
  $r = New-Object ExLive+RECT
  [ExLive]::GetWindowRect($hwnd, [ref]$r) | Out-Null
  $w = $r.Right - $r.Left; $h = $r.Bottom - $r.Top
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
  . (Join-Path $PSScriptRoot "_repo-root.ps1")
  $out = Join-Path $script:TwaRepoRoot "scripts\$name"
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "SHOT=$out $($w)x$($h)"
}

function Click-XY([int]$x, [int]$y) {
  [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($x, $y)
  Start-Sleep -Milliseconds 120
  [ExLive]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [ExLive]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

function Get-ChromeEl {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  $chrome = $null
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.Name -match 'Chrome|كروم|Extensions|LinkedIn') { $chrome = $w }
  }
  return $chrome
}

$chromeProc = Get-Process chrome | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
$hwnd = $chromeProc.MainWindowHandle
Show-Hwnd $hwnd
$chrome = Get-ChromeEl

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$trueCond = [System.Windows.Automation.Condition]::TrueCondition

function Set-Url([string]$url) {
  $chrome = Get-ChromeEl
  $box = $null
  foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
    if ($e.Current.Name -match 'Address|search|عنوان|بحث|Omnibox') { $box = $e; break }
  }
  $box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($url)
  $box.SetFocus()
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Write-Output "GOTO=$url"
}

Set-Url "chrome://extensions"
Start-Sleep -Seconds 3
$chrome = Get-ChromeEl
$twaRect = $null
foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  if ($c.Current.Name -match 'TWA Reply Assist' -and $c.Current.BoundingRectangle.Y -gt 200) {
    $twaRect = $c.Current.BoundingRectangle
    Write-Output ("TWA_CARD {0},{1}" -f $twaRect.X,$twaRect.Y)
  }
}
$best = $null; $bestDist = 1e9
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -ne 'Reload') { continue }
  $br = $b.Current.BoundingRectangle
  if (-not $twaRect) { continue }
  $dist = [Math]::Abs($br.Y - $twaRect.Y) + [Math]::Abs($br.X - $twaRect.X)
  if ($dist -lt $bestDist) { $bestDist = $dist; $best = $b }
}
$br = $best.Current.BoundingRectangle
Click-XY ([int]($br.X + $br.Width / 2)) ([int]($br.Y + $br.Height / 2))
Write-Output "RELOADED dist=$bestDist"
Start-Sleep -Seconds 2

Set-Url "https://www.linkedin.com/feed/"
Start-Sleep -Seconds 8
$chrome = Get-ChromeEl
$twa = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'TWA Reply Assist') { $twa = $b }
}
$br = $twa.Current.BoundingRectangle
Click-XY ([int]($br.X + $br.Width / 2)) ([int]($br.Y + $br.Height / 2))
Write-Output "CLICKED_TWA"
Start-Sleep -Seconds 2
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 600

$chrome = Get-ChromeEl
$add = $null
foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  $n = $c.Current.Name
  if ($n -match 'Add a comment') {
    Write-Output "ADD_CANDIDATE=$n"
    if (-not $add -or $c.Current.BoundingRectangle.Y -lt $add.Current.BoundingRectangle.Y) { $add = $c }
  }
}
if ($add) {
  $ar = $add.Current.BoundingRectangle
  Write-Output ("CLICK_ADD {0},{1} {2}" -f $ar.X,$ar.Y,$add.Current.Name)
  Click-XY ([int]($ar.X + [Math]::Max($ar.Width, 20) / 2)) ([int]($ar.Y + [Math]::Max($ar.Height, 12) / 2))
} else {
  Write-Output "NO_ADD_COMMENT"
}
Start-Sleep -Seconds 2
Save-Shot $hwnd "extras-01-composer.png"

$chrome = Get-ChromeEl
$agree = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -eq 'Agree') {
    $br = $b.Current.BoundingRectangle
    Write-Output ("AGREE {0},{1}" -f $br.X,$br.Y)
    if (-not $agree -or $br.Y -lt $agree.Current.BoundingRectangle.Y) { $agree = $b }
  }
}
if (-not $agree) { throw "NO_AGREE" }
$br = $agree.Current.BoundingRectangle
Click-XY ([int]($br.X + $br.Width / 2)) ([int]($br.Y + $br.Height / 2))
Write-Output "CLICKED_AGREE"
Start-Sleep -Seconds 10
Save-Shot $hwnd "extras-02-draft.png"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [ExLive]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
}
Write-Output "DONE"
