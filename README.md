# Midway MCR Monoboard port for MiSTer

[Original readme](readme_orig.txt) (mostly irrelevant to MiSTer)

# Keyboard inputs :
```
   ESC         : Coin 1
   UP,DOWN,LEFT,RIGHT arrows : Player 1
   LCtrl  : Fire A
   LAlt   : Fire B
   Space  : Fire C   
   LShift : Fire D
   Z      : Fire E
   X      : Fire F 


   MAME/IPAC/JPAC Style Keyboard inputs:
     5           : Coin 1
     6           : Coin 2
     1           : Start 1 Player
     2           : Start 2 Player
     R,F,D,G     : Player 2
     A           : Fire2 A
     S           : Fire2 B 
     Q           : Fire2 C
     W           : Fire2 D
     I           : Fire2 E
     K           : Fire2 F
	
 Joystick support. 
```

# Games

### Sarge
Supported 2 control modes:
1. Up/Down - left side, X/B - right side, A - Fire 1, Y - Fire 2
2. Up/Down/Left/Right - movements, A - Fire 1, B - Fire 2

### Rampage
Up to 3 players.
Up/Down/Left/Right - movements, A - Punch, B - Jump

### Power Drive
Up to 3 players. Each playey has its own coin button to join.
A - Left Wheel, B - Right Wheel, C - Wheelie, D - 4WD/2WD

### Max RPM
Up to 2 players. Each player has its own start button to join.
Left/Right - Steering, Up/Down - Thottle +/-, A,B - Gear +/-

### Demolition Derby
Up to 4 players. Each player has its own start button to join.
Left/Right - Steering, A - Forward, B - Reverse

### Star Guards
Up to 3 players. Each playey has its own coin and start buttons to join.
Supported 2 control modes:
1. A - Fire right, B - Fire bottom, X - Fire up, Y - Fire left.
2. Any of A/B/X/Y is fire to the fly direction.

# ROMs
```
                                 *** Attention ***

ROMs are not included. In order to use this arcade, you need to provide the
correct ROMs.

To simplify the process .mra files are provided in the releases folder, that
specifies the required ROMs with checksums. The ROMs .zip filename refers to the
corresponding file of the M.A.M.E. project.

Please refer to https://github.com/MiSTer-devel/Main_MiSTer/wiki/Arcade-Roms for
information on how to setup and use the environment.

Quickreference for folders and file placement:

/_Arcade/<game name>.mra
/_Arcade/cores/<game rbf>.rbf
/_Arcade/mame/<mame rom>.zip
/_Arcade/hbmame/<hbmame rom>.zip

```

Launch game using the appropriate .MRA
