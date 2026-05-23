@echo off
SET /P choice="Enter target browser (chrome/firefox): "

IF /I "%choice%"=="chrome" (
    del manifest.json >nul 2>&1
    copy /Y manifest.chrome.json manifest.json
    echo Switched to Chrome Manifest.
) ELSE IF /I "%choice%"=="firefox" (
    del manifest.json >nul 2>&1
    copy /Y manifest.firefox.json manifest.json
    echo Switched to Firefox Manifest.
) ELSE (
    echo Invalid choice.
)
pause