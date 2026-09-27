# Deploying socha3.com

Every merge to `master` deploys the site to https://socha3.com/ through
`.github/workflows/deploy.yml`. You can also start a deploy by hand from the Actions tab.

This is the same setup as GigaGarageSale (`bigmac529/GigaGarageSale`, `docs/DEPLOY.md`):
build on a GitHub-hosted runner, then a self-hosted runner on the socha3 Windows server
installs the package. The difference is that socha3.com is an ASP.NET Core app hosted
in-process by IIS, not a Node service, so the site is taken offline with
`app_offline.htm` instead of stopping a Windows service.

| Piece | Value |
| --- | --- |
| Public URL | https://socha3.com/ (Cloudflare → IIS, ASP.NET Core Module V2, in-process `Portfolio.Server.exe`) |
| Site folder | repository variable **`DEPLOY_PATH`** (the IIS site's physical path; must be set, see below) |
| Health check | https://socha3.com/api/profile (JSON) and https://socha3.com/ (must reference the new `main-*.js`), with a cache-busting query |
| Backups | `C:\WebApps\_deploy-backups\Portfolio\<timestamp>` (last 5 kept; override with the optional variable `DEPLOY_BACKUP_ROOT`) |
| Runner | self-hosted Windows runner on the server in `C:\actions-runner-portfolio`, labels `self-hosted, windows, portfolio` |

## How it works

1. **Build and smoke test** (GitHub-hosted `ubuntu-latest`):
   - `npm ci` and `npm run build` in `client/` (Node 20)
   - replaces `Portfolio.Server/wwwroot` with `client/dist/client/browser` (the committed `wwwroot` is ignored, so it can't be stale)
   - `dotnet publish Portfolio.Server -c Release -r win-x64 --self-contained false` (.NET 10), the same framework-dependent win-x64 build as the live site. `profile.json` is copied next to `Portfolio.Server.exe` by the csproj (`CopyToPublishDirectory`), and the job fails if it isn't there.
   - starts the published app with `dotnet Portfolio.Server.dll` and checks `/api/profile` and `/`
   - uploads a package: the publish output plus `DEPLOYED_COMMIT`, and `scripts/ci-deploy.ps1`
   - if the repository variable `DEPLOY_PATH` isn't set, it builds only and skips the deploy with a warning
2. **Deploy** (the self-hosted runner on the server) downloads the package and runs `scripts/ci-deploy.ps1`, which:
   1. backs up the current site folder (except `Logs\`)
   2. writes `app_offline.htm` to the site folder. The ASP.NET Core Module shuts the app down and IIS releases the DLLs, and visitors see a short "updating" page. The script waits until `Portfolio.Server.dll` is unlocked. No admin rights or app-pool commands are needed.
   3. mirrors the publish output into the site folder (`robocopy /MIR`, so old hashed bundles are removed). It never touches `web.config`, `appsettings.Production.json`, `Logs\`, `logs\` or `.well-known\`. `web.config` is created from the publish output only if it's missing.
   4. removes `app_offline.htm`, so the next request starts the new version
   5. polls https://socha3.com/api/profile and https://socha3.com/ for up to 90 seconds
   6. if anything fails after the site was taken offline, it restores the backup, brings the site back, checks health again, and **fails the job**

   Deploys never overlap (`concurrency: deploy-portfolio-production`). A newer run waits for the current one to finish.

The deploy uses no repository secrets. The runner connects out to GitHub, so nothing on the server has to be opened to the internet.

**Cloudflare:** the health check bypasses the cache, but visitors can still get cached HTML. If the new version doesn't show up, purge `https://socha3.com/` (and `/index.html`) in the Cloudflare dashboard. The purge isn't automated because no Cloudflare token is stored for these repos.

## One-time setup

### 0. Find the site folder and set `DEPLOY_PATH`

On the server (elevated PowerShell), find the IIS site that serves `socha3.com`:

```powershell
Import-Module WebAdministration
Get-Website | Where-Object { ($_.bindings.Collection.bindingInformation -join ' ') -match ':socha3\.com(\s|$)' } |
  Select-Object Name, applicationPool, physicalPath
```

Then set the repository variable to that `physicalPath` (as an absolute path, e.g. `C:\WebApps\<SiteName>`):

- GitHub → **bigmac529/Portfolio → Settings → Secrets and variables → Actions → Variables → New repository variable**: name `DEPLOY_PATH`, value = the physical path.
- Or: `gh variable set DEPLOY_PATH -R bigmac529/Portfolio --body 'C:\WebApps\<SiteName>'`

Optional: `DEPLOY_BACKUP_ROOT` (default `C:\WebApps\_deploy-backups\Portfolio`). It must be outside `DEPLOY_PATH`.

The IIS site name and app pool aren't needed by the deploy (it uses `app_offline.htm`), but make sure the app pool is **Started** and its identity can read the site folder (new files inherit the folder's permissions).

### 1. Create the runner's service account

The runner needs to write to the site folder and the backup folder, nothing else (no service or IIS rights).

```powershell
$site = "<DEPLOY_PATH value>"
$pw = Read-Host "Password for gha-portfolio" -AsSecureString
New-LocalUser -Name "gha-portfolio" -Password $pw -PasswordNeverExpires `
  -UserMayNotChangePassword -Description "GitHub Actions runner - socha3.com Portfolio deploys"

New-Item -ItemType Directory -Force "C:\WebApps\_deploy-backups\Portfolio" | Out-Null
icacls $site /grant "gha-portfolio:(OI)(CI)M" /T
icacls "C:\WebApps\_deploy-backups\Portfolio" /grant "gha-portfolio:(OI)(CI)M" /T
```

Don't add it to Administrators.

### 2. Install and register the runner as a service

Runners are registered per repository, so this repo needs its own runner (the GigaGarageSale and SnakeArcade runners can't pick up its jobs). It lives in its own folder, `C:\actions-runner-portfolio`, like `C:\actions-runner-gigagaragesale`.

1. Get a registration token: GitHub → **bigmac529/Portfolio → Settings → Actions → Runners → New self-hosted runner → Windows**, or `gh api -X POST repos/bigmac529/Portfolio/actions/runners/registration-token --jq .token`. It's valid for 1 hour.
2. Download and unpack the runner (the same page shows the current version and SHA-256):

   ```powershell
   [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
   New-Item -ItemType Directory -Force C:\actions-runner-portfolio | Out-Null
   Set-Location C:\actions-runner-portfolio
   $ver = "2.337.0"
   Invoke-WebRequest -UseBasicParsing -OutFile "runner.zip" `
     "https://github.com/actions/runner/releases/download/v$ver/actions-runner-win-x64-$ver.zip"
   Add-Type -AssemblyName System.IO.Compression.FileSystem
   [System.IO.Compression.ZipFile]::ExtractToDirectory("C:\actions-runner-portfolio\runner.zip", "C:\actions-runner-portfolio")
   ```

3. Configure it as a Windows service with the `portfolio` label (`self-hosted`, `Windows` and `X64` are added automatically):

   ```powershell
   .\config.cmd --url https://github.com/bigmac529/Portfolio --token <TOKEN> `
     --name socha3-portfolio --labels portfolio --work _work --runasservice
   ```

   When it asks for the service account, enter `.\gha-portfolio` and its password.
4. Verify: `Get-Service "actions.runner.bigmac529-Portfolio.*"` is **Running**, and Settings → Actions → Runners shows `socha3-portfolio` as **Idle** with labels `self-hosted`, `Windows`, `X64`, `portfolio`.

### 3. Lock down Actions (the repository is public)

- GitHub → Settings → Actions → General → *Approval for running fork pull request workflows*: **Require approval for all external contributors**.
- Keep `pull_request` / `pull_request_target` triggers out of any workflow whose jobs use `runs-on: [self-hosted, ...]`.
- Optional: Settings → Environments → **production** → Deployment branches → *Selected branches* → `master`. The environment is created by the first deploy.

## First deploy

1. Finish the setup above (runner Idle, `DEPLOY_PATH` set).
2. Start a deploy: **Actions → Deploy → Run workflow → Branch: master**, or

   ```bash
   gh workflow run deploy.yml -R bigmac529/Portfolio --ref master
   gh run watch -R bigmac529/Portfolio
   ```

   Merging a PR into `master` does the same. If the runner is offline, the deploy job waits in the queue (up to 24 hours).

After a deploy, `<DEPLOY_PATH>\DEPLOYED_COMMIT` contains the commit SHA that is live.

## Rolling back

- A failed deploy rolls itself back automatically and the run is marked failed.
- To go back to an earlier version later, revert the PR on GitHub and merge the revert.
- Manual restore from a backup:

  ```powershell
  $site = "<DEPLOY_PATH value>"
  $b = "C:\WebApps\_deploy-backups\Portfolio\<timestamp>"
  Set-Content "$site\app_offline.htm" "Updating"
  Start-Sleep 5
  robocopy $b $site /MIR /XF web.config app_offline.htm appsettings.Production.json /XD Logs logs .well-known
  Remove-Item "$site\app_offline.htm"
  Invoke-WebRequest https://socha3.com/api/profile -UseBasicParsing
  ```

## Troubleshooting

- **Deploy job skipped with "DEPLOY_PATH is not set"**: add the repository variable (step 0).
- **Deploy job stuck on "Waiting for a runner"**: the runner service is stopped, or its labels don't include `portfolio`.
- **"AppRoot does not exist"**: `DEPLOY_PATH` doesn't match the IIS site's physical path.
- **"Portfolio.Server.dll is still locked"**: the app didn't shut down after `app_offline.htm`. Check the app pool in IIS Manager; recycling it (`Restart-WebAppPool <pool>`, as admin) and re-running the deploy fixes it.
- **Access denied** on robocopy: recheck the `icacls` grants for `gha-portfolio`.
- **Logs**: the Actions run log, `<DEPLOY_PATH>\Logs` (Serilog), and `C:\actions-runner-portfolio\_diag` for the runner itself.
