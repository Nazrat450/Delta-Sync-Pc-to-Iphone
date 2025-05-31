@echo off
:: Launch sync script
schtasks /run /tn "DeltaSyncTray"
timeout /t 2 /nobreak >nul

:: Launch emulator and wait for it to exit before ending batch
start "" /WAIT "E:\Emulation\Gameboy\visualboyadvance-m.exe" "E:\Emulation\Gameboy\PokemonSeaGlass.gba"