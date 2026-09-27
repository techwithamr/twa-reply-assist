Add-Type -AssemblyName UIAutomationClient
Add-Type -AssemblyName UIAutomationTypes

$root = [System.Windows.Automation.AutomationElement]::RootElement
$chrome = $null
$cond = New-Object System.Windows.Automation.PropertyCondition(
  [System.Windows.Automation.AutomationElement]::ControlTypeProperty,
  [System.Windows.Automation.ControlType]::Window
)
foreach ($w in $root.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)) {
  $name = $w.Current.Name
  if ($name -match 'Chrome|كروم|Extensions|إضافات') {
    $chrome = $w
    Write-Output "WINDOW=$name"
  }
}
if (-not $chrome) { Write-Output "NO_CHROME_WINDOW"; exit 1 }

$walker = [System.Windows.Automation.TreeWalker]::ControlViewWalker
$hits = New-Object System.Collections.Generic.List[string]
function Walk($el, $depth) {
  if ($depth -gt 12 -or $hits.Count -gt 80) { return }
  $n = $el.Current.Name
  $ct = $el.Current.ControlType.ProgrammaticName
  $auto = $el.Current.AutomationId
  if ($n -or $auto) {
    if ($n -match 'Developer|مطور|Load|تحميل|unpacked|غير|Browse|Extensions|إضاف|Enable|وضع') {
      $hits.Add(("$depth|$ct|$n|$auto"))
    }
  }
  $child = $walker.GetFirstChild($el)
  while ($child) {
    Walk $child ($depth + 1)
    $child = $walker.GetNextSibling($child)
  }
}
Walk $chrome 0
$hits | ForEach-Object { $_ }
Write-Output "HIT_COUNT=$($hits.Count)"
