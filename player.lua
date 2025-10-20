-- player.lua (compatibilidade com Basalt: fallback para progress bar text-based)
local basalt = require("basalt")
local speaker = peripheral.find("speaker")

if not speaker then
    error("Speaker nao encontrado!")
end

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
    local name = url:match("([^/]+)%.f234%.dfpwm$") or ("Musica " .. i)
    if #name > 28 then name = name:sub(1,28) .. "..." end
    songNames[i] = name
end

local currentSong = 1
local isPlaying = false
local isPaused = false
local audioHandle = nil
local decoder = nil
local volume = 1.0
local songLength = 0
local currentTime = 0

local main = basalt.createFrame()
main:setBackground(colors.black)

-- header
local header = main:addFrame()
header:setPosition(1,1)
header:setSize(51,4)
header:setBackground(colors.blue)
local title = header:addLabel(); title:setText("ELFSMUSIC"); title:setPosition(16,2); title:setForeground(colors.white)
local subtitle = header:addLabel(); subtitle:setText("by elf4iries"); subtitle:setPosition(20,3); subtitle:setForeground(colors.lightBlue)

-- container
local container = main:addFrame(); container:setPosition(1,5); container:setSize(51,21); container:setBackground(colors.black)

-- playlist label + frame + list
local listLabel = container:addLabel(); listLabel:setText("PLAYLIST:"); listLabel:setPosition(2,1); listLabel:setForeground(colors.yellow)
local listFrame = container:addFrame(); listFrame:setPosition(2,2); listFrame:setSize(30,18); listFrame:setBackground(colors.gray)
local songList = listFrame:addList(); songList:setPosition(1,1); songList:setSize(30,18); songList:setBackground(colors.gray); songList:setForeground(colors.white)

for i, name in ipairs(songNames) do
    local it = { text = name }
    if i == currentSong then it.selected = true end
    songList:addItem(it)
end

-- control frame
local control = container:addFrame(); control:setPosition(33,1); control:setSize(18,22); control:setBackground(colors.black)
local nowLabel = control:addLabel(); nowLabel:setText("TOCANDO:"); nowLabel:setPosition(1,1); nowLabel:setForeground(colors.yellow)
local musicLabel = control:addLabel(); musicLabel:setPosition(1,2); musicLabel:setSize(18,1); musicLabel:setForeground(colors.white); musicLabel:setText(songNames[currentSong])
local statusLabel = control:addLabel(); statusLabel:setText("Parado"); statusLabel:setPosition(1,3); statusLabel:setForeground(colors.orange)

local playB = control:addButton(); playB:setText("▶"); playB:setPosition(5,5); playB:setSize(8,3); playB:setBackground(colors.green); playB:setForeground(colors.white)
local pauseB = control:addButton(); pauseB:setText("⏸"); pauseB:setPosition(5,9); pauseB:setSize(8,3); pauseB:setBackground(colors.yellow); pauseB:setForeground(colors.black)
local stopB = control:addButton(); stopB:setText("⏹"); stopB:setPosition(5,13); stopB:setSize(8,3); stopB:setBackground(colors.red); stopB:setForeground(colors.white)
local quitB = control:addButton(); quitB:setText("SAIR"); quitB:setPosition(1,17); quitB:setSize(18,2); quitB:setBackground(colors.red); quitB:setForeground(colors.white)

-- ===== compat factory para progressbars =====
local function makeProgress(parent, x, y, width, opts)
    -- opts: {initial = 0, barChar = "█", emptyChar = " "}
    opts = opts or {}
    local initial = opts.initial or 0
    local barChar = opts.barChar or "█"
    local emptyChar = opts.emptyChar or " "
    -- se parent tiver addProgressbar, usa nativo
    if type(parent.addProgressbar) == "function" then
        local pb = parent:addProgressbar()
        if x and y then pb:setPosition(x, y) end
        if width then pb:setSize(width, 1) end
        pb:setBackground(colors.gray)
        -- setProgress espera 0-100 nas docs
        pb:setProgress(initial)
        return {
            setProgress = function(_, v) pb:setProgress(v) end,
            raw = pb
        }
    else
        -- fallback: cria label e desenha barra textual
        local lbl = parent:addLabel()
        if x and y then lbl:setPosition(x, y) end
        lbl:setSize(width or 20, 1)
        local function drawBar(v)
            local pct = math.max(0, math.min(100, math.floor(v)))
            local w = (width or 20)
            local filled = math.floor((pct/100) * w)
            local bar = string.rep(barChar, filled) .. string.rep(emptyChar, math.max(0, w - filled))
            lbl:setText("[" .. bar .. "] " .. tostring(pct) .. "%")
        end
        drawBar(initial)
        return {
            setProgress = function(_, v) drawBar(v) end,
            raw = lbl
        }
    end
end
-- ===== fim factory =====

-- cria volume bar (usa factory)
local volBar = makeProgress(control, 1, 20, 18, { initial = math.floor(volume * 100) })

local volDown = control:addButton(); volDown:setText("-"); volDown:setPosition(1,21); volDown:setSize(8,1); volDown:setBackground(colors.gray); volDown:setForeground(colors.white)
local volUp = control:addButton(); volUp:setText("+"); volUp:setPosition(10,21); volUp:setSize(9,1); volUp:setBackground(colors.gray); volUp:setForeground(colors.white)

-- cria barra de progresso da música
local prog = makeProgress(control, 1, 23, 18, { initial = 0 })
local progText = control:addLabel(); progText:setPosition(1,24); progText:setText("0:00 / 0:00"); progText:setForeground(colors.lightGray)

local footer = main:addLabel(); footer:setText("Speaker: " .. (speaker and "OK" or "NAO ENCONTRADO")); footer:setPosition(2,26); footer:setForeground(speaker and colors.lime or colors.red)

-- util
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
    prog.setProgress(prog, 0)
    progText:setText("0:00 / 0:00")
end

local function progressLooper()
    while isPlaying do
        if not isPaused and songLength > 0 then
            currentTime = math.min(currentTime + 1, songLength)
            local percent = math.floor((currentTime / songLength) * 100)
            prog.setProgress(prog, percent)
            progText:setText(string.format("%d:%02d / %d:%02d", math.floor(currentTime/60), currentTime%60, math.floor(songLength/60), songLength%60))
        end
        os.sleep(1)
    end
end

local function playNext()
    currentSong = currentSong + 1
    if currentSong > #playlist then currentSong = 1 end
    -- refaz lista para marcar selected (compatível)
    songList:clear()
    for i, name in ipairs(songNames) do
        local t = { text = name }
        if i == currentSong then t.selected = true end
        songList:addItem(t)
    end
    musicLabel:setText(songNames[currentSong])
    basalt.schedule(function() playAudio() end)
end

function playAudio()
    if not speaker then
        statusLabel:setText("Sem speaker!")
        statusLabel:setForeground(colors.red)
        return
    end

    stopAudio()
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

        -- lê todo (simples) e fecha handle
        local data = {}
        while true do
            local chunk = handle:read(16 * 1024)
            if not chunk then break end
            table.insert(data, chunk)
        end
        pcall(function() handle:close() end)
        local audio = table.concat(data)

        decoder = require("cc.audio.dfpwm").make_decoder()
        isPlaying = true
        isPaused = false
        currentTime = 0
        songLength = math.max(1, math.ceil(#audio / 16384)) -- estimativa em segundos

        statusLabel:setText("Tocando")
        statusLabel:setForeground(colors.lime)
        musicLabel:setText(songNames[currentSong])

        basalt.schedule(progressLooper)

        local pos = 1
        local chunkSize = 16384
        while isPlaying and pos <= #audio do
            if not isPaused then
                local rawChunk = audio:sub(pos, pos + chunkSize - 1)
                local okPlay = safePlayAudio(decoder(rawChunk))
                if not okPlay then os.pullEvent("speaker_audio_empty") end
                pos = pos + chunkSize
            else
                os.sleep(0.1)
            end
        end

        isPlaying = false
        statusLabel:setText("Finalizado")
        prog.setProgress(prog, 100)
        os.sleep(0.5)
        playNext()
    end)
end

-- List onSelect (docs oficiais: onSelect(index, item))
songList:onSelect(function(index, item)
    if index and type(index) == "number" then
        currentSong = index
        musicLabel:setText(songNames[currentSong])
        -- atualiza visual selected
        songList:clear()
        for i, name in ipairs(songNames) do
            local t = { text = name }
            if i == currentSong then t.selected = true end
            songList:addItem(t)
        end
    end
end)

playB:onClick(function()
    if not isPlaying then basalt.schedule(function() playAudio() end)
    elseif isPaused then isPaused = false; statusLabel:setText("Tocando") end
end)

pauseB:onClick(function() if isPlaying then isPaused = not isPaused; statusLabel:setText(isPaused and "Pausado" or "Tocando") end end)
stopB:onClick(function() stopAudio() end)
quitB:onClick(function() stopAudio(); basalt.stop() end)

volDown:onClick(function() volume = math.max(0, volume - 0.1); volBar.setProgress(volBar, math.floor(volume*100)) end)
volUp:onClick(function() volume = math.min(1, volume + 0.1); volBar.setProgress(volBar, math.floor(volume*100)) end)

basalt.run()
