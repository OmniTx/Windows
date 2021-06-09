@echo off
color 3
fstuil set memory query usage
fstuil set memory query usage 2
fsutil behavior set disableLastAccess 0
fsutil behavior set disable8dot3 1 
cls
echo ram  and hdd is optimized!
pause