# Pattern Trainer Plugin for Pac-Man #

Do you want to get good at the original arcade Pac-Man? The solution is here! 

The Pac-Man Trainer will help you to improve your Pac-Man skills.  It's an interactive
aid to learning the common patterns for completing boards - or helping you complete the
entire game.  
You follow an on-screen path through each board.  
To master the patterns, you must stay on track, with frame perfect accuracy, anticipating 
the turns and steering early.

Here's a video review by GenXGrownUp: https://www.youtube.com/watch?v=YXgzogIQPOc

There are different pattern sets to help you get to achieve your goals.  You may want
to reach the 9th Key at level 21 from which point all of the remaining boards play the
same.  You may want to complete the game by reaching the infamous split-screen at 
level 256.  You may want to achieve a "Perfect Pac-Man" score of 3,333,360 by eating 
every pellet, every bonus and every ghost possible.  You may just want a new PB!

![Pac-Man Trainer Plugin Demo](demo.gif)

The HUD shows information which can help during gameplay.  
On the left of the screen you will see the current level (e.g. "L. 001"),  the current
pattern (e.g. "P. 02"), and the current status (e.g. S. ACE).  The status will change 
if you start falling behind from "ACE" to "OK" and finally "BAD" based on the number of
dropped movements/frames.  It is still possible to complete the board with a "BAD" 
status but following the now "red" path will not guarantee success and you should be 
more cautious.  
If you die then the pattern will automatically fail and you will see a blinking "FAIL" 
message.  You are on your own to complete the board.
The trainer also supports partial patterns.  For these,  you will be guided for a short
period before the path ends (or turns yellow). The HUD will display "F/S" (FREESTYLE), 
and you will be on your own to clear the remaining pellets.

Press P2 button to toggle between the currently available pattern sets.
    
### Pacstrats pattern set:
    Use only three patterns to clear boards 1 through 255 and get to the kill screen!
    Pattern 01 is used on boards 1 through 4
    Pattern 02 is used on boards 5 through 20
    Pattern 03 is used on boards 21 through 255
    All three patterns clear the entire board and get both prizes.

More information Pacstrats patterns in the video at:
	https://www.youtube.com/watch?v=wKQy8LTTzC4
	
    
### Killerclown pattern set:
    Uses 5 patterns but some of them are very similar so should be easier to learn.
    These patterns are robust until near the end of each board.  You may need to 
    freestyle to tidy up some remaining pellets on your own. 
    Pattern 01 is for board 1 only.  It's freestyle near the end if you prefer.
    Pattern 02 is for boards 2 through 4.  It's a slight variation from pattern 1.
    Pattern 03 if for boards 5 through 16 and 18.
    Pattern 04 is for boards 17, 19 and 20.  You'll need to freestyle near the end.
    Pattern 05 is for boards 21 through 255

More information about Killerclown's patterns is to be found at:
    https://www.mameworld.info/net/pacman/patterns.html


### Perfect NRC set:
    An advanced pattern set for attaining the Perfect Pacman score by NR Chapman
    There are 13 different patterns including the split-screen pattern.
	
	Patterns 01, 02, 03 and 04 are for boards 1, 2, 3 and 4 respectively.
	Pattern 05 is for boards 5, 7, 8 and 11.
	Pattern 06 is for board 6 only.
	Pattern 07 is for board 9, 12, 13, 15, 16 and 18.  Freestyling is necessary near the end.
	Pattern 08 is for board 10 only
	Pattern 09 is for board 14 only
	Pattern 10 is for board 17 only
	Pattern 11 is for boards 19 and 20
	Pattern 12 is for boards 21 to 255.  There is a safe spot if you need a rest.
	Pattern 13 is for board 256 (split-screen).  Freestyling to collect 9 hidden dots on each life.

    Archive web information can be found at
    https://web.archive.org/web/20061103090947/http://nrchapman.com/pacman/


![Perfect Pac-Man Pattern Demo](demo2.gif)


## Minimum start up arguments:

```mame pacman -plugin pactrainer```


Tested with latest MAME version

Compatible with all MAME versions from at least 0.196

  
## Installing and running
 
The Plugin is installed by copying the pactrainer folder into your MAME plugins folder.

The Plugin is run by adding `-plugin pactrainer` to your MAME arguments e.g.

```mame pacman -plugin pactrainer```  

Works with "pacman" and "puckman" roms only.


## Upgrading from a previous pactrainer install

Delete or overwrite the existing `pactrainer/` folder in your MAME plugins
directory with this one. The plugin filename and the `-plugin pactrainer`
argument are unchanged, so nothing else in your MAME setup needs to move.

Migration notes:

- Your saved pattern-set choice (`active.dat`) is still read from the old
  location under the plugin directory, so your pattern preference carries over
  automatically. New writes go to MAME's `homepath` instead — typical defaults:
  - Windows: `%USERPROFILE%\.mame\pactrainer\`
  - macOS/Linux: `~/.mame/pactrainer/`
- Nothing is written under the plugin directory any more, so read-only or
  system-managed installs (RetroPie, packaged MAME) now work.
- The new `artwork/` and `sounds/` features are opt-in. If you don't install
  them, the plugin behaves exactly as before except for the on-screen
  `popmessage` cues and the breakpoint markers on repeat plays.


## Optional: side-bezel face overlay

The plugin drives a MAME output named `pactrainer_face` that reports the current
performance tier every frame:

    0 = ACE   1 = OK   2 = BAD   3 = FAIL

### Install the layout

The repo ships identical layouts under `artwork/pacman/` and `artwork/puckman/`.
MAME does not share artwork between the parent ROM and its clones automatically,
so **install the folder that matches the ROM name you launch with**:

- Launching `mame pacman -plugin pactrainer`? Copy `artwork/pacman/` into your
  MAME `artworkpath` (either as a `pacman/` folder or zipped as `pacman.zip`).
- Launching `mame puckman -plugin pactrainer`? Copy `artwork/puckman/` into
  your MAME `artworkpath` (as `puckman/` or `puckman.zip`).
- Not sure which you use, or use both? Install both folders. There's no downside.

Then relaunch MAME and select the **Trainer** view: press `Tab` in the MAME
window → Video Options → View → `Trainer`.

The bundled `default.lay` uses coloured disks as placeholders so the overlay
works with no extra downloads.

### Adding your own face artwork

1. Drop your images in the artwork folder that matches your ROM
   (`artwork/pacman/` and/or `artwork/puckman/`), alongside `default.lay`.
   Suggested names: `ace.png`, `ok.png`, `bad.png`, `fail.png`.
2. MAME accepts **PNG** (with alpha, recommended), **JPG**, **BMP**, and **SVG**
   for artwork files.
3. Edit `default.lay` in the same folder and replace the four
   `<disk state="N">...</disk>` lines inside the `<element name="face">` block
   with (adjust the extension if you're not using PNG):

   ```xml
   <image state="0" file="ace.png"/>
   <image state="1" file="ok.png"/>
   <image state="2" file="bad.png"/>
   <image state="3" file="fail.png"/>
   ```

4. If you use both ROM names, apply the same edit to both `default.lay` files
   (or just install the same folder as both `pacman/` and `puckman/`).

Sensible source sizes are ~64x64 or 128x128 — the layout scales them into a
56x56 bezel slot.

The plugin runs normally if the artwork is not installed; the face output just
has no consumer.


## Breakpoint map

Each time your run drops from ACE to OK on the pattern, the plugin records the
board coordinate. The next time you play the same pattern, coloured markers
appear at those spots during the first few seconds of the board so you can see
your recurring problem corners. Corners you miss repeatedly grow more opaque.

Data is written to MAME's `homepath` as `pactrainer/misses_<set>_<group>.dat`
(one row per point: `seq,y,x,count`). Nothing is written under the plugin
directory, so read-only installs are supported. The `active.dat` file that
remembers your selected pattern set is also written to `homepath`.


## Cues

Two things trigger cues during play:

- **Tier change** — fires when your tier gets worse (rate-limited to once per
  second).
- **All four ghosts** — fires the first time your score jumps by 1600 within a
  fright period, celebrating a full ghost train.

Both always show a MAME `popmessage`. They will *also* play a sound file if one
is present in the plugin's `sounds/` directory.

### Adding sound files

Drop **WAV** files into `pactrainer/sounds/` with these exact names:

| File | Fires when |
|---|---|
| `fanfare.wav` | You eat all four ghosts on one energizer |
| `tier_ok.wav` | Tier drops from ACE to OK |
| `tier_bad.wav` | Tier drops to BAD |
| `tier_fail.wav` | You die mid-board |

Notes:

- WAV is the only format guaranteed to play across Windows / macOS / Linux with
  no extra dependencies. MAME's Lua API has no play-sound primitive, so the
  plugin shells out to the host OS's built-in player (`powershell` on Windows,
  `afplay` on macOS, `paplay` or `aplay` on Linux). Other formats (MP3, OGG)
  will work only if the picked player happens to support them.
- Keep clips short (< 1 second) so they don't overlap with each other or with
  the game's own audio.
- Missing files silently no-op — the `popmessage` still fires, so nothing
  breaks.


## Troubleshooting

#### How do I get the plugin to work with Launchbox?

 - Edit your PacMan game. Under Emulation, check the box to use custom command-line parameters. in the space below, add ```-plugin pactrainer```
 
 
#### How do I get the plugin to work with RetroPie?

 - In the RetroPie Setup menu, under Manage Packages,  under Experimental Packages, Install MAME via binary.  This is a more recent MAME which supports plugins.
 - Copy the pactrainer folder into /opt/retropie/emulators/mame/plugins
 - Obviously,  copy your pacman.zip into the new roms folder
 - Edit the plugin.ini file which can be found at /opt/retropie/configs/mame/plugin.ini to include an extra line, as below.  This enables the pactrainer plugin.
 
```
hiscore 1
pactrainer 1
```
 

## Thanks to

The MAMEdev team at
- https://docs.mamedev.org

Scott Lawrence (BleuLlama) for Pac-Man ROM Disassembly resources at
- https://github.com/BleuLlama/GameDocs/blob/master/disassemble/mspac.asm

Pacstrats for his excellent 3 pattern video at
- https://www.youtube.com/watch?v=wKQy8LTTzC4

Killerclown for his Pac-Man patterns and strategy guide at:
- https://www.mameworld.info/net/pacman/patterns.html

NR Chapman for his perfect Pac-Man guide at:
- https://web.archive.org/web/20061103090947/http://nrchapman.com/pacman/

Mr2Nut123 for his inspiration to create this trainer.  Good luck with your journey to the Pac-Man split-screen.
- https://www.twitch.tv/mr2nut123


## Feedback

Please send feedback to jon123wilson@hotmail.com

Jon