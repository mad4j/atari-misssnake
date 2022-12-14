/*
 * MissSnake!
 * an Atari 2600 remake of the famous Snake game
 * 
 * Daniele Olmisani <daniele.olmisani@gmail.com>
 * Luca Olmisani <olmisani.luca@gmail.com>
 * Maria Segnalini <maria.segnalini@bgmail.com>
 *
 */

    temp1=temp1

    ; use NTSC system (262 scanlines, 60Hz) 
    set tv ntsc

    ; use 32KB ROM (8 banks) with Super Chip RAM
    set romsize 32kSC

    ; smart bank switching
    set smartbranching on
    
    ; remove horizontal scan lines
    set kernel_options no_blank_lines

    ; use inlined random for fast bank switching
    set optimization inlinerand

    ; rationale:
    ; random numbers can slow down bank-switched games.
    ; This will speed things up.

    ; use 24 rows playfield (nearly square pixels)
    const pfres = 24
    const pfrowheight = 4

    ; use ALARMCLOCK font for score digits
    const fontstyle = 4

    ; use meangful names for directions values
    const NORTH = %00000000
    const EAST  = %01010101
    const SOUTH = %10101010
    const WEST  = %11111111

    ; rationale:
    ; each byte will store the same direction
    ; reapeted 4 times

    ; NTSC color palette
    const FOREG_NTSC_COLOR = $CA
    const BACKG_NTSC_COLOR = $00
    const SCORE_NTSC_COLOR = $2C
    const FOOD_NTSC_COLOR  = $4A

    const GAMEOVER_NTSC_FOREG = $4E
    const GAMEOVER_NTSC_BACKG = $00
    
    const TITLE1_NTSC_COLOR = $DA
    const TITLE2_NTSC_COLOR = $96

    ; PAL60 color palette
    const FOREG_PAL_COLOR = $5A
    const BACKG_PAL_COLOR = $00
    const SCORE_PAL_COLOR = $2C
    const FOOD_PAL_COLOR  = $6A

    const GAMEOVER_PAL_FOREG = $6E
    const GAMEOVER_PAL_BACKG = $00

    const TITLE1_PAL_COLOR = $3A
    const TITLE2_PAL_COLOR = $96

    ; max snake length
    const SNAKE_MAX_LEN = 192

    ; all-purpose bits for various jobs
    dim bits = z
    dim bits0_DebounceReset = z
    dim bits1_DebounceFireButton = z
    dim bits2_GameOverFlag = z
    dim bits3_TitleSoundFlag = z

    ; counting stuff for screen delay logic
    dim frames = s
    dim seconds = c

    ; how fast miss-snake is running?
    dim speed = s
 	dim counter = c

    ; position of food
    dim foodX = a
    dim foodY = b

    ; position of miss-snake head
    dim headX = x
    dim headY = y

    ; direction of miss-snake head
    dim headDir = d

    ; grown of miss-snake
    dim grown = g

    ; length of miss-snake
    dim length = l

    ; position of miss-snake tail
    dim tailX = i
    dim tailY = j

    ; start/end index of miss-snake body directions
    dim tailEnd = k
    dim tailStart = h

    ; array of miss-snake body directions
    dim directions = var0

    ; rationale:
    ; with SuperChip RAM the playfield is moved on the extra
    ; space leaving default allocated RAM (var0 - var47) free
    ; for application purposes

    ; activate game sounds
    dim eatSound = f
    dim crashSound = f

    ; activate screen shake effect
    dim shakescreen = m
    dim shaking_effect = n

    ; needed to change colors on title screen
    dim bmp_48x1_2_color = u
    dim bmp_48x1_3_color = t
    dim bmp_48x1_2_index = o

    ; references to score values (three chunks of two digits)
    dim score1 = score
    dim score2 = score+1
    dim score3 = score+2

    ; high score value (three chunks of two digits)
    dim highScore1 = p
    dim highScore2 = q
    dim highScore3 = r

    ; reset high score value
    highScore1 = 0
    highScore2 = 0
    highScore3 = 0

/*
 * Game initializaion
 * clear game internal state and in/out registers
 */

_GameInit

    ; mute volume of both sound channels
    AUDV0 = 0
    AUDV1 = 0

    ; skip title screen if game has been played and player
    ; presses fire button or reset switch at the end of the game
    if bits2_GameOverFlag{2} then goto _MainLoopSetup bank2

_TitleScreenSetup

    ; display high scores in title screen
    score1 = highScore1
    score2 = highScore2
    score3 = highScore3

    if switchbw then scorecolor = SCORE_NTSC_COLOR else scorecolor = SCORE_PAL_COLOR


    ; debounce the reset switch
    bits0_DebounceReset{0} = 1

    ; rationale:
    ; the reset switch becomes inactive if it hasn't been
    ; released after entering a different segment of the
    ; program. 
    ; It does double duty sometimes by debouncing
    ; the fire button too.

    ; start frame counting
    frames = 0

_TitleScreenLoop

    ; check title colors
    if switchbw then bmp_48x1_2_color = TITLE1_NTSC_COLOR else bmp_48x1_2_color = TITLE1_PAL_COLOR
    if switchbw then bmp_48x1_3_color = TITLE2_NTSC_COLOR else bmp_48x1_3_color = TITLE2_PAL_COLOR

    ; swap aninamtion frames
    if frames<210 then bmp_48x1_2_index=0 else bmp_48x1_2_index=117

    gosub titledrawscreen bank4

    ; increment frames counter
    frames=frames+1
    if frames>240 then frames=0

    ; no button pressed then clear debounce bit
    if !switchreset && !joy0fire then bits0_DebounceReset{0} = 0 : goto _SkipTitleResetFire

    ; debounce bit active, then remain on the title screen
    if bits0_DebounceReset{0} then goto _SkipTitleResetFire

    ; button pressed and debounce bit deactivated, then start the game
    goto _MainLoopSetup bank2

    ; rationale:
    ; bank switching and long pressure of console buttons may cause
    ; bouncing effect that results in jumping intermediate screens

_SkipTitleResetFire

    ; return at the beginning of the loop
    goto _TitleScreenLoop


/*
 * START OF BANK 2
 * ---------------
 */

    bank 2

    temp1 = temp1

_MainLoopSetup

    ; reset bouncing bits
    bits0_DebounceReset{0} = 1
    bits1_DebounceFireButton{1} = 1

    ; reset game over flag
    bits2_GameOverFlag{2} = 0

    ; deactivate sounds
    eatSound=0
    crashSound=0

    ; dummy food position
    foodX=0
    foodY=0

    ; miss-snake head starting position
    headX = 5
    headY = 5

    ; miss-snake head starting direction
    headDir = EAST

    ; miss-snake initial length
    length=1

    ; miss-snake initial grown
    grown=2

    ; initial indexs of body direcrtions
    tailStart = 0
    tailEnd = 0

    ; miss-snake tail is near the head
    tailX = headX-1
    tailY = headY

    ; store initial direction
    directions[tailStart] = headDir

    ; reset player score
    score = 0

    ; initial ms-snake speed (one step every 'speed' frames)
    speed = 0
    counter = 0

    ; clear the play field
    pfclear

    ; draw game field border
    pfhline 0 0 31 on
    pfhline 0 22 31 on
    pfvline 0 1 21 on
    pfvline 31 1 21 on

    ; food sprite
    player0:
    %01100000
    %11110000
    %11110000
    %01100000
    %00000000
    %00000000
    %00000000
    %00000000
end

_MainLoop

    if switchbw then COLUP0 = FOOD_NTSC_COLOR else COLUP0 = FOOD_PAL_COLOR

    bits1_DebounceFireButton{1} = 0

    drawscreen

    ; if the reset switch is not pressed, turn off debounce and skip this section
    if !switchreset then bits0_DebounceReset{0} = 0 : goto _SkipMainReset

    ; if the reset switch hasn`t been released, skip this section
    if bits0_DebounceReset{0} then goto _SkipMainReset

    ; clear the game over bit so the title screen will appear
    bits2_GameOverFlag{2} = 0

    ; reset pressed appropriately: restart the program
    goto _GameInit bank1


_SkipMainReset

    ; check to see if the game is over
    if bits2_GameOverFlag{2} then goto _GameOverSetup bank3

    if switchbw then COLUPF = FOREG_NTSC_COLOR else COLUPF = FOREG_PAL_COLOR
    if switchbw then COLUBK = BACKG_NTSC_COLOR else COLUBK = BACKG_PAL_COLOR

    ; advance head position
    pfpixel headX headY on

    ; if no growing then advance tail position
    if grown=0 then pfpixel tailX tailY off

    ; if no food on game field then compute new food position
    if foodX=0 && foodY=0 then gosub _UpdateFood bank3

    if eatSound=0 then goto _SkipSound1
    AUDV0 = 8 : AUDC0 = 4 : AUDF0 = 19
    eatSound = eatSound-1
_SkipSound1
    if !eatSound then AUDV0 = 0

    counter = counter+1
    if counter > speed then gosub _UpdateSnake bank3
    if headX=foodX && headY=foodY then gosub _UpdateEat bank3    

    ; verify change of directions
    if joy0up && headDir<>SOUTH then headDir=NORTH
    if joy0down && headDir<>NORTH then headDir=SOUTH
    if joy0left && headDir<>EAST then headDir=WEST
    if joy0right && headDir<>WEST then headDir=EAST    

    ; rationale: it is not possible to make turns of 180 degree
    ; in order to avoid auto-biting

    goto _MainLoop


/*
 * START OF BANK 3
 * ---------------
 */
 
    bank 3

    temp1 = temp1

    data MASKS
    %00000011, %00001100, %00110000, %11000000
end    

_UpdateSnake
    counter=0
    
    if grown>0 then grown=grown-1 : length=length+1 else gosub _UpdateTail

    ; miss-snake speed depends on its length
    speed = (SNAKE_MAX_LEN-length)/16

    gosub _UpdateHead

    ; rationale:
    ; update the tail before the head in order to save one memory location
    ; in this way, when SNAKE_MAX_LEN is reached, the location freed by tail
    ; will be occupied by the head

    return

_UpdateHead
    if headDir = NORTH then headY = headY-1
    if headDir = EAST then headX = headX+1
    if headDir = SOUTH then headY = headY+1
    if headDir = WEST then headX = headX-1

    tailStart=tailStart+1
    if tailStart=SNAKE_MAX_LEN then tailStart=0

    temp1 = tailStart / 4
    temp2 = tailStart & %00000011

    temp3 = headDir & MASKS[temp2]

    directions[temp1] = directions[temp1] & (MASKS[temp2] ^ %11111111)
    directions[temp1] = directions[temp1] | temp3

    if headX=foodX && headY=foodY then goto _SkipCollisionCheck
    if pfread(headX, headY) then bits2_GameOverFlag{2} = 1

_SkipCollisionCheck
    return

_UpdateTail

    temp1 = tailEnd / 4
    temp2 = tailEnd & %00000011

    temp3 = directions[temp1] & MASKS[temp2]

    if temp3 = NORTH & MASKS[temp2] then tailY = tailY-1
    if temp3 = EAST & MASKS[temp2] then tailX = tailX+1
    if temp3 = SOUTH & MASKS[temp2] then tailY = tailY+1
    if temp3 = WEST & MASKS[temp2] then tailX = tailX-1

    tailEnd=tailEnd+1
    if tailEnd=SNAKE_MAX_LEN then tailEnd=0

    return

_UpdateFood

    ; new food position
    foodX = (rand&31)
    foodY = (rand&23)
    
    ; last playfield line is not visible
    if foodY = 23 then goto _UpdateFood

    ; check if (foodX, foodY) is free
    if pfread(foodX,foodY) then goto _UpdateFood

    ; converts playfiled in player coordinates
    player0x = foodX*4+17
    player0y = foodY*4+4

    return

_UpdateEat
    score=score+1

    ; no more grown if SNAKE_MAX_LEN will be reached
    if length+grown = SNAKE_MAX_LEN then goto _SkipGrownIncrement
    
    ; increment ms-snake length
    grown=grown+1

    ; rationale:
    ; new increment will be added to any previous increment
    ; not yet completed 

_SkipGrownIncrement

    eatSound = 6

    foodX=0
    foodY=0

    return

/*
 * Game Over
 * manage Game Over screen
 */
_GameOverSetup

    ; remove player1 from the playfield
    player0x = 0 : player0y = 0

    ; debounce the reset switch.
    bits0_DebounceReset{0} = 1
    
    ; activate crash sound
    crashSound=8

    ; activate shake effect
    shaking_effect = 25

    ; verify if a new high score is achived
    if score1 > highScore1 then goto __New_High_Score
    if score1 < highScore1 then goto __Skip_High_Score

    if score2 > highScore2 then goto __New_High_Score
    if score2 < highScore2 then goto __Skip_High_Score

    if score3 > highScore3 then goto __New_High_Score
    if score3 < highScore3 then goto __Skip_High_Score

    goto __Skip_High_Score

__New_High_Score

    ; activate title screen sound
    bits3_TitleSoundFlag{3} = 1

    highScore1 = score1
    highScore2 = score2
    highScore3 = score3

    playfield:
    ................................
    ................................
    ................................
    .........X..X.XXX.X...X.........
    .........XX.X.X...X...X.........
    .........X.XX.XX..X.X.X.........
    .........X..X.X...X.X.X.........
    .........X..X.XXX..X.X..........
    ................................
    .........X.X.X.XXXX.X.X.........
    .........X.X.X.X....X.X.........
    .........XXX.X.X.XX.XXX.........
    .........X.X.X.X..X.X.X.........
    .........X.X.X.XXXX.X.X.........
    ................................
    ......XXX.XXX.XXX.XXXX.XXX......
    ......X...X...X.X.X..X.X........
    ......XXX.X...X.X.XXX..XX.......
    ........X.X...X.X.X..X.X........
    ......XXX.XXX.XXX.X..X.XXX......
    ................................
    ................................
    ................................
    ................................
end


   goto _GameOverLoop bank3

__Skip_High_Score

    playfield:
    ................................
    ................................
    ................................
    .XXXXXX.XXXXXX.XXXXXXXXXX.XXXXX.
    .XX.....XX..XX.XX..XX..XX.XX....
    .XX.XXX.XXXXXX.XX..XX..XX.XXXX..
    .XX..XX.XX..XX.XX..XX..XX.XX....
    .XXXXXX.XX..XX.XX..XX..XX.XXXXX.
    ................................
    ...XXXXXX.XX..XX.XXXXX.XXXXXX...
    ...XX..XX.XX..XX.XX....XX..XX...
    ...XX..XX.XX..XX.XXXX..XXXXX....
    ...XX..XX.XX..XX.XX....XX..XX...
    ...XXXXXX...XX...XXXXX.XX..XX...
    ................................
    ................................
    ................................
    ................................
    ................................
    ................................
    ................................
    ................................
    ................................
    ................................
end

_GameOverLoop

    ; set right color values
    if switchbw then COLUPF = GAMEOVER_NTSC_FOREG else COLUPF = GAMEOVER_PAL_FOREG
    if switchbw then COLUBK = GAMEOVER_NTSC_BACKG else COLUBK = GAMEOVER_PAL_BACKG

    ; rationale
    ; pluggable mini-kernels should modify pre-configured colors

    ; manage crash sound
    if crashSound=0 then goto _SkipSound2

    AUDV0 = 8 : AUDC0 = 3 : AUDF0 = 19
    crashSound = crashSound-1

_SkipSound2
    if !crashSound then AUDV0 = 0

    frames = frames + 1

    ; manage shaking effect
    if shaking_effect = 0 then goto _SkipShake
    shakescreen = shakescreen+32
    shaking_effect = shaking_effect-1

_SkipShake

   ; frames counter resets every second (60 frames)
   if frames < 60 then goto _SkipCounter

   ; frames counter reset
   frames = 0

   ; increment seconds counters on frame counter reset
   seconds = seconds + 1

   ; remain on gameover screen for 5 seconds
   if seconds = 5 then bits2_GameOverFlag{2} = 0 : goto _GameInit bank1


_SkipCounter

    drawscreen

    if !switchreset && !joy0fire then bits0_DebounceReset{0} = 0 : goto _SkipGameOverReset

    if bits0_DebounceReset{0} then goto _SkipGameOverReset

    goto _GameInit bank1


_SkipGameOverReset

    goto _GameOverLoop

/*
 * START OF BANK 4
 * ---------------
 */

    bank 4

    temp1 = temp1

    asm
    include "titlescreen/asm/titlescreen.asm"
end

    bank 5

    bank 6

    bank 7

    bank 8
