Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class RealChrome {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern void keybd_event(byte bVk, byte bScan, uint dwFlags, UIntPtr dwExtraInfo);
  [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr hWnd);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[RealChrome]::SetProcessDPIAware() | Out-Null

function Get-ChromeWindows {
  Get-Process chrome -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero -and $_.MainWindowTitle } |
    ForEach-Object {
      $r = New-Object RealChrome+RECT
      [RealChrome]::GetWindowRect($_.MainWindowHandle, [ref]$r) | Out-Null
      [pscustomobject]@{
        Proc = $_
        Title = $_.MainWindowTitle
        Hwnd = $_.MainWindowHandle
        Left = $r.Left
        Top = $r.Top
        W = $r.Right - $r.Left
        H = $r.Bottom - $r.Top
        Area = ($r.Right - $r.Left) * ($r.Bottom - $r.Top)
      }
    }
}

function Show-Hwnd([IntPtr]$hwnd) {
  if ([RealChrome]::IsIconic($hwnd)) { [RealChrome]::ShowWindow($hwnd, 9) | Out-Null }
  else { [RealChrome]::ShowWindow($hwnd, 5) | Out-Null }
  [RealChrome]::keybd_event(0x12, 0, 0, [UIntPtr]::Zero)
  [RealChrome]::BringWindowToTop($hwnd) | Out-Null
  [RealChrome]::SetForegroundWindow($hwnd) | Out-Null
  [RealChrome]::keybd_event(0x12, 0, 2, [UIntPtr]::Zero)
  Start-Sleep -Milliseconds 400
}

function Save-Shot([IntPtr]$hwnd, [string]$name) {
  Show-Hwnd $hwnd
  Start-Sleep -Milliseconds 500
  $r = New-Object RealChrome+RECT
  [RealChrome]::GetWindowRect($hwnd, [ref]$r) | Out-Null
  $w = $r.Right - $r.Left
  $h = $r.Bottom - $r.Top
  if ($w -lt 50 -or $h -lt 50) { Write-Output "SKIP_SHOT $name tiny $($w)x$($h)"; return }
  $bmp = New-Object System.Drawing.Bitmap $w, $h
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.CopyFromScreen($r.Left, $r.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
  . (Join-Path $PSScriptRoot "_repo-root.ps1")
  $out = Join-Path $script:TwaRepoRoot "scripts\$name"
  $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
  $g.Dispose(); $bmp.Dispose()
  Write-Output "SHOT=$out $($w)x$($h) @$($r.Left),$($r.Top)"
}

function Get-ChromeUia([IntPtr]$hwnd) {
  $root = [System.Windows.Automation.AutomationElement]::RootElement
  $winCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Window
  )
  foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $winCond)) {
    if ($w.Current.NativeWindowHandle -eq $hwnd.ToInt32() -or $w.Current.Name -match 'Chrome|كروم') {
      return $w
    }
  }
  return $null
}

function Set-Omnibox([System.Windows.Automation.AutomationElement]$chrome, [string]$url) {
  $editCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Edit
  )
  $box = $null
  foreach ($e in $chrome.FindAll([System.Windows.Automation.TreeScope]::Descendants, $editCond)) {
    if ($e.Current.Name -match 'Address|search|عنوان|بحث|Omnibox') { $box = $e; break }
  }
  if (-not $box) { throw "NO_OMNIBOX" }
  $box.GetCurrentPattern([System.Windows.Automation.ValuePattern]::Pattern).SetValue($url)
  $box.SetFocus()
  Start-Sleep -Milliseconds 150
  [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")
  Write-Output "OMNIBOX=$url"
}

Write-Output "=== WINDOWS ==="
$wins = @(Get-ChromeWindows)
foreach ($w in $wins) {
  Write-Output ("WIN '{0}' {1}x{2} @{3},{4} hwnd={5}" -f $w.Title,$w.W,$w.H,$w.Left,$w.Top,$w.Hwnd)
}
if ($wins.Count -eq 0) { Write-Output "NO_CHROME"; exit 1 }

$pick = $wins | Sort-Object @{e={ if ($_.Title -match 'LinkedIn|Feed') { 1 } else { 0 } }; Descending=$true}, Area -Descending | Select-Object -First 1
Write-Output ("PICK '{0}' {1}x{2}" -f $pick.Title,$pick.W,$pick.H)

# Minimize Cursor so the Chrome bitmap is actually Chrome
Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [RealChrome]::ShowWindow($_.MainWindowHandle, 6) | Out-Null
}
Start-Sleep -Milliseconds 400
Save-Shot $pick.Hwnd "real-01-before.png"

$uia = Get-ChromeUia $pick.Hwnd
if (-not $uia) { Write-Output "NO_UIA" } else { Write-Output "UIA=$($uia.Current.Name)" }

# Dump toolbar-ish buttons
if ($uia) {
  $btnCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Button
  )
  $n = 0
  foreach ($b in $uia.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
    $name = $b.Current.Name
    if ($name -and $name -match 'TWA|Reply|Yapzy|Extensions|إضاف|Puzzle|extension') {
      Write-Output "BTN=$name"
      $n++
    }
  }
  Write-Output "BTN_HITS=$n"
}

# Reload via extensions page
if ($uia) {
  Set-Omnibox $uia "chrome://extensions"
  Start-Sleep -Seconds 2
  Save-Shot $pick.Hwnd "real-02-extensions.png"
  $uia = Get-ChromeUia $pick.Hwnd
  $btnCond = New-Object System.Windows.Automation.PropertyCondition(
    [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
    [System.Windows.Automation.ControlType]::Button
  )
  $reloaded = 0
  foreach ($b in $uia.FindAll([System.Windows.Automation.TreeScope]::Descendants, $btnCond)) {
    if ($b.Current.Name -eq 'Reload') {
      try {
        $b.GetCurrentPattern([System.Windows.Automation.InvokePattern]::Pattern).Invoke()
        $reloaded++
        Write-Output "CLICKED_RELOAD"
        Start-Sleep -Milliseconds 250
      } catch {
        Write-Output "RELOAD_FAIL=$($_.Exception.Message)"
      }
    }
    if ($b.Current.Name -match 'TWA|Reply Assist|Details') {
      Write-Output "EXT_BTN=$($b.Current.Name)"
    }
  }
  Write-Output "RELOAD_COUNT=$reloaded"
  Start-Sleep -Seconds 1
  Set-Omnibox $uia "https://www.linkedin.com/feed/"
  Start-Sleep -Seconds 7
  Save-Shot $pick.Hwnd "real-03-linkedin.png"
}

# Restore Cursor
Get-Process Cursor -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  [RealChrome]::ShowWindow($_.MainWindowHandle, 9) | Out-Null
}
Write-Output "DONE"
