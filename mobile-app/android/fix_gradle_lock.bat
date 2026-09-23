@echo off
echo Stopping all Gradle daemons...
gradlew.bat --stop
echo Killing java.exe...
taskkill /F /IM java.exe /T 2>nul
echo Cleaning lock files...
if exist .gradle\noVersion rmdir /S /Q .gradle\noVersion
del /F /Q .gradle\8.14\checksums\checksums.lock 2>nul
del /F /Q .gradle\8.14\executionHistory\executionHistory.lock 2>nul
del /F /Q .gradle\8.14\fileHashes\fileHashes.lock 2>nul
del /F /Q .gradle\buildOutputCleanup\buildOutputCleanup.lock 2>nul
echo Done! Gradle locks cleared.
pause
