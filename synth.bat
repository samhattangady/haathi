@echo off
set library=zig-out\lib\synthelligence.wasm
set wasm=web\synthelligence.wasm
if exist %library% (del %library%)
if exist %wasm% (del %wasm%)
call timecmd current_zig build -Dsynthelligence=true %*
if exist %library% (move %library% %wasm%)
goto :done

:done
