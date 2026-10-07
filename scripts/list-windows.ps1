Add-Type @"
using System;
using System.Text;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public class EnumWins2 {
  public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
}
"@
$lines = New-Object System.Collections.Generic.List[string]
$cb = [EnumWins2+EnumProc]{
  param($h,$l)
  if (-not [EnumWins2]::IsWindowVisible($h)) { return $true }
  $sb = New-Object System.Text.StringBuilder 512
  [void][EnumWins2]::GetWindowText($h, $sb, $sb.Capacity)
  $t = $sb.ToString()
  if ([string]::IsNullOrWhiteSpace($t)) { return $true }
  $r = New-Object EnumWins2+RECT
  [EnumWins2]::GetWindowRect($h, [ref]$r) | Out-Null
  $w = $r.Right - $r.Left; $hgt = $r.Bottom - $r.Top
  if ($w -lt 200 -or $hgt -lt 150) { return $true }
  [void]$lines.Add(("{0}x{1} @{2},{3} | {4}" -f $w,$hgt,$r.Left,$r.Top,$t))
  return $true
}
[EnumWins2]::EnumWindows($cb, [IntPtr]::Zero) | Out-Null
$lines | Sort-Object | ForEach-Object { $_ }
