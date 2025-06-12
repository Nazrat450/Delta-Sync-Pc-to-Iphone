@echo off

:: Launch DeltaSyncTray via scheduled task
schtasks /run /tn "DeltaSyncTray"

:: Wait 2 seconds for DeltaSyncTray to initialize
timeout /t 2 /nobreak >nul

:: Launch the emulator and ROM with high priority and wait for it to close
start "" /high /wait "E:\Emulation\Gameboy\visualboyadvance-m.exe" "E:\Emulation\Gameboy\PokemonSeaGlass.gba"