local basalt = require("basalt")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Speaker não encontrado!")
end

-- Variáveis globais
local searchResults = {}
local isPlaying = false
local isPaused = false
local audioResponse = nil
local currentTrack = nil
local trackLength = 0
local currentTime = 0

-- Funções auxiliares
local function shorten(str, len)
    if #str > len then
        return string.sub(str, 1, len - 3) .. "..."
    end
    return str
end

local function center(str, width)
    local pad = math.floor((width - #str) / 2)
    return string.rep(" ", pad) .. str
end

-- Criação da janela principal
local main = basalt.createFrame("mainFrame")
main:setBackground(colors.black)
main:setForeground(colors.white)

-- Cabeçalho
local title = main:addLabel()
title:setText("🎵 elf4iries Music Player")
title:setForeground(colors.cyan)
title:setPosition(2, 2)

-- Campo de busca
local input = main:addInput()
input:setPosition(2, 4)
input:setSize(30, 1)
input:setDefaultText("Pesquisar música...")

-- Botão de busca
local searchBtn = main:addButton()
searchBtn:setText("Buscar")
searchBtn:setPosition(34, 4)

-- Lista de resultados
local resultList = main:addList()
resultList:setPosition(2, 6)
resultList:setSize(38, 10)
resultList:setScrollable(true)

-- Label de status
local statusLabel = main:addLabel()
statusLabel:setText("")
statusLabel:setPosition(2, 17)
statusLabel:setForeground(colors.lightGray)

-- Barra de progresso (simples e animada)
local progressBar = main:addLabel()
progressBar:setPosition(2, 19)
progressBar:setSize(38, 1)
progressBar:setBackground(colors.gray)
progressBar:setForeground(colors.lime)
progressBar:setText("")

-- Atualiza visual da barra de progresso
local function updateProgress()
    if not isPlaying or trackLength == 0 then return end
    currentTime = currentTime + 1
    if currentTime > trackLength then
        isPlaying = false
        progressBar:setText("")
        statusLabel:setText("✅ Música finalizada")
        return
    end

    local filled = math.floor((currentTime / trackLength) * 38)
    local bar = string.rep("█", filled)
    progressBar:setText(bar)
end

-- Busca simulada (substitua por API real se quiser)
local function searchMusic(query)
    searchResults = {
        {title = "lofi - elf4iries", length = 120},
        {title = "rainy vibes - elf4iries", length = 140},
        {title = "forest dreams - elf4iries", length = 180},
        {title = "night lights - elf4iries", length = 160}
    }

    resultList:clear()
    for i, result in ipairs(searchResults) do
        resultList:addItem(shorten(result.title, 35))
    end
end

-- Tocar música
local function playMusic(index)
    local track = searchResults[index]
    if not track then return end

    currentTrack = track.title
    trackLength = track.length
    currentTime = 0
    isPlaying = true

    statusLabel:setText("🎶 Tocando: " .. track.title)
    progressBar:setText("")

    -- Simulação de execução com progress bar
    basalt.schedule(function()
        while isPlaying do
            updateProgress()
            os.sleep(1)
        end
    end)
end

-- Eventos
searchBtn:onClick(function()
    local query = input:getValue()
    if query == "" then
        statusLabel:setText("Digite algo para pesquisar!")
    else
        statusLabel:setText("🔍 Buscando...")
        os.sleep(0.2)
        searchMusic(query)
        statusLabel:setText("Selecione uma música da lista.")
    end
end)

resultList:onSelect(function(self, event, item)
    local index = self:getItemIndex(item)
    playMusic(index)
end)

-- Loop principal
basalt.autoUpdate()
