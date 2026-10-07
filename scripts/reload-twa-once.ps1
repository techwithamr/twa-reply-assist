Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RelOnce {
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
[RelOnce]::SetProcessDPIAware() | Out-Null

function Show-Hwnd([IntPtr]$hwnd) {
  Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
    [RelOnce]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
  }
  [RelOnce]::ShowWindow($hwnd, 3) | Out-Null
  [RelOnce]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
  [RelOnce]::BringWindowToTop($hwnd) | Out-Null
  [RelOnce]::SetForegroundWindow($hwnd) | Out-Null
  [RelOnce]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 400
}

function Save-Shot([IntPtr]$hwnd, [string]$name) {
  $r = New-Object RelOnce+RECT
  [RelOnce]::GetWindowRect($hwnd, [ref]$r) | Out-Null
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
  [RelOnce]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 40
  [RelOnce]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
}

$chromeProc = Get-Process chrome | Where-Object { $_.MainWindowTitle } | Select-Object -First 1
$hwnd = $chromeProc.MainWindowHandle
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

$editCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Edit
)
$box = $null
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -match 'Address|search|عنوان|بحث|Omnibox') { $box = $e; break }
}
$box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("chrome://extensions")
$box.SetFocus()
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 3
$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم|Extensions') { $chrome = $w }
}

$trueCond = [System.Windows.Automation.Condition]::TrueCondition
$twaRect = $null
foreach ($c in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $trueCond)) {
  if ($c.Current.Name -match 'TWA Reply Assist') {
    $twaRect = $c.Current.BoundingRectangle
    Write-Output ("TWA_NODE={0} {1},{2}" -f $c.Current.Name,$twaRect.X,$twaRect.Y)
  }
}

$btnCond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Button
)
$best = $null
$bestDist = 1e9
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -ne 'Reload') { continue }
  $br = $b.Current.BoundingRectangle
  if (-not $twaRect) { continue }
  $dist = [Math]::Abs($br.Y - $twaRect.Y) + [Math]::Abs($br.X - $twaRect.X)
  Write-Output ("RELOAD {0},{1} dist={2}" -f $br.X,$br.Y,$dist)
  if ($dist -lt $bestDist) { $bestDist = $dist; $best = $b }
}
if (-not $best) { throw "NO_TWA_RELOAD" }
$br = $best.Current.BoundingRectangle
$x = [int]($br.X + $br.Width / 2)
$y = [int]($br.Y + $br.Height / 2)
Write-Output "CLICK_RELOAD=$x,$y dist=$bestDist"
Click-XY $x $y
Start-Sleep -Seconds 2
Save-Shot $hwnd "real-08-reloaded.png"

$box = $null
foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
  if ($e.Current.Name -match 'Address|search|عنوان|بحث|Omnibox') { $box = $e; break }
}
$box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue("https://www.linkedin.com/feed/")
$box.SetFocus()
[System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
Start-Sleep -Seconds 8

$chrome = $null
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
  if ($w.Current.Name -match 'Chrome|كروم|LinkedIn') { $chrome = $w }
}
$twa = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'TWA Reply Assist') { $twa = $b }
}
$br = $twa.Current.BoundingRectangle
Click-XY ([int]($br.X + $br.Width / 2)) ([int]($br.Y + $br.Height / 2))
Write-Output "CLICKED_TWA"
Start-Sleep -Seconds 2
Save-Shot $hwnd "real-09-popup.png"

# Click the first orange action in the popup: "افتح اللوحة على البوست ده"
# Popup sits under the TWA icon. From last shot the button is roughly below the title.
$open = $null
foreach ($b in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
  if ($b.Current.Name -match 'افتح|لوحة|Open panel|البوست') {
    Write-Output "OPEN_BTN=$($b.Current.Name)"
    $open = $b
  }
}
if ($open) {
  $ob = $open.Current.BoundingRectangle
  Click-XY ([int]($ob.X + $ob.Width / 2)) ([int]($ob.Y + $ob.Height / 2))
  Write-Output "CLICKED_OPEN_PANEL"
  Start-Sleep -Seconds 2
} else {
  # fallback: click below TWA icon where the first popup button sits
  Click-XY ([int]($br.X - 80)) ([int]($br.Y + 90))
  Write-Output "CLICKED_OPEN_FALLBACK"
  Start-Sleep -Seconds 2
}
Save-Shot $hwnd "real-10-after-open.png"
Start-Sleep -Milliseconds 400
[System.Windows.Forms.SendKeys]::SendWait("{ESC}")
Start-Sleep -Milliseconds 700
Save-Shot $hwnd "real-11-real-feed.png"

Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [RelOnce]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
}
Write-Output "DONE"
