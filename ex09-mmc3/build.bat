@echo off
c:\cc65\bin\ca65 src\main.asm
c:\cc65\bin\ca65 src\sprite.asm
c:\cc65\bin\ca65 src\collisions.asm
c:\cc65\bin\ca65 src\input.asm
c:\cc65\bin\ca65 src\paddle.asm
c:\cc65\bin\ca65 src\background.asm
c:\cc65\bin\ca65 src\ggsound.asm
c:\cc65\bin\ca65 src\tracks.asm
c:\cc65\bin\ld65 src\main.o src\sprite.o src\collisions.o src\input.o src\paddle.o src\background.o src\ggsound.o src\tracks.o -C nes.cfg -o ex09-mmc3.nes
