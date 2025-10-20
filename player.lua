-- ELF4IRIES MUSIC PLAYER - versão compatível universal 💙
-- tema navy, shuffle ativo, sem erros de progressbar/hide/show

-- 🔧 verifica e carrega basalt
if not fs.exists("/basalt") then
    print("Baixando Basalt...")
    shell.run("pastebin run ESs1mg7P")
end

local basalt = require("basalt")
local dfpwm = require("cc.audio.dfpwm")

-- 🎶 playlist
local playlist = {
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/AURORA%20-%20Apple%20Tree.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/AURORA%20-%20Cure%20For%20Me.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/AURORA%20-%20Murder%20Song%20(5,%204,%203,%202,%201).f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Bela%20Lugosi's%20Dead%20(Official%20Version).f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Conqueror.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Dark%20Entries.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Dracula%20Teeth.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Lady%20Gaga%20-%20The%20Dead%20Dance%20(slowed%20+%20reverb).f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Monolith.f234.dfpwm",
    "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Silent%20Hedges.f234.dfpwm"
}

local songNames = {}
for i, url in ipairs(playlist) do
    local name = url:match("([^/]+)%.f234%.dfpwm$") or ("Música " .. i)
    name = name:gsub("%%20", " ")
    if #name > 28 then name = name:sub(1, 28) .. "..." end
    songNames[i] = name
end

-- ⚙️ variáveis principais
local speaker = peripheral.find("speaker")
local currentSong = 1
local isPlaying, isPaused = false, false
local volume = 1.0
local shuffle = true
local repeatTrack = false
local audioHandle = nil
local decoder = dfpwm.make_decoder()
local progressValue = 0

-- 🧠 ui base
local main = basalt.createFrame():setBackground(colors.black)
local playlistFrame = main:addFrame():setSize("parent.w", "parent.h"):setBackground(colors.black)
local playerFrame = main:addFrame():setSize("parent.w", "parent.h"):setBackground(colors.black):setVisible(false)

-- 🎨 cabeçalho
playlistFrame:addFrame():setSize("parent.w", 3):setBackground(colors.blue)
    :addLabel():setText("ELF4IRIES MUSIC PLAYER"):setPosition(2,2):setForeground(colors.white)

-- lista de músicas
local songList = playlistFrame:addList():setPosition(2,5):setSize(35,15)
for _, name in ipairs(songNames) do songList:addItem(name) end

-- botão tocar
local playButton = playlistFrame:addButton():setText("▶ Tocar"):setSize(12,3):setPosition(2,22)
    :setBackground(colors.blue):setForeground(colors.white)

-- player ui
playerFrame:addLabel():setText("Tocando:"):setPosition(2,2):setForeground(colors.lightBlue)
local songLabel = playerFrame:addLabel():setText(""):setPosition(2,3):setForeground(colors.white)
local statusLabel = playerFrame:addLabel():setText("Parado"):setPosition(2,4):setForeground(colors.orange)

-- barra de progresso custom (sem addProgressbar)
local progressFrame = playerFrame:addFrame():setPosition(2,6):setSize(46,1):setBackground(colors.gray)
local progressBar = progressFrame:addFrame():setPosition(1,1):setSize(1,1):setBackground(colors.blue)

-- botões
local pauseBtn = playerFrame:addButton():setText("⏸"):setPosition(2,8):setSize(4,2)
    :setBackground(colors.yellow):setForeground(colors.black)
local stopBtn = playerFrame:addButton():setText("⏹"):setPosition(8,8):setSize(4,2)
    :setBackground(colors.red):setForeground(colors.white)
local nextBtn = playerFrame:addButton():setText("⏭"):setPosition(14,8):setSize(4,2)
    :setBackground(colors.blue):setForeground(colors.white)
local shuffleBtn = playerFrame:addButton():setText("🔀"):setPosition(20,8):setSize(4,2)
    :setBackground(colors.blue):setForeground(colors.white)
local repeatBtn = playerFrame:addButton():setText("🔁"):setPosition(26,8):setSize(4,2)
    :setBackground(colors.gray):setForeground(colors.white)
local backToList = playerFrame:addButton():setText("↩ Voltar"):setPosition(2,15):setSize(10,2)
    :setBackground(colors.blue):setForeground(colors.white)

-- 🔊 funções
local function stopAudio()
    if audioHandle then pcall(function() audioHandle.close() end) end
    isPlaying, isPaused = false, false
    statusLabel:setText("Parado"):setForeground(colors.orange)
    progressValue = 0
    progressBar:setSize(1,1)
end

local function updateProgress()
    basalt.schedule(function()
        while isPlaying do
            progressValue = math.min(progressValue + 1, 46)
            progressBar:setSize(progressValue, 1)
            os.sleep(0.2)
        end
    end)
end

local function playAudio()
    stopAudio()
    local songUrl = playlist[currentSong]
    songLabel:setText(songNames[currentSong])
    statusLabel:setText("Carregando..."):setForeground(colors.yellow)
    local ok, handle = pcall(http.get, songUrl)
    if not ok or not handle then
        statusLabel:setText("Erro HTTP"):setForeground(colors.red)
        return
    end
    audioHandle = handle
    isPlaying, isPaused = true, false
    statusLabel:setText("Tocando"):setForeground(colors.lime)
    updateProgress()

    basalt.schedule(function()
        local buffer
        while isPlaying do
            if isPaused then os.sleep(0.1)
            else
                local chunk = audioHandle.read(16 * 1024)
                if not chunk then break end
                buffer = decoder(chunk)
                while not speaker.playAudio(buffer, volume) do os.pullEvent("speaker_audio_empty") end
            end
        end
        audioHandle.close()
        if repeatTrack then playAudio()
        elseif shuffle then currentSong = math.random(1, #playlist) playAudio()
        else currentSong = currentSong % #playlist + 1 playAudio() end
    end)
end

-- 🎚️ eventos
playButton:onClick(function()
    local selected = songList:getItemIndex()
    if selected then currentSong = selected end
    playlistFrame:setVisible(false)
    playerFrame:setVisible(true)
    playAudio()
end)

pauseBtn:onClick(function()
    if isPlaying then
        isPaused = not isPaused
        if isPaused then statusLabel:setText("Pausado"):setForeground(colors.orange)
        else statusLabel:setText("Tocando"):setForeground(colors.lime) end
    end
end)

stopBtn:onClick(stopAudio)
nextBtn:onClick(function()
    currentSong = currentSong % #playlist + 1
    playAudio()
end)

shuffleBtn:onClick(function()
    shuffle = not shuffle
    shuffleBtn:setBackground(shuffle and colors.blue or colors.gray)
end)

repeatBtn:onClick(function()
    repeatTrack = not repeatTrack
    repeatBtn:setBackground(repeatTrack and colors.blue or colors.gray)
end)

backToList:onClick(function()
    stopAudio()
    playerFrame:setVisible(false)
    playlistFrame:setVisible(true)
end)

main:addLabel():setText("Speaker: " .. (speaker and "OK" or "NÃO ENCONTRADO"))
    :setPosition(2,25):setForeground(speaker and colors.lime or colors.red)

basalt.autoUpdate()
