local basalt = require("basalt")
local dfpwm = require("cc.audio.dfpwm")

local speaker = peripheral.find("speaker")
if not speaker then
    error("Speaker não encontrado!")
end

-- Ative HTTP no arquivo config: "http.enable=true"

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

-- UI
local frame = basalt.createFrame()
frame:setBackground(colors.black)

local header = frame:addFrame():setPosition(1,1):setSize(51,3):setBackground(colors.blue)
header:addLabel():setText("ELF4IRIES MUSIC PLAYER"):setPosition(2,2):setForeground(colors.cyan)

local list = frame:addList():setPosition(2,5):setSize(30,15):setBackground(colors.gray):setForeground(colors.white)
for _, n in ipairs(songNames) do list:addItem(n) end

local right = frame:addFrame():setPosition(33,5):setSize(17,15):setBackground(colors.black)

local nowLabel = right:addLabel():setText("Tocando:"):setPosition(1,1):setForeground(colors.lightBlue)
local songLabel = right:addLabel():setText("-"):setPosition(1,2):setForeground(colors.white)
local statusLabel = right:addLabel():setText("Parado"):setPosition(1,3):setForeground(colors.orange)

local progBar = right:addLabel():setText(""):setPosition(1,5):setSize(17,1)

local function updateProgress(p)
    p = math.max(0, math.min(100, math.floor(p)))
    local w = 17
    local fill = math.floor(w * p / 100)
    progBar:setText(string.rep("█", fill))
end

-- Botões simples ASCII
local btnPlay = right:addButton():setText("[PLAY]"):setPosition(2,7):setSize(12,1):setBackground(colors.cyan)
local btnPause = right:addButton():setText("[PAUSE]"):setPosition(2,8):setSize(12,1):setBackground(colors.lightBlue)
local btnStop = right:addButton():setText("[STOP]"):setPosition(2,9):setSize(12,1):setBackground(colors.blue)
local btnNext = right:addButton():setText("[NEXT]"):setPosition(2,10):setSize(12,1):setBackground(colors.gray)
local btnPrev = right:addButton():setText("[PREV]"):setPosition(2,11):setSize(12,1):setBackground(colors.gray)

local volLabel = right:addLabel():setText("Vol:"):setPosition(1,13):setForeground(colors.lightBlue)
local volDown = right:addButton():setText("-"):setPosition(1,14):setSize(7,1):setBackground(colors.gray)
local volUp = right:addButton():setText("+"):setPosition(9,14):setSize(7,1):setBackground(colors.gray)
local volValue = right:addLabel():setText("100%"):setPosition(6,13):setForeground(colors.white)

-- ====== Funções ======
local function stopAudio()
    isPlaying = false
    isPaused = false
    statusLabel:setText("Parado"):setForeground(colors.orange)
    progBar:setText("")
end

local function playMusic(index)
    stopAudio()
    currentSong = index
    songLabel:setText(songNames[index])
    statusLabel:setText("Carregando..."):setForeground(colors.yellow)

    local ok, handle = pcall(http.get, playlist[index])
    if not ok or not handle then
        statusLabel:setText("Erro HTTP"):setForeground(colors.red)
        return
    end

    local decoder = dfpwm.make_decoder()
    isPlaying = true
    statusLabel:setText("Tocando"):setForeground(colors.lime)

    local totalBytes, processed = 1, 0
    while isPlaying do
        if isPaused then
            os.sleep(0.1)
        else
            local chunk = handle.read(16 * 1024)
            if not chunk then break end
            processed = processed + #chunk
            local buffer = decoder(chunk)
            speaker.playAudio(buffer, volume)

            updateProgress((processed / totalBytes) * 100)
            os.sleep(0.05)
        end
    end
    handle.close()
    stopAudio()
end

-- ====== Eventos ======
list:onSelect(function(_, _, item)
    local index = list:getItemIndex(item)
    playMusic(index)
end)

btnPlay:onClick(function()
    playMusic(currentSong)
end)

btnPause:onClick(function()
    isPaused = not isPaused
    if isPaused then
        statusLabel:setText("Pausado"):setForeground(colors.orange)
    else
        statusLabel:setText("Tocando"):setForeground(colors.lime)
    end
end)

btnStop:onClick(stopAudio)

btnNext:onClick(function()
    currentSong = currentSong + 1
    if currentSong > #playlist then currentSong = 1 end
    playMusic(currentSong)
end)

btnPrev:onClick(function()
    currentSong = currentSong - 1
    if currentSong < 1 then currentSong = #playlist end
    playMusic(currentSong)
end)

volDown:onClick(function()
    volume = math.max(0, volume - 0.1)
    volValue:setText(math.floor(volume * 100) .. "%")
end)

volUp:onClick(function()
    volume = math.min(1, volume + 0.1)
    volValue:setText(math.floor(volume * 100) .. "%")
end)

-- Execução
basalt.run()
