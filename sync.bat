@echo off
chcp 65001 > NUL
echo ====================================
echo   Dang kiem tra va sync len GitHub...
echo ====================================

git add .

set msg=%~1
if "%msg%"=="" set msg=Auto sync %date% %time%

git diff-index --quiet HEAD
if %errorlevel% equ 0 (
    echo [THONG BAO] Khong co thay doi nao moi de commit.
) else (
    git commit -m "%msg%"
)

echo.
echo Dang push len GitHub...
git push origin main

echo.
echo ====================================
echo   Hoan thanh sync!
echo ====================================
pause
