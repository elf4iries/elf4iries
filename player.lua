-- player.lua (corrigido, compatível com Basalt oficial)
-- autor: elf4iries (ajustado)
local basalt = require("basalt")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Speaker nao encontrado!")
end

-- APIs (exemplo; substituir se usar outra)
local SEARCH_API = "https://music.madefor.cc/search"
local CONNECT_API = "https://music.madefor.cc/stream/"

-- playlist estática (modo exemplo — tu pode popular por busca)
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

-- extrai nomes curtos das URLs
local songNames = {}
for i, url in ipairs(playlist) do
    local name = url:match("([^/]+)%.f234%.dfpwm$") or ("Musica " .. i)
    if #name > 28 then name = name:sub(1,28) .. "..." end
    songNames[i] = name
end

-- estado
local currentSong = 1
local isPlaying = false
local isPaused = false
local audioHandle = nil
local decoder = nil
local volume = 1.0
local songLength = 0     -- estimativa em segundos
local currentTime = 0

-- UI
local main = basalt.createFrame()
main:setBackground(colors.black)

-- header
local header = main:addFrame()
header:setPosition(1,1)
header:setSize(51,4)
header:setBackground(colors.blue)
local title = header:addLabel()
title:setText("ELFSMUSIC")
title:setPosition(16,2)
title:setForeground(colors.white)
local subtitle = header:addLabel()
subtitle:setText("by elf4iries")
subtitle:setPosition(20,3)
subtitle:setForeground(colors.lightBlue)

-- container
local container = main:addFrame()
container:setPosition(1,5)
container:setSize(51,21)
container:setBackground(colors.black)

-- label playlist
local listLabel = container:addLabel()
listLabel:setText("PLAYLIST:")
listLabel:setPosition(2,1)
listLabel:setForeground(colors.yellow)

-- frame da lista
local listFrame = container:addFrame()
listFrame:setPosition(2,2)
listFrame:setSize(30,18)
listFrame:setBackground(colors.gray)

-- cria a List
local songList = listFrame:addList()
songList:setPosition(1,1)
songList:setSize(30,18)
songList:setBackground(colors.gray)
songList:setForeground(colors.white)

-- adiciona items como tabelas e marca o primeiro como selected=true
for i, name in ipairs(songNames) do
    local item = { text = name }
    if i == currentSong then item.selected = true end -- definida por docs: items podem ter selected
    songList:addItem(item)
end

-- painel de controle
local control = container:addFrame()
control:setPosition(33,1)
control:setSize(18,22)
control:setBackground(colors.black)

local nowLabel = control:addLabel()
nowLabel:setText("TOCANDO:")
nowLabel:setPosition(1,1)
nowLabel:setForeground(colors.yellow)

local musicLabel = control:addLabel()
musicLabel:setPosition(1,2)
musicLabel:setSize(18,1)
musicLabel:setForeground(colors.white)
musicLabel:setText(songNames[currentSong])

local statusLabel = control:addLabel()
statusLabel:setText("Parado")
statusLabel:setPosition(1,3)
statusLabel:setForeground(colors.orange)

-- botoes
local playB = control:addButton(); playB:setText("▶"); playB:setPosition(5,5); playB:setSize(8,3)
playB:setBackground(colors.green); playB:setForeground(colors.white)
local pauseB = control:addButton(); pauseB:setText("⏸"); pauseB:setPosition(5,9); pauseB:setSize(8,3)
pauseB:setBackground(colors.yellow); pauseB:setForeground(colors.black)
local stopB = control:addButton(); stopB:setText("⏹"); stopB:setPosition(5,13); stopB:setSize(8,3)
stopB:setBackground(colors.red); stopB:setForeground(colors.white)
local quitB = control:addButton(); quitB:setText("SAIR"); quitB:setPosition(1,17); quitB:setSize(18,2)
quitB:setBackground(colors.red); quitB:setForeground(colors.white)

-- volume
local volLabel = control:addLabel(); volLabel:setText("VOLUME:"); volLabel:setPosition(1,19); volLabel:setForeground(colors.yellow)
local volBar = control:addProgressbar(); volBar:setPosition(1,20); volBar:setSize(18,1); volBar:setProgress(100); volBar:setBackground(colors.gray)
local volDown = control:addButton(); volDown:setText("-"); volDown:setPosition(1,21); volDown:setSize(8,1)
volDown:setBackground(colors.gray); volDown:setForeground(colors.white)
local volUp = control:addButton(); volUp:setText("+"); volUp:setPosition(10,21); volUp:setSize(9,1)
volUp:setBackground(colors.gray); volUp:setForeground(colors.white)

-- barra de progresso musical (0-100 conforme docs)
local prog = control:addProgressbar()
prog:setPosition(1, 23)
prog:setSize(18, 1)
prog:setProgress(0)
prog:setBackground(colors.gray)

local progText = control:addLabel()
progText:setPosition(1, 24)
progText:setText("0:00 / 0:00")
progText:setForeground(colors.lightGray)

-- footer speaker
local footer = main:addLabel()
footer:setText("Speaker: " .. (speaker and "OK" or "NAO ENCONTRADO"))
footer:setPosition(2,26)
footer:setForeground(speaker and colors.lime or colors.red)

-- util: play audio com pcall
local function safePlayAudio(buffer)
    if not speaker then return false end
    local ok, res = pcall(function() return speaker.playAudio(buffer, volume) end)
    return ok and res
end

local function stopAudio()
    isPlaying = false
    isPaused = false
    if audioHandle then pcall(function() audioHandle:close() end) end
    audioHandle, decoder = nil, nil
    statusLabel:setText("Parado")
    statusLabel:setForeground(colors.orange)
    prog:setProgress(0); progText:setText("0:00 / 0:00")
end

-- avança para proxima
local function playNext()
    currentSong = currentSong + 1
    if currentSong > #playlist then currentSong = 1 end
    -- para marcar o selected: recria lista com selected no index corrente
    songList:clear()
    for i, name in ipairs(songNames) do
        local item = { text = name }
        if i == currentSong then item.selected = true end
        songList:addItem(item)
    end
    musicLabel:setText(songNames[currentSong])
    basalt.schedule(function() playAudio() end)
end

-- atualiza barra de progresso em loop (usa setProgress 0-100)
local function progressLooper()
    while isPlaying do
        if not isPaused and songLength > 0 then
            currentTime = math.min(currentTime + 1, songLength)
            local percent = math.floor((currentTime / songLength) * 100)
            prog:setProgress(percent)
            progText:setText(string.format("%d:%02d / %d:%02d", math.floor(currentTime/60), currentTime%60, math.floor(songLength/60), songLength%60))
        end
        os.sleep(1)
    end
end

-- função de tocar (usa basalt.schedule pra não travar)
function playAudio()
    if not speaker then
        statusLabel:setText("Sem speaker!")
        statusLabel:setForeground(colors.red)
        return
    end

    stopAudio() -- reseta estado

    local url = playlist[currentSong]
    statusLabel:setText("Carregando...")
    statusLabel:setForeground(colors.yellow)

    basalt.schedule(function()
        local ok, handle = pcall(http.get, url)
        if not ok or not handle then
            statusLabel:setText("Erro ao carregar")
            statusLabel:setForeground(colors.red)
            os.sleep(2)
            playNext()
            return
        end

        -- inicializa decoder (dfpwm)
        decoder = require("cc.audio.dfpwm").make_decoder()
        audioHandle = handle
        isPlaying = true
        isPaused = false
        currentTime = 0

        -- tentativa de estimativa: número de chunks => aproximação de segundos
        local size = 0
        -- lê todo o conteúdo em memória (pode ser pesado; ideal stream)
        -- para simplicidade aqui, ler em pedaços e concatenar
        local data = {}
        while true do
            local chunk = audioHandle:read(16 * 1024)
            if not chunk then break end
            size = size + #chunk
            table.insert(data, chunk)
        end
        local audio = table.concat(data)
        -- fecha handle
        pcall(function() audioHandle:close() end)
        audioHandle = nil

        -- estima duração aproximada: cada bloco 16384 corresponde ~1 segundo de reprodução no caso dfpwm streaming (isto é estimativa)
        songLength = math.max(1, math.ceil(#audio / 16384))
        statusLabel:setText("Tocando")
        statusLabel:setForeground(colors.lime)
        musicLabel:setText(songNames[currentSong])

        -- inicia looper da barra
        basalt.schedule(progressLooper)

        -- envia blocos ao speaker
        local pos = 1
        local chunkSize = 16384
        while isPlaying and pos <= #audio do
            if not isPaused then
                local rawChunk = audio:sub(pos, pos + chunkSize - 1)
                local okPlay = safePlayAudio(decoder(rawChunk))
                if not okPlay then
                    -- espera evento do speaker liberar
                    os.pullEvent("speaker_audio_empty")
                end
                pos = pos + chunkSize
            else
                os.sleep(0.1)
            end
        end

        isPlaying = false
        statusLabel:setText("Finalizado")
        prog:setProgress(100)
        os.sleep(0.5)
        playNext()
    end)
end

-- Eventos: onSelect fornece (index, item) segundo docs oficiais
-- https://basalt.madefor.cc/references/elements/List.html
songList:onSelect(function(index, item)
    if index and type(index) == "number" then
        currentSong = index
        musicLabel:setText(songNames[currentSong])
        -- refaz seleção visual (opcional) marcando selected nas items
        songList:clear()
        for i, name in ipairs(songNames) do
            local t = { text = name }
            if i == currentSong then t.selected = true end
            songList:addItem(t)
        end
    end
end)

-- botões
playB:onClick(function()
    if not isPlaying then
        basalt.schedule(function() playAudio() end)
    elseif isPaused then
        isPaused = false
        statusLabel:setText("Tocando")
        statusLabel:setForeground(colors.lime)
    end
end)

pauseB:onClick(function()
    if isPlaying then
        isPaused = not isPaused
        statusLabel:setText(isPaused and "Pausado" or "Tocando")
    end
end)

stopB:onClick(function() stopAudio() end)

quitB:onClick(function() stopAudio(); basalt.stop() end)

volDown:onClick(function()
    volume = math.max(0, volume - 0.1)
    volBar:setProgress(math.floor(volume * 100))
end)

volUp:onClick(function()
    volume = math.min(1, volume + 0.1)
    volBar:setProgress(math.floor(volume * 100))
end)

-- start UI
basalt.run()
