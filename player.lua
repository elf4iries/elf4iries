-- player.lua — Basalt (recente) + navy + shuffle ON + repeat + fade + progress real
local basalt = require("basalt")
local dfpwm  = require("cc.audio.dfpwm")

-- ====== Periférico ======
local speaker = peripheral.find("speaker")
if not speaker then error("Speaker não encontrado!") end

-- ====== Playlist ======
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
for i,url in ipairs(playlist) do
  local n = url:match("([^/]+)%.f234%.dfpwm$") or ("Música "..i)
  if #n>30 then n = n:sub(1,30).."..." end
  names[i] = n
end

-- ====== Estado ======
local curIdx         = 1
local isPlaying      = false
local isPaused       = false
local shuffleOn      = true     -- ligado por padrão
local repeatOne      = false
local userVolume     = 1.0      -- 0.0..1.0 (exposto ao usuário)
local gainNow        = 0.0      -- volume aplicado com fade
local gainTarget     = 1.0
local progressPct    = 0
local elapsedSec     = 0
local totalBytes     = 0
local processedBytes = 0

-- ====== Util ======
local function fmt_time(sec)
  sec = math.max(0, math.floor(sec))
  return string.format("%d:%02d", math.floor(sec/60), sec%60)
end

local function setGain(target, steps, sleepTick)
  steps = steps or 10; sleepTick = sleepTick or 0
  local delta = (target - gainNow) / steps
  for _=1,steps do
    gainNow = math.max(0, math.min(1, gainNow + delta))
    if sleepTick>0 then os.sleep(sleepTick) end
  end
  gainNow = target
end

local function spkPlay(buffer)
  -- aplica fade multiplicando o ganho final por userVolume
  local ok,res = pcall(function() return speaker.playAudio(buffer, gainNow * userVolume) end)
  return ok and res
end

local function headers_length(h)
  if not h then return nil end
  for k,v in pairs(h) do
    local key = k:lower()
    if key == "content-length" then
      local s = type(v)=="table" and v[1] or v
      local n = tonumber(s)
      if n and n>0 then return n end
    end
  end
  return nil
end

-- ====== Shuffle ======
local function makeShuffled(n)
  local t = {}
  for i=1,n do t[i]=i end
  for i=n,2,-1 do
    local j = math.random(i)
    t[i],t[j] = t[j],t[i]
  end
  return t
end
local order = makeShuffled(#playlist)
local function nextIndex()
  if repeatOne then return curIdx end
  if shuffleOn then
    -- pega posição atual dentro de "order" e vai para a próxima
    local pos=1
    for i,v in ipairs(order) do if v==curIdx then pos=i; break end end
    pos = pos + 1; if pos>#order then pos=1 end
    return order[pos]
  else
    local n = curIdx + 1; if n>#playlist then n=1 end
    return n
  end
end
local function prevIndex()
  if repeatOne then return curIdx end
  if shuffleOn then
    local pos=1
    for i,v in ipairs(order) do if v==curIdx then pos=i; break end end
    pos = pos - 1; if pos<1 then pos=#order end
    return order[pos]
  else
    local p = curIdx - 1; if p<1 then p=#playlist end
    return p
  end
end

-- ====== UI (tema navy: azul, preto, branco) ======
local root = basalt.createFrame(); root:setBackground(colors.black)

local header = root:addFrame():setPosition(1,1):setSize(51,3):setBackground(colors.blue)
header:addLabel():setText("ELF4IRIES MUSIC PLAYER"):setPosition(2,2):setForeground(colors.white)

local playlistFrame = root:addFrame():setPosition(1,4):setSize(51,23):setBackground(colors.black)
local playerFrame   = root:addFrame():setPosition(1,4):setSize(51,23):setBackground(colors.black)

-- START on playlist
playerFrame:hide()
playlistFrame:show()

-- Playlist UI
local list = playlistFrame:addList():setPosition(2,2):setSize(34,18):setBackground(colors.gray):setForeground(colors.white)
for _,n in ipairs(names) do list:addItem(n) end

local btnPlaySel  = playlistFrame:addButton():setText("▶ Tocar Selecionada"):setPosition(38,2):setSize(12,3):setBackground(colors.blue):setForeground(colors.white)
local btnShuffle  = playlistFrame:addButton():setText("🔀 Shuffle: ON"):setPosition(38,6):setSize(12,3):setBackground(colors.lightBlue):setForeground(colors.black)
local btnOpenNow  = playlistFrame:addButton():setText("Abrir Player »"):setPosition(38,10):setSize(12,3):setBackground(colors.gray):setForeground(colors.white)

-- Player UI
local lblNow  = playerFrame:addLabel():setText("Tocando agora:"):setPosition(2,1):setForeground(colors.white)
local lblName = playerFrame:addLabel():setText("-"):setPosition(2,2):setForeground(colors.white):setSize(47,1)

local timeRow = playerFrame:addFrame():setPosition(2,4):setSize(47,1):setBackground(colors.black)
local lblTime = timeRow:addLabel():setText("0:00 / --:--"):setPosition(1,1):setForeground(colors.white)

local prog = playerFrame:addProgressbar():setPosition(2,5):setSize(47,1)
prog:setBackground(colors.gray); prog:setProgressBar(colors.blue); prog:setProgress(0)

local row1 = playerFrame:addFrame():setPosition(2,7):setSize(47,3):setBackground(colors.black)
local btnPrev  = row1:addButton():setText("⏮"):setPosition(1,1):setSize(9,3):setBackground(colors.gray):setForeground(colors.white)
local btnPlay  = row1:addButton():setText("▶"):setPosition(11,1):setSize(9,3):setBackground(colors.blue):setForeground(colors.white)
local btnPause = row1:addButton():setText("⏸"):setPosition(21,1):setSize(9,3):setBackground(colors.lightBlue):setForeground(colors.black)
local btnStop  = row1:addButton():setText("⏹"):setPosition(31,1):setSize(9,3):setBackground(colors.blue):setForeground(colors.white)

local row2 = playerFrame:addFrame():setPosition(2,11):setSize(47,3):setBackground(colors.black)
local btnNext   = row2:addButton():setText("⏭"):setPosition(1,1):setSize(9,3):setBackground(colors.gray):setForeground(colors.white)
local btnRepeat = row2:addButton():setText("Repeat: OFF"):setPosition(11,1):setSize(15,3):setBackground(colors.gray):setForeground(colors.white)
local btnShuf2  = row2:addButton():setText("Shuffle: ON"):setPosition(27,1):setSize(15,3):setBackground(colors.lightBlue):setForeground(colors.black)

local row3 = playerFrame:addFrame():setPosition(2,15):setSize(47,3):setBackground(colors.black)
local lblVol   = row3:addLabel():setText("Vol: 100%"):setPosition(1,2):setForeground(colors.white)
local btnVdn   = row3:addButton():setText("-"):setPosition(12,1):setSize(5,3):setBackground(colors.gray):setForeground(colors.white)
local btnVup   = row3:addButton():setText("+"):setPosition(18,1):setSize(5,3):setBackground(colors.gray):setForeground(colors.white)
local btnBack  = row3:addButton():setText("« Playlist"):setPosition(26,1):setSize(21,3):setBackground(colors.gray):setForeground(colors.white)

local lblStatus = playerFrame:addLabel():setText("Parado").setPosition and playerFrame:addLabel():setPosition(2,19) or playerFrame:addLabel()
lblStatus:setText("Parado"); lblStatus:setPosition(2,19); lblStatus:setForeground(colors.white)

-- ====== Funções de controle ======
local playbackThread -- id da rotina atual

local function stopPlayback()
  isPlaying = false
  isPaused  = false
  gainTarget = 0.0
  -- fade out curto (não bloqueia decoding, apenas baixa ganho)
  setGain(0.0, 6, 0)
  lblStatus:setText("Parado")
end

local function startPlayback(index)
  -- finalizar qualquer reprodução anterior
  stopPlayback()
  curIdx = index
  lblName:setText(names[curIdx])
  lblStatus:setText("Carregando...")

  basalt.schedule(function()
    -- abrir conexão
    local ok, handle = pcall(http.get, playlist[curIdx])
    if not ok or not handle then
      lblStatus:setText("Erro de rede")
      return
    end
    -- detectar tamanho
    local hdrOk, hdrs = pcall(handle.getResponseHeaders, handle)
    totalBytes = headers_length(hdrOk and hdrs or nil) or 0
    processedBytes, progressPct, elapsedSec = 0, 0, 0
    prog:setProgress(0)
    lblTime:setText("0:00 / " .. (totalBytes>0 and "--:--" or "--:--"))

    -- decoder
    local decoder = dfpwm.make_decoder()

    -- estado
    isPlaying, isPaused = true, false
    lblStatus:setText("Tocando")
    -- fade in
    gainNow = 0.0; gainTarget = 1.0; setGain(1.0, 10, 0)

    -- reprodução (stream)
    local CHUNK = 16384
    local tick = 0
    while isPlaying do
      if isPaused then
        os.sleep(0.05)
      else
        local chunk = handle.read(CHUNK)
        if not chunk then break end

        processedBytes = processedBytes + #chunk
        local pcm = decoder(chunk)

        -- toca e, se buffer cheio, aguarda speaker esvaziar
        if not spkPlay(pcm) then
          os.pullEvent("speaker_audio_empty")
        end

        -- progresso e tempo (estimativa pelo fluxo de chunks)
        tick = tick + 1
        if tick % 4 == 0 then
          elapsedSec = elapsedSec + 1
          local pct = 0
          if totalBytes>0 then pct = math.floor(processedBytes*100/totalBytes) end
          progressPct = math.max(progressPct, pct)
          prog:setProgress(progressPct)
          lblTime:setText(("%s / --:--"):format(fmt_time(elapsedSec)))
          os.sleep(0) -- yield leve
        end
      end
    end

    pcall(handle.close, handle)

    if isPlaying then
      -- terminou natural → próxima (respeitando repeat/shuffle)
      if repeatOne then
        startPlayback(curIdx)
      else
        startPlayback(nextIndex())
      end
    else
      -- parado manualmente
      prog:setProgress(0)
    end
  end)
end

-- ====== Ligações de eventos (playlist) ======
btnPlaySel:onClick(function()
  local item = list:getItem(list:getItemIndex(list:getItem(list:getItemIndex() or 1)) or 1) -- fallback
  local idx  = list:getItemIndex(item) or 1
  playlistFrame:hide(); playerFrame:show()
  startPlayback(idx)
end)

btnShuffle:onClick(function()
  shuffleOn = not shuffleOn
  if shuffleOn then
    order = makeShuffled(#playlist)
    btnShuffle:setText("🔀 Shuffle: ON")
  else
    btnShuffle:setText("🔀 Shuffle: OFF")
  end
end)

btnOpenNow:onClick(function()
  playlistFrame:hide(); playerFrame:show()
end)

-- ====== Ligações de eventos (player) ======
btnPlay:onClick(function()
  if not isPlaying then startPlayback(curIdx)
  elseif isPaused then isPaused=false; lblStatus:setText("Tocando") end
end)

btnPause:onClick(function()
  if isPlaying then
    isPaused = not isPaused
    lblStatus:setText(isPaused and "Pausado" or "Tocando")
  end
end)

btnStop:onClick(function() stopPlayback(); prog:setProgress(0) end)

btnNext:onClick(function() startPlayback(nextIndex()) end)
btnPrev:onClick(function() startPlayback(prevIndex()) end)

btnRepeat:onClick(function()
  repeatOne = not repeatOne
  btnRepeat:setText(repeatOne and "Repeat: ON" or "Repeat: OFF")
end)

btnShuf2:onClick(function()
  shuffleOn = not shuffleOn
  if shuffleOn then order = makeShuffled(#playlist) end
  btnShuf2:setText(shuffleOn and "Shuffle: ON" or "Shuffle: OFF")
end)

btnVdn:onClick(function()
  userVolume = math.max(0, userVolume - 0.1)
  lblVol:setText(("Vol: %d%%"):format(math.floor(userVolume*100)))
end)

btnVup:onClick(function()
  userVolume = math.min(1, userVolume + 0.1)
  lblVol:setText(("Vol: %d%%"):format(math.floor(userVolume*100)))
end)

btnBack:onClick(function()
  stopPlayback()
  playerFrame:hide(); playlistFrame:show()
end)

-- Selecionar via clique direto na lista
list:onSelect(function(_, _, item)
  local idx = list:getItemIndex(item)
  if idx then
    playlistFrame:hide(); playerFrame:show()
    startPlayback(idx)
  end
end)

-- ====== Loop ======
basalt.autoUpdate()
