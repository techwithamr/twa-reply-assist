Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class WinShot {
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
[WinShot]::SetProcessDPIAware() | Out-Null

$label = $args[0]
if (-not $label) { $label = "chrome" }
. (Join-Path $PSScriptRoot "_repo-root.ps1")
$out = Join-Path $script:TwaRepoRoot "scripts\proof-$label.png"

$best = $null
$bestArea = 0
Get-Process chrome -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowHandle -ne [IntPtr]::Zero } | ForEach-Object {
  $rect = New-Object WinShot+RECT
  [WinShot]::GetWindowRect($_.MainWindowHandle, [ref]$rect) | Out-Null
  $w = $rect.Right - $rect.Left
  $h = $rect.Bottom - $rect.Top
  $area = $w * $h
  Write-Output "WIN title='$($_.MainWindowTitle)' $($w)x$($h) hwnd=$($_.MainWindowHandle)"
  if ($area -gt $bestArea -and $w -gt 400 -and $h -gt 300) {
    $best = $_
    $bestArea = $area
  }
}
if (-not $best) { Write-Output "NO_WINDOW"; exit 1 }

$rect = New-Object WinShot+RECT
[WinShot]::GetWindowRect($best.MainWindowHandle, [ref]$rect) | Out-Null
$w = $rect.Right - $rect.Left
$h = $rect.Bottom - $rect.Top
Write-Output "PICK title='$($best.MainWindowTitle)' $($w)x$($h)"
[WinShot]::ShowWindow($best.MainWindowHandle, 9) | Out-Null
[WinShot]::SetForegroundWindow($best.MainWindowHandle) | Out-Null
Start-Sleep -Milliseconds 500
$bmp = New-Object System.Drawing.Bitmap $w, $h
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, (New-Object System.Drawing.Size $w, $h))
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $bmp.Dispose()
Write-Output "SHOT=$out $($w)x$($h)"
