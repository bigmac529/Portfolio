# socha3.com Portfolio

Reconstructed source for [socha3.com](https://socha3.com): an ASP.NET Core 10.0 host plus an Angular 19 + Tailwind SPA.

```
Portfolio/
├── Portfolio.Server/     ASP.NET Core 10.0 API + static/SPA host
│   ├── Controllers/      GET /api/Profile (case-insensitive; live client uses /api/profile)
│   ├── Models/           Profile, Role, Education, skills, links
│   ├── Utility/          JsonSerializerDefault (camelCase, case-insensitive)
│   ├── profile.json      Live profile payload (studyAbroad spelling corrected)
│   └── wwwroot/          Published Angular output lives here
├── client/               Angular 19.0 standalone SPA + Tailwind CSS
└── Portfolio.slnx
```

## Prerequisites

- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) (built with 10.0.401)
- Node.js 20+ and npm

## Run locally

Two equivalent workflows.

### A. `dotnet run` (API + SpaProxy launches Angular)

From `Portfolio.Server/`:

```bash
dotnet run --launch-profile http
```

- API / Swagger: http://localhost:5126 (Swagger UI only in Development)
- SpaProxy starts `npm start` in `client/` and forwards non-API requests to http://localhost:4200
- Browse http://localhost:5126 — the page is the Angular app; `/api/profile` is served by Kestrel

HTTPS profile (`https`) listens on https://localhost:7126 as well.

### B. Two terminals (Angular proxy)

```bash
# terminal 1
cd Portfolio.Server
dotnet run --launch-profile http

# terminal 2
cd client
npm install
npm start          # ng serve --port 4200, proxies /api → http://localhost:5126
```

Browse http://localhost:4200.

## Publish (IIS / win-x64, matching socha3.com)

1. Build the SPA into the server `wwwroot`:

```bash
cd client
npm install
npm run build
# Angular 19 application builder output:
#   client/dist/client/browser/*
```

```bash
# from Portfolio/
rm -rf Portfolio.Server/wwwroot/*
cp -R client/dist/client/browser/. Portfolio.Server/wwwroot/
```

2. Publish the server (framework-dependent, win-x64, same as the live deploy):

```bash
cd Portfolio.Server
dotnet publish -c Release -r win-x64 --self-contained false -o ./publish
```

`dotnet publish` emits `web.config` for IIS in-process hosting (`Portfolio.Server.exe`).

3. Deploy the publish folder. **`profile.json` must sit next to the executable** (the controller reads `Path.Combine(Environment.CurrentDirectory, "profile.json")`). It is already copied to the output/publish directory.

4. IIS: AspNetCoreModuleV2, in-process, site root = publish folder. The app uses `UseDefaultFiles` + `MapStaticAssets` + `MapFallbackToFile("/index.html")` for SPA deep links.

Serilog file logs go to `Logs/log-{Date}.log` (see `appsettings.json` `Logging:PathFormat`).

## API

| Method | Path | Notes |
|--------|------|--------|
| GET | `/api/Profile` or `/api/profile` | Loads `profile.json` once into a static cache |

CORS: `AllowAnyOrigin` / `AllowAnyHeader` / `AllowAnyMethod`.

Swagger (`Portfolio API` v1, UI title `Swagger UI - Portfolio`) is registered only when `ASPNETCORE_ENVIRONMENT=Development`.

## Notes vs live socha3.com

- `profile.json` is the live `GET /api/profile` payload (pretty-printed). The IIS deploy file had a typo key `studyAboad` on `education[0]`; this tree uses `studyAbroad` so it binds to `Education.StudyAbroad`.
- Client calls `/api/profile` (lowercase) to match the live bundle. ASP.NET routing is case-insensitive.
- UI sections, snapshot-card copy, skill filter, and top-5-by-signal logic were recovered from the live Ivy bundle + `RECON.md`.
- Optional metadata: Company `Socha3`, ProjectGuid `972ec1cd-f27a-4626-8e72-9569d8ba7d47`.
