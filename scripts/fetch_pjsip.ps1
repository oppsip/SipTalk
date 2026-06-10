param(
    [string] $Repo = "https://github.com/pjsip/pjproject.git",
    [string] $Tag = "2.17",
    [string] $ExpectedCommit = "5a457451fa2712ba18e12b01738e8ff3af2b26fd",
    [string] $Destination = "third_party/pjproject"
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$destinationPath = Join-Path $root $Destination

if (!(Test-Path $destinationPath)) {
    New-Item -ItemType Directory -Force -Path (Split-Path $destinationPath) | Out-Null
    git clone --branch $Tag --depth 1 $Repo $destinationPath
} else {
    git -C $destinationPath fetch --no-tags --depth 1 origin "refs/tags/$Tag`:refs/tags/$Tag"
    git -C $destinationPath checkout $Tag
}

$actualCommit = (git -C $destinationPath rev-parse HEAD).Trim()
if ($actualCommit -ne $ExpectedCommit) {
    throw "PJSIP checkout mismatch. Expected $ExpectedCommit, got $actualCommit."
}

Write-Host "PJSIP $Tag ready at $destinationPath ($actualCommit)"
