-- player.lua - Música com Basalt e DFPWM
local basalt = require("basalt")
local dfpwm = require("cc.audio.dfpwm")
-- Encontrar speakers conectados
local speakers = { peripheral.find("speaker") }
if #speakers == 0 then error("No speaker peripheral found") end

-- Variáveis de controle
local isPaused = false
local breakit = false
local returnToMenu = false
local shuffleEnabled = false
local playedTracks = {}
local volume = 1.0    -- volume (0.0 a 3.0)
local trackProgress = 0
local currentPosition = 1
local trackStartTime = 0
local backPressedOnce = false
local rootFolder = "/disk/"

-- Contar chaves em tabela
local function tablelength(t)
  local count = 0 for _,_ in pairs(t) do count = count + 1 end
  return count
end

-- Ler lista de arquivos de um diretório
local function readFolderContents(path)
  local files = {}
  for _, file in ipairs(fs.list(path)) do table.insert(files, file) end
  return files
end

-- Tocar chunk de áudio em todos os speakers
local function playChunk(chunk)
  local ret = nil
  local threads = {}
  for i,s in ipairs(speakers) do
    if i == 1 then
      table.insert(threads, function() ret = s.playAudio(chunk, volume) end)
    else
      table.insert(threads, function() s.playAudio(chunk, volume) end)
    end
  end
  parallel.waitForAll(table.unpack(threads))
  return ret
end

-- Atualiza rótulo de shuffle
local function updateShuffleStateLabel()
  if shuffleEnabled then shuffleStateLabel:setText("Aleatório: Ligado")
  else shuffleStateLabel:setText("Aleatório: Desligado") end
end

-- Alterna shuffle
local function onShufflePressed()
  shuffleEnabled = not shuffleEnabled
  updateShuffleStateLabel()
end

-- Alterna play/pause
local function togglePauseState()
  isPaused = not isPaused
end

-- Botão voltar faixa ou reiniciar
local function onPlaybackPressed()
  local now = os.clock()
  if backPressedOnce and (now - trackStartTime) <= 3 then
    currentPosition = math.max(1, currentPosition - 1)
    backPressedOnce = false
  else
    if (now - trackStartTime) > 3 then
      currentPosition = math.max(1, currentPosition - 1)
    end
    backPressedOnce = true
    trackStartTime = now
  end
  breakit = true
end

-- Botão avançar faixa
local function onSkipPressed()
  breakit = true
end

-- Botão voltar ao menu principal
local function onMainMenuButtonPressed()
  breakit = true; returnToMenu = true
  rootFolder = "/disk/"
  updateFileList(rootFolder)
  basalt.setActiveFrame(explorerFrame)
  explorerFrame:show(); playerFrame:hide()
  basalt.update()
end

-- Tocar arquivo DFPWM (com pause)
local function playSound(filePath)
  breakit = false; trackStartTime = os.clock()
  local fileName = filePath:match("^.+/(.+)$") or filePath
  trackLabel:setText(fileName)  -- atualiza rótulo
  local file = fs.open(filePath, "rb")
  if not file then return end
  local decoder = dfpwm.make_decoder()
  local totalSize = fs.getSize(filePath)
  trackProgress = 0
  while true do
    if breakit then break end
    if isPaused then
      os.sleep(0.1)
    else
      local chunk = file.read(1024 * 16)
      if not chunk then break end
      local decoded = decoder(chunk)
      if totalSize then
        trackProgress = math.floor((file.seek() / totalSize) * 100)
      end
      -- Tocar, aguardando buffer vazio se necessário
      while not playChunk(decoded) do
        if isPaused or breakit then break end
        os.pullEvent("speaker_audio_empty")
      end
    end
  end
  file.close()
end

-- Loop principal de reprodução
local function mainLoop(initialTrackPath)
  local fileLister = readFolderContents(rootFolder)
  if initialTrackPath then
    playSound(initialTrackPath)
    -- Ajustar posição atual para a próxima faixa
    for idx,f in ipairs(fileLister) do
      if fs.combine(rootFolder,f) == initialTrackPath then
        currentPosition = idx + 1; break
      end
    end
  end
  if shuffleEnabled and tablelength(playedTracks) >= #fileLister then
    playedTracks = {}
  end
  while currentPosition <= #fileLister do
    if returnToMenu then break end
    local filePath = fs.combine(rootFolder, fileLister[currentPosition])
    if shuffleEnabled then
      local nextTrack
      repeat
        nextTrack = math.random(1, #fileLister)
      until not playedTracks[nextTrack]
      playedTracks[nextTrack] = true
      currentPosition = nextTrack
      filePath = fs.combine(rootFolder, fileLister[currentPosition])
      playSound(filePath)
    else
      playSound(filePath)
      currentPosition = currentPosition + 1
    end
    if currentPosition > #fileLister and not shuffleEnabled then
      breakit = true; returnToMenu = true
      basalt.setActiveFrame(explorerFrame)
      explorerFrame:show(); playerFrame:hide()
      basalt.update()
      updateFileList("/disk/")
      break
    end
  end
end

-- Criar frames Basalt
local explorerFrame = basalt.createFrame()
explorerFrame:show()
local playerFrame = basalt.createFrame()

-- UI de exploração de arquivos
local fileList = explorerFrame:addList()
  :setPosition(2,2)
  :setSize(30,15)

function updateFileList(path)
  fileList:clear()
  for _,f in ipairs(fs.list(path)) do fileList:addItem(f) end
end

fileList:onSelect(function(self, evt, item)
  if item and item.text then
    local selPath = fs.combine(rootFolder, item.text)
    if fs.isDir(selPath) then
      rootFolder = selPath .. "/"
      updateFileList(rootFolder)
    else
      basalt.setActiveFrame(playerFrame)
      playerFrame:show(); explorerFrame:hide()
      parallel.waitForAll(
        function() mainLoop(selPath) end,
        function()
          breakit = false; returnToMenu = false
          local sw, sh = playerFrame:getSize()
          -- Nome da faixa
          trackLabel = playerFrame:addLabel():setPosition(1,2):setSize(sw,1):setText(item.text)
          -- Botão Shuffle
          playerFrame:addButton():setText("Aleatório"):setPosition(1,4):setSize(10,1):onClick(onShufflePressed)
          shuffleStateLabel = playerFrame:addLabel():setText("Aleatório: Desligado"):setPosition(12,4):setSize(10,1)
          -- Slider de volume
          playerFrame:addLabel():setText("Volume:"):setPosition(1,6)
          local volumeSlider = playerFrame:addSlider():setPosition(10,6):setSize(sw-11,1):setMax(300):setValue(volume*100)
          volumeSlider:onChange(function(_,val) volume = val/100 end)
          -- Slider de progresso
          playerFrame:addLabel():setText("Progresso:"):setPosition(1,8)
          local progressSlider = playerFrame:addSlider():setPosition(12,8):setSize(sw-13,1):setMax(100)
          progressSlider:onChange(function() progressSlider:setValue(trackProgress) end)
          -- Botões de controle
          local bottomY = sh - 2
          playerFrame:addButton():setText("="):setPosition(1,1):setSize(3,1):onClick(onMainMenuButtonPressed)
          playerFrame:addButton():setText("<"):setPosition(3,bottomY):setSize(3,1):onClick(onPlaybackPressed)
          playerFrame:addButton():setText("||"):setPosition(8,bottomY):setSize(3,1):onClick(togglePauseState)
          playerFrame:addButton():setText(">"):setPosition(13,bottomY):setSize(3,1):onClick(onSkipPressed)
          -- Visualizador de barras
          local numBars=16; local bw=1; local vh=10
          local vsx = math.floor((sw - numBars*bw)/2); local vsy = sh - vh - 3
          local bars={}
          for i=1,numBars do
            local xpos = vsx + (i-1)*bw
            bars[i] = playerFrame:addLabel():setPosition(xpos,vsy):setSize(bw,vh):setText("|")
          end
          -- Loop de eventos do playerFrame
          while true do
            if returnToMenu then break end
            updateShuffleStateLabel()
            for i=1,numBars do
              local h = isPaused and 0 or math.random(1,vh)
              bars[i]:setText(string.rep("|",h))
            end
            progressSlider:setValue(trackProgress)
            local ev = {os.pullEventRaw()}
            basalt.update(table.unpack(ev))
          end
        end
      )
    end
  end
end)

-- Iniciar lista e rodar UI
updateFileList(rootFolder)
basalt.autoUpdate()
