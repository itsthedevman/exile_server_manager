@echo off

SET ESM_SERVER_PATH=E:\ArmaServers
SET ESM_DEPLOYMENT_PATH=%ESM_SERVER_PATH%\Deployment\ESM

ruby.exe .\tools\esm_build_tool run %*
