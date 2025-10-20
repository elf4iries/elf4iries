-- player.lua — Basalt compat + tema azul + streaming seguro
local basalt = require("basalt")
local dfpwm  = require("cc.audio.dfpwm")

local spk = peripheral.find("speaker")
if not spk then error("Speaker nao encontrado!") end

-- ======== PLAYLIST (completa) ========
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
  "https://raw.githubusercontent.com/elf4iries/elf4iries/main/musicas/Silent Hedges.f234.dfpwm",
}

local names = {}
for i,u in ipairs(playlist) do
  local n = u:match("([^/]+)%.f234%.dfpwm$") or ("Música "..i)
  if #n>28 then n = n:sub(1,28).."..."; end
  names[i]=n
end

-- ======== ESTADO ========
local cur = 1
local playing = false
local paused  = false
local volume  = 1.0
local progressPct = 0

-- ======== UI (tema azul) ========
local main = basalt.createFrame()
main:setBackground(colors.black)

local header = main:addFrame():setPosition(1,1):setSize(51,3):setBackground(colors.blue)
header:addLabel():setText("ELF4IRIES MUSIC PLAYER"):setPosition(2,2):setForeground(colors.cyan)

-- lista
local lf = main:addFrame():setPosition(2,5):setSize(30,18):setBackground(colors.gray)
local list = lf:addList():setPosition(1,1):setSize(30,18):setBackground(colors.gray):setForeground(colors.white)
for _,n in ipairs(names) do list:addItem(n) end

-- painel direito
local right = main:addFrame():setPosition(33,5):setSize(17,18):setBackground(colors.black)

local lblNow = right:addLabel():setText("Tocando:"):setPosition(1,1):setForeground(colors.lightBlue)
local lblName= right:addLabel():setText(names[cur]):setPosition(1,2):setForeground(colors.white):setSize(17,1)

local lblStat= right:addLabel():setText("Parado"):setPosition(1,3):setForeground(colors.orange)

-- barra de progresso textual (fallback universal)
local lblProg = right:addLabel():setPosition(1,5):setSize(17,1):setText("")
local function setProgress(p) -- p: 0..100
  p = math.max(0, math.min(100, math.floor(p)))
  local w = 17
  local fill = math.floor(w * p / 100)
  lblProg:setText(string.rep("#", fill))
end

-- botões
local bPlay  = right:addButton():setText("▶"):setPosition(3,7):setSize(4,2):setBackground(colors.cyan)
local bPause = right:addButton():setText("⏸"):setPosition(8,7):setSize(4,2):setBackground(colors.lightBlue):setForeground(colors.black)
local bStop  = right:addButton():setText("⏹"):setPosition(13,7):setSize(4,2):setBackground(colors.blue)

local bPrev  = right:addButton():setText("⏮"):setPosition(3,10):setSize(4,2):setBackground(colors.gray)
local bNext  = right:addButton():setText("⏭"):setPosition(8,10):setSize(4,2):setBackground(colors.gray)

-- volume
right:addLabel():setText("Vol:"):setPosition(1,13):setForeground(colors.lightBlue)
local lblVol = right:addLabel():setText("100%"):setPosition(5,13)
local bVdn = right:addButton():setText("-"):setPosition(1,14):setSize(7,1):setBackground(colors.gray)
local bVup = right:addButton():setText("+"):setPosition(9,14):setSize(7,1):setBackground(colors.gray)

-- rodapé
main:addLabel():setText("Speaker: OK"):setPosition(2,24):setForeground(colors.lime)

-- ======== ÁUDIO (streaming + yields) ========
local function safePlay(buf)
  local ok,res = pcall(function() return spk.playAudio(buf, volume) end)
  return ok and res
end

local function stopAudio()
  playing = false
  paused = false
  progressPct = 0
  setProgress(0)
  lblStat:setText("Parado"):setForeground(colors.orange)
end

local function startSong(i)
  cur = i
  lblName:setText(names[cur])
  lblStat:setText("Carregando..."):setForeground(colors.yellow)
  setProgress(0)
  playing = true
  paused = false

  -- roda em background e sempre rende
  basalt.schedule(function()
    -- http.get pode travar alguns ticks, mas é curto
    local ok, handle = pcall(http.get, playlist[cur], {["Cache-Control"]="no-cache"})
    if not ok or not handle then
      lblStat:setText("Erro HTTP"):setForeground(colors.red); playing=false; return
    end

    local decoder = dfpwm.make_decoder()
    lblStat:setText("Tocando"):setForeground(colors.lime)

    -- stream por chunks pequenos e yields frequentes
    local CHUNK = 4096           -- menor = mais seguro
    local count = 0              -- para yield periódico
    local totalBytes = 0         -- só p/ estimativa de progresso (best-effort)
    while playing do
      if paused then
        os.sleep(0.05)           -- render
      else
        local chunk = handle:read(CHUNK)
        if not chunk then break end
        totalBytes = totalBytes + #chunk
        local pcm = decoder(chunk)

        -- toca: se o buffer estiver cheio, esperamos o evento do speaker (yield)
        local okP = safePlay(pcm)
        if not okP then
          os.pullEvent("speaker_audio_empty")
        end

        -- yield explícito a cada ~32 chunks
        count = count + 1
        if count % 32 == 0 then os.sleep(0) end

        -- barra de progresso “animada” (sem tamanho real do arquivo)
        progressPct = (progressPct + 2) % 100
        setProgress(progressPct)
      end
    end

    pcall(function() handle.close() end)
    if playing then
      -- terminou a música naturalmente
      lblStat:setText("Fim"):setForeground(colors.cyan)
      setProgress(100)
      os.sleep(0.2)
      -- pula para a próxima
      local nxt = cur + 1; if nxt > #playlist then nxt = 1 end
      startSong(nxt)
    else
      -- parado manualmente
      setProgress(0)
    end
  end)
end

-- ======== EVENTOS ========
list:onSelect(function(self, _, item)
  local idx = self:getItemIndex(item)
  if idx then startSong(idx) end
end)

bPlay:onClick(function()
  if not playing then startSong(cur)
  elseif paused then paused=false; lblStat:setText("Tocando"):setForeground(colors.lime) end
end)

bPause:onClick(function()
  if playing then
    paused = not paused
    if paused then lblStat:setText("Pausado"):setForeground(colors.orange)
    else lblStat:setText("Tocando"):setForeground(colors.lime) end
  end
end)

bStop:onClick(function() stopAudio() end)

bPrev:onClick(function()
  local i = cur - 1; if i < 1 then i = #playlist end
  if playing then stopAudio() end
  startSong(i)
end)

bNext:onClick(function()
  local i = cur + 1; if i > #playlist then i = 1 end
  if playing then stopAudio() end
  startSong(i)
end)

bVdn:onClick(function()
  volume = math.max(0, volume - 0.1)
  lblVol:setText(tostring(math.floor(volume*100)).."%")
end)

bVup:onClick(function()
  volume = math.min(1, volume + 0.1)
  lblVol:setText(tostring(math.floor(volume*100)).."%")
end)

-- ======== LOOP UI ========
basalt.run() 
