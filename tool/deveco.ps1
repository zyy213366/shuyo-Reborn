param([Parameter(ValueFromRemainingArguments=$true)][string[]]$CliArgs)
$ErrorActionPreference = 'Stop'
. "$PSScriptRoot/harmony-env.ps1"
$env:DEVECO_CLI_CLT_PATH = 'D:\Huawei\command-line-tools'
$env:DEVECO_CLI_DATA_DIR = 'D:\Huawei\deveco-cli-data'
$env:DEVECO_CLI_DISABLE_TELEMETRY = '1'
$cli = 'D:\Huawei\deveco-cli\node_modules\.bin\devecocli.cmd'
if (!(Test-Path -LiteralPath $cli)) { throw 'DevEco CLI is not installed at D:\Huawei\deveco-cli.' }
& $cli @CliArgs
exit $LASTEXITCODE
