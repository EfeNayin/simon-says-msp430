
;*******************************************************************************
 .cdecls C,LIST,  "msp430.h"

;-------------------------------------------------------------------------------
            .def    RESET                   ; Export program entry-point to
                                            ; make it known to linker.
;------------------------------------------------------------------------------
            .text                           ; Program Start
;------------------------------------------------------------------------------
RESET       mov.w   #0280h,SP               ; Initialize stackpointer
StopWDT     mov.w   #WDTPW+WDTHOLD,&WDTCTL  ; Stop WDT

SETUP:
    bis.b #BUTALL, &P1REN ; enable buttons
    bis.b #BUTALL, &P1OUT ; button presses h -> l 
    bis.b #LEDALL, &P2DIR   ; set leds as output
    bic.b #LEDALL, &P2OUT   ; Ensure all are OFF initially

    bis.w #GIE, SR ; enable interrupts
    bis.b #BUT0|BUT1|BUT2|BUT3, &P1IES ; buttons interrupts from H to L
    bis.b #BUT0|BUT1|BUT2|BUT3, &P1IE  ; enable button interrupts

;------------------------------------------------------------------------------
;           MAIN LOOP
;------------------------------------------------------------------------------
wait:
    mov.w #ORDER, r10
    inc r12 ; seed 
    bit.b #00001000b,&P1IN
    
    jnz wait

MAINLOOP:
    call #GEN_RANDOM ; create random array
    call #SHOW_LEVEL 
    mov.b #ON, &STATE ; set game state
PLAYER_TURN:
    cmp #ON, &STATE
    jz PLAYER_TURN ; player still playing
    
    cmp #WIN, &STATE 
    jz WIN ; player passed the level

    cmp #LOSE, &STATE 
    jz LOSE ; player passed the level
 
EGG:
    push r12 ; corrupt stack >w<
    ret


LOSE:
    ; do smth
    bic.w #GIE, SR ; disable interrupts
    jmp LOSE

WIN:
    inc.w &LEVEL ; increnent level
    jmp MAINLOOP ; continue 

SHOW_LEVEL:
    mov.w #ORDER, r11
    mov.w &LEVEL, r5
    inc.w r5 ; do at least once
.SHOW_LEVEL.loop:
    mov.w @r11+,r13 ; get current and increment pointer
    ; show the generated lights
    bis.b BITLEDTABLE(r13), &P2OUT
    call #DELAY
    bic.b #LEDALL, &P2OUT  ; turn off

    dec r5
    jn .SHOW_LEVEL.loop ; return if -1 (flowed)
    ret

GEN_RANDOM:
; --- (Seed in R12) ---
    mov.w &LEVEL,r11
; xorshift798
    mov.w #7, r5
    call #SHR
    mov.w #9, r5
    call #SHL
    mov.w #8, r5
    call #SHR    
; save the value 
    mov r12, r13 ; mask bits
    and.w #0x0003,r13
    mov.w r13,ORDER(r11)
    ret                         ; Return to caller
    
SHR: 
    rra.w r12
    dec.w r5
    jnz SHR
    ret 
SHL: 
    rla.w r12
    dec.w r5
    jnz SHL
    ret
DELAY: 
    push r5
    xor.w r5,r5
.DELAY_LOOP:
    nop
    nop
    nop
    dec r5
    jnz .DELAY_LOOP
    pop r5
    ret

; BUTTON ISR
p1_ISR: 
    

    bic.b #00001000b, &P1IFG ; clear IF for next interrupt
    reti
;------------------------------------------------------------------------------
;           data
;------------------------------------------------------------------------------
.data
STATE:
    .byte 0
LEVEL:
    .word 0
ORDER:
    .skip 32 ,0xff

; DEFINE LED CONSTANTS 
LED0    .equ    0x0001
LED1    .equ    0x0002
LED2    .equ    0x0004
LED3    .equ    0x0008
LEDALL  .equ    0x000f
; DEFINE BUTTON CONSTANTS
BUT0    .equ    0x0001
BUT1    .equ    0x0002
BUT2    .equ    0x0008
BUT3    .equ    0x0010
BUTONB  .equ    0x0004
BUTALL  .equ    0x001f
; DEFINE GAME STATES
ON      .equ    0
WIN     .equ    1
LOSE    .equ    2
EGG     .equ    3

BITLEDTABLE: .word 0x0102,0x0408 ; convert table for led: int to pin
BITBUTTABLE: .word 0x0102,0x0810 ; convert table for buttons: int to pin

;-------------------------------------------------------------------------------
; Stack Pointer definition
            ;-------------------------------------------------------------------------------
            .global __STACK_END
            .sect .stack


;------------------------------------------------------------------------------
;           Interrupt Vectors
;------------------------------------------------------------------------------
            .sect ".int02" ; Port 1 interrupt vector
            .short p1_ISR
            .sect   ".reset"                ; MSP430 RESET Vector
            .short  RESET                   ;        
            .end

