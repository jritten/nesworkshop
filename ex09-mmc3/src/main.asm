.include "constants.inc"
.include "header.inc"
.include "tracks.inc"
.include "ggsound.inc"

.segment "ZEROPAGE"
.exportzp sprite_x, sprite_y, sprite_v, sprite_h
.exportzp paddle_x, paddle_y, controller1, temp_storage
sprite_x: .res 1
sprite_y: .res 1
sprite_v: .res 1  ; sprite's vertical movement direction
                  ; 0 for up, 1 for down
sprite_h: .res 1  ; sprite's horizontal movement direction
                  ; 0 for left, 1 for right
paddle_x: .res 1
paddle_y: .res 1
controller1: .res 1
temp_storage: .res 1
scroll_x: .res 1
scroll_table: .res 1
nmis:      .res 1

.segment "BSS"

.segment "CODE"
.import update_sprite_position
.import draw_sprite
.import process_collisions
.import read_controller
.import update_paddle_position
.import draw_paddle
.import draw_backgrounds

.proc irq_handler
  PHA
  TXA
  PHA
  TYA
  PHA ; save those registers!

  LDA #$01
  STA $e000  ; acknowledge IRQ

  LDY #$3f

  LDA #$00  ; turn off screen
  STA PPUMASK

  LDX PPUSTATUS
  STY PPUADDR ; #$3f
  STA PPUADDR	; #$00
  LDA #$16
  STA PPUDATA ; set BG color to red
  STY PPUADDR ; #$3f
  LDA #$12
  STA PPUADDR
  LDA #$21
  STA PPUDATA ; set sprite color 1 to blue

  ; scrolling mid-frame is tricky
  ; this does not behave how you'd expect
  LDA scroll_x
  STA PPUSCROLL
  STA PPUSCROLL
  LDA scroll_table
  STA PPUCTRL

  LDA #%00011110  ; turn on screen
  STA PPUMASK

  PLA
  TAY
  PLA
  TAX
  PLA ; restore all registers
  RTI
.endproc

.proc reset_handler
  SEI            ; disable interrupts
  CLD           ; turn off non-existent decimal mode

  LDA #$40
  STA $4017      ; turn off APU frame IRQ


  LDX #$ff
  TXS            ; initialize the stack pointer

  LDX #$00
  STX PPUCTRL   ; disable NMI
  STX PPUMASK   ; turn off display
  STX $4010      ; turn off DMC IRQs

  BIT $2002      ; acknowledge stray vblank
  CLI            ; enable interrupts

vblankwait:     ; wait for PPU to fully boot up
  BIT PPUSTATUS
  BPL vblankwait

vblankwait2:
  BIT PPUSTATUS
  BPL vblankwait2

  LDA #SOUND_REGION_NTSC
  STA sound_param_byte_0
  LDA #<song_list
  STA sound_param_word_0
  LDA #>song_list
  STA sound_param_word_0+1
  LDA #<sfx_list
  STA sound_param_word_1
  LDA #>sfx_list
  STA sound_param_word_1+1
  LDA #<envelopes_list
  STA sound_param_word_2
  LDA #>envelopes_list
  STA sound_param_word_2+1
  LDA #0
  STA sound_param_word_3
  STA sound_param_word_3+1
  JSR sound_initialize

  JMP main
.endproc

.proc nmi_handler
  PHA
  TXA
  PHA
  TYA
  PHA ; save those registers!

  ; set up IRQ scanline counter
  LDA #$01
  STA $e000 ; acknowledge existing interrupts
  LDA #$99
  STA $c000
  STA $c001 ; $99 = 153 scanlines
  LDA #$01
  STA $e001 ; turn on the countdown

  LDX PPUSTATUS
  LDA #$3f
  STA PPUADDR
  LDA #$00
  STA PPUADDR
  LDA #$21
  STA PPUDATA ; reset BG color to blue

  LDX PPUSTATUS
  LDA #$3f
  STA PPUADDR
  LDA #$12
  STA PPUADDR
  LDA #$16
  STA PPUDATA ; reset sprite color 1 to red

  LDA #$00    ; draw SOMETHING first,
  STA OAMADDR ; in case we run out
  LDA #$02    ; of vblank time,
  STA OAMDMA  ; then update positions

  LDA scroll_x
  STA PPUSCROLL
  LDA #$00
  STA PPUSCROLL
  LDA scroll_table
  STA PPUCTRL

  LDA scroll_x
  CLC
  ADC #$01
  STA scroll_x
  CMP #$00
  BNE no_wrap
  LDA scroll_table
  CMP #%10010000
  BEQ first_nametable
  LDA #%10010000
  STA scroll_table
  JMP no_wrap
first_nametable:
  LDA #%10010001
  STA scroll_table
no_wrap:

  INC nmis

  PLA
  TAY
  PLA
  TAX
  PLA ; restore all registers
  RTI
.endproc

.proc main
  LDA #$70        ; set up initial sprite values
  STA sprite_x    ; these are stored in zeropage
  LDA #$30
  STA sprite_y
  LDA #$01
  STA sprite_v
  STA sprite_h

  LDA #$70
  STA paddle_x
  LDA #$d8
  STA paddle_y

  LDA #$00
  STA scroll_x
  STA nmis
  LDA #%10010000
  STA scroll_table

  LDX PPUSTATUS   ; reset PPUADDR latch
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR     ; set PPU to write to $3f00 (palette ram)

copy_palettes:
  LDA palettes,x  ; use indexed addressing into palette storage
  STA PPUDATA
  INX
  CPX #$20          ; have we copied 32 values?
  BNE copy_palettes ; if no, repeat

vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  JSR draw_backgrounds

vblankwait2:
  BIT PPUSTATUS
  BPL vblankwait2

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

  LDA #song_index_Main
  STA sound_param_byte_0
  JSR play_song

forever:
  JSR process_collisions
  JSR update_sprite_position
  JSR draw_sprite
  JSR read_controller
  JSR update_paddle_position
  JSR draw_paddle

  soundengine_update

  LDA nmis
wait_for_vblank:
  CMP nmis
  BEQ wait_for_vblank

  JMP forever     ; do nothing, forever
.endproc

.segment "RODATA"
palettes:
.byte $21, $00, $16, $30
.byte $21, $01, $0f, $31
.byte $21, $06, $16, $26
.byte $21, $09, $19, $29

.byte $21, $00, $16, $30
.byte $21, $01, $0f, $31
.byte $21, $06, $16, $26
.byte $21, $09, $19, $29

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "CHR"
.incbin "font.chr"
