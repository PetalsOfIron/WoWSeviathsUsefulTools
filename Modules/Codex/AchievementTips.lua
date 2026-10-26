-- Seviath's Codex — how to do achievements with special conditions
--  • Curated solo strategies for well-known raid achievements (our own words,
--    based on community guides: wow.gg, frostyboost, Icy Veins).
--  • For every other achievement: practical tips derived from the game's own
--    requirement text ("without…", "within…", "N times"…).

local ADDON, ns = SFP_Module("Codex")

ns.ACH_TIPS = {
    -- Glory of the Firelands Raider (mount: Corrupted Fire Hawk) — 25 Heroic for the Heroic kills
    ["death from above"] = "Beth'tilac: never hit a Cinderweb Drone up on the web. Solo: kill her on the ground floor before she comes down in phase 2 — you never need to go up.",
    ["do a barrel roll!"] = "Alysrazor: nobody may be hit by Firestorm, Incendiary Cloud, Lava Spew or Fiery Tornado. Solo: burst her down the moment the fight starts, before those abilities appear. If she takes off, fly with the tornado gaps and avoid the lava worms in the middle.",
    ["share the pain"] = "Baleroc: nobody may get Torment more than 3 times. Solo: kill him fast — it usually completes on its own.",
    ["not an ambi-turner"] = "Lord Rhyolith: only damage his RIGHT foot. Target 'Right Foot', no cleave / AoE / trinkets that hit the left foot. He turns, walks over the volcanoes, then phase 2 — finish him.",
    ["bucket list"] = "Shannox: before killing him, lead him through 5 places: Flameforge, Beth'tilac's Lair, Path of Corruption, the Broken Stone and the Ridge of Ancient Flame. Don't kill his escort trash; walk with him until each place is ticked in the achievement window, then kill him.",
    ["only the penitent..."] = "Majordomo Staghelm area: when the fire orbs fall, every orb must be 'kneeled' at before it hits the ground. Solo: use a teleport (Warlock Demonic Circle/Gateway, Mage Blink, Monk Transcendence, Demon Hunter mobility) — set it at one orb, start the event, /kneel at the second orb, teleport back and /kneel at the first. Easiest with one friend standing at each orb. Hardest one of the meta.",
    ["heroic: shannox"] = "Set 25-player Heroic before entering (right-click your portrait), then just kill.",
    ["heroic: beth'tilac"] = "Set 25-player Heroic, then just kill.",
    ["heroic: lord rhyolith"] = "Set 25-player Heroic, then just kill (do Not an Ambi-Turner in the same kill).",
    ["heroic: alysrazor"] = "Set 25-player Heroic, then just kill.",
    ["heroic: baleroc"] = "Set 25-player Heroic, then just kill.",
    ["heroic: majordomo fandral staghelm"] = "Set 25-player Heroic, then just kill.",

    -- Delves
    ["let me solo him: nullaeus"] = "Kill Nullaeus alone on Tier 11 in Torment's Rise (Voidstorm). Full fight guide: Delves » Torment's Rise. Interrupt every Emptiness of the Void, dispel Devouring Essence, dodge Void Zone and Black Hole. Reward: Arcanovoid Construct mount.",
    ["my shady nemesis"] = "Kill Nullaeus in Torment's Rise (Voidstorm) on any difficulty. Fight guide: Delves » Torment's Rise.",

    -- Glory of the Dragon Soul Raider (mount: Twilight Harbinger) — all on Heroic
    ["don't stand so close to me"] = "Morchok: during Black Blood of the Earth nobody may be within 5 yards of another player. Solo: completes on its own — just kill.",
    ["ping pong champion"] = "Warlord Zon'ozz: bounce the Void of the Unmaking orb back 10 times before it hits him. Stand in the orb's path to bounce it. Don't kill him too early — take off your weapon to lower your damage.",
    ["taste the rainbow!"] = "Yor'sahj: let these ooze pairs reach him: Black+Blue, Black+Yellow, Purple+Yellow, Red+Green. Kill the other colors, keep him alive with low damage (remove weapon) while waiting for the right pairs. Can take several waves.",
    ["deck defender"] = "Warmaster Blackhorn: no Twilight Barrage may hit the Skyfire. Stand in every purple circle on the deck to soak it; kill the drakes fast — barrages stop when they die.",
    ["maybe he'll get dizzy..."] = "Spine of Deathwing: make him barrel roll in both directions. Kill tendrils one at a time, stand on one edge to tip him, then run to the other edge when the warning appears. Don't fall off.",
    ["chromatic champion"] = "Madness of Deathwing: the achievement wants a kill started from each Aspect's platform — pick a different platform first each week until all are done.",
}

-- Practical advice from the requirement text itself (works for every achievement)
function ns:AchievementTip(name, desc)
    local curated = name and self.ACH_TIPS[name:lower()]
    if curated then return curated end
    local d = (desc or ""):lower()
    if d == "" then return nil end
    local tips = {}
    local function add(s) tips[#tips + 1] = s end
    local solo = d:find("no raid member") or d:find("no member") or d:find("no player") or d:find("no one")
        or d:find("none of your") or d:find("any raid member") or d:find("no party member")
    if solo then add("rule about other players — usually completes automatically when you're alone; just avoid the named ability yourself.") end
    if d:find("without") and not solo then add("don't do / don't get hit by the named thing during the fight — read the goal carefully.") end
    if d:find("within %d+") or d:find("seconds") or d:find("before") then add("timed: burst it down — use your big cooldowns at once.") end
    if d:find("%d+ times") or d:find("stacks") or d:find("all %d+") or d:find("%f[%a]while%f[%A]") or d:find("%f[%a]after%f[%A]") then
        add("the boss must stay alive long enough: take off your weapon (and maybe armor) to lower your damage, let the mechanic happen, then re-equip and kill.")
    end
    if d:find("heroic") then add("set the difficulty to Heroic first (right-click your portrait).") end
    if d:find("mythic") then add("set the difficulty to Mythic first (right-click your portrait).") end
    if d:find("25") and d:find("player") then add("25-player mode: right-click your portrait » Raid Difficulty » 25 Player.") end
    if d:find("%f[%a]each%f[%A]") or d:find("%f[%a]every%f[%A]") then add("needs every listed part — check the achievement window to see what's still missing.") end
    if d:find("collect") or d:find("loot") or d:find("obtain") then add("collect the named items/things — they're usually in the boss room or drop from adds.") end
    if #tips == 0 then return nil end
    return table.concat(tips, "\n        ")
end
