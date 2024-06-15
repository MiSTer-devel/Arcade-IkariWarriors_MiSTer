# SNK Ikari Warriors / Victory Road:
![Ikari Warriors](/docs/ikaria-warriors-flyer.jpg)
![Victory Road](/docs/victory_road.pjg.jpg)

* Update [15/06/24] Added GRS Superjoystick support for rotative joystick control. See notes about configuration.

Ikari Warriors and Victory Road are run and gun vertical shooters developed by SNK in 1986. Victory Road is the sequel to Ikari Warriors.
The game was released at the time when there were many Commando clones on the market. What made Ikari Warriors instantly distinct, were rotary joysticks and the allowing simultaneous play by two people.

Ikari Warriors involves Ralf Jones and Clark Steel (known outside Japan as Paul and Vince in the Ikari series) battling through hordes of enemies. According to designer Keiko Iju, the game was inspired by the then-popular Rambo films and takes its name from the Japanese title of Rambo: First Blood Part II (Rambo: Ikari no Dasshutsu or "The Angry Escape").
Follow any core updates and news on my Twitter acount [@RndMnkIII](https://twitter.com/RndMnkIII). this project is a hobby but it requires investing in arcade game boards and specific tools, so any donation is welcome: [https://ko-fi.com/rndmnkiii](https://ko-fi.com/rndmnkiii).

## About
This core as beta release will be published as independet core. Finally will be unified with the SNK Triple Z80 Core. For a list of games intended to work with the SNK Triple Z80 Core see:
[https://github.com/mamedev/mame/blob/master/src/mame/drivers/snk.cpp](https://github.com/mamedev/mame/blob/master/src/mame/drivers/snk.cpp).  

## Third party cores
* Based on [https://github.com/antoniovillena/MiSTer_DB9/blob/master/Cores/AtariST_MiSTer/sys/joydb15.v](joydb15.v) by Aitor Pelaez (NeuroRulez).
* Daniel Wallner T80 core [jesus@opencores.org](https://opencores.org/projects/t80).
* JTOPL FPGA Clone of Yamaha OPL hardware by Jose Tejada, @topapate [(https://github.com/jotego/jtopl)](https://github.com/jotego/jtopl).
* Based on Tim Rudy 7400 TTL library [https://github.com/TimRudy/ice-chips-verilog](https://github.com/TimRudy/ice-chips-verilog).

## Instructions:
Two players can participate in this game simultaneously. Ikari Warriors/Victory Road use rotary joysticks: those which could be rotated in addition to being pushed in eight directions. The game also featured two buttons, one for the standard gun and another for lobbing grenades. It allowed two players to play cooperatively, side by side and to use vehicles (tank).
Apart from the standard MiSTer game controller support there is also there is SNAC support for:
* DB15 arcade controls (tested with the Splitter for official MiSTer by Antonio Villena. See: https://www.antoniovillena.es/store/product/splitter-for-official-mister/).
* Native adapter for SNK LS-30 joystick. This is a D.I.Y development of the author of the core and is commented on in a separate project. See: https://github.com/RndMnkIII/SNK_LS-30_Rotary_Joystick_SNAC_adapter. You can build a alternative one if you already have some DB15 SNAC adapter as the Antonio Villena Splitter seen before.
You can change the settings in the Core Menu: 
* SNAC > DB15 Devices: Off,OnlyP1,OnlyP2,P1&P2 (fixed controls: button A: rotate left, button B: fire, button C: grenade, button D: rotate right).
* SNAC > Native LS-30 Adapter: Off,OnlyP1,OnlyP2,P1&P2 (maps over buttons F,E,D,C of a DB15 interface the LS-30 rotary four wire data, button A: fire, button B: grenade).

Alternatively, you can wire this adapter if you already are using a DB15 SNAC adapter as the Official Mister Splitter by Antonio Villena and you don't want to build my native adapter design MCU based:
![gamepad buttons](/docs/ls30_to_db15_adapter2.png)

### GRS Superjoystick support
https://thunderstickstudio.com/products/grs-super-joystick

Now you can use the GRS Superjoystick specifically designed for SNK games that uses LS-30 rotative joystick. 
Before to use it you need to plug the game controller into a PC Windows machine, install and execute the TS-RJConfigurator utility:
https://cdn.shopifycdn.net/s/files/1/0606/7516/2341/files/TS-RJConfigurator-V1.04.9.rar

You need to adjust MODE pressing the button on the GRS Super Joystick until you get the button GREEN lit and set to 12 WAY mode  pressing WAY button until the button is blinking (follow the tsticks user manual procedure for this). Now assign in the `Keyboard` section of TS-RJConfigurator Spinner Left to `Left Key` and Spinner Right to `Right Key` if you want to use the GRS Super Joystick as Player1 or Spinner Left to `C Key` and Spinner Right to `V` if you want to use the GRS Super Joystick as Player2 in MiSTer. Now press `Save Configuration` button and now you can deattach the controller from PC and attach it to MiSTer. You need to assign your GRS game controller as Player1 or Player2 based on the previous configuration done in TS-RJConfigurator.
you need to enable it in the core menu as: `SNAC & GRS Super Joystick > Use GRS Super JoyStick: ON`. Now the rotate left, rotate righ action will be assigned to the selected player.
Regardless of the settings made for the joystick buttons, you should ignore the assignments made for the left and right rotation keys made for generic controllers.

## Manual installation
Rename the Arcade-IkariWarriors_XXXXXXXX.rbf file to IkariWarriors_XXXXXXXX.rbf and copy to the SD Card to the folder  /media/fat/_Arcade/cores and the .MRA files to /media/fat/_Arcade.

The required ROM files follow the MAME naming conventions (check inside MRA for this). Is the user responsability to be installed in the following folder:
/media/fat/_Arcade/mame/<mame rom>.zip

## Acknowledgments
* To all Ko-fi contributors for supporting this project: __@bdlou__, __Peter Bray__, __Nat__, __Funkycochise__, __David__, __Kevin Coleman__, __Denymetanol__, __Schermobianco__, __TontonKaloun__, __Wark91__, __Dan__, __Beaps__, __Todd Gill__, __John Stringer__, __Moi__, __Olivier Krumm__, __Raymond Bielun__.
* Thanks to __@antoniovillena__ and __@NeuroRulez__ for their help and patience with SNAC support for DB15.
* Thanks to __@Salamander329__ for his MiSTer LED screen artworks, gives a more special arcade touch to MiSTer.
* __@FCochise__ for helping with the rom settings of MRA files.
* __@alanswx__ for helping me with some technical aspects related to the use of the MiSTer framework.
* And all those who with their comments and shows of support have encouraged me to continue with this project.


