@echo off
call timecmd current_zig build %* && current_zig build %* run
