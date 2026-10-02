local p = {}
local wikipedia = "https://en.wikipedia.org/wiki/"
local noLang = false

local function genEn(frame)
  local enPage = frame.args[1]
  if enPage ~= nil then
    enPage = enPage:gsub(" ", "_")
  else
    enPage = ""
  end
  local display = frame.args[2]
  if display ~= nil and display ~= "" then
    display = display:gsub("_", " ")
  else
    display = enPage:gsub("_", " ")
  end
  local title = mw.title.getCurrentTitle()
  local  res = "（[" .. wikipedia .. enPage .. " " .. display .. "]）"
 --  end 
  if noLang ~= true then
    res = res .. "[[en:" .. enPage:gsub("_", " ") .. "]]"
  end
  return res
end

function p.en(frame)
  return genEn(frame)
end

function p.enNoLang(frame)
  noLang = true
  return genEn(frame)
end

return p