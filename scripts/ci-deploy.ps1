#Requires -Version 5.1
<#
.SYNOPSIS
  Deploy a published Portfolio.Server build to the socha3.com IIS site.

.DESCRIPTION
  Run by the self-hosted runner in .github/workflows/deploy.yml (Windows
  PowerShell 5.1). Same shape as GigaGarageSale's scripts/ci-deploy.ps1, adapted
  to an ASP.NET Core app hosted in-process by IIS (no Node service to stop):

    1. Pre-flight: the package has Portfolio.Server.exe/.dll, web.config,
       profile.json and wwwroot\index.html; the paths are sane.
    2. Backs up the current site to -BackupRoot\<timestamp> (last -KeepBackups kept).
    3. Takes the app offline by writing app_offline.htm to the content root.
       The ASP.NET Core Module then shuts the app down and IIS releases the
       file locks on the DLLs (no admin rights / Stop-WebAppPool needed), and
       visitors get a short "updating" page instead of errors.
    4. Waits until Portfolio.Server.dll is no longer locked.
    5. Mirrors the package into the content root (robocopy /MIR). Never
       copied over or deleted: web.config, app_offline.htm,
       appsettings.Production.json, Logs\, logs\, .well-known\
       (plus -ExtraExcludeDirs / -ExtraExcludeFiles).
       web.config is created from the package only if it is missing.
    6. Removes app_offline.htm (the next request starts the new version).
    7. Polls <PublicUrl>api/profile (JSON) and <PublicUrl> (must reference the
       new main-*.js bundle) with a cache-busting query, so Cloudflare goes to
       the origin.
    8. If anything fails after the site was taken offline, restores the backup,
       brings the site back and exits 1.

  Robocopy exit codes 0-7 are success; 8 or higher is a failure.

.EXAMPLE
  .\scripts\ci-deploy.ps1 -Source C:\temp\portfolio-package\site -AppRoot D:\path\to\socha3-site
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$Source,
  [Parameter(Mandatory = $true)][string]$AppRoot,
  [string]$BackupRoot = "C:\WebApps\_deploy-backups\Portfolio",
  [string]$PublicUrl = "https://socha3.com/",
  [int]$HealthTimeoutSec = 90,
  [int]$UnlockTimeoutSec = 60,
  [int]$KeepBackups = 5,
  [string]$Commit = "",
  [string[]]$ExtraExcludeDirs = @(),
  [string[]]$ExtraExcludeFiles = @()
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"
# Windows PowerShell 5.1 defaults can lack TLS 1.2 for the public health check.
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12

# Never copied over, never deleted (server-owned).
$PreserveFiles = @("web.config", "app_offline.htm", "appsettings.Production.json") + $ExtraExcludeFiles
$PreserveDirs = @("Logs", "logs", ".well-known") + $ExtraExcludeDirs
$MainDll = "Portfolio.Server.dll"

function Write-Step([string]$Message) {
  Write-Host ""
  Write-Host "=== $Message ===" -ForegroundColor Cyan
}

# Runs a native command without letting stderr output abort the script; returns the exit code.
function Invoke-Native([string]$Exe, [string[]]$Arguments) {
  $old = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  try {
    & $Exe @Arguments 2>&1 | ForEach-Object { Write-Host "$_" }
    return $LASTEXITCODE
  } finally {
    $ErrorActionPreference = $old
  }
}

# Mirrors $From into $To, leaving the server-owned files and folders alone.
function Sync-Site([string]$From, [string]$To) {
  $opts = @($From, $To, "/MIR", "/R:5", "/W:3", "/NP", "/NFL", "/NDL", "/NJH", "/XF") + $PreserveFiles + @("/XD") + $PreserveDirs
  $code = Invoke-Native "robocopy.exe" $opts
  if ($code -ge 8) { throw "robocopy '$From' -> '$To' failed (exit code $code)" }
}

function Set-AppOffline {
  $html = "<!doctype html><html><head><meta charset=""utf-8""><title>Updating</title>" +
          "<meta http-equiv=""refresh"" content=""10""></head>" +
          "<body style=""font-family:sans-serif;text-align:center;padding-top:15vh"">" +
          "<h1>socha3.com is updating</h1><p>Back in a few seconds.</p></body></html>"
  Set-Content -LiteralPath (Join-Path $AppRoot "app_offline.htm") -Value $html -Encoding UTF8
  Write-Host "app_offline.htm written - IIS is shutting the app down"
}

function Remove-AppOffline {
  $f = Join-Path $AppRoot "app_offline.htm"
  if (Test-Path -LiteralPath $f) {
    Remove-Item -LiteralPath $f -Force
    Write-Host "app_offline.htm removed - site is back online"
  }
}

# app_offline.htm makes the ASP.NET Core Module stop the app; wait until the
# worker process has let go of the main DLL so robocopy can overwrite it.
function Wait-Unlocked {
  $dll = Join-Path $AppRoot $MainDll
  if (-not (Test-Path -LiteralPath $dll)) { return }
  $deadline = (Get-Date).AddSeconds($UnlockTimeoutSec)
  while ($true) {
    try {
      $fs = [System.IO.File]::Open($dll, "Open", "ReadWrite", "None")
      $fs.Close()
      Write-Host "$MainDll is unlocked"
      Start-Sleep -Seconds 1
      return
    } catch {
      if ((Get-Date) -ge $deadline) {
        throw "$MainDll is still locked $UnlockTimeoutSec s after app_offline.htm (IIS app pool did not release it)"
      }
      Start-Sleep -Seconds 2
    }
  }
}

function Get-MainBundle([string]$IndexHtml) {
  if (-not (Test-Path -LiteralPath $IndexHtml)) { return $null }
  $m = [regex]::Match((Get-Content -LiteralPath $IndexHtml -Raw), 'main-[A-Za-z0-9]+\.js')
  if ($m.Success) { return $m.Value }
  return $null
}

function Test-SiteHealthy([string]$ExpectedBundle) {
  $base = $PublicUrl.TrimEnd("/")
  $deadline = (Get-Date).AddSeconds($HealthTimeoutSec)
  $lastError = ""
  while ((Get-Date) -lt $deadline) {
    $nocache = [DateTime]::UtcNow.Ticks
    try {
      $api = Invoke-WebRequest -Uri "$base/api/profile?nocache=$nocache" -UseBasicParsing -TimeoutSec 15 `
        -Headers @{ "Cache-Control" = "no-cache" }
      $json = $api.Content | ConvertFrom-Json
      if ([int]$api.StatusCode -eq 200 -and $json.name) {
        $page = Invoke-WebRequest -Uri "$base/?nocache=$nocache" -UseBasicParsing -TimeoutSec 15 `
          -Headers @{ "Cache-Control" = "no-cache" }
        $html = $page.Content
        if ([int]$page.StatusCode -eq 200 -and $html -match "<app-root" -and $html -notmatch "socha3.com is updating") {
          if (-not $ExpectedBundle -or $html.Contains($ExpectedBundle)) {
            Write-Host ("GET {0}/api/profile -> 200 (name: {1})" -f $base, $json.name)
            Write-Host ("GET {0}/ -> 200{1}" -f $base, $(if ($ExpectedBundle) { " (serves $ExpectedBundle)" } else { "" }))
            return $true
          }
          $lastError = "home page does not reference $ExpectedBundle yet"
        } else {
          $lastError = "home page: status $($page.StatusCode), no <app-root> or still offline"
        }
      } else {
        $lastError = "api/profile: unexpected response $($api.StatusCode)"
      }
    } catch {
      $lastError = $_.Exception.Message
    }
    Start-Sleep -Seconds 3
  }
  Write-Host "Health check failed after $HealthTimeoutSec s: $lastError" -ForegroundColor Red
  return $false
}

# ---------------------------------------------------------------- preflight
if (-not $AppRoot) { throw "AppRoot is empty - set the DEPLOY_PATH repository variable." }
$Source = ([System.IO.Path]::GetFullPath($Source)).TrimEnd("\")
$AppRoot = ([System.IO.Path]::GetFullPath($AppRoot)).TrimEnd("\")
$BackupRoot = ([System.IO.Path]::GetFullPath($BackupRoot)).TrimEnd("\")
Write-Step "Deploying $(if ($Commit) { $Commit } else { 'package' }) from $Source to $AppRoot"
Write-Host "BackupRoot : $BackupRoot"
Write-Host "PublicUrl  : $PublicUrl"

if ($AppRoot.Length -le 3 -or ([System.IO.Path]::GetPathRoot($AppRoot)).TrimEnd("\") -eq $AppRoot) {
  throw "Refusing to deploy to drive root '$AppRoot'."
}
if ($AppRoot -ieq $Source -or
    $AppRoot.StartsWith("$Source\", [StringComparison]::OrdinalIgnoreCase) -or
    $Source.StartsWith("$AppRoot\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "Source and AppRoot must be different, non-nested folders."
}
if ($BackupRoot -ieq $AppRoot -or $BackupRoot.StartsWith("$AppRoot\", [StringComparison]::OrdinalIgnoreCase)) {
  throw "BackupRoot must be outside AppRoot (it would be purged by the mirror)."
}
foreach ($required in @("Portfolio.Server.exe", $MainDll, "web.config", "profile.json", "wwwroot\index.html")) {
  if (-not (Test-Path -LiteralPath (Join-Path $Source $required))) {
    throw "Package is missing $required - refusing to deploy."
  }
}
if (-not (Test-Path -LiteralPath $AppRoot -PathType Container)) {
  throw "AppRoot '$AppRoot' does not exist. Check the DEPLOY_PATH repository variable (it must be the IIS site's physical path)."
}
New-Item -ItemType Directory -Path $BackupRoot -Force | Out-Null
$expectedBundle = Get-MainBundle (Join-Path $Source "wwwroot\index.html")

# ---------------------------------------------------------------- backup
$backup = $null
if (Test-Path -LiteralPath (Join-Path $AppRoot $MainDll)) {
  $backup = Join-Path $BackupRoot (Get-Date -Format "yyyyMMdd-HHmmss")
  Write-Step "Backing up current site to $backup"
  $code = Invoke-Native "robocopy.exe" (@($AppRoot, $backup, "/MIR", "/R:2", "/W:2", "/NP", "/NFL", "/NDL", "/NJH", "/XF", "app_offline.htm", "/XD") + $PreserveDirs)
  if ($code -ge 8) { throw "Backup failed (robocopy exit code $code) - nothing on the site was changed." }
} else {
  Write-Step "No $MainDll in $AppRoot - first deploy, nothing to back up"
}

# ---------------------------------------------------------------- deploy
$offline = $false
try {
  Write-Step "Taking the site offline (app_offline.htm)"
  Set-AppOffline
  $offline = $true
  Wait-Unlocked

  Write-Step "Mirroring the package (preserving web.config, appsettings.Production.json, Logs\)"
  Sync-Site -From $Source -To $AppRoot

  $webConfig = Join-Path $AppRoot "web.config"
  if (-not (Test-Path -LiteralPath $webConfig)) {
    Copy-Item -LiteralPath (Join-Path $Source "web.config") -Destination $webConfig
    Write-Host "Created web.config from the package"
  } elseif ((Get-FileHash -LiteralPath $webConfig).Hash -ne (Get-FileHash -LiteralPath (Join-Path $Source "web.config")).Hash) {
    Write-Host "NOTE: keeping the server's web.config; it differs from the one dotnet publish generated." -ForegroundColor Yellow
  } else {
    Write-Host "Keeping existing web.config (same as the package)"
  }

  Write-Step "Bringing the site back online"
  Remove-AppOffline
  $offline = $false

  Write-Step "Health check $PublicUrl"
  if (-not (Test-SiteHealthy $expectedBundle)) { throw "New version is not healthy" }
} catch {
  Write-Host ""
  Write-Host "DEPLOY FAILED: $($_.Exception.Message)" -ForegroundColor Red
  if ($backup) {
    Write-Step "Rolling back to $backup"
    try {
      Set-AppOffline
      Wait-Unlocked
      Sync-Site -From $backup -To $AppRoot
      Remove-AppOffline
      if (Test-SiteHealthy (Get-MainBundle (Join-Path $backup "wwwroot\index.html"))) {
        Write-Host "ROLLBACK OK - previous version is serving again" -ForegroundColor Yellow
      } else {
        Write-Host "ROLLBACK DONE BUT THE SITE IS STILL UNHEALTHY - check the server" -ForegroundColor Red
      }
    } catch {
      Write-Host "ROLLBACK FAILED: $($_.Exception.Message) - check the server" -ForegroundColor Red
      try { Remove-AppOffline } catch { Write-Host "Could not remove app_offline.htm: $($_.Exception.Message)" -ForegroundColor Red }
    }
  } elseif ($offline) {
    Write-Host "No backup to roll back to (first deploy); removing app_offline.htm anyway." -ForegroundColor Red
    try { Remove-AppOffline } catch { Write-Host "Could not remove app_offline.htm: $($_.Exception.Message)" -ForegroundColor Red }
  }
  exit 1
}

# ---------------------------------------------------------------- tidy up
Write-Step "Pruning old backups (keeping $KeepBackups)"
Get-ChildItem -LiteralPath $BackupRoot -Directory |
  Sort-Object Name -Descending |
  Select-Object -Skip $KeepBackups |
  ForEach-Object { Write-Host "Removing $($_.FullName)"; Remove-Item -LiteralPath $_.FullName -Recurse -Force }

Write-Host ""
Write-Host "DEPLOY OK" -ForegroundColor Green
Write-Host "Public URL: $PublicUrl"
Write-Host "If Cloudflare still shows old HTML, purge https://socha3.com/ in the Cloudflare dashboard."
exit 0
