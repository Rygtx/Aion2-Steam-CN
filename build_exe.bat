@echo off
chcp 65001 >nul
echo 正在编译 AION 2 国际服简繁一键汉化工具...
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /target:winexe /win32manifest:app.manifest /out:永恒之塔2一键汉化.exe Aion2CNTool.cs
if %errorlevel% equ 0 (
    echo ========================================
    echo 编译成功：永恒之塔2一键汉化.exe
    echo ========================================
) else (
    echo 编译失败，请检查环境！
)
pause
