local basalt = require("basalt")
local dfpwm = require("cc.audio.dfpwm")

local speaker = peripheral.find("speaker")
if not speaker then
    error("Speaker não encontrado!")
end

-- 🎵 Playlist completa
local playlist = {
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/AURORA - Apple Tree.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/AURORA - Cure For Me.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/AURORA - Murder Song (5, 4, 3, 2, 1).f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Bela Lugosi's Dead (Official Version).f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Conqueror.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Dark Entries.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Dracula Teeth.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Lady Gaga - The Dead Dance (slowed + reverb).f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Monolith.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Silent Hedges.f234.dfpwm"
}

local songNames = {}
for i, url in ipairs(playlist) do
    local name = url:match("([^/]+)%.f234%.dfpwm$") or ("Música " .. i)
    if #name > 28 then name = name:sub(1,28) .. "..." end
    songNames[i] = name
end

local currentSong = 1
local isPlaying = false
local isPaused = false
local volume = 1.0
local decoder = nil
local audioHandle = nil
local currentTime = 0

local function safePlayAudio(buffer)
    local ok, res = pcall(function() return speaker.playAudio(buffer, volume) end)
    return ok and res
end

local function stopAudio()
    isPlaying = false
    isPaused = false
    if audioHandle then pcall(function() audioHandle.close() end) end
    audioHandle = nil
end

-- ===== UI =====
local explorerFrame = basalt.createFrame()
local playerFrame = basalt.createFrame()
basalt.setActiveFrame(explorerFrame)

-- === FRAME EXPLORADOR ===
local title = explorerFrame:addLabel()
title:setText("🎵 ELF4IRIES MUSIC PLAYER")
title:setPosition(2,1)
title:setForeground(colors.cyan)

local songList = explorerFrame:addList()
songList:setPosition(2,3)
songList:setSize(45,14)
for _, name in ipairs(songNames) do songList:addItem(name) end

local playBtn = explorerFrame:addButton()
playBtn:setText("▶ Tocar")
playBtn:setPosition(2,18)
playBtn:setSize(12,2)
playBtn:setBackground(colors.green)

-- === FRAME PLAYER ===
local header = playerFrame:addLabel()
header:setText("🎶 Tocando agora:")
header:setPosition(2,1)
header:setForeground(colors.yellow)

local nowPlaying = playerFrame:addLabel()
nowPlaying:setText("")
nowPlaying:setPosition(2,2)
nowPlaying:setForeground(colors.white)

local status = playerFrame:addLabel()
status:setText("Parado")
status:setPosition(2,3)
status:setForeground(colors.orange)

local progress = playerFrame:addLabel()
progress:setPosition(2,5)
progress:setSize(45,1)
progress:setText("")

local pauseBtn = playerFrame:addButton()
pauseBtn:setText("⏸ Pausar")
pauseBtn:setPosition(2,7)
pauseBtn:setSize(10,2)
pauseBtn:setBackground(colors.yellow)
pauseBtn:setForeground(colors.black)

local stopBtn = playerFrame:addButton()
stopBtn:setText("⏹ Parar")
stopBtn:setPosition(14,7)
stopBtn:setSize(10,2)
stopBtn:setBackground(colors.red)

local nextBtn = playerFrame:addButton()
nextBtn:setText("⏭ Próxima")
nextBtn:setPosition(26,7)
nextBtn:setSize(10,2)
nextBtn:setBackground(colors.gray)

local volLabel = playerFrame:addLabel()
volLabel:setText("Volume:")
volLabel:setPosition(2,10)
volLabel:setForeground(colors.yellow)

local volValue = playerFrame:addLabel()
volValue:setText("100%")
volValue:setPosition(10,10)
volValue:setForeground(colors.white)

local volDown = playerFrame:addButton()
volDown:setText("-")
volDown:setPosition(2,11)
volDown:setSize(4,1)
volDown:setBackground(colors.lightGray)

local volUp = playerFrame:addButton()
volUp:setText("+")
volUp:setPosition(7,11)
volUp:setSize(4,1)
volUp:setBackground(colors.lightGray)

local backBtn = playerFrame:addButton()
backBtn:setText("🔙 Voltar ao Menu")
backBtn:setPosition(2,13)
backBtn:setSize(18,2)
backBtn:setBackground(colors.gray)

-- ===== FUNÇÕES DE ÁUDIO =====
local function playSong(index)
    stopAudio()
    currentSong = index
    nowPlaying:setText(songNames[index])
    status:setText("Carregando...")
    status:setForeground(colors.yellow)
    basalt.schedule(function()
        local ok, handle = pcall(http.get, playlist[index])
        if not ok or not handle then
            status:setText("Erro ao carregar!")
            status:setForeground(colors.red)
            return
        end
        audioHandle = handle
        decoder = dfpwm.make_decoder()
        isPlaying = true
        isPaused = false
        currentTime = 0
        status:setText("Tocando")
        status:setForeground(colors.lime)
        while isPlaying do
            if not isPaused then
                local chunk = audioHandle.read(16*1024)
                if not chunk then
                    stopAudio()
                    status:setText("Fim da música")
                    progress:setText("")
                    break
                end
                local buffer = decoder(chunk)
                safePlayAudio(buffer)
                currentTime = (currentTime + 1) % 45
                progress:setText(string.rep("█", currentTime))
            else
                os.sleep(0.1)
            end
        end
    end)
end

-- ===== EVENTOS =====
songList:onSelect(function(_,_,item)
    local idx = songList:getItemIndex(item)
    basalt.setActiveFrame(playerFrame)
    playSong(idx)
end)

playBtn:onClick(function()
    basalt.setActiveFrame(playerFrame)
    playSong(1)
end)

pauseBtn:onClick(function()
    if isPlaying then
        isPaused = not isPaused
        if isPaused then
            status:setText("Pausado")
            status:setForeground(colors.orange)
        else
            status:setText("Tocando")
            status:setForeground(colors.lime)
        end
    end
end)

stopBtn:onClick(function()
    stopAudio()
    status:setText("Parado")
    status:setForeground(colors.orange)
end)

nextBtn:onClick(function()
    local nextSong = currentSong + 1
    if nextSong > #playlist then nextSong = 1 end
    playSong(nextSong)
end)

volDown:onClick(function()
    volume = math.max(0, volume - 0.1)
    volValue:setText(math.floor(volume * 100).."%")
end)

volUp:onClick(function()
    volume = math.min(1, volume + 0.1)
    volValue:setText(math.floor(volume * 100).."%")
end)

backBtn:onClick(function()
    stopAudio()
    basalt.setActiveFrame(explorerFrame)
end)

basalt.autoUpdate()
