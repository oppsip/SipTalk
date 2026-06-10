$ErrorActionPreference = "Stop"

$script = Join-Path $PSScriptRoot "install_linux_ndk_wsl.sh"
$scriptPath = (Resolve-Path $script).ProviderPath.Replace("\", "/")
$wslScript = (wsl wslpath -a $scriptPath).Trim()

wsl bash "$wslScript"
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
