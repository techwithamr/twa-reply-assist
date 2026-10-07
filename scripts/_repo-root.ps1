# One load/output folder for every helper script.
$script:TwaGithubRoot = "C:\Github\twa-reply-assist"
$script:TwaHereRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
if (Test-Path -LiteralPath (Join-Path $script:TwaGithubRoot "manifest.json")) {
  $script:TwaRepoRoot = $script:TwaGithubRoot
} else {
  $script:TwaRepoRoot = $script:TwaHereRoot
}
