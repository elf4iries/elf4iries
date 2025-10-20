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

local listFrame = main:addFrame()
    :setPosition(3, 6)
    :setSize(28, 16)
    :setBackground(colors.white)

local listLabel = main:addLabel()
    :setText("PLAYLIST:")
    :setPosition(3, 5)
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
    :setText("TOCANDO:")
    :setPosition(4, 1)
    :setForeground(colors.lightBlue)

local statusLabel = controlFrame:addLabel()
    :setText("Parado")
    :setPosition(5, 2)
    :setForeground(colors.cyan)

local playButton = controlFrame:addButton()
    :setText("> PLAY")
    :setPosition(1, 4)
    :setSize(16, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local pauseButton = controlFrame:addButton()
    :setText("|| PAUSE")
    :setPosition(1, 7)
    :setSize(16, 2)
    :setBackground(colors.cyan)
    :setForeground(colors.black)

local stopButton = controlFrame:addButton()
    :setText("[] STOP")
    :setPosition(1, 10)
    :setSize(16, 2)
    :setBackground(colors.lightBlue)
    :setForeground(colors.white)

local prevButton = controlFrame:addButton()
    :setText("<< ANTERIOR")
    :setPosition(1, 13)
    :setSize(16, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local nextButton = controlFrame:addButton()
    :setText("PROXIMA >>")
    :setPosition(1, 16)
    :setSize(16, 2)
    :setBackground(colors.blue)
    :setForeground(colors.white)

local quitButton = controlFrame:addButton()
    :setText("X SAIR")
    :setPosition(1, 19)
    :setSize(16, 2)
    :setBackground(colors.gray)
    :setForeground(colors.white)

local volumeLabel = main:addLabel()
    :setText("VOL: 100%")
    :setPosition(3, 23)
    :setForeground(colors.lightBlue)

local volDownButton = main:addButton()
    :setText("-")
    :setPosition(3, 24)
    :setSize(3, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local volUpButton = main:addButton()
    :setText("+")
    :setPosition(7, 24)
    :setSize(3, 1)
    :setBackground(colors.lightGray)
    :setForeground(colors.black)

local footerLabel = main:addLabel()
    :setText("Speaker: " .. (speaker and "OK" or "NAO"))
    :setPosition(15, 24)
    :setForeground(speaker and colors.cyan or colors.gray)

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

function playAudio()
    if not speaker then
        statusLabel:setText("Sem speaker")
        statusLabel:setForeground(colors.gray)
        return
    end
    
    stopAudio()
    
    local songUrl = playlist[currentSong]
    statusLabel:setText("Loading")
    statusLabel:setForeground(colors.lightBlue)
    
    local success, handle = pcall(http.get, songUrl)
    
    if not success or not handle then
        statusLabel:setText("Erro!")
        statusLabel:setForeground(colors.gray)
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
                local success2, chunk = pcall(function()
                    return audioHandle.read(16 * 1024)
                end)
                
                if not success2 or not chunk then
                    stopAudio()
                    break
                end
                
                local buffer = decoder(chunk)
                
                while isPlaying and not isPaused do
                    if speaker.playAudio(buffer, volume) then
                        break
                    end
                    sleep(0.05)
                end
            else
                sleep(0.1)
            end
        end
    end)
end

local clickedSong = 0
songList:onClick(function(self, event, button, x, y)
    clickedSong = y
    if clickedSong >= 1 and clickedSong <= #songNames then
        currentSong = clickedSong
        playAudio()
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
