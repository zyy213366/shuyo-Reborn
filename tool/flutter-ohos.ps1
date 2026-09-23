param([Parameter(ValueFromRemainingArguments=$true)][string[]]$FlutterArgs)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$env:GIT_CONFIG_COUNT = '2'
$env:GIT_CONFIG_KEY_0 = 'safe.directory'
$env:GIT_CONFIG_VALUE_0 = "$projectRoot/.tools/flutter-ohos"
$env:GIT_CONFIG_KEY_1 = 'safe.directory'
$env:GIT_CONFIG_VALUE_1 = $projectRoot
$env:PUB_CACHE = "$projectRoot/.tools/pub-cache-ohos"
& "$projectRoot/.tools/flutter-ohos/bin/flutter.bat" @FlutterArgs
exit $LASTEXITCODE
