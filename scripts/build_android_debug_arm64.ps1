$ErrorActionPreference = "Stop"

$flutter = "C:\work\flutter\flutter\bin\flutter.bat"

& $flutter --no-version-check build apk --debug --target-platform android-arm64
if ($LASTEXITCODE -ne 0) {
    exit $LASTEXITCODE
}
