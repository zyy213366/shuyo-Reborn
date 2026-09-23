param([switch]$CachedTool, [Parameter(ValueFromRemainingArguments=$true)][string[]]$FlutterArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$env:GIT_CONFIG_COUNT = '2'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = "$projectRoot/.tools/flutter"
$env:GIT_CONFIG_KEY_1 = 'safe.directory'
$env:GIT_CONFIG_VALUE_1 = $projectRoot
$env:PUB_CACHE = "$projectRoot/.tools/pub-cache"
$env:GRADLE_USER_HOME = "$projectRoot/.tools/gradle-cache"
$env:ANDROID_HOME = "$projectRoot/.tools/android-sdk"
$env:ANDROID_SDK_ROOT = $env:ANDROID_HOME
$localJdk = Get-ChildItem "$projectRoot/.tools/jdk21" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($localJdk) {
    $env:JAVA_HOME = $localJdk.FullName
}
if ($env:HTTPS_PROXY) {
    $buildProxy = [Uri]$env:HTTPS_PROXY
    $env:JAVA_TOOL_OPTIONS = "-Dhttp.proxyHost=$($buildProxy.Host) -Dhttp.proxyPort=$($buildProxy.Port) -Dhttps.proxyHost=$($buildProxy.Host) -Dhttps.proxyPort=$($buildProxy.Port)"
}
if ($CachedTool) {
    # Use the already bootstrapped SDK on exFAT, where the batch bootstrap's
    # Unblock-File (NTFS alternate stream) operation is unsupported.
    & "$projectRoot/.tools/flutter/bin/cache/dart-sdk/bin/dart.exe" "$projectRoot/.tools/flutter/bin/cache/flutter_tools.snapshot" @FlutterArgs
} else {
    & "$projectRoot/.tools/flutter/bin/flutter.bat" @FlutterArgs
}
exit $LASTEXITCODE
