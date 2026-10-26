# SeviathsUsefulTools (formerly SeviathsFarmPack)

Glowing cyan farm spots on the World of Warcraft world map for in-demand creature loot -
cloth, leather, elements, meat and BoE pets - from Classic to Mists of Pandaria, plus rare spawns, with auction
house prices and Wowhead links.

## Install
Unzip so the folder sits at `World of Warcraft/_classic_/Interface/AddOns/SeviathsUsefulTools/`
(the `.toc` file directly inside it), then restart the game or `/reload`.

## Features
- **Zone map:** exact farm spots glow cyan with mob name + coordinates. Hover a spot for
  its drops and AH value. Ctrl+Click for a waypoint.
- **Continent map:** one spot per farm mob; zoom in for the full spawn areas.
- **Farm browser** (minimap button or `/sfp`): every expansion, zone, farm spot and old
  raid/dungeon with entrance coordinates, AH value, BoE drop chances, Wowhead links.
- **Rares:** orange spots for rares that drop mounts, pets and toys, with spawn tips.
  A gold star marks the ones worth grinding.
- **Hunter tames:** green spots with the hunter crest for spirit beasts and unique-looking
  pets, with what they are and how to tame them.
- **Map layers:** a button in the top-left corner of the world map opens a panel to turn each
  layer on/off: farm spots, rares, hunter tames, mining, herbalism, dungeons, raids, labels.
- **Gathering list:** bottom-right of each zone map - the expansion's ores and herbs with the best
  zone for each (click to open it).
- **Special materials:** magenta spots for lure beasts, special cloth and rare hides.
- **Learned farm spots:** the addon remembers where you loot farm materials and BoEs and turns those
  places into farm spots with your own drop rates - works in every zone.
- **Mining & herbalism:** the best zone for every ore and herb (Classic to Mists of Pandaria), shown as
  small pick / flower symbols; hover one for every ore and herb around it.
- **Dungeons & raids:** every dungeon and raid of every expansion with a mount or sellable BoE drop
  (read from the in-game Adventure Guide) - entrance icons on the map, loot and prices on hover.
- **Source icons:** every loot line shows whether it comes from mining, herbalism, skinning,
  cloth, enchanting, a boss, etc. "Best spot for ..." marks the top mob for each material.
- **BoE drops:** gear and recipes with drop chances, shown first in every list.
- **Auction house:** prices load the first time you open the AH and refresh after 12 h.
  Auctionator prices are used as a fallback.
- **Minimap button:** pulses cyan while you stand in a farm zone.
- **About page:** Esc > Options > AddOns > SeviathsUsefulTools.

## Commands
| Command | |
|---|---|
| `/sfp` | farm browser + settings |
| `/sfp spawns` | farm spot glows on/off |
| `/sfp rares` | rare spots on/off |
| `/sfp hunter` | hunter tame spots on/off |
| `/sfp gather` | mining & herbalism spots on/off |
| `/sfp dungeons` | dungeon/raid icons on/off |
| `/sfp mapbutton` | world map layer button on/off |
| `/sfp map` | world map overlay on/off |
| `/sfp minimap` | minimap button on/off |
| `/sfp scan` | rescan AH prices (AH open) |
| `/sfp min <gold>` | only show zones worth at least this |
| `/sfp tooltip` | item tooltip lines on/off |
| `/sfp version` | version info |

## Data
Item data and spawn positions come from wowhead.com. Drop chances are approximate.
No grey items; common quality and up.

## License
CC BY-NC 3.0 - free to use and modify with credit, not for sale. See LICENSE.


## Merged modules (1.18)
The Farm Pack now includes, in `Modules/`:
- **Seviath's Codex** (by Petalsofiron) - `/codex`: encyclopedia and guide
- **Seviath's Dungeons & Raids** - `/sdr`: group tools, raid buffs, tier tokens, player tags
- **Seviath's Guild Helper** - `/gi`: guild recruiting with /who, whispers and auto-invite

Right-click the minimap button for a menu with all of them. License of all parts: CC BY-NC 3.0.
