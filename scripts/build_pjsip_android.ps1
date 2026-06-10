param(
    [string] $Abi = "arm64-v8a",
    [int] $ApiLevel = 28,
    [string] $AndroidNdkRoot = "",
    [string] $PjprojectDir = "third_party/pjproject",
    [string] $OpenSslDir = "",
    [string] $OboeDir = "",
    [switch] $RequireSsl,
    [switch] $RequireOboe
)

$ErrorActionPreference = "Stop"

function ConvertTo-WslPathInput {
    param([string] $Path)
    return $Path.Replace("\", "/")
}

$root = (Resolve-Path (Join-Path $PSScriptRoot "..")).ProviderPath
$pjprojectPath = (Resolve-Path (Join-Path $root $PjprojectDir)).ProviderPath

if ([string]::IsNullOrWhiteSpace($AndroidNdkRoot)) {
    if ($env:ANDROID_NDK_LINUX_ROOT) {
        $AndroidNdkRoot = $env:ANDROID_NDK_LINUX_ROOT
    }
}

if ([string]::IsNullOrWhiteSpace($AndroidNdkRoot)) {
    throw "Linux Android NDK not found. Install the Linux NDK in WSL and pass -AndroidNdkRoot /path/to/android-ndk-rXX, or set ANDROID_NDK_LINUX_ROOT."
}

if ($RequireSsl -and !(Test-Path $OpenSslDir)) {
    throw "OpenSSL is required for production TLS/SRTP. Pass -OpenSslDir."
}

if ($RequireOboe -and !(Test-Path $OboeDir)) {
    throw "Oboe is required by this build. Pass -OboeDir."
}

$wslPjproject = (wsl wslpath -a (ConvertTo-WslPathInput $pjprojectPath)).Trim()
$wslNdk = if ($AndroidNdkRoot.StartsWith("/")) {
    $AndroidNdkRoot
} else {
    (wsl wslpath -a (ConvertTo-WslPathInput $AndroidNdkRoot)).Trim()
}
$wslOpenSsl = if ($OpenSslDir) { (wsl wslpath -a (ConvertTo-WslPathInput $OpenSslDir)).Trim() } else { "" }
$wslOboe = if ($OboeDir) { (wsl wslpath -a (ConvertTo-WslPathInput $OboeDir)).Trim() } else { "" }

$script = Join-Path $root "scripts/build_pjsip_android_wsl.sh"
$wslScript = (wsl wslpath -a (ConvertTo-WslPathInput $script)).Trim()

wsl test -x "$wslNdk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++"
if ($LASTEXITCODE -ne 0) {
    throw "The NDK path must contain Linux host tools: $wslNdk/toolchains/llvm/prebuilt/linux-x86_64/bin/clang++. Windows NDK host tools cannot be used from WSL."
}

wsl bash "$wslScript" `
    "$wslPjproject" `
    "$wslNdk" `
    "$Abi" `
    "$ApiLevel" `
    "$wslOpenSsl" `
    "$wslOboe"

if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
