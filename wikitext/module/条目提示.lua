-- 悬停提示卡：法术 / 专长 / 物品共用一套。
-- '''直接读条目页上的模板参数'''，包括完整正文——不走数据层，因为
-- Data:*.tab 的单格上限是 400 字符，而正文动辄上千字（解除魔法 1183 字）。
-- 读页面还有个好处：条目页一改，卡片跟着变，不用重导数据。
local p = {}

-- 把 {{模板 |k=v ... }} 拆成表。值可能跨多行（正文有分段和空行），所以按行走：
-- 遇到 |key= 开一个新键，否则把这一行接到当前键后面。
local function parse(text, tpl)
    local t = {}
    local start = string.find(text, '{{' .. tpl, 1, true)
    if not start then return t end
    local key = nil
    for _, line in ipairs(mw.text.split(string.sub(text, start), '\n', true)) do
        local k, v = string.match(line, '^|([%w_]+)=(.*)$')
        if k then
            key = k
            t[k] = v
        elseif string.sub(line, 1, 2) == '}}' then
            break
        elseif key then
            t[key] = t[key] .. '\n' .. line
        end
    end
    return t
end

local function has(v) return v and v ~= '' end

-- 一格「标签 值」，源数据里的分号显示成顿号
local function seg(label, val)
    if not has(val) then return '' end
    return '<span style="white-space:nowrap">' .. label .. ' '
        .. string.gsub(val, ';', '、') .. '</span>　'
end

local function line(style, s)
    if not has(s) then return '' end
    return '<div style="' .. style .. '">' .. s .. '</div>'
end

local MUTED = 'color:#8a8175;font-size:.95em'
local DARK = 'color:#5c4f35'

-- 卡片外壳：'''底色必须写死在行内''' ——浮层本身透明，不自带底就是字浮在页面上
local function shell(parts)
    return '<div style="max-width:32em;max-height:24em;overflow-y:auto;'
        .. 'background:#fffdf8;border:1px solid #d9d2c4;border-radius:4px;'
        .. 'padding:.55em .8em;font-size:.85em;line-height:1.6;color:#333;'
        .. 'box-shadow:0 2px 10px rgba(90,74,46,.14)">'
        .. table.concat(parts, '\n') .. '</div>'
end

local function head(name, en)
    local x = ''
    if has(en) then
        x = ' <span style="font-weight:normal;font-size:.85em;color:#8a8175">' .. en .. '</span>'
    end
    return '<div style="font-weight:bold;font-size:1.15em">' .. name .. x .. '</div>'
end

local function body(s)
    if not has(s) then return '' end
    return '<div style="border-top:1px solid #ebe4d6;padding-top:.4em;margin-top:.25em">'
        .. s .. '</div>'
end

local function load(frame, tpl)
    local name = frame.args[1]
    if not has(name) then name = mw.title.getCurrentTitle().text end
    local page = mw.title.new(name)
    local text = page and page:getContent()
    if not text then return nil, name end
    return parse(text, tpl), name
end

local function fail(name)
    return '<span style="color:#a00">找不到页面：' .. tostring(name) .. '</span>'
end

function p.spell(frame)
    local s, name = load(frame, 'Spell')
    if not s then return fail(name) end
    local tags = ''
    if has(s.tags) then tags = '（' .. s.tags .. '）' end
    local meta = seg('施法', s.action) .. seg('成分', s.components) .. seg('距离', s.range)
        .. seg('目标', s.target or s.effect or s.area) .. seg('持续', s.duration)
        .. seg('豁免', s.save) .. seg('法术抗力', s.sr)
    return frame:preprocess(shell({
        head(s.name or name, s.english_name),
        line(DARK, (s.school or '') .. tags),
        line(DARK, has(s.levels) and string.gsub(s.levels, ';', '、') or ''),
        line(MUTED .. ';margin:.15em 0 .4em', meta),
        body(s.description),
        line(MUTED .. ';margin-top:.4em', has(s.source) and ('出处 ' .. s.source) or ''),
    }))
end

-- 专长先决条件的标准写法、挂准确的链（模块:专长链，2026-09-29）；数据里没有（新专长、重定向名）返回 nil，照旧用原文
local function featPre(name)
    local ok, chain = pcall(require, '模块:专长链')
    return ok and chain.text and chain.text(name) or nil
end

function p.feat(frame)
    local s, name = load(frame, 'Feat')
    if not s then return fail(name) end
    local extra = ''
    if has(s.normal) then extra = extra .. line(MUTED .. ';margin-top:.35em', '常规：' .. s.normal) end
    if has(s.special) then extra = extra .. line(MUTED .. ';margin-top:.35em', '特殊：' .. s.special) end
    return frame:preprocess(shell({
        head(s.name or name, s.english_name),
        line(DARK, has(s.categories) and string.gsub(s.categories, ';', '、') or ''),
        line(MUTED .. ';margin:.15em 0 .4em', seg('先决条件', featPre(name) or s.prerequisites)),
        line('color:#6b5b3e', s.description),
        body(s.benefit),
        extra,
        line(MUTED .. ';margin-top:.4em',
            has(s.source_name) and ('出处 ' .. s.source_name) or ''),
    }))
end

function p.item(frame)
    local s, name = load(frame, '物品')
    if not s then return fail(name) end
    local cat = s.category or ''
    if has(s.slot) then cat = cat .. '　' .. s.slot end
    local meta = seg('价格', s.price) .. seg('重量', s.weight) .. seg('灵光', s.aura)
        .. seg('CL', s.cl) .. seg('伤害', s.dmg) .. seg('重击', s.crit)
        .. seg('射程', s.range) .. seg('类型', s.type)
    local craft = ''
    if has(s.requirements) then
        craft = '制造需求 ' .. s.requirements
        if has(s.cost) then craft = craft .. '；造价 ' .. s.cost end
    end
    return frame:preprocess(shell({
        head(s.name or name, s.english_name),
        line(DARK, cat),
        line(MUTED .. ';margin:.15em 0 .4em', meta),
        body(s.description),
        line(MUTED .. ';margin-top:.35em', craft),
        line(MUTED .. ';margin-top:.4em',
            has(s.source_name) and ('出处 ' .. s.source_name) or ''),
    }))
end

-- 自动认类型：看条目页上挂的是哪个模板，派给对应的卡。
-- 散文里的链接不知道目标是法术还是专长，用这个入口就不用在调用处写死。
function p.auto(frame)
    local name = frame.args[1]
    if not has(name) then name = mw.title.getCurrentTitle().text end
    local page = mw.title.new(name)
    local text = page and page:getContent()
    if not text then return fail(name) end
    if string.find(text, '{{Spell', 1, true) then return p.spell(frame) end
    if string.find(text, '{{Feat', 1, true) then return p.feat(frame) end
    if string.find(text, '{{物品', 1, true) then return p.item(frame) end
    return ''      -- 不是这三类就什么都不弹
end

return p