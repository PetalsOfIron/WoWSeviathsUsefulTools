@echo off
rem Keeps the addon's Data\Learned.lua up to date while you play (needs Python with the "lupa" package).
cd /d "%~dp0"
python watch_learned.py
pause
