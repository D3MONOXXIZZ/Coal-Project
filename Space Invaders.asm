org 100h                ; Define origin for DOS .COM executable (starts at offset 0100h)

jmp Start               ; Jump over the data declarations to the main program entry point

;; ==========================================
;; GAME DATA & VARIABLES
;; ==========================================
GameState db 0          ; 0 = Playing, 1 = Win, 2 = Game Over
ExitFlag db 0           ; 1 = Player requested to quit (ESC)

PlayerX db 40           ; Player starting X coordinate (middle of 80-column screen)
PlayerY db 23           ; Player Y coordinate (near bottom of 25-row screen)

LastTick dw 0           ; Used for frame rate synchronization (BIOS timer ticks)

EnemyDir db 1           ; Enemy movement direction: 1 = Right, 0FFh (-1) = Left
EnemyMoveDelay dw 4     ; How many frames to wait before moving enemies (controls speed)
EnemyMoveCounter dw 0   ; Counter to track when to move enemies
EnemyAnim db 0          ; Enemy animation frame (0 or 1)

Score dw 0              ; Current player score
PrevScore dw 0          ; Used to check if the score needs to be redrawn

;; --- Bullet Variables ---
BulletCount equ 5       ; Max number of bullets on screen at once
BulletActive db BulletCount dup (0) ; Array: 1 if bullet is active, 0 if free
BulletX db BulletCount dup (0)      ; Array: Bullet X positions
BulletY db BulletCount dup (0)      ; Array: Bullet Y positions
PrevBulletActive db BulletCount dup (0) ; For erasing old frames (anti-flicker)
PrevBulletX db BulletCount dup (0)
PrevBulletY db BulletCount dup (0)                            

;; --- Enemy Variables ---
EnemyRows equ 5         ; 5 rows of enemies
EnemyCols equ 11        ; 11 columns of enemies
EnemyCount equ EnemyRows*EnemyCols ; Total 55 enemies
EnemyAlive db EnemyCount dup (0)   ; Array: 1 if alive, 0 if destroyed
EnemyX db EnemyCount dup (0)       ; Array: Enemy X positions
EnemyY db EnemyCount dup (0)       ; Array: Enemy Y positions
PrevEnemyAlive db EnemyCount dup (0) ; For erasing old frames (anti-flicker)
PrevEnemyX db EnemyCount dup (0)
PrevEnemyY db EnemyCount dup (0)

PrevPlayerX db 40       ; For erasing old player position    



;; --- Graphics & Strings ---
EnemySpriteW equ 3      ; Enemy width is 3 characters
EnemySprite0 db '/', 'X', '\' ; Animation frame 1
EnemySprite1 db '\', 'X', '/' ; Animation frame 2

HudScore db 'SCORE:',0
HudQuit db 'ESC:QUIT  R:RESTART',0

MsgWin db 'YOU WIN!',0
MsgGameOver db 'GAME OVER',0
MsgPrompt db 'R=RESTART  ESC=QUIT',0   

;; ==========================================
;; MAIN PROGRAM ENTRY
;; ==========================================
Start:
    ; Set up Data Segment (DS) and Extra Segment (ES) to match Code Segment (CS)
    push cs
    pop ds
    push cs
    pop es
    
    ; Set up the stack safely
    cli                 ; Clear interrupts while modifying stack
    push cs
    pop ss
    mov sp, 0FFFEh      ; Set stack pointer to top of segment
    sti                 ; Restore interrupts

    call SetTextMode    ; Initialize standard 80x25 text mode
    call ResetGame      ; Set up initial game state           
                            