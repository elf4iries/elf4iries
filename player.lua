local basalt = require("basalt")
local PLAYLIST_URL = "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/playlist.json"

local main = basalt.createFrame()

local playlist = {}
local currentSong = 1
local isPlaying = false
local isPaused = false
local speaker = peripheral.find("speaker")
local audioHandle = nil
local decoder = nil

main:setBackground(colors.black)

local headerFrame = main:addFrame()
headerFrame:setPosition(1, 1)
headerFrame:setSize(51, 5)
headerFrame:setBackground(colors.blue)

local titleLabel = headerFrame:addLabel()
titleLabel:setText("AURORA MUSIC PLAYER")
titleLabel:setPosition(16, 2)
titleLabel:setForeground(colors.white)

local subtitleLabel = headerFrame:addLabel()
subtitleLabel:setText("by elf4iries")
subtitleLabel:setPosition(20, 3)
subtitleLabel:setForeground(colors.lightBlue)

local infoFrame = main:addFrame()
infoFrame:setPosition(2, 7)
infoFrame:setSize(49, 7)
infoFrame:setBackground(colors.gray)

local statusLabel = infoFrame:addLabel()
statusLabel:setText("Status: Carregando...")
statusLabel:setPosition(2, 2)
statusLabel:setForeground(colors.white)

local songLabel = infoFrame:addLabel()
songLabel:setText("Musica: Nenhuma")
songLabel:setPosition(2, 4)
songLabel:setForeground(colors.lightBlue)

local progressLabel = infoFrame:addLabel()
progressLabel:setText("Progresso: 0 / 0")
progressLabel:setPosition(2, 6)
progressLabel:setForeground(colors.cyan)

local playButton = main:addButton()
playButton:setText("PLAY")
playButton:setPosition(2, 16)
playButton:setSize(10, 3)
playButton:setBackground(colors.blue)
playButton:setForeground(colors.white)

local pauseButton = main:addButton()
pauseButton:setText("PAUSE")
pauseButton:setPosition(13, 16)
pauseButton:setSize(10, 3)
pauseButton:setBackground(colors.cyan)
pauseButton:setForeground(colors.black)

local stopButton = main:addButton()
stopButton:setText("STOP")
stopButton:setPosition(24, 16)
stopButton:setSize(10, 3)
stopButton:setBackground(colors.lightBlue)
stopButton:setForeground(colors.white)

local prevButton = main:addButton()
prevButton:setText("<< ANTERIOR")
prevButton:setPosition(2, 20)
prevButton:setSize(15, 3)
prevButton:setBackground(colors.blue)
prevButton:setForeground(colors.white)

local nextButton = main:addButton()
nextButton:setText("PROXIMA >>")
nextButton:setPosition(18, 20)
nextButton:setSize(15, 3)
nextButton:setBackground(colors.blue)
nextButton:setForeground(colors.white)

local quitButton = main:addButton()
quitButton:setText("SAIR")
quitButton:setPosition(35, 20)
quitButton:setSize(8, 3)
quitButton:setBackground(colors.red)
quitButton:setForeground(colors.white)

local speakerLabel = main:addLabel()
speakerLabel:setText("Speaker: " .. (speaker and "OK" or "NAO"))
speakerLabel:setPosition(2, 24)
speakerLabel:setForeground(speaker and colors.lime or colors.red)

local function updateDisplay()
    if #playlist > 0 then
        local songUrl = playlist[currentSong]
        local songName = songUrl:match("([^/]+)%.f234%.dfpwm$") or "Desconhecida"
        songName = songName:gsub("%%20", " ")
        songName = songName:gsub("%%28", "(")
        songName = songName:gsub("%%29", ")")
        songName = songName:gsub("%%2C", ",")
        songName = songName:gsub("%%27", "'")
        songName = songName:gsub("%%2B", "+")
        
        if #songName > 35 then
            songName = songName:sub(1, 35) .. "..."
        end
        
        songLabel:setText("Musica: " .. songName)
        progressLabel:setText("Progresso: " .. currentSong .. " / " .. #playlist)
    end
end

local function stopAudio()
    if audioHandle then
        pcall(function() audioHandle.close() end)
        audioHandle = nil
    end
    isPlaying = false
    isPaused = false
    statusLabel:setText("Status: Parado")
    statusLabel:setForeground(colors.orange)
end

local function playAudio()
    if not speaker then
        statusLabel:setText("Status: Sem speaker!")
        statusLabel:setForeground(colors.red)
        return
    end
    
    if #playlist == 0 then
        statusLabel:setText("Status: Playlist vazia!")
        statusLabel:setForeground(colors.red)
        return
    end
    
    stopAudio()
    
    local songUrl = playlist[currentSong]
    updateDisplay()
    statusLabel:setText("Status: Carregando...")
    statusLabel:setForeground(colors.yellow)
    
    local success, result = pcall(function()
        return http.get(songUrl)
    end)
    
    if not success or not result then
        statusLabel:setText("Status: Erro ao carregar!")
        statusLabel:setForeground(colors.red)
        return
    end
    
    audioHandle = result
    decoder = require("cc.audio.dfpwm").make_decoder()
    isPlaying = true
    isPaused = false
    statusLabel:setText("Status: Tocando")
    statusLabel:setForeground(colors.lime)
    
    basalt.schedule(function()
        while isPlaying and audioHandle do
            if not isPaused then
                local success, chunk = pcall(function()
                    return audioHandle.read(16 * 1024)
                end)
                
                if not success or not chunk then
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
                
                while not speaker.playAudio(buffer) and isPlaying do
                    os.pullEvent("speaker_audio_empty")
                end
            else
                sleep(0.1)
            end
        end
    end)
end

playButton:onClick(function()
    if not isPlaying then
        playAudio()
    elseif isPaused then
        isPaused = false
        statusLabel:setText("Status: Tocando")
        statusLabel:setForeground(colors.lime)
    end
end)

pauseButton:onClick(function()
    if isPlaying and not isPaused then
        isPaused = true
        statusLabel:setText("Status: Pausado")
        statusLabel:setForeground(colors.orange)
    end
end)

stopButton:onClick(function()
    stopAudio()
end)

nextButton:onClick(function()
    if #playlist > 0 then
        currentSong = currentSong + 1
        if currentSong > #playlist then
            currentSong = 1
        end
        if isPlaying then
            playAudio()
        else
            updateDisplay()
        end
    end
end)

prevButton:onClick(function()
    if #playlist > 0 then
        currentSong = currentSong - 1
        if currentSong < 1 then
            currentSong = #playlist
        end
        if isPlaying then
            playAudio()
        else
            updateDisplay()
        end
    end
end)

quitButton:onClick(function()
    stopAudio()
    basalt.stop()
end)

basalt.schedule(function()
    sleep(0.5)
    
    local success, response = pcall(function()
        return http.get(PLAYLIST_URL)
    end)
    
    if not success or not response then
        statusLabel:setText("Status: Erro ao carregar playlist!")
        statusLabel:setForeground(colors.red)
        return
    end
    
    local playlistData = response.readAll()
    response.close()
    
    local success2, result = pcall(function()
        return textutils.unserialiseJSON(playlistData)
    end)
    
    if not success2 or not result or #result == 0 then
        statusLabel:setText("Status: Playlist invalida!")
        statusLabel:setForeground(colors.red)
        return
    end
    
    playlist = result
    statusLabel:setText("Status: Pronto! " .. #playlist .. " musicas")
    statusLabel:setForeground(colors.lime)
    updateDisplay()
end)

basalt.run()
