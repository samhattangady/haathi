@echo off
call timecmd current_zig build %* -Dfont_builder=true && current_zig build %* -Dfont_builder=true run
