@echo off
color 2
fstuil set memory query usage
fstuil set memory query usage 2
fsutil behavior set disableLastAccess 1
fsutil behavior set disable8dot3 1 

cls
echo ram  and hdd is optimized!
pause