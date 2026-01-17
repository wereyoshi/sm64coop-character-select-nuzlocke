-- name: Character Select Nuzlocke
-- description:  character select nuzlocke  \nCreated by wereyoshi.
-- pausable: true
-- category: cs

gPlayerSyncTable[0].nocharacters = false --if no characters remain
local useablecharacter = {}--table of useablecharacters
local characternametable = {} --table of cs character names
gPlayerSyncTable[0].usingdeadcharacter = false --whether the current player is using an elimated character
gPlayerSyncTable[0].resetingnuzlocketable = false --whether the player is resetting their nuzlocke table
gPlayerSyncTable[0].team = 0 --what team the player is on
local sendingpackets = false --used for sending packets when the local player elimates a character
local teamfunction --a function used for determining a player's team takes a mariostate as a param and returns isfreeforall(boolean) and currentteam
local inittable = false --whether the nuzlocke table needs to be initialized
local modsupporthelperfunctions = {} --local references to functions from other mods
local servermodsync = false --used for making modsupport run once
local charactertable = {} --a copy of character select's character table
local otherplayercharactertable = {} --a serverside copy of non host nuzlocke tables
local charmax --the total number of cs characters
local costumemaxtable = {} --the number of costumes each cs character has
local canopencsmenu = 2 --the current cs menu status
local currentcostume --the current cs costume for the local player
local currentcharacter --the current cs character for the local player
local currentcharacttype --the current cs forcecharacter type for the local player
local version = "1.1.1" -- the current version of the mod
local lastdeadcharacter --last character the local player died as
local lastdeadcostume --the costume of the last character the local player died as
local lastdeadstage --the  stage where the last character that the local player died as died in
local onnocharactersfunctiontable = {} --table of functions to run when the local player runs out of characters
local onnuzlockeresetfunctiontable = {} --table of functions to run when the nuzlocke table is reset for the local player
local onnuzlockeupdatefunctiontable = {} --table of functions to run when the nuzlocke table is updated for the local player
local resettable_command
local nuzlockechangecharacterpause_command
local resetsaveonreset = true --whether the current save should also be reset when reseting the nuzlocke if true the save will be reset with nuzlocke reset
local hookupdate
local othermodsetresetonsavesetting = false --whether another mod changed resetsaveonreset through the api
local deathicon = gTextures.no_camera
gGlobalSyncTable.isfreeforall = false --whether it is a free for all
gGlobalSyncTable.canchangecharacteronexit = false --whether players can change characters on pause exit
local bool_to_str = {[false] = "off",[true] = "on"} --table for converting boolean into string

local charmin = 0 --the first character in the character select table

local startinglevel --the level you start in
local startingarea -- the area you start in
local startingactnum -- the act you start in
local teamfunctionsetbyothermod = false

if table.deepcopy == nil then
    log_to_console(string.format("Outdated coopdx client detected that lacks needed functions for character select nuzlocke mod version %s",version), 1)
    return
end

---this is the function character select nuzlocke uses by default to reset the current save
local resetnuzlocksavefunction = function()
    local file = get_current_save_file_num() - 1
    save_file_erase(file)
    gMarioStates[0].numStars = 0
end

---@param m MarioState
---Called once per player per frame at the end of a mario update 
local function final_mario_update(m)
    if (m.playerIndex ~= 0) or (currentcharacter ~= modsupporthelperfunctions.finalindex) then return end
    local iscsmenuopen = modsupporthelperfunctions.charSelect.is_menu_open() --whether the cs menu is open
    if  (canopencsmenu == 3) then
        canopencsmenu = 4
        modsupporthelperfunctions.charSelect.set_menu_open(true)
    elseif (canopencsmenu == 4) then
        modsupporthelperfunctions.charSelect.set_menu_open(true)
    elseif (m.health > 0xff) and (modsupporthelperfunctions.charSelect.is_menu_open() == false) and (not gPlayerSyncTable[0].nocharacters) then
        local remainingcharactercount = 0
        local chardescription = "The following characters remain: "
        local livesremainstring
        local lockedcharactercount = 0 --the current number of locked non eliminated characters
        djui_chat_message_create("The following characters remain:")
        for key,value in pairs(useablecharacter)do
            for subkey,subvalue in pairs(useablecharacter[key])do
                if useablecharacter[key][subkey] == true then
                    djui_chat_message_create(string.format("%s ", charactertable[key][subkey].name))
                    chardescription = string.format("%s %s ",chardescription, charactertable[key][subkey].name)
                    remainingcharactercount = remainingcharactercount + 1
                    if charactertable[key].locked == 1 then
                        lockedcharactercount = lockedcharactercount + 1
                    end
                end
            end
        end
        if remainingcharactercount > 1 then
            djui_chat_message_create(string.format("%d characters remain", remainingcharactercount))
            livesremainstring = string.format("%d characters remain", remainingcharactercount)
        elseif remainingcharactercount == 1 then
            djui_chat_message_create("1 character remains")
            livesremainstring = "1 character remains"
        else
            djui_chat_message_create("out of characters")
            livesremainstring = "out of characters"
        end
        if lockedcharactercount > 0 then
            if lockedcharactercount >= remainingcharactercount then
                djui_chat_message_create(string.format("out of useable characters due to the remaining %d characters needing to be unlocked", lockedcharactercount))
                gPlayerSyncTable[0].nocharacters = true
            else
                djui_chat_message_create(string.format("%d of which need to be unlocked", lockedcharactercount))
            end
        end
        modsupporthelperfunctions.charSelect.character_edit(modsupporthelperfunctions.finalindex,livesremainstring,chardescription,nil,nil,nil)
        update_mod_menu_element_name(modsupporthelperfunctions.charactercountmenuindex,livesremainstring)
        canopencsmenu = 2
        modsupporthelperfunctions.charSelect.set_menu_open(true)
        if (gPlayerSyncTable[0].usingdeadcharacter == true) then
            gPlayerSyncTable[0].usingdeadcharacter = false
            lastdeadcostume = modsupporthelperfunctions.charSelect.character_get_current_costume()
            lastdeadcharacter = modsupporthelperfunctions.charSelect.character_get_current_number()
            lastdeadstage = get_level_name(gNetworkPlayers[0].currCourseNum, gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex)
        elseif lastdeadcharacter ~= modsupporthelperfunctions.finalindex then
            sendingpackets = true
        end
        if (remainingcharactercount == 0) then
            gPlayerSyncTable[0].nocharacters = true
            for key,value in pairs(onnocharactersfunctiontable)do
                value()
            end
        end
    end
end

---@param m MarioState
---@param o Object
---@param interactType InteractionType
--this function is for allowing mario to interact with objects.
local function allow_interact(m, o, interactType)
    if (m.playerIndex ~= 0) or (currentcharacter ~= modsupporthelperfunctions.finalindex) then return end
    local allowedinteracttype = {[INTERACT_WARP] = true,[INTERACT_DOOR] = true,[INTERACT_WARP_DOOR] = true,[INTERACT_BBH_ENTRANCE] = true}
    if allowedinteracttype[interactType] ~= true then
        return false
    end

end

---@param m MarioState
---@param incomingAction integer
--this function is called before every time a player's current action is changed
local function before_set_mario_action(m,incomingAction)
    if (m.playerIndex ~= 0) or (currentcharacter ~= modsupporthelperfunctions.finalindex) then return end
    if (incomingAction == ACT_GROUND_POUND_LAND) then
        return ACT_JUMP_LAND
    end
end

--function to initialize the nuzlocke table
local function init_nuzlocketable()
    modsupporthelperfunctions.statustable = {}--table of mod menu positions for each character's status
    local sortedtable = {} --table of character select characters sorted by name
    for i = charmin,charmax do
        useablecharacter[i] = {}
        characternametable[i] = {}
        modsupporthelperfunctions.statustable[i] = {}
        if charactertable[i].locked == 1 then
            modsupporthelperfunctions.charSelect.character_set_locked(i,function ()
                return true
            end,false) --unlocking all characters
        end
        for j = 1, costumemaxtable[i] do
            useablecharacter[i][j] = true
            characternametable[i][j] = charactertable[i][j].name
            table.insert(sortedtable,{name = charactertable[i][j].name,characterindex = i, costumeindex = j})
        end
    end
    table.sort(sortedtable,function(currentindex,nextindex)
        return currentindex.name < nextindex.name
    end)
    hook_mod_menu_text("format : name (status) [charindex,costumeindex]")
    for key,value in pairs(sortedtable) do
        modsupporthelperfunctions.statustable[value.characterindex][value.costumeindex] = hook_mod_menu_text(string.format("%s (alive)  [%d,%d]",value.name,value.characterindex,value.costumeindex))
    end
end

--function to make a nuzlocke table
local function make_nuzlocketable()
    local newtable ={}
    for i = charmin,charmax do
        newtable[i] = {}
        for j = 1, costumemaxtable[i] do
            newtable[i][j] = true
        end
    end
    return newtable
end

--function to reset the nuzlocke table
local function reset_nuzlocketable(nuztable)
    for i = charmin,charmax do
        for j = 1, costumemaxtable[i] do
            nuztable[i][j] = true
            modsupporthelperfunctions.charSelect.character_edit_costume(i,j,characternametable[i][j],nil, nil,nil, nil, nil, charactertable[i][j].lifeIcon, nil)
            if (nuztable == useablecharacter) and (modsupporthelperfunctions.statustable[i][j] ~= nil) then
                update_mod_menu_element_name(modsupporthelperfunctions.statustable[i][j],string.format("%s (alive)  [%d,%d]",charactertable[i][j].name,i,j))
            end
        end
    end
    if resetsaveonreset == true then
        warp_to_level(startinglevel, startingarea, startingactnum)
    end
    
end

---@param s string the string to be split
---@param delimiter string what to check for when spliting the string
---this function splits a string by a delimiter and returns the result as a table
local function split_string(s,delimiter)
    local result = {}
    for str in string.gmatch(s, "([^" .. delimiter .. "]+)") do
        table.insert(result, str)
    end
    return result

end
---@param index number local index of the player whose nuzlocke table should be reset
--this function resets the nuzlocke table of a single player
local function reset_singlenuzlocketable(index)
    if network_is_server() then
        if (index ~= 0) then
            gPlayerSyncTable[index].nocharacters = false
            gPlayerSyncTable[index].resetingnuzlocketable = true
            reset_nuzlocketable(otherplayercharactertable[index])
        end
    else
        local playerglobalindex = network_global_index_from_local(index)
        network_send_to(network_local_index_from_global(0),true,{servernuzlockeresetrequestsingle = true,globalindexofplayer = playerglobalindex})

    end

end

---@param playerindex number the local player index of a player to revive a character for
---@param charactertorevive number the character to revive's position in the character select table
---@param costumeofcharactertorevive number the costume number of the character to revive in the character select table
--function used by the host to revive a character for a player
local function revive_character(playerindex,charactertorevive,costumeofcharactertorevive)
    if not network_is_server() then
        djui_chat_message_create('Only the host can change this setting!')
         return
    end
    local otherplayerteam
    local localplayerteam
    local isfreeforall
    local reviveteam
    local x
    local teammateteam
    if playerindex ~= 0 then
        otherplayercharactertable[playerindex][charactertorevive][costumeofcharactertorevive] = true
        network_send_to(playerindex,true,{revivedcharacter = charactertorevive,revivededcostume = costumeofcharactertorevive})
        gPlayerSyncTable[playerindex].nocharacters = false
        isfreeforall,reviveteam = teamfunction(gMarioStates[playerindex])
        isfreeforall,localplayerteam = teamfunction(gMarioStates[0])
        if (isfreeforall ~= true) then
            if reviveteam == localplayerteam then
                gPlayerSyncTable[playerindex].nocharacters = false
                useablecharacter[charactertorevive][costumeofcharactertorevive] = true
                if (modsupporthelperfunctions.statustable[charactertorevive][costumeofcharactertorevive] ~= nil) then
                    update_mod_menu_element_name(modsupporthelperfunctions.statustable[charactertorevive][costumeofcharactertorevive],(string.format("%s (alive)  [%d,%d]",charactertable[charactertorevive][costumeofcharactertorevive].name,charactertorevive,costumeofcharactertorevive)))
                end
                modsupporthelperfunctions.charSelect.character_edit_costume(charactertorevive,costumeofcharactertorevive,characternametable[charactertorevive][costumeofcharactertorevive],nil, nil,nil, nil, nil, nil, nil)
                for i = 1, costumemaxtable[charactertorevive] do --setting back the character icons for the revived character's costumes
                    modsupporthelperfunctions.charSelect.character_edit_costume(charactertorevive,i,nil,nil, nil,nil, nil, nil, charactertable[charactertorevive][i].lifeIcon, nil)
                end
                for key,value in pairs(onnuzlockeupdatefunctiontable)do
                    value()
                end
            end
            for i = 1,MAX_PLAYERS - 1 do
                x,otherplayerteam = teamfunction(gMarioStates[i])
                if (i ~= playerindex) and (reviveteam == otherplayerteam) then
                    network_send_to(playerindex,true,{revivedcharacter = charactertorevive,revivededcostume = costumeofcharactertorevive})
                    otherplayercharactertable[i][charactertorevive][costumeofcharactertorevive] = true
                end
            end
        end
        
    else
        gPlayerSyncTable[playerindex].nocharacters = false
        useablecharacter[charactertorevive][costumeofcharactertorevive] = true
        if (modsupporthelperfunctions.statustable[charactertorevive][costumeofcharactertorevive] ~= nil) then
            update_mod_menu_element_name(modsupporthelperfunctions.statustable[charactertorevive][costumeofcharactertorevive],(string.format("%s (alive)  [%d,%d]",charactertable[charactertorevive][costumeofcharactertorevive].name,charactertorevive,costumeofcharactertorevive)))
        end
        modsupporthelperfunctions.charSelect.character_edit_costume(charactertorevive,costumeofcharactertorevive,characternametable[charactertorevive][costumeofcharactertorevive],nil, nil,nil, nil, nil, nil, nil)
        for i = 1, costumemaxtable[charactertorevive] do --setting back the character icons for the revived character's costumes
            modsupporthelperfunctions.charSelect.character_edit_costume(charactertorevive,i,nil,nil, nil,nil, nil, nil, charactertable[charactertorevive][i].lifeIcon, nil)
        end
        for key,value in pairs(onnuzlockeupdatefunctiontable)do
            value()
        end
        
        isfreeforall,otherplayerteam = teamfunction(gMarioStates[playerindex])
        isfreeforall,localplayerteam = teamfunction(gMarioStates[0])
        gPlayerSyncTable[playerindex].nocharacters = false
        if (isfreeforall ~= true) then
            for i = 1,MAX_PLAYERS - 1 do
                x,otherplayerteam = teamfunction(gMarioStates[i])
                if (localplayerteam == otherplayerteam) then
                    network_send_to(i,true,{revivedcharacter = charactertorevive,revivededcostume = costumeofcharactertorevive})
                    otherplayercharactertable[i][charactertorevive][costumeofcharactertorevive] = true
                end
            end
        end
    end

end

---arg[1] playerindex number the local player index of a player to revive a character for
---arg[2] charactertorevive number the character to revive's position in the character select table
---arg[3] costumeofcharactertorevive number the costume number of the character to revive in the character select table
---alt arg[2] charactername string the name of a character in the character select table
--function used by the host to revive a character for a player
local server_revive_character_for_player = function(...)
    local arg  = table.pack(...)
    local playerindex ---the local player index of a player to revive a character for
    local charactertorevive ---the character to revive's position in the character select table
    local costumeofcharactertorevive ---the costume number of the character to revive in the character select table
    local name ---a name in the character select table
    local namefound = false --if name was found in the character select table
    if type(arg[1]) == "number" and (arg[1] >= 0) and (arg[1] < MAX_PLAYERS) then
        playerindex = arg[1]
    else
        log_to_console(string.format("invalid playerindex was passed to revive_character function character select nuzlocke mod version is %s",version), 1)
        return
    end
    if (type(arg[2]) == "number") and ((type(arg[3]) == "number")) then
        charactertorevive = arg[2]
        costumeofcharactertorevive = arg[3]
        if charactertable[charactertorevive][costumeofcharactertorevive] == nil then
            log_to_console(string.format("invalid character number and costume number where passed to revive_character function character select nuzlocke mod version is %s",version), 1)
            return
        end
    elseif (type(arg[2]) == "string") then
        name = string.lower(arg[2])
        for key,value in pairs(characternametable)do
            for subkey,subvalue in pairs(characternametable[key])do
                if (subvalue ~= nil) and (string.lower(subvalue) == name) then
                    charactertorevive = key
                    costumeofcharactertorevive = subkey
                    namefound = true
                    break
                end
            end
        end
        if namefound ~= true then
            log_to_console(string.format("invalid character name %s was passed to revive_character function character select nuzlocke mod version is %s",name,version), 1)
            return
        end
    end
    revive_character(playerindex,charactertorevive,costumeofcharactertorevive)
end

---determines what happens on level start
local function on_level_init()
    if inittable ~= true then
        charactertable = table.deepcopy(modsupporthelperfunctions.charSelect.character_get_full_table())
        for key,value in pairs(charactertable)do
            costumemaxtable[key] = #(charactertable[key])
        end
        charmax = #charactertable 
        modsupporthelperfunctions.charactercountmenuindex = hook_mod_menu_text("all characters are alive")
        init_nuzlocketable()
        modsupporthelperfunctions.finalindex = modsupporthelperfunctions.charSelect.character_add("nuzlocke death tracker","no character lost", nil, nil, nil, CT_MARIO, deathicon,1) --index used for checking if the player has no lives left in the character select mod
        hook_event(HOOK_MARIO_UPDATE, final_mario_update) --Called once per player per frame at the end of a mario update
        hook_event(HOOK_ALLOW_INTERACT, allow_interact) --Called before mario interacts with an object, return true to allow the interaction
        hook_event(HOOK_BEFORE_SET_MARIO_ACTION, before_set_mario_action) --hook which is called before every time a player's current action is changed.Return an action to change the incoming action or 1 to cancel the action change.
        lastdeadcostume = modsupporthelperfunctions.charSelect.character_get_current_costume()
        lastdeadcharacter = modsupporthelperfunctions.charSelect.character_get_current_number()
        lastdeadstage = get_level_name(gNetworkPlayers[0].currCourseNum, gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex)
        startinglevel = gNetworkPlayers[0].currLevelNum
        startingarea = gNetworkPlayers[0].currAreaIndex
        startingactnum = gNetworkPlayers[0].currAreaIndex
        inittable = true
        modsupporthelperfunctions.charSelect.set_menu_open(true)
        modsupporthelperfunctions.charSelect.credit_add(string.format("character select nuzlocke version %s", version),"wereyoshi","mod maker")
        if network_is_server() then
            for i = 1, MAX_PLAYERS - 1 do
                otherplayercharactertable[i] = make_nuzlocketable()
            end
            
        else
            local playerglobalindex = gNetworkPlayers[0].globalIndex
            network_send_to(network_local_index_from_global(0),true,{syncrequest = true,globalindexofplayer = playerglobalindex})

        end
        for key,value in pairs(onnuzlockeupdatefunctiontable)do
            value()
        end
    end
    
  end



---@param m MarioState
---Called when the player dies
local function on_death(m)
    if (m.playerIndex ~= 0) or (currentcharacter == modsupporthelperfunctions.finalindex) then 
        return
    end
    lastdeadcostume = modsupporthelperfunctions.charSelect.character_get_current_costume()
    lastdeadcharacter = modsupporthelperfunctions.charSelect.character_get_current_number()
    local deadcostumecount = 0
    lastdeadstage = get_level_name(gNetworkPlayers[0].currCourseNum, gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex)
    useablecharacter[lastdeadcharacter][lastdeadcostume] = false
    if (modsupporthelperfunctions.statustable[lastdeadcharacter][lastdeadcostume] ~= nil) then
        update_mod_menu_element_name(modsupporthelperfunctions.statustable[lastdeadcharacter][lastdeadcostume],(string.format("%s (dead)  [%d,%d]",charactertable[lastdeadcharacter][lastdeadcostume].name,lastdeadcharacter,lastdeadcostume)))
    end

    for key,value in pairs(onnuzlockeupdatefunctiontable)do
        value()
    end
    modsupporthelperfunctions.charSelect.character_edit_costume(lastdeadcharacter,lastdeadcostume,"(x)" ..characternametable[lastdeadcharacter][lastdeadcostume],nil, nil,nil, nil, nil, nil, nil)
    modsupporthelperfunctions.charSelect.character_set_current_number(modsupporthelperfunctions.finalindex)
    for i = 1,costumemaxtable[lastdeadcharacter] do
        if useablecharacter[lastdeadcharacter][i] == false then
            deadcostumecount = deadcostumecount + 1
        end
    end
    if deadcostumecount == costumemaxtable[lastdeadcharacter] then
        for i = 1,costumemaxtable[lastdeadcharacter] do
                modsupporthelperfunctions.charSelect.character_edit_costume(lastdeadcharacter,i,nil,nil, nil,nil, nil, nil, deathicon, nil)
        end
    end
    currentcostume = 1
    currentcharacter = modsupporthelperfunctions.finalindex
    currentcharacttype = CT_MARIO
end

---@param dataTable table a table received from another player
---Called when the mod receives a packet that used network_send() or network_send_to()
local function on_packet_receive(dataTable)
    local deadcostumecount = 0
    if (type(dataTable.diedascharacter) == "number") and(type(dataTable.diedascostume) == "number")  and (type(dataTable.globalindexofplayer) == "number") and (type(dataTable.diedinstage) == "string") then
        local localotherplayerindex = network_local_index_from_global(dataTable.globalindexofplayer)
        djui_chat_message_create(string.format("%s(%d character %d costume) eliminated due to %s in %s",charactertable[dataTable.diedascharacter][dataTable.diedascostume].name,dataTable.diedascharacter,dataTable.diedascostume,gNetworkPlayers[localotherplayerindex].name,dataTable.diedinstage))

        if network_is_server() then
            local otherplayerteam
            local localplayerteam
            local isfreeforall
            local x
            local teammateteam
            isfreeforall,otherplayerteam = teamfunction(gMarioStates[localotherplayerindex])
            isfreeforall,localplayerteam = teamfunction(gMarioStates[0])
            otherplayercharactertable[localotherplayerindex][dataTable.diedascharacter][dataTable.diedascostume] = false
            for i = 1, MAX_PLAYERS -1 do
                isfreeforall,teammateteam = teamfunction(gMarioStates[i])
                if (i~= localotherplayerindex) and (otherplayerteam == teammateteam)then
                    otherplayercharactertable[i][dataTable.diedascharacter][dataTable.diedascostume] = false
                end
            end
            if (otherplayerteam ~= localplayerteam) or isfreeforall then
                return
            end    
        end
        if (currentcharacter == dataTable.diedascharacter ) and (currentcostume == dataTable.diedascostume) then
            gPlayerSyncTable[0].usingdeadcharacter = true
        else
            local receiveddeadcharacter = dataTable.diedascharacter
            local receiveddeadcostume = dataTable.diedascostume
            useablecharacter[dataTable.diedascharacter][receiveddeadcostume] = false
            if (modsupporthelperfunctions.statustable[receiveddeadcharacter][receiveddeadcostume] ~= nil) then
                update_mod_menu_element_name(modsupporthelperfunctions.statustable[receiveddeadcharacter][receiveddeadcostume],(string.format("%s (dead)  [%d,%d]",charactertable[receiveddeadcharacter][receiveddeadcostume].name,receiveddeadcharacter,receiveddeadcostume)))
            end
            
            modsupporthelperfunctions.charSelect.character_edit_costume(receiveddeadcharacter,receiveddeadcostume,"(x)" ..characternametable[receiveddeadcharacter][receiveddeadcostume],nil, nil,nil, nil, nil, nil, nil)
            
            for i = 1,costumemaxtable[receiveddeadcharacter] do
                if useablecharacter[receiveddeadcharacter][i] == false then
                    deadcostumecount = deadcostumecount + 1
                end
            end
            if deadcostumecount == costumemaxtable[receiveddeadcharacter] then
                for i = 1,costumemaxtable[receiveddeadcharacter] do
                        modsupporthelperfunctions.charSelect.character_edit_costume(receiveddeadcharacter,i,nil,nil, nil,nil, nil, nil, deathicon, nil)
                end
            end
            for key,value in pairs(onnuzlockeupdatefunctiontable)do
                value()
            end
        end
    elseif (type(dataTable.revivedcharacter) == "number") and(type(dataTable.revivededcostume) == "number") then
        local revivecharacter = dataTable.revivedcharacter
        local revivecostume = dataTable.revivededcostume
        djui_chat_message_create(string.format("%s(%d character %d costume) was revived",charactertable[revivecharacter][revivecostume].name,revivecharacter,revivecostume))
        useablecharacter[revivecharacter][revivecostume] = true
        if (modsupporthelperfunctions.statustable[revivecharacter][revivecostume] ~= nil) then
            update_mod_menu_element_name(modsupporthelperfunctions.statustable[revivecharacter][revivecostume],(string.format("%s (alive)  [%d,%d]",charactertable[revivecharacter][revivecostume].name,revivecharacter,revivecostume)))
        end
        modsupporthelperfunctions.charSelect.character_edit_costume(revivecharacter,revivecostume,characternametable[revivecharacter][revivecostume],nil, nil,nil, nil, nil, nil, nil)
        for i = 1, costumemaxtable[revivecharacter] do --setting back the character icons for the revived character's costumes
            modsupporthelperfunctions.charSelect.character_edit_costume(revivecharacter,i,nil,nil, nil,nil, nil, nil, charactertable[revivecharacter][i].lifeIcon, nil)
        end
        for key,value in pairs(onnuzlockeupdatefunctiontable)do
            value()
        end
    elseif ((dataTable.syncrequest ~= nil) and (dataTable.syncrequest == true)) and (type(dataTable.globalindexofplayer) == "number") then
        local localotherplayerindex = network_local_index_from_global(dataTable.globalindexofplayer)
        local eliminatedtable = {}
        local eliminatedstring
        local eliminatedentry
        local nocharacterseliminated = true
        if not network_is_server() then
            return
        end
        
        for key,value in pairs(otherplayercharactertable[localotherplayerindex])do
            for subkey,subvalue in pairs(otherplayercharactertable[localotherplayerindex][key])do
                if otherplayercharactertable[localotherplayerindex][key][subkey] == false then
                    eliminatedentry = string.format("%d_%d", key,subkey)
                    eliminatedtable[#eliminatedtable+1] = eliminatedentry
                    if nocharacterseliminated == true then
                        nocharacterseliminated = false
                    end
                end
            end
        end
        
        if nocharacterseliminated ~= true then
            eliminatedstring = table.concat(eliminatedtable," ")
            network_send_to(localotherplayerindex,true,{stringofeliminatedcharacters = eliminatedstring})
        end
    elseif (type(dataTable.stringofeliminatedcharacters) == "string") then
        local eliminatedtable = split_string(dataTable.stringofeliminatedcharacters," ")
        local entry
        local characterentry
        local costumeentry
        for key,value in pairs(eliminatedtable)do
            entry = split_string(value,"_")
            characterentry = tonumber(entry[1])
            costumeentry = tonumber(entry[2])
            if (characterentry == nil) or (costumeentry == nil) then
                break
            end
            useablecharacter[characterentry][costumeentry] = false
            update_mod_menu_element_name(modsupporthelperfunctions.statustable[characterentry][costumeentry],(string.format("%s (dead)  [%d,%d]",charactertable[characterentry][costumeentry].name,characterentry,costumeentry)))
            modsupporthelperfunctions.charSelect.character_edit_costume(characterentry,costumeentry,"(x)" ..characternametable[characterentry][costumeentry],nil, nil,nil, nil, nil, nil, nil)
            if (gPlayerSyncTable[0].usingdeadcharacter ~= true) and (characterentry == currentcharacter) and (costumeentry == currentcostume) then
                gPlayerSyncTable[0].usingdeadcharacter = true
            end
            
        end
        for key,value in pairs(onnuzlockeupdatefunctiontable)do
            value()
        end
    elseif(type(dataTable.servernuzlockeresetrequest) ~= "nil") and (dataTable.servernuzlockeresetrequest == true) and (type(dataTable.globalindexofplayer) == "number") then
        if not network_is_server() then
            return
        end
        local localotherplayerindex = network_local_index_from_global(dataTable.globalindexofplayer)
        djui_chat_message_create(string.format("Moderator %s reset the nuzlocke",gNetworkPlayers[localotherplayerindex].name))
        resettable_command()
    elseif(type(dataTable.servernuzlockeresetrequestsingle) ~= "nil") and (dataTable.servernuzlockeresetrequestsingle == true) and (type(dataTable.globalindexofplayer) == "number") then
        if not network_is_server() then
            return
        end
        reset_singlenuzlocketable(network_local_index_from_global(dataTable.globalindexofplayer))
    end
    

end

local function save_nuzlockesettings()
    mod_storage_save_bool("canchangecharacteronexit", gGlobalSyncTable.canchangecharacteronexit)
end

local function load_nuzlockesettings()
    if mod_storage_load_bool("canchangecharacteronexit") then
        gGlobalSyncTable.canchangecharacteronexit = mod_storage_load_bool("canchangecharacteronexit")
    else
        mod_storage_save_bool("canchangecharacteronexit", gGlobalSyncTable.canchangecharacteronexit)
    end
    
end

--function used for built in support for some external mods
local function modsupport()
    
    if _G.charSelect ~= nil then --if the character select mod is on
        modsupporthelperfunctions.charSelect = _G.charSelect --local reference for _G.charSelect
        modsupporthelperfunctions.charselectoptions = {}
        modsupporthelperfunctions.charselectoptions.localmodeltogglepos = modsupporthelperfunctions.charSelect.optionTableRef.localModels --for char select versions 1.1 and up
        modsupporthelperfunctions.charselectoptions.localmovesettogglepos =modsupporthelperfunctions.charSelect.optionTableRef.localMoveset --for char select versions 1.1 and up
        local csversiontable = modsupporthelperfunctions.charSelect.version_get_full()
        if (csversiontable.major > 15) or ((csversiontable.major == 15) and (csversiontable.minor > 1))  then --check for update with character_set_current_number getting second parameter
            charmin = 0
        else
            charmin = 1
        end
        if (csversiontable.major > 15) or ((csversiontable.major == 15) and (csversiontable.minor > 0))  then --check for update with character_set_current_number getting second parameter
            modsupporthelperfunctions.charselectoptions.globalmovesettogglepos =modsupporthelperfunctions.charSelect.optionTableRef.restrictMovesets --for char select versions 1.1 and up
            ---Called once per frame	
            hookupdate = function()
                local m = gMarioStates[0] --the local player's mariostate
                local np = gNetworkPlayers[m.playerIndex] --the local player's ggNetworkPlayers struct
                local currentcscharacter = modsupporthelperfunctions.charSelect.character_get_current_number() --the local player's current character
                local currentcscostume = modsupporthelperfunctions.charSelect.character_get_current_costume() --the local player's current character select costume
                local iscsmenuopen = modsupporthelperfunctions.charSelect.is_menu_open() --whether the cs menu is open
                if (gPlayerSyncTable[0].usingdeadcharacter == true) and (canopencsmenu < 1) and(currentcharacter ~= modsupporthelperfunctions.finalindex) then
                    m.health = 0xff
                elseif gPlayerSyncTable[0].resetingnuzlocketable == true then
                    reset_nuzlocketable(useablecharacter)
                    for key,value in pairs(onnuzlockeresetfunctiontable)do
                        value()
                    end
                    for key,value in pairs(onnuzlockeupdatefunctiontable)do
                        value()
                    end
                    gPlayerSyncTable[0].resetingnuzlocketable = false
                elseif (iscsmenuopen ~= false) and (canopencsmenu == 4) then
                    canopencsmenu = 3
                    modsupporthelperfunctions.charSelect.character_set_current_number(currentcharacter,currentcostume)
                elseif (iscsmenuopen == false) and (canopencsmenu == 3) then
                    if (currentcostume ~= currentcscostume) or (currentcharacter ~= currentcscharacter) then
                        modsupporthelperfunctions.charSelect.character_set_current_number(currentcharacter,currentcostume)
                    else
                        canopencsmenu = 0
                    end

                elseif (iscsmenuopen ~= false) and (canopencsmenu == 2) then
                    canopencsmenu = 1
                elseif (iscsmenuopen == false) and (canopencsmenu == 1) then
                    canopencsmenu = 0
                    currentcostume = currentcscostume
                    currentcharacter = currentcscharacter
                    if currentcharacter ~= modsupporthelperfunctions.finalindex then
                        currentcharacttype = (charactertable[currentcharacter][currentcostume]).forceChar
                    else
                        currentcharacttype = CT_MARIO
                    end
                    
                elseif ((currentcscharacter ~= currentcharacter) or (currentcostume ~= currentcscostume)) and (canopencsmenu == 0) then
                    modsupporthelperfunctions.charSelect.character_set_current_number(currentcharacter,currentcostume)
                elseif (currentcscharacter ~= modsupporthelperfunctions.finalindex) and (useablecharacter[currentcscharacter] ~= nil) and (useablecharacter[currentcscharacter][currentcscostume] ~= true) then
                    canopencsmenu = 2
                    modsupporthelperfunctions.charSelect.set_menu_open(true)
        
                end
                if (iscsmenuopen)  then
                    if (modsupporthelperfunctions.charSelect.get_options_status(modsupporthelperfunctions.charselectoptions.localmodeltogglepos) == 0) then
                        modsupporthelperfunctions.charSelect.set_options_status(modsupporthelperfunctions.charselectoptions.localmodeltogglepos,1)
                    elseif (modsupporthelperfunctions.charSelect.get_options_status(modsupporthelperfunctions.charselectoptions.globalmovesettogglepos) == 0) and (modsupporthelperfunctions.charSelect.get_options_status(modsupporthelperfunctions.charselectoptions.localmovesettogglepos) == 0) then
                        modsupporthelperfunctions.charSelect.set_options_status(modsupporthelperfunctions.charselectoptions.localmovesettogglepos,1)
                    end
                end
            end
        else
            log_to_console(string.format("character select version %s is older than the supported version for character nuzlocke please update at https://github.com/Squishy6094/character-select-coop/releases ",modsupporthelperfunctions.charSelect.version_get()),1)
            ---Called once per frame	
            hookupdate = function()
                local m = gMarioStates[0] --the local player's mariostate
                local np = gNetworkPlayers[m.playerIndex] --the local player's ggNetworkPlayers struct
                local currentcscharacter = modsupporthelperfunctions.charSelect.character_get_current_number() --the local player's current character
                local currentcscostume = modsupporthelperfunctions.charSelect.character_get_current_costume() --the local player's current character select costume
                local iscsmenuopen = modsupporthelperfunctions.charSelect.is_menu_open() --whether the cs menu is open
                if (gPlayerSyncTable[0].usingdeadcharacter == true) and (canopencsmenu < 1) and(currentcharacter ~= modsupporthelperfunctions.finalindex) then
                    m.health = 0xff
                elseif gPlayerSyncTable[0].resetingnuzlocketable == true then
                    reset_nuzlocketable(useablecharacter)
                    for key,value in pairs(onnuzlockeresetfunctiontable)do
                        value()
                    end
                    for key,value in pairs(onnuzlockeupdatefunctiontable)do
                        value()
                    end
                    gPlayerSyncTable[0].resetingnuzlocketable = false
                elseif (iscsmenuopen ~= false) and (canopencsmenu == 4) then
                    djui_chat_message_create(string.format("switch back to %s (character slot %d costume slot %d charactertype %d )",charactertable[currentcharacter][currentcostume].name,currentcharacter,currentcostume,currentcharacttype ))
                    canopencsmenu = 3
                    modsupporthelperfunctions.charSelect.character_set_current_number(currentcharacter)
                elseif (iscsmenuopen == false) and (canopencsmenu == 3) then
                    if (currentcostume ~= currentcscostume) or (currentcharacter ~= currentcscharacter) then
                        canopencsmenu = 4
                        modsupporthelperfunctions.charSelect.set_menu_open(true)
                        modsupporthelperfunctions.charSelect.character_set_current_number(currentcharacter)
                    else
                        canopencsmenu = 0
                        modsupporthelperfunctions.charSelect.set_menu_open(false)
                    end

                elseif (iscsmenuopen ~= false) and (canopencsmenu == 2) then
                    canopencsmenu = 1
                elseif (iscsmenuopen == false) and (canopencsmenu == 1) then
                    canopencsmenu = 0
                    currentcostume = currentcscostume
                    currentcharacter = currentcscharacter
                    if currentcharacter ~= modsupporthelperfunctions.finalindex then
                        currentcharacttype = (charactertable[currentcharacter][currentcostume]).forceChar
                    else
                        currentcharacttype = CT_MARIO
                    end
                elseif (canopencsmenu == 1)  then
                    if (modsupporthelperfunctions.charSelect.get_options_status(modsupporthelperfunctions.charselectoptions.localmodeltogglepos) == 0) then
                        modsupporthelperfunctions.charSelect.set_options_status(modsupporthelperfunctions.charselectoptions.localmodeltogglepos,1)
                    elseif (modsupporthelperfunctions.charSelect.get_options_status(modsupporthelperfunctions.charselectoptions.localmovesettogglepos) == 0) then
                        modsupporthelperfunctions.charSelect.set_options_status(modsupporthelperfunctions.charselectoptions.localmovesettogglepos,1)
                    end
                elseif (iscsmenuopen ~= false) and (canopencsmenu < 1) then
                    modsupporthelperfunctions.charSelect.set_menu_open(false)
                elseif ((currentcscharacter ~= currentcharacter) or (currentcostume ~= currentcscostume)) and (canopencsmenu == 0) then
                    djui_chat_message_create(string.format("switch back to %s (character slot %d costume slot %d charactertype %d )",charactertable[currentcharacter][currentcostume].name,currentcharacter,currentcostume,currentcharacttype ))
                    canopencsmenu = 4
                    modsupporthelperfunctions.charSelect.set_menu_open(true)
                    modsupporthelperfunctions.charSelect.character_set_current_number(currentcharacter)
                elseif (currentcscharacter ~= modsupporthelperfunctions.finalindex) and (useablecharacter[currentcscharacter] ~= nil) and (useablecharacter[currentcscharacter][currentcscostume] ~= true) then
                    canopencsmenu = 2
                    modsupporthelperfunctions.charSelect.set_menu_open(true)
        
                end
            end
            _G.charselectnuzlockeapi.set_nuzlockecharacter = function(cscharacterindex,cscharactercostumeindex)
                if gPlayerSyncTable[0].nocharacters == true then
                    return
                elseif (cscharacterindex ~= nil) and (cscharactercostumeindex == nil) then
                    if (useablecharacter[cscharacterindex] ~= nil) and (useablecharacter[cscharacterindex] ~= nil) and (useablecharacter[cscharacterindex][cscharactercostumeindex] == true) then
                        currentcostume = cscharactercostumeindex
                        currentcharacter = cscharacterindex
                        currentcharacttype = (charactertable[cscharacterindex][currentcostume]).forceChar
                        canopencsmenu = 4
                        log_to_console(string.format("current character changed to %s (character slot %d costume slot %d charactertype %d ) by a mod using character select nuzlocke's api",charactertable[currentcharacter][currentcostume].name,currentcharacter,currentcostume,currentcharacttype ))
        
                        return true
                    else
                        log_to_console(string.format("Either the character number of a dead character was passed or an invalid character number was passed to set_nuzlockecharacter function character select nuzlocke mod version is %s",version), 1)
                        return false
                    end
        
                elseif (useablecharacter[cscharacterindex] ~= nil) and (useablecharacter[cscharacterindex][cscharactercostumeindex] == true) then
                    currentcharacter = cscharacterindex
                    currentcostume= cscharactercostumeindex
                    currentcharacttype = (charactertable[cscharacterindex][cscharactercostumeindex]).forceChar
                    canopencsmenu = 0
                    log_to_console(string.format("current character changed to %s (character slot %d costume slot %d charactertype %d ) by a mod using character select nuzlocke's api",charactertable[currentcharacter][currentcostume].name,currentcharacter,currentcostume,currentcharacttype ))
                    return true
                else
                    log_to_console(string.format("Either the character number and costume number of a dead character was passed or an invalid character number and costume number where passed to set_nuzlockecharacter function character select nuzlocke mod version is %s",version), 1)
                    return false
                end
        
            end
        end
        
        hook_event(HOOK_ON_LEVEL_INIT, on_level_init) -- Called when the level is initialized

        hook_event(HOOK_ON_DEATH, on_death) --hook for the player dying
    
        hook_event(HOOK_UPDATE, hookupdate) -- hook that is called once per frame
        
        if not othermodsetresetonsavesetting then
            for key,value in pairs(gActiveMods) do
                if (value.incompatible ~= nil) and string.match((value.incompatible), "gamemode") then
                    resetsaveonreset = false
                end
            end
        end
            local resetnuzlocktext = "reset nuzlocke"
            if resetsaveonreset then
                resetnuzlocktext = resetnuzlocktext .."(This option will reset the current save)"
            end
            hook_mod_menu_button(resetnuzlocktext,function(index)
                resettable_command()
            end)
            modsupporthelperfunctions.canchangecharacteronexitpos = hook_mod_menu_button("changing character on pause exit is " .. bool_to_str[gGlobalSyncTable.canchangecharacteronexit],function(index)
                nuzlockechangecharacterpause_command(bool_to_str[not gGlobalSyncTable.canchangecharacteronexit])
            end)
            hook_mod_menu_text("when on hold b when pause exiting to not change characters")

            hook_mod_menu_button("save current nuzlocke settings",function(index)
                characterselectnuzlockeconfig_command("save")
            end)
            hook_mod_menu_button("load current nuzlocke settings",function(index)
                characterselectnuzlockeconfig_command("load")
            end)
            if _G.mhApi ~= nil and (not teamfunctionsetbyothermod) then
                modsupporthelperfunctions.mhApi = _G.mhApi --local reference for _G.mhApi
                teamfunction = function (m)
                    local isfreeforall = false --whether its a free for all or not false if it is not a freeforall 
                    local currentteam = modsupporthelperfunctions.mhApi.getTeam(m.playerIndex)--the current team the mariostate is on
                    return isfreeforall,currentteam
                end
            elseif (_G.ShineThief ~= nil) and (not teamfunctionsetbyothermod) then
                modsupporthelperfunctions.ShineThief = _G.ShineThief --local reference for _G.ShineThief
                teamfunction = function (m)
                    local isfreeforall = false --whether its a free for all or not false if it is not a freeforall 
                    local currentteam = modsupporthelperfunctions.ShineThief.getTeam(m.playerIndex)--the current team the mariostate is on
                    return isfreeforall,currentteam
                end
            elseif not teamfunctionsetbyothermod then
                teamfunction = function (m)
                    local currentteam = 0 --the current team the mariostate is on
                    return gGlobalSyncTable.isfreeforall,currentteam
                end
                hook_mod_menu_checkbox("toggle nuzlocke free for all",gGlobalSyncTable.isfreeforall,function(index,value)
                    if not network_is_server() then
                        return
                    end
                    gGlobalSyncTable.isfreeforall = not gGlobalSyncTable.isfreeforall
                    value = gGlobalSyncTable.isfreeforall
                end)
            end
    else
        log_to_console(string.format("the character select mod was not found. \n This mod relies on the character select mod to function which can be found at https://github.com/Squishy6094/character-select-coop/releases \n  character select nuzlocke mod version is %s",version), 2)

    end
    

end

--- @param m MarioState
--Called when a player connects
local function on_player_connected(m)
    -- only run on server
    if not network_is_server() then
        return
	end
    if servermodsync == false then
        modsupport()
        servermodsync = true
        load_nuzlockesettings()
    end
end

--Called when the local player finishes the join process (if the player isn't the host)
local function on_join()
    if servermodsync == false then
        modsupport()
        servermodsync = true
    end

end

---@param m MarioState
--Called once per player per frame at the end of a mario update
local function before_mario_update(m)
    if m.playerIndex ~= 0 then return end
    if sendingpackets then
        local playerglobalindex = gNetworkPlayers[0].globalIndex --global index of the local player
        local isfreeforall --whether it is a freeforall
        local localplayerteam --the local player's team
        local otherplayerteam --another player's team
        local x
        isfreeforall,localplayerteam = teamfunction(m)
            if (isfreeforall ~= true) and (lastdeadcharacter ~= modsupporthelperfunctions.finalindex) then
                for i = 1,MAX_PLAYERS - 1 do
                    x,otherplayerteam = teamfunction(gMarioStates[i])
                    if (localplayerteam == otherplayerteam) or (gNetworkPlayers[gMarioStates[i].playerIndex].globalIndex == 0) then
                        network_send_to(gMarioStates[i].playerIndex,true,{diedascharacter = lastdeadcharacter,diedascostume = lastdeadcostume,globalindexofplayer = playerglobalindex,diedinstage = lastdeadstage})
                        if network_is_server() and otherplayercharactertable[i] ~= nil and otherplayercharactertable[i][lastdeadcharacter] ~= nil  then
                            otherplayercharactertable[i][lastdeadcharacter][lastdeadcostume] = false
                        end
                    end
                end
            end
            lastdeadcostume = modsupporthelperfunctions.charSelect.character_get_current_costume()
            lastdeadcharacter = modsupporthelperfunctions.charSelect.character_get_current_number()
            lastdeadstage = get_level_name(gNetworkPlayers[0].currCourseNum, gNetworkPlayers[0].currLevelNum, gNetworkPlayers[0].currAreaIndex)
            sendingpackets = false
    end
end

---@param usedExitToCastle boolean
--Called when the local player exits through the pause screen, return false to prevent the exit
local function on_pause_exit(usedExitToCastle)
    local m = gMarioStates[0]
    if ((m.pos.y ~= m.floorHeight) and (m.input & INPUT_IN_WATER == 0)) or (m.hurtCounter > 0) then
        return false
    elseif gGlobalSyncTable.canchangecharacteronexit and (m.controller.buttonDown & B_BUTTON == 0) then
        canopencsmenu = 2
        modsupporthelperfunctions.charSelect.set_menu_open(true)
    end
end

hook_event(HOOK_ON_PACKET_RECEIVE	, on_packet_receive) --Called when the mod receives a packet that used network_send() or network_send_to()

hook_event(HOOK_ON_PLAYER_CONNECTED, on_player_connected) -- hook for player joining

hook_event(HOOK_JOINED_GAME, on_join) -- Called when the local player finishes the join process (if the player isn't the host)

hook_event(HOOK_BEFORE_MARIO_UPDATE, before_mario_update) -- Called when the local player finishes the join process (if the player isn't the host)

hook_event(HOOK_ON_PAUSE_EXIT, on_pause_exit) --Called when the local player exits through the pause screen, return false to prevent the exit

--command to reset the nuzlocke
resettable_command = function()
    if (not network_is_server()) and (not network_is_moderator()) then
        djui_chat_message_create('Only the host or a mod can change this setting!')
        return true
    elseif (not network_is_server()) then
        network_send_to(network_local_index_from_global(0),true,{servernuzlockeresetrequest = true,globalindexofplayer = gNetworkPlayers[0]})
        return true
    end
    if resetsaveonreset == true then
        resetnuzlocksavefunction()
    end
    
    for i = 0,MAX_PLAYERS - 1 do
        gPlayerSyncTable[i].nocharacters = false
        gPlayerSyncTable[i].resetingnuzlocketable = true
        if i > 0 then
            reset_nuzlocketable(otherplayercharactertable[i])
        end
    end
    return true
end

--- @param msg string
--this function toggles changing character on pauseexit
nuzlockechangecharacterpause_command = function(msg)
    if not network_is_server() then
        djui_chat_message_create('Only the host can change this setting!')
        return true
    end
	local m = string.lower(msg)
    if m == 'on' then
        djui_chat_message_create('changing character on pause exit is \\#00C7FF\\on\\#ffffff\\!')
		gGlobalSyncTable.canchangecharacteronexit = true 
        return true
	elseif m == 'off' then
		djui_chat_message_create('changing character on pause exit is \\#A02200\\off\\#ffffff\\!')
		gGlobalSyncTable.canchangecharacteronexit = false 
		return true
	else
		return false
    end
end

--- @param msg string
--this function allows the host to revive a character
nuzlockerevivecharacter_command = function(msg)
    if not network_is_server() then
        djui_chat_message_create('Only the host can change this setting!')
        return true
    end
    local revivetable = split_string(msg," ")
    if #revivetable == 3 then --revive character by character and costume position for a player
        server_revive_character_for_player(tonumber(revivetable[1]),tonumber(revivetable[2]),tonumber(revivetable[3]))
        return true
    elseif #revivetable == 2 then --revive character by name for a player
        server_revive_character_for_player(tonumber(revivetable[1]),revivetable[2]:gsub("^%s*(.-)%s*$", "%1"))
        return true
    end
end

--- @param msg string
--this is the function for save server settings or loading them
characterselectnuzlockeconfig_command = function(msg)
    local m = string.lower(msg)
    if m == 'save' then
        save_nuzlockesettings()
        return true
    elseif m == 'load' then
        if not network_is_server() and not network_is_moderator then
            djui_chat_message_create('Only the host or a mod can change this setting!')
            return true
        else
            load_nuzlockesettings()
            return true
        end
    end

end

hook_chat_command('resetnuzlocketable', "reset nuzlocke", resettable_command)

hook_chat_command('nuzlockechangecharacterpause', "toggle changing character after pause exiting a stage when on can hold b when pause exiting to stick to current character instead", nuzlockechangecharacterpause_command)

hook_chat_command('nuzlockerevivecharacter', "revive a character for a player and their team using either the character's name or their table position and costume position. 1st argument is the player to revive the character for.", nuzlockerevivecharacter_command)

hook_chat_command('characterselectnuzlockeconfig', "[save|load] to save the current character select nuzlocke settings to a file or load them (loading only works if used by a moderator or the server)", characterselectnuzlockeconfig_command)


hook_mod_menu_text(string.format("Character Select Nuzlocke version %s",version))



hook_on_sync_table_change(gGlobalSyncTable,"canchangecharacteronexit","tag",function(tag, oldVal, newVal)
    update_mod_menu_element_name(modsupporthelperfunctions.canchangecharacteronexitpos,"changing character on pause exit is " .. bool_to_str[gGlobalSyncTable.canchangecharacteronexit])
end)



--character select nuzlocke api functions
_G.charselectnuzlockeapi = {
    --- @param func function function to check if the local player is on the same team as the kirby projectile's owner
    --function for other mods to add a team check for gamemodes 
    addteamcheck = function(func)
        teamfunctionsetbyothermod = true
        teamfunction = func --expects the function to have parameters customfunc(m) param m mariostate and the function should return two values isfreeforall which is a boolean and currentteam which is a number
        --[[example function
        teamfunction = function (m)
            local isfreeforall = false --whether its a free for all or not false if it is not a freeforall 
            local currentteam = 0 --the current team the mariostate is on
            return isfreeforall,currentteam
        end ]]
    end,
    --function that lets other mods get a table of only the current dead characters
    get_deadcharactertable = function()
        local tableofdeadcharacters = {}
        for i = charmin,charmax do
            for j = 1, costumemaxtable[i] do
                if useablecharacter[i][j] ~= true then
                    table.insert(tableofdeadcharacters,{i,j})
                end
            end
        end
        return tableofdeadcharacters
    end,
    ---@param index number? the index of the player to see if they have no characters
    ---this function lets other mods see if a player has no characters
    get_hascharacterstatus = function(index)
        if index == nil then
            return gPlayerSyncTable[0].nocharacters
        elseif (type(index) == "number") and (index >= 0) and (index < MAX_PLAYERS) then
            return gPlayerSyncTable[index].nocharacters
        else
            log_to_console(string.format("invalid playerindex was passed to get_hascharacterstatus function character select nuzlocke mod version is %s",version), 1)
        end
    end,
    ---@param includelocked boolean? --whether to include locked characters in the returned table
    --function that lets other mods get a table of only the current living characters
    get_livingcharactertable = function(includelocked)
        local sizeoflivingtable = 0
        local tableoflivingcharacters = {}
        local copychartable
        if includelocked then
            for i = charmin,charmax do
                for j = 1, costumemaxtable[i] do
                    if useablecharacter[i][j] == true then
                        table.insert(tableoflivingcharacters,{i,j})
                        sizeoflivingtable = sizeoflivingtable + 1
                    end
                end
            end
        else
            copychartable = modsupporthelperfunctions.charSelect.character_get_full_table()
            for i = charmin,charmax do
                for j = 1, costumemaxtable[i] do
                    if (useablecharacter[i][j] == true) and (copychartable[i][j].locked ~= 1) then
                        table.insert(tableoflivingcharacters,{i,j})
                        sizeoflivingtable = sizeoflivingtable + 1
                    end
                end
            end
        end
        
        return tableoflivingcharacters,sizeoflivingtable
    end,
    --- function to allow other mods to get the current resetnuzlocksavefunction function
    get_resetnuzlocksavefunction = function()
        return resetnuzlocksavefunction
    end,
    --resets the nuzlocke table for everyone
    reset_nuzlocketable = function()
        resettable_command()
    end,
    ---@param bool boolean whether the save should be reset with nuzlocke reset if true the save will be reset with nuzlocke table reset
    --function to for other mods to set if this mod will reset the save with nuzlocke table reset
    reset_save_on_reset = function(bool)
        othermodsetresetonsavesetting = true
        resetsaveonreset = bool
    end,
    --- @param func function function to run when the local player's nuzlocke table is reset
    --- function to allow other mods to run code when the local player's nuzlocke table is reset
    on_nuzlockereset = function(func)
        onnuzlockeresetfunctiontable[#onnuzlockeresetfunctiontable + 1] = func
    end,
     --- @param func function function to run when the local player's nuzlocke table updates
    --- function to allow other mods to run code whenever the local player's nuzlocke table changes
    on_nuzlocketableupdate = function(func)
        onnuzlockeupdatefunctiontable[#onnuzlockeupdatefunctiontable + 1] = func
    end,
    ---arg[1] playerindex number the local player index of a player to revive a character for
    ---arg[2] charactertorevive number the character to revive's position in the character select table
    ---arg[3] costumeofcharactertorevive number the costume number of the character to revive in the character select table
    ---alt arg[2] charactername string the name of a character in the character select table
    --function used by the host to revive a character for a player
    server_revive_character_for_player = server_revive_character_for_player,
    ---@param index number local index of the player whose nuzlocke table should be reset
--this function resets the nuzlocke table of a single player
    reset_nuzlocketableofspecificplayer = function(index)
        reset_singlenuzlocketable(index)
    end,
    ---@param cscharacterindex number the cs character to switch to's position in the character select table
    ---@param cscharactercostumeindex number the costume of the cs character to switch to in the character select table
    ---this function allows other mods to set the current nuzlocke character
    set_nuzlockecharacter = function(cscharacterindex,cscharactercostumeindex)
        if gPlayerSyncTable[0].nocharacters == true then
            return
        elseif (cscharacterindex ~= nil) and (cscharactercostumeindex == nil) then
            if (useablecharacter[cscharacterindex] ~= nil) and (useablecharacter[cscharacterindex] ~= nil) and (useablecharacter[cscharacterindex][cscharactercostumeindex] == true) then
                currentcostume = cscharactercostumeindex
                currentcharacter = cscharacterindex
                currentcharacttype = (charactertable[cscharacterindex][currentcostume]).forceChar
                canopencsmenu = 0
                log_to_console(string.format("current character changed to %s (character slot %d costume slot %d charactertype %d ) by a mod using character select nuzlocke's api",charactertable[currentcharacter][currentcostume].name,currentcharacter,currentcostume,currentcharacttype ))

                return true
            else
                log_to_console(string.format("Either the character number of a dead character was passed or an invalid character number was passed to set_nuzlockecharacter function character select nuzlocke mod version is %s",version), 1)
                return false
            end

        elseif (useablecharacter[cscharacterindex] ~= nil) and (useablecharacter[cscharacterindex][cscharactercostumeindex] == true) then
            currentcharacter = cscharacterindex
            currentcostume= cscharactercostumeindex
            currentcharacttype = (charactertable[cscharacterindex][cscharactercostumeindex]).forceChar
            canopencsmenu = 0
            return true
        else
            log_to_console(string.format("Either the character number and costume number of a dead character was passed or an invalid character number and costume number where passed to set_nuzlockecharacter function character select nuzlocke mod version is %s",version), 1)
            return false
        end

    end,
    --- @param func function function to run when resetting nuzlocke save
    --- function to allow other mods to replace the function character select nuzlocke uses to reset the current save. 
    set_resetnuzlocksavefunction = function(func)
        resetnuzlocksavefunction = func
    end,
    --- @param func function function to run when the local player has no characters left
    --- function to allow other mods to run code when the local player runs out of characters
    on_nocharactersleftfunction = function(func)
        onnocharactersfunctiontable[#onnocharactersfunctiontable + 1] = func
    end,
    --this function returns the current version of the mod
    get_version = function()
        return version
    end

}

modsupporthelperfunctions.charselectnuzlockeapi = _G.charselectnuzlockeapi --local reference for _G.charselectnuzlockeapi

