param(
  [switch]$PrepareOnly,
  [string]$DevEcoHome,
  [string]$SigningProfile,
  [switch]$Unsigned,
  [switch]$SkipChecks,
  [string]$StageName = 'harmony-app'
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
if ($StageName -notmatch '^harmony-[a-z0-9-]+$') { throw 'StageName must start with harmony- and contain only lowercase letters, digits and hyphens.' }
$stage = Join-Path $projectRoot ('.tools/' + $StageName)
$sources = Get-Content (Join-Path $projectRoot 'harmony/sources.json') -Raw | ConvertFrom-Json
function Assert-Exit([string]$Step) {
  if ($LASTEXITCODE -ne 0) { throw "$Step failed (exit $LASTEXITCODE)." }
}
if ($Unsigned -and $SigningProfile) {
  throw 'Choose either -Unsigned or -SigningProfile, not both.'
}
if ($DevEcoHome) {
  . "$PSScriptRoot/harmony-env.ps1" -DevEcoHome $DevEcoHome
} elseif (!$PrepareOnly -and !$env:DEVECO_SDK_HOME -and (Test-Path -LiteralPath 'D:\Huawei\command-line-tools\sdk')) {
  . "$PSScriptRoot/harmony-env.ps1"
}
if (!$PrepareOnly) {
  $sdkMetadata = if ($env:DEVECO_SDK_HOME) { Join-Path $env:DEVECO_SDK_HOME 'default/sdk-pkg.json' }
  if (!$sdkMetadata -or !(Test-Path -LiteralPath $sdkMetadata)) {
    throw 'Install HarmonyOS API 26 SDK and supply its tool directory with -DevEcoHome.'
  }
  $sdkInfo = Get-Content -LiteralPath $sdkMetadata -Raw | ConvertFrom-Json
  if ([int]$sdkInfo.data.apiVersion -lt 26) {
    throw "Flutter OHOS 3.41.10 requires compile SDK API 26; installed SDK is API $($sdkInfo.data.apiVersion). Install Command Line Tools 26.0.0 or newer. No generated project files were replaced."
  }
}
# Pin repositories before generating path overrides. Sparse clones avoid fetching
# unrelated plugins; Android's pubspec.lock and .dart_tool are never touched.
foreach ($source in @($sources.flutter, $sources.webview, $sources.preferences)) {
  $sourcePath = Join-Path $projectRoot ('.tools/' + $source.directory)
  $createdSource = !(Test-Path -LiteralPath "$sourcePath/.git")
  if ($createdSource) {
    if ($source.sparse) {
      & git -c http.version=HTTP/1.1 clone --depth 1 --filter=blob:none --sparse --single-branch --branch $source.branch $source.url $sourcePath
    } else {
      & git -c http.version=HTTP/1.1 clone --depth 1 --single-branch --branch $source.branch $source.url $sourcePath
    }
    Assert-Exit 'Clone official Harmony source'
    # A plugin branch can move after this manifest was written. Fetch and use
    # the exact revision in a newly created cache, never reset an existing cache.
    & git -c "safe.directory=$sourcePath" -C $sourcePath fetch --depth 1 origin $source.revision
    Assert-Exit 'Fetch pinned revision'
    & git -c "safe.directory=$sourcePath" -C $sourcePath switch --detach $source.revision
    Assert-Exit 'Select pinned revision'
  }
  $actual = & git -c "safe.directory=$sourcePath" -C $sourcePath rev-parse HEAD
  Assert-Exit 'Read source revision'
  if ($actual.Trim() -ne $source.revision) {
    throw "Source revision mismatch at $sourcePath. Expected $($source.revision); preserve local changes and prepare the pinned revision before retrying."
  }
  if ($source.sparse) {
    & git -c "safe.directory=$sourcePath" -C $sourcePath sparse-checkout set $source.sparse
    Assert-Exit 'Fetch selected plugin sources'
  }
}
New-Item -ItemType Directory -Force $stage | Out-Null
foreach ($folder in @('lib', 'assets', 'test', 'ohos')) {
  $target = [IO.Path]::GetFullPath((Join-Path $stage $folder))
  $allowedRoot = [IO.Path]::GetFullPath($stage).TrimEnd('\') + '\'
  if (!$target.StartsWith($allowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace path outside the generated staging directory: $target"
  }
  if (Test-Path -LiteralPath $target) { Remove-Item -LiteralPath $target -Recurse -Force }
  # The Flutter OHOS pub-get post-hook requires HarmonyOS SDK whenever an
  # ohos directory is present. PrepareOnly checks Dart first, then adds native
  # sources. A real build always runs the native hook with the SDK installed.
  if ($folder -ne 'ohos' -or !$PrepareOnly) {
    Copy-Item -LiteralPath (Join-Path $projectRoot $folder) -Destination $target -Recurse
  }
}
foreach ($file in @('pubspec.yaml', 'analysis_options.yaml', 'NOTICE.md', 'LICENSE')) {
  Copy-Item -LiteralPath (Join-Path $projectRoot $file) -Destination $stage -Force
}
$webRoot = (Join-Path $projectRoot '.tools/ohos-webview/packages/webview_flutter').Replace('\', '/')
$preferencesRoot = (Join-Path $projectRoot '.tools/ohos-preferences/packages/shared_preferences').Replace('\', '/')
# The adapted WebView interface is 2.13.1. Override only the isolated Harmony
# project, including its test interface; keep Android's newer dependencies.
@"
dependency_overrides:
  webview_flutter:
    path: '$webRoot/webview_flutter'
  webview_flutter_platform_interface:
    path: '$webRoot/webview_flutter_platform_interface'
  shared_preferences:
    path: '$preferencesRoot/shared_preferences'
  shared_preferences_ohos:
    path: '$preferencesRoot/shared_preferences_ohos'
"@ | Set-Content -LiteralPath "$stage/pubspec_overrides.yaml" -Encoding utf8
if ($SigningProfile -and !$PrepareOnly) {
  # Keep the real profile, passwords and certificate paths outside the repository.
  Copy-Item -LiteralPath $SigningProfile -Destination "$stage/ohos/build-profile.json5" -Force
}
Push-Location $stage
try {
  & "$PSScriptRoot/flutter-ohos.ps1" pub get
  Assert-Exit 'Resolve Harmony plugins'
  if (!$SkipChecks) {
    & "$PSScriptRoot/flutter-ohos.ps1" analyze --no-pub
    Assert-Exit 'Analyze Harmony Dart application'
    & "$PSScriptRoot/flutter-ohos.ps1" test --no-pub
    Assert-Exit 'Test Harmony Dart application'
  }
  if ($PrepareOnly) {
    Copy-Item -LiteralPath (Join-Path $projectRoot 'ohos') -Destination "$stage/ohos" -Recurse
    Write-Host "Harmony project prepared: $stage/ohos"
    Write-Host 'Native compilation requires HarmonyOS API 26 SDK; device installation also requires a signing profile.'
    return
  }
  # New Command Line Tools do not install the Flutter-generated npm dependency.
  # Copy the pinned local plugin instead of creating unsupported exFAT symlinks.
  $flutterPlugin = Join-Path $projectRoot '.tools/flutter-ohos/packages/flutter_tools/hvigor'
  @{ dependencies = @{ 'flutter-hvigor-plugin' = ('file:' + $flutterPlugin.Replace('\', '/')) } } |
    ConvertTo-Json -Depth 4 | Set-Content -LiteralPath "$stage/ohos/package.json" -Encoding utf8
  $npm = Join-Path $env:DEVECO_NODE_HOME 'npm.cmd'
  & $npm install --prefix "$stage/ohos" --install-links --ignore-scripts --no-audit --no-fund
  Assert-Exit 'Install pinned Flutter Hvigor plugin'
  $hapArgs = @('build', 'hap', '--release', '--no-pub')
  if ($Unsigned) { $hapArgs += '--no-codesign' }
  & "$PSScriptRoot/flutter-ohos.ps1" @hapArgs
  Assert-Exit 'Build native Harmony HAP'
  $haps = @(Get-ChildItem -LiteralPath "$stage/ohos/entry/build" -Recurse -Filter '*.hap' -File)
  if ($haps.Count -eq 0) { throw 'Build returned without a HAP artifact.' }
  $output = Join-Path $projectRoot 'build/harmony'
  New-Item -ItemType Directory -Force $output | Out-Null
  foreach ($hap in $haps) { Copy-Item -LiteralPath $hap.FullName -Destination $output -Force }
  Write-Host "HAP artifacts: $output. Only signed artifacts may be installed on the authorized device."
} finally {
  Pop-Location
}



