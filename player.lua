local basalt = require("basalt")

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
    local name = url:match("([^/]+)%.f234%.dfpwm$") or "Musica " .. i
    if #name > 28 then
        name = name:sub(1, 28) .. "..."
    end
    songNames[i] = name
end

local currentSong = 1
local isPlaying = false
local isPaused = false
local speaker = peripheral.find("speaker")
local audioHandle = nil
local decoder = nil
local volume = 1.0

local main = basalt.getMainFrame()
main:setBackground(colors.black)

local headerFrame = main:addFrame()
    :setPosition(1, 1)
    :setSize(51, 4)
    :setBackground(colors.blue)

local titleLabel = headerFrame:addLabel()
    :setText("ELFSMUSIC")
    :setPosition(21, 2)
    :setForeground(colors.white)

local subtitleLabel = headerFrame:addLabel()
    :setText("by elf4iries")
    :setPosition(20, 3)
    :setForeground(colors.lightBlue)

local mainContainer = main:addFrame()
    :setPosition(1, 5)
    :setSize(51, 21)
    :setBackground(colors.black)

local listFrame = mainContainer:addFrame()
    :setPosition(2, 1)
    :setSize(30, 18)
    :setBackground(colors.lightGray)

local listLabel = mainContainer:addLabel()
    :setText("PLAYLIST:")
    :setPosition(2, 1)
    :setForeground(colors.lightBlue)
    :setBackground(colors.black)

local songList = listFrame:addList()
    :setPosition(1, 1)
    :setSize(30, 18)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

for i, name in ipairs(songNames) do
    songList:addItem(name)
end

local controlFrame = mainContainer:addFrame()
    :setPosition(33, 1)
    :setSize(18, 18)
    :setBackground(colors.black)

local nowPlayingLabel = controlFrame:addLabel()
    :setText("TOCANDO:")
    :setPosition(1, 1)
    :setForeground(colors.lightBlue)

local statusLabel = controlFrame:addLabel()
    :setText("Parado")
    :setPosition(1, 3)
    :setForeground(colors.cyan)

local playButton = controlFrame:addButton()
    :setText("PLAY")
    :setPosition(1, 5)
    :setSize(18, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local pauseButton = controlFrame:addButton()
    :setText("PAUSE")
    :setPosition(1, 8)
    :setSize(18, 2)
    :setBackground(colors.cyan)
    :setForeground(colors.black)

local stopButton = controlFrame:addButton()
    :setText("STOP")
    :setPosition(1, 11)
    :setSize(18, 2)
    :setBackground(colors.lightBlue)
    :setForeground(colors.white)

local quitButton = controlFrame:addButton()
    :setText("SAIR")
    :setPosition(1, 14)
    :setSize(18, 2)
    :setBackground(colors.gray)
    :setForeground(colors.white)

local volumeLabel = controlFrame:addLabel()
    :setText("VOLUME: 100%")
    :setPosition(1, 17)
    :setForeground(colors.lightBlue)

local volDownButton = controlFrame:addButton()
    :setText("-")
    :setPosition(1, 18)
    :setSize(8, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local volUpButton = controlFrame:addButton()
    :setText("+")
    :setPosition(10, 18)
    :setSize(9, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local footerLabel = main:addLabel()
    :setText("Speaker: " .. (speaker and "OK" or "NAO ENCONTRADO"))
    :setPosition(2, 26)
    :setForeground(speaker and colors.cyan or colors.lightGray)

local function stopAudio()
    isPlaying = false
    isPaused = false
    
    if audioHandle then
        pcall(function() audioHandle.close() end)
        audioHandle = nil
    end
    
    statusLabel:setText("Parado")
    statusLabel:setForeground(colors.cyan)
end

local function playNextSong()
    currentSong = currentSong + 1
    if currentSong > #playlist then
        currentSong = 1
    end
    playAudio()
end

function playAudio()
    if not speaker then
        statusLabel:setText("Sem speaker!")
        statusLabel:setForeground(colors.gray)
        return
    end
    
    stopAudio()
    
    local songUrl = playlist[currentSong]
    statusLabel:setText("Carregando...")
    statusLabel:setForeground(colors.lightBlue)
    
    local success, handle = pcall(http.get, songUrl)
    
    if not success or not handle then
        statusLabel:setText("Erro!")
        statusLabel:setForeground(colors.gray)
        sleep(2)
        playNextSong()
        return
    end
    
    audioHandle = handle
    decoder = require("cc.audio.dfpwm").make_decoder()
    isPlaying = true
    isPaused = false
    statusLabel:setText("Tocando")
    statusLabel:setForeground(colors.cyan)
    
    basalt.schedule(function()
        while isPlaying and audioHandle do
            if not isPaused then
                local chunk = audioHandle.read(16 * 1024)
                
                if not chunk then
                    stopAudio()
                    sleep(0.5)
                    playNextSong()
                    break
                end
                
                local buffer = decoder(chunk)
                
                while not speaker.playAudio(buffer, volume) and isPlaying and not isPaused do
                    os.pullEvent("speaker_audio_empty")
                end
            else
                sleep(0.1)
            end
        end
    end)
end

songList:onChange(function(self, event, item)
    for i, name in ipairs(songNames) do
        if name == item.text then
            currentSong = i
            if isPlaying then
                playAudio()
            end
            break
        end
    end
end)

playButton:onClick(function()
    if not isPlaying then
        playAudio()
    elseif isPaused then
        isPaused = false
        statusLabel:setText("Tocando")
        statusLabel:setForeground(colors.cyan)
    end
end)

pauseButton:onClick(function()
    if isPlaying and not isPaused then
        isPaused = true
        statusLabel:setText("Pausado")
        statusLabel:setForeground(colors.lightBlue)
    end
end)

stopButton:onClick(function()
    stopAudio()
end)

quitButton:onClick(function()
    stopAudio()
    basalt.stop()
end)

volDownButton:onClick(function()
    volume = math.max(0, volume - 0.1)
    volumeLabel:setText("VOLUME: " .. math.floor(volume * 100) .. "%")
end)

volUpButton:onClick(function()
    volume = math.min(1, volume + 0.1)
    volumeLabel:setText("VOLUME: " .. math.floor(volume * 100) .. "%")
end)

basalt.run()
