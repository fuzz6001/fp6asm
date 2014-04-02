@echo off
set TARGET=fp6asm
as80 -x3 -l -h0 -i %TARGET%.asm
