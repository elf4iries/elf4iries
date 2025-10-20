-- player.lua
-- autor: elf4iries 🧚🌿
-- Music Player Basalt Edition ✨

local basalt = require("basalt")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Speaker nao encontrado!")
end

local SEARCH_API = "https://music.madefor.cc/search"
local CONNECT_API = "https://music.madefor.cc/stream/"

local searchResults = {}
local isPlaying = false
local isPaused = false
local audioResponse = nil
local selectedIndex = nil
local songLength = 0
local currentTime = 0

local mainFrame = basalt.createFrame()
mainFrame:setBackground(colors.black)
mainFrame:setForeground(colors.white)
mainFrame:setSize("parent.w", "parent.h")

local title = mainFrame:addLabel()
title:setText("🎶 Music Player — elf4iries")
title:setPosition(2, 1)
title:setForeground(colors.lime)

local searchBox = mainFrame:addInput()
searchBox:setPosition(2, 3)
searchBox:setSize(30, 1)
searchBox:setDefaultText("Digite o nome da música...")

local searchButton = mainFrame:addButton()
searchButton:setText("🔍 Buscar")
searchButton:setPosition(34, 3)

local songList = mainFrame:addList()
songList:setPosition(2, 5)
songList:setSize(40, 9)
songList:setScrollable(true)

local playButton = mainFrame:addButton()
playButton:setText("▶ Play")
playButton:setPosition(2, 15)

local pauseButton = mainFrame:addButton()
pauseButton:setText("⏸ Pause")
pauseButton:setPosition(10, 15)

local stopButton = mainFrame:addButton()
stopButton:setText("⏹ Stop")
stopButton:setPosition(18, 15)

local statusLabel = mainFrame:addLabel()
statusLabel:setText("Pronto.")
statusLabel:setPosition(2, 17)
statusLabel:setForeground(colors.yellow)

-- Barra de progresso animada
local progressBar = mainFrame:addProgressbar()
progressBar:setPosition(2, 19)
progressBar:setSize(40, 1)
progressBar:setProgress(0)
progressBar:setForeground(colors.lime)
progressBar:setBackground(colors.gray)

local progressText = mainFrame:addLabel()
progressText:setPosition(2, 20)
progressText:setText("⏳ 0:00 / 0:00")
progressText:setForeground(colors.lightGray)

-- função universal para selecionar item (compatível com qualquer Basalt)
local function selectListItem(list, index)
    if not list or not index then return end
    if list.selectItem then
        list:selectItem(index)
    elseif list.setIndex then
        list:setIndex(index)
    elseif list.setSelected then
        list:setSelected(index)
    end
end

-- Busca de músicas
local function searchMusic(query)
    statusLabel:setText("Buscando por \"" .. query .. "\"...")
    local res = http.get(SEARCH_API .. "?q=" .. textutils.urlEncode(query))
    if not res then
        statusLabel:setText("Erro na busca.")
        return
    end

    local data = textutils.unserializeJSON(res.readAll())
    res.close()

    if not data or #data == 0 then
        songList:clear()
        statusLabel:setText("Nenhum resultado encontrado.")
        return
    end

    searchResults = data
    songList:clear()
    for _, v in ipairs(data) do
        songList:addItem(v.title or "Sem título", v.author or "")
    end

    selectListItem(songList, 1)
    statusLabel:setText("Resultados encontrados: " .. tostring(#data))
end

-- Atualiza a barra de progresso durante reprodução
local function updateProgressBar()
    while isPlaying do
        if not isPaused and songLength > 0 then
            currentTime = currentTime + 1
            local progress = math.min(currentTime / songLength, 1)
            progressBar:setProgress(progress)
            progressText:setText(string.format("🎵 %d:%02d / %d:%02d", math.floor(currentTime/60), currentTime%60, math.floor(songLength/60), songLength%60))
        end
        os.sleep(1)
    end
    progressBar:setProgress(0)
    progressText:setText("⏳ 0:00 / 0:00")
end

-- Reproduzir música
local function playSong(index)
    if not searchResults[index] then
        statusLabel:setText("Selecione uma música primeiro.")
        return
    end

    local song = searchResults[index]
    statusLabel:setText("Baixando " .. song.title .. "...")
    local res = http.get(CONNECT_API .. song.id)
    if not res then
        statusLabel:setText("Erro ao baixar a música.")
        return
    end

    local audio = res.readAll()
    res.close()

    audioResponse = audio
    isPlaying = true
    isPaused = false
    currentTime = 0
    songLength = math.ceil(#audio / 16384)  -- estimativa de duração
    statusLabel:setText("Tocando: " .. song.title)

    -- inicia thread da barra de progresso
    basalt.schedule(updateProgressBar)

    -- toca a música em blocos
    local chunkSize = 16384
    local pos = 1
    while isPlaying and pos <= #audio do
        if not isPaused then
            local chunk = audio:sub(pos, pos + chunkSize - 1)
            speaker.playAudio(chunk)
            pos = pos + chunkSize
        else
            os.sleep(0.1)
        end
    end

    isPlaying = false
    statusLabel:setText("🎵 Música finalizada.")
end

-- Eventos
searchButton:onClick(function()
    local query = searchBox:getValue()
    if query and query ~= "" then
        searchMusic(query)
    else
        statusLabel:setText("Digite algo para buscar.")
    end
end)

songList:onSelect(function(self, event, item)
    selectedIndex = item
end)

playButton:onClick(function()
    if selectedIndex then
        basalt.schedule(function() playSong(selectedIndex) end)
    else
        statusLabel:setText("Selecione uma música.")
    end
end)

pauseButton:onClick(function()
    if isPlaying then
        isPaused = not isPaused
        statusLabel:setText(isPaused and "⏸ Música pausada." or "▶ Retomando...")
    end
end)

stopButton:onClick(function()
    if isPlaying then
        isPlaying = false
        statusLabel:setText("⏹ Música parada.")
    end
end)

basalt.run()
