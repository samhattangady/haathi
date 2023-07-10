@echo off
set library=zig-out\lib\haathi.wasm
set wasm=hiveminder\haathi.wasm
if exist %library% (del %library%)
if exist %wasm% (del %wasm%)
call timecmd current_zig build -Dhiveminder=true %*
if exist %library% (move %library% %wasm%)
goto :done

:done
