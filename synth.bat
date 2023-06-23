@echo off
set library=zig-out\lib\synthelligence.wasm
if exist %library% (del %library%)
call timecmd current_zig build -Dsynthelligence=true
if exist %library% (move %library% web)
goto :done

:done
