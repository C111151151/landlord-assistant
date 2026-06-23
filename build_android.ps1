$ErrorActionPreference = 'Stop'

$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
$flutter = if ($flutterCommand) {
    $flutterCommand.Source
} elseif (Test-Path 'C:\Users\user\flutter\bin\flutter.bat') {
    'C:\Users\user\flutter\bin\flutter.bat'
} else {
    throw '找不到 Flutter SDK。請先安裝 Flutter，或將 flutter\bin 加入 PATH。'
}

& $flutter doctor

if (-not (Test-Path 'android')) {
    & $flutter create --project-name landlord_assistant --platforms=android .
}

& $flutter pub get
& $flutter analyze
& $flutter build apk --release

Write-Host ''
Write-Host 'APK 已完成：build\app\outputs\flutter-apk\app-release.apk' -ForegroundColor Green
