local basalt = require("basalt")

local main = basalt.createFrame()

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

main:setBackground(colors.black)

local headerFrame = main:addFrame()
headerFrame:setPosition(1, 1)
headerFrame:setSize(51, 4)
headerFrame:setBackground(colors.blue)

local titleLabel = headerFrame:addLabel()
titleLabel:setText("AURORA MUSIC PLAYER")
titleLabel:setPosition(16, 2)
titleLabel:setForeground(colors.white)

local subtitleLabel = headerFrame:addLabel()
subtitleLabel:setText("by elf4iries")
subtitleLabel:setPosition(20, 3)
subtitleLabel:setForeground(colors.lightBlue)

local mainContainer = main:addFrame()
mainContainer:setPosition(1, 5)
mainContainer:setSize(51, 21)
mainContainer:setBackground(colors.black)

local listFrame = mainContainer:addFrame()
listFrame:setPosition(2, 1)
listFrame:setSize(30, 18)
listFrame:setBackground(colors.gray)

local listLabel = mainContainer:addLabel()
listLabel:setText("PLAYLIST:")
listLabel:setPosition(2, 1)
listLabel:setForeground(colors.yellow)
listLabel:setBackground(colors.black)

local songList = listFrame:addList()
songList:setPosition(1, 1)
songList:setSize(30, 18)
songList:setBackground(colors.gray)
songList:setForeground(colors.white)

for i, name in ipairs(songNames) do
    songList:addItem(name)
end

songList:setValue(songNames[1])

local controlFrame = mainContainer:addFrame()
controlFrame:setPosition(33, 1)
controlFrame:setSize(18, 18)
controlFrame:setBackground(colors.black)

local nowPlayingLabel = controlFrame:addLabel()
nowPlayingLabel:setText("TOCANDO:")
nowPlayingLabel:setPosition(1, 1)
nowPlayingLabel:setForeground(colors.yellow)

local statusLabel = controlFrame:addLabel()
statusLabel:setText("Parado")
statusLabel:setPosition(1, 3)
statusLabel:setForeground(colors.orange)

local playButton = controlFrame:addButton()
playButton:setText("PLAY")
playButton:setPosition(1, 5)
playButton:setSize(18, 2)
playButton:setBackground(colors.blue)
playButton:setForeground(colors.white)

local pauseButton = controlFrame:addButton()
pauseButton:setText("PAUSE")
pauseButton:setPosition(1, 8)
pauseButton:setSize(18, 2)
pauseButton:setBackground(colors.cyan)
pauseButton:setForeground(colors.black)

local stopButton = controlFrame:addButton()
stopButton:setText("STOP")
stopButton:setPosition(1, 11)
stopButton:setSize(18, 2)
stopButton:setBackground(colors.lightBlue)
stopButton:setForeground(colors.white)

local quitButton = controlFrame:addButton()
quitButton:setText("SAIR")
quitButton:setPosition(1, 14)
quitButton:setSize(18, 2)
quitButton:setBackground(colors.red)
quitButton:setForeground(colors.white)

local volumeLabel = controlFrame:addLabel()
volumeLabel:setText("VOLUME:")
volumeLabel:setPosition(1, 17)
volumeLabel:setForeground(colors.yellow)

local volumeBar = controlFrame:addProgressbar()
volumeBar:setPosition(1, 18)
volumeBar:setSize(18, 1)
volumeBar:setProgress(100)
volumeBar:setProgressBar(colors.blue)
volumeBar:setBackground(colors.gray)

local volDownButton = controlFrame:addButton()
volDownButton:setText("-")
volDownButton:setPosition(1, 19)
volDownButton:setSize(8, 1)
volDownButton:setBackground(colors.gray)
volDownButton:setForeground(colors.white)

local volUpButton = controlFrame:addButton()
volUpButton:setText("+")
volUpButton:setPosition(10, 19)
volUpButton:setSize(9, 1)
volUpButton:setBackground(colors.gray)
volUpButton:setForeground(colors.white)

local footerLabel = main:addLabel()
footerLabel:setText("Speaker: " .. (speaker and "OK" or "NAO ENCONTRADO"))
footerLabel:setPosition(2, 26)
footerLabel:setForeground(speaker and colors.lime or colors.red)

local function stopAudio()
    isPlaying = false
    isPaused = false
    
    if audioHandle then
        pcall(function() audioHandle.close() end)
        audioHandle = nil
    end
    
    statusLabel:setText("Parado")
    statusLabel:setForeground(colors.orange)
end

local function playNextSong()
    currentSong = currentSong + 1
    if currentSong > #playlist then
        currentSong = 1
    end
    songList:selectItem(currentSong)
    playAudio()
end

function playAudio()
    if not speaker then
        statusLabel:setText("Sem speaker!")
        statusLabel:setForeground(colors.red)
        return
    end
    
    stopAudio()
    
    local songUrl = playlist[currentSong]
    statusLabel:setText("Carregando...")
    statusLabel:setForeground(colors.yellow)
    
    local success, handle = pcall(http.get, songUrl)
    
    if not success or not handle then
        statusLabel:setText("Erro!")
        statusLabel:setForeground(colors.red)
        sleep(2)
        playNextSong()
        return
    end
    
    audioHandle = handle
    decoder = require("cc.audio.dfpwm").make_decoder()
    isPlaying = true
    isPaused = false
    statusLabel:setText("Tocando")
    statusLabel:setForeground(colors.lime)
    
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

songList:onSelect(function(self, event, item)
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
        statusLabel:setForeground(colors.lime)
    end
end)

pauseButton:onClick(function()
    if isPlaying and not isPaused then
        isPaused = true
        statusLabel:setText("Pausado")
        statusLabel:setForeground(colors.orange)
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
    volumeBar:setProgress(math.floor(volume * 100))
end)

volUpButton:onClick(function()
    volume = math.min(1, volume + 0.1)
    volumeBar:setProgress(math.floor(volume * 100))
end)

basalt.run()
