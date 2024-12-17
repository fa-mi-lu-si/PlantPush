# Plant Push

[![Game Splash screen gif with rotating level](assets/banner.gif)](https://fa-mi-lu-si.itch.io/plant-push)

## Play In Browser

[Play on itch.io](https://fa-mi-lu-si.itch.io/plant-push)

## Installation

The game is made with tic80
https://github.com/nesbox/TIC-80/


I recommend you download and install tic80 for your platform (make sure it's on your $PATH)
Then just clone this repo and run this command to run the game.
```
tic80 --fs . --cmd 'load game.tic & import code game.lua & run' --keepcmd --skip
```

## How it started

<p>
    <img src="./assets/level%201.gif" alt="level 1" width=45%>
    <img src="./assets/level%209.gif" alt="level 9" width=45%>
</p>

This project began in 2021 when I was exploring tic80 and found [this](https://tic80.com/play?cart=1229) cart.
I thougt it would be better to move the camera view using the mouse so I implemented that feature.
Then I started creating a player charachter.
I gradually added features without much idea of how the final concept was going to look like.
Moveable player character,
3D coordinate system overlaid on TIC-80's tilemap,
Basic scripting system for block-player interactions.
