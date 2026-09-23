param([string]$DevEcoHome = 'D:\Huawei\command-line-tools')
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$resolvedDevEco = (Resolve-Path -LiteralPath $DevEcoHome).Path
$isCommandLine = Test-Path -LiteralPath "$resolvedDevEco/tool/node/node.exe"
$nodeDirectory = if ($isCommandLine) { "$resolvedDevEco/tool/node" } else { "$resolvedDevEco/tools/node" }
if (!(Test-Path -LiteralPath "$resolvedDevEco/sdk")) { throw "HarmonyOS SDK not found at $resolvedDevEco/sdk" }
$env:DEVECO_SDK_HOME = "$resolvedDevEco/sdk"
$env:DEVECO_NODE_HOME = $nodeDirectory
$env:NODE_HOME = $nodeDirectory
$env:JAVA_HOME = "$resolvedDevEco/jbr"
if (!(Test-Path -LiteralPath "$env:JAVA_HOME/bin/java.exe")) {
  $projectJdk = Get-ChildItem "$projectRoot/.tools/jdk21" -Directory | Select-Object -First 1
  if (!$projectJdk) { throw 'JDK 21 is required. Install a JDK or use DevEco Studio with its bundled jbr.' }
  $env:JAVA_HOME = $projectJdk.FullName
}
$env:HVIGOR_USER_HOME = 'D:\Huawei\cache\hvigor'
$env:npm_config_cache = 'D:\Huawei\cache\npm'
$env:Path = "$nodeDirectory;$resolvedDevEco/bin;$resolvedDevEco/ohpm/bin;$resolvedDevEco/hvigor/bin;$resolvedDevEco/tools/ohpm/bin;$resolvedDevEco/tools/hvigor/bin;$env:JAVA_HOME/bin;$resolvedDevEco/sdk/default/openharmony/toolchains;$env:Path"
# Prefer IPv4 for the vendor CDN on networks with unreachable IPv6 routes.
if ($env:NODE_OPTIONS -notmatch 'dns-result-order') {
  $env:NODE_OPTIONS = "$env:NODE_OPTIONS --dns-result-order=ipv4first".Trim()
}
