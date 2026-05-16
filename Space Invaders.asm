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
PrevEnemyAlive db EnemyCount dup (0) ; For erasing old frames 
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

;; ==========================================
;; SETUP & SYSTEM FUNCTIONS
;; ==========================================
SetTextMode proc near
    mov ax, 0003h       ; BIOS func 00h: Set video mode, mode 03h: 80x25 16-color text
    int 10h
    ret
SetTextMode endp

ResetGame proc near
    ; Reset all core variables to starting defaults
    mov ExitFlag, 0
    mov GameState, 0
    mov PlayerX, 40
    mov PlayerY, 23
    mov EnemyDir, 1
    mov EnemyMoveDelay, 4
    mov EnemyMoveCounter, 0
    mov EnemyAnim, 0
    mov Score, 0
    mov PrevScore, 0

    call ClearScreen
    call ClearBullets
    call InitEnemies    ; Generate the grid of enemies
    call DrawHUD        ; Draw static text (SCORE:, ESC:QUIT)
    call DrawEnemies
    call DrawPlayer
    call SyncPrevState  ; Sync logic so first frame doesn't erase incorrectly
    call InitLastTick   ; Reset the timer for frame syncing
    ret
ResetGame endp

InitLastTick proc near
    push ax
    push cx
    push dx
    mov ah, 00h         ; BIOS int 1Ah, func 00h: Get System Time
    int 1Ah
    mov LastTick, dx    ; Store lower word of tick count
    pop dx
    pop cx
    pop ax
    ret
InitLastTick endp

FrameSync proc near
    push ax
    push cx
    push dx
    mov cx, 5000        ; Failsafe timeout counter
FrameSync_Wait:
    mov ah, 00h         ; Get System Time
    int 1Ah
    cmp dx, LastTick    ; Compare current tick with last tick
    jne FrameSync_Got   ; If different, a tick has passed (18.2 ticks/sec)
    loop FrameSync_Wait ; Otherwise, keep waiting
FrameSync_Got:
    mov LastTick, dx    ; Update LastTick for the next frame
    pop dx
    pop cx
    pop ax
    ret
FrameSync endp              

;; ==========================================
;; INPUT HANDLING
;; ==========================================
PollInput proc near
    push ax
    push bx
    push dx

PollInput_Check:
    mov ah, 01h         ; BIOS int 16h, func 01h: Check keystroke status
    int 16h
    jz PollInput_Done   ; Zero flag set if no key pressed
    mov ah, 00h         ; BIOS int 16h, func 00h: Read keystroke (removes from buffer)
    int 16h

    cmp al, 1Bh         ; Check for ASCII 27 (ESC key)
    jne PollInput_NotEsc
    mov ExitFlag, 1     ; Trigger exit
    jmp PollInput_Done
PollInput_NotEsc:
    cmp al, 'r'         ; Check lowercase 'r'
    je PollInput_Restart
    cmp al, 'R'         ; Check uppercase 'R'
    je PollInput_Restart

    cmp al, ' '         ; Check Spacebar
    je PollInput_Fire

    cmp al, 'a'         ; Check A
    je PollInput_Left
    cmp al, 'A'
    je PollInput_Left
    cmp al, 'd'         ; Check D
    je PollInput_Right
    cmp al, 'D'
    je PollInput_Right

    cmp al, 0           ; Extended keycode (like arrows)? AL will be 0
    jne PollInput_Check
    cmp ah, 4Bh         ; Left Arrow scan code
    je PollInput_Left
    cmp ah, 4Dh         ; Right Arrow scan code
    je PollInput_Right
    jmp PollInput_Check ; Loop back to drain buffer if unknown key

PollInput_Left:
    mov al, PlayerX
    cmp al, 0           ; Don't let player go past left edge
    je PollInput_Check
    dec al              ; Move left
    mov PlayerX, al
    jmp PollInput_Check

PollInput_Right:
    mov al, PlayerX
    cmp al, 79          ; Don't let player go past right edge
    jae PollInput_Check
    inc al              ; Move right
    mov PlayerX, al
    jmp PollInput_Check

PollInput_Fire:
    call FireBullet     ; Spawn a bullet
    jmp PollInput_Check
                                             
PollInput_Restart:
    cmp GameState, 0    ; Only allow restart if not actively playing? Wait, logic says:
    je PollInput_Check  ; Ignore restart if already playing (GameState 0)
    call ResetGame
    jmp PollInput_Done

PollInput_Done:
    pop dx
    pop bx
    pop ax
    ret
PollInput endp   

;; ==========================================
;; BULLET LOGIC
;; ==========================================
ClearBullets proc near
    push ax
    push cx
    push di
    mov cx, BulletCount ; Loop through all bullets
    mov di, 0
ClearBullets_Loop:
    mov byte ptr [BulletActive+di], 0 ; Deactivate bullet
    mov byte ptr [BulletX+di], 0
    mov byte ptr [BulletY+di], 0
    inc di
    loop ClearBullets_Loop
    pop di
    pop cx
    pop ax
    ret
ClearBullets endp 

FireBullet proc near
    push ax
    push bx
    push cx
    push di

    mov di, 0
    mov cx, BulletCount
FireBullet_Find:
    cmp byte ptr [BulletActive+di], 0 ; Find the first inactive bullet slot
    je FireBullet_Use
    inc di
    loop FireBullet_Find
    jmp FireBullet_Done               ; If no slots, can't fire

FireBullet_Use:
    mov al, PlayerY
    cmp al, 2           ; Don't fire if too close to the top HUD
    jbe FireBullet_Done
    dec al              ; Start bullet 1 row above player
    mov byte ptr [BulletY+di], al
    mov al, PlayerX     ; Match bullet X to player X
    mov byte ptr [BulletX+di], al
    mov byte ptr [BulletActive+di], 1 ; Mark bullet as active

FireBullet_Done:
    pop di
    pop cx
    pop bx
    pop ax
    ret
FireBullet endp