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