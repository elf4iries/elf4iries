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
    if #name > 26 then
        name = name:sub(1, 26) .. "..."
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
local animFrame = 1

local main = basalt.getMainFrame()
main:setBackground(colors.black)

local headerFrame = main:addFrame()
    :setPosition(1, 1)
    :setSize(51, 4)
    :setBackground(colors.blue)

local titleLabel = headerFrame:addLabel()
    :setText("ELFSMUSIC")
    :setPosition(22, 2)
    :setForeground(colors.white)

local subtitleLabel = headerFrame:addLabel()
    :setText("by elf4iries")
    :setPosition(21, 3)
    :setForeground(colors.lightBlue)

local listFrame = main:addFrame()
    :setPosition(3, 6)
    :setSize(28, 16)
    :setBackground(colors.white)

local listLabel = main:addLabel()
    :setText("PLAYLIST")
    :setPosition(12, 5)
    :setForeground(colors.lightBlue)

local songList = listFrame:addList()
    :setPosition(1, 1)
    :setSize(28, 16)
    :setBackground(colors.white)
    :setForeground(colors.black)

for i, name in ipairs(songNames) do
    songList:addItem(name)
end

local controlFrame = main:addFrame()
    :setPosition(33, 5)
    :setSize(16, 20)
    :setBackground(colors.black)

local nowPlayingLabel = controlFrame:addLabel()
    :setText("TOCANDO AGORA")
    :setPosition(3, 1)
    :setForeground(colors.lightBlue)

local statusLabel = controlFrame:addLabel()
    :setText("Parado")
    :setPosition(6, 2)
    :setForeground(colors.cyan)

local animLabel = controlFrame:addLabel()
    :setText("")
    :setPosition(7, 3)
    :setForeground(colors.cyan)

local playButton = controlFrame:addButton()
    :setText(">")
    :setPosition(3, 5)
    :setSize(3, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local pauseButton = controlFrame:addButton()
    :setText("||")
    :setPosition(7, 5)
    :setSize(3, 2)
    :setBackground(colors.cyan)
    :setForeground(colors.black)

local stopButton = controlFrame:addButton()
    :setText("[]")
    :setPosition(11, 5)
    :setSize(3, 2)
    :setBackground(colors.lightBlue)
    :setForeground(colors.white)

local prevButton = controlFrame:addButton()
    :setText("<<")
    :setPosition(3, 8)
    :setSize(5, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local nextButton = controlFrame:addButton()
    :setText(">>")
    :setPosition(9, 8)
    :setSize(5, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local volumeLabel = controlFrame:addLabel()
    :setText("VOL: 100%")
    :setPosition(4, 11)
    :setForeground(colors.lightBlue)

local volDownButton = controlFrame:addButton()
    :setText("-")
    :setPosition(3, 12)
    :setSize(5, 2)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local volUpButton = controlFrame:addButton()
    :setText("+")
    :setPosition(9, 12)
    :setSize(5, 2)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local quitButton = controlFrame:addButton()
    :setText("SAIR")
    :setPosition(5, 15)
    :setSize(6, 2)
    :setBackground(colors.gray)
    :setForeground(colors.white)

local footerLabel = main:addLabel()
    :setText("Speaker: " .. (speaker and "OK" or "NAO"))
    :setPosition(20, 24)
    :setForeground(speaker and colors.cyan or colors.gray)

local function updateAnimation()
    if isPlaying and not isPaused then
        local frames = {"~", "=", "-"}
        animLabel:setText(frames[animFrame])
        animFrame = animFrame + 1
        if animFrame > #frames then
            animFrame = 1
        end
    else
        animLabel:setText("")
    end
end

local function stopAudio()
    isPlaying = false
    isPaused = false
    
    if audioHandle then
        pcall(function() audioHandle.close() end)
        audioHandle = nil
    end
    
    statusLabel:setText("Parado")
    statusLabel:setForeground(colors.cyan)
    animLabel:setText("")
end

function playAudio()
    if not speaker then
        statusLabel:setText("Sem speaker")
        statusLabel:setForeground(colors.gray)
        return
    end
    
    stopAudio()
    
    local songUrl = playlist[currentSong]
    statusLabel:setText("Carregando")
    statusLabel:setForeground(colors.lightBlue)
    
    audioHandle = http.get(songUrl)
    
    if not audioHandle then
        statusLabel:setText("Erro HTTP")
        statusLabel:setForeground(colors.gray)
        return
    end
    
    decoder = require("cc.audio.dfpwm").make_decoder()
    isPlaying = true
    isPaused = false
    statusLabel:setText("Tocando")
    statusLabel:setForeground(colors.cyan)
    
    basalt.schedule(function()
        while isPlaying and audioHandle do
            updateAnimation()
            
            if not isPaused then
                local chunk = audioHandle.read(16 * 1024)
                
                if not chunk then
                    stopAudio()
                    currentSong = currentSong + 1
                    if currentSong > #playlist then
                        currentSong = 1
                    end
                    sleep(0.5)
                    playAudio()
                    break
                end
                
                local buffer = decoder(chunk)
                
                while not speaker.playAudio(buffer, volume) do
                    if not isPlaying or isPaused then break end
                    os.pullEvent("speaker_audio_empty")
                end
            else
                sleep(0.1)
            end
        end
    end)
end

songList:onChange(function(self, event, item)
    if item and item.text then
        for i, name in ipairs(songNames) do
            if name == item.text then
                currentSong = i
                playAudio()
                break
            end
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

prevButton:onClick(function()
    currentSong = currentSong - 1
    if currentSong < 1 then
        currentSong = #playlist
    end
    if isPlaying then
        playAudio()
    end
end)

nextButton:onClick(function()
    currentSong = currentSong + 1
    if currentSong > #playlist then
        currentSong = 1
    end
    if isPlaying then
        playAudio()
    end
end)

quitButton:onClick(function()
    stopAudio()
    basalt.stop()
end)

volDownButton:onClick(function()
    volume = math.max(0, volume - 0.1)
    volumeLabel:setText("VOL: " .. math.floor(volume * 100) .. "%")
end)

volUpButton:onClick(function()
    volume = math.min(1, volume + 0.1)
    volumeLabel:setText("VOL: " .. math.floor(volume * 100) .. "%")
end)

basalt.run()
