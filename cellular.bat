@echo off
set library=zig-out\lib\haathi.wasm
set out_folder=cellular
set src_folder=web
set out_wasm=%out_folder%\haathi.wasm
set out_html=%out_folder%\index.html
set out_js=%out_folder%\haathi.js
set src_html=%src_folder%\index.html
set src_js=%src_folder%\haathi.js

if exist %library% (del %library%)
if exist %out_wasm% (del %out_wasm%)
if exist %out_html% (del %out_html%)
if exist %out_js% (del %out_js%)
call timecmd current_zig build -Dcellular=true %*
if exist %library% (move %library% %out_wasm%)
copy %src_html% %out_html%
copy %src_js% %out_js%
goto :done

:done
