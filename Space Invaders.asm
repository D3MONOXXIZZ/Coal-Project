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
                                                                         
                                                                         
                                                                         ;; ==========================================
;; CORE GAME LOOP
;; ==========================================
MainLoop:
    cmp ExitFlag, 0     ; Check if ESC was pressed
    jne Quit            ; If yes, exit to DOS

    cmp GameState, 0    ; Check if we are actively playing
    jne NotPlaying      ; If not (Win/Loss), jump to handle those screens

    ; -- Active Gameplay Loop --
    call FrameSync           ; Lock frame rate using BIOS timer
    call PollInput           ; Read keyboard input
    call ErasePrevEntities   ; Erase old sprites to prevent trails/flicker
    call UpdateBullets       ; Move bullets up
    call UpdateEnemies       ; Move enemies left/right/down
    call CheckCollisions     ; Check if bullets hit enemies
    call CheckWinLose        ; Check if player won or enemies reached the bottom
    
    cmp GameState, 0         ; Did state change after checks?
    jne MainLoop             ; If yes, restart loop to trigger win/lose screens
    
    call DrawScoreIfChanged  ; Update HUD
    call DrawEnemies         ; Render enemies at new positions
    call DrawBullets         ; Render bullets at new positions
    call DrawPlayer          ; Render player
    call SyncPrevState       ; Save current positions for next frame's erasure
    jmp MainLoop             ; Repeat

NotPlaying:
    cmp GameState, 1    ; Is state 1 (Win)?
    jne ShowLose        ; If not, it must be 2 (Game Over)
    call ShowWinScreen  ; Display Win Screen
    jmp MainLoop

ShowLose:
    call ShowGameOverScreen ; Display Game Over Screen
    jmp MainLoop

Quit:
    call SetTextMode    ; Reset video mode to clear screen
    mov ax, 4C00h       ; DOS interrupt to terminate program
    int 21h
