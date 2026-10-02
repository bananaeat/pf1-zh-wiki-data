-- 危害卡片（2026-10-02；AoN「Afflictions/Hazards」一章全量录入，用户定：做「危害速查」，毒药、毒品物品速查里照旧也能查到）。
-- 源文件在仓库 design/hazard_card.lua，站上是 模块:危害；由 模板:危害 调用：{{#invoke:危害|card}}（参数取模板的）。
-- 外观沿用物品卡（Common.css「物品卡片」一节的 .item 类），一栏一项，页上的参数就是数据（危害速查从这里导）。
--
-- kind（八类，进同名分类，另进 分类:危害）：毒药、疾病、诅咒、毒品、疯狂、腐化、作祟、陷阱。
-- 通用：name、english_name（照抄 AoN 条目名，自动链到 AoN；地址不同写 aon=，写 aon=无 不挂）、source（书名，几本用「、」）、description（卡内正文）。
-- 苦难（毒药、疾病、诅咒、毒品、疯狂）：type 类型、save 豁免、onset 发作期、frequency 频率、effect 效果、
--   initial 初始效果、secondary 次要效果、cure 治愈、price 价格、weight 重量；毒品另有 addiction 成瘾性、damage 伤害；疯狂另有 dormancy 休眠效果。
-- 作祟：cr、xp、alignment 阵营、area 范围、cl 施法者等级、notice 察觉、hp 生命值、weakness 弱点、trigger 触发、reset 复位、effect 效果、destruction 摧毁。
-- 陷阱：cr、trap_type 类型（机械／魔法）、perception 察觉 DC、disable 解除装置 DC、trigger 触发、duration 持续时间、reset 复位、bypass 绕过、effect 效果。
-- 腐化：只有通用栏；催化剂、进程、显形等长文写在卡片下面的正文里。
local p = {}
local U = mw.ustring

local AON = {
    ['毒药'] = 'PoisonDisplay.aspx?ItemName=', ['疾病'] = 'Diseases.aspx?ItemName=', ['诅咒'] = 'Curses.aspx?ItemName=',
    ['毒品'] = 'Drugs.aspx?ItemName=', ['疯狂'] = 'Madnesses.aspx?ItemName=', ['腐化'] = 'Corruptions.aspx?ItemName=',
    ['作祟'] = 'Haunts.aspx?ItemName=', ['陷阱'] = 'Traps.aspx?ItemName=',
}
-- 规则页（标签挂链）
local RULE = {
    ['毒药'] = '疾病与毒药#毒药', ['疾病'] = '疾病与毒药#疾病', ['诅咒'] = '特殊能力#诅咒', ['毒品'] = '药物与成瘾',
    ['疯狂'] = '疯狂', ['腐化'] = '腐化', ['作祟'] = '作祟', ['陷阱'] = '陷阱',
}

local function trim(s) return s and mw.text.trim(s) or '' end

local function list(v)
    local out = {}
    for part in mw.text.gsplit(v or '', '[，,、；;]', false) do
        part = trim(part)
        if part ~= '' then out[#out + 1] = part end
    end
    return out
end

local function sources(v)
    local d = mw.loadData('模块:版权抬头/书目')
    local out = {}
    for _, t in ipairs(list(v)) do
        local b = d.by[t] or d.by[U.lower(t)]
        if b then
            local s = U.find(b.name, '[一-鿿]') and ('《[[' .. b.name .. ']]》') or ('《' .. b.name .. '》')
            if b.abbr ~= '' then s = s .. '（' .. b.abbr .. '）' end
            out[#out + 1] = s
        else
            out[#out + 1] = '《' .. t .. '》'
        end
    end
    return table.concat(out, '、')
end

local function stat(k, v, wide)
    if not v or v == '' then return '' end
    return '<span class="item-stat' .. (wide and ' wide' or '') .. '"><span class="k">' .. k .. '</span>' .. v .. '</span>'
end

local function block(k, v)
    if not v or v == '' then return '' end
    return '<div class="item-block"><span class="k">' .. k .. '</span>' .. v .. '</div>'
end

function p.card(frame)
    local a = frame:getParent().args
    local g = function(k) return trim(a[k]) end
    local title = mw.title.getCurrentTitle()
    local name = g('name') ~= '' and g('name') or title.text
    local kind = g('kind')
    local rule = RULE[kind]
    local tags = '<span class="tag">' .. (rule and ('[[' .. rule .. '|' .. kind .. ']]') or (kind ~= '' and kind or '危害')) .. '</span>'
    if g('type') ~= '' and g('type') ~= kind then tags = tags .. '<span class="tag">' .. g('type') .. '</span>' end
    if g('trap_type') ~= '' then tags = tags .. '<span class="tag">' .. g('trap_type') .. '</span>' end

    local en, aon, enline = g('english_name'), g('aon'), ''
    if en ~= '' then
        if aon == '无' or (aon == '' and not AON[kind]) then
            enline = en
        else
            local url = aon ~= '' and aon or (AON[kind] .. mw.uri.encode(en, 'PATH'))
            enline = '[https://aonprd.com/' .. url .. ' ' .. en .. ']'
        end
        enline = '<div class="item-en">' .. enline .. '</div>'
    end

    local cr = g('cr')
    local crline = ''
    if cr ~= '' then
        crline = '<span class="item-cr">CR ' .. cr .. (g('xp') ~= '' and (' · XP ' .. g('xp')) or '') .. '</span>'
    end

    local s = {
        -- 苦难
        stat('豁免', g('save')),
        stat('发作期', g('onset')),
        stat('频率', g('frequency')),
        stat('成瘾性', g('addiction')),
        stat('治愈', g('cure')),
        stat('价格', g('price')),
        stat('重量', g('weight')),
        -- 作祟
        stat('阵营', g('alignment')),
        stat('范围', g('area')),
        stat('施法者等级', g('cl')),
        stat('生命值', g('hp')),
        stat('弱点', g('weakness'), true),
        -- 陷阱
        stat('察觉', g('perception')),
        stat('解除装置', g('disable')),
        stat('触发', g('trigger')),
        stat('持续时间', g('duration')),
        stat('复位', g('reset')),
        stat('绕过', g('bypass'), true),
        -- 作祟的察觉栏常写成「[[察觉]] DC 20（……）」：标签已经是察觉，去掉值开头的那个
        stat('察觉', (U.gsub(g('notice'), '^%[?%[?察觉%]?%]?%s*(DC)', '%1')), true),       -- 只去掉紧跟 DC 的（「察觉或知识」不动）
    }
    local out = { '<div class="item item-hazard"><div class="item-head"><div class="item-name">', name, crline,
                  '<span class="item-cats">', tags, '</span></div>', enline, '</div>',
                  '<div class="item-stats">', table.concat(s), '</div>' }
    out[#out + 1] = block('初始效果', g('initial'))
    out[#out + 1] = block('次要效果', g('secondary'))
    out[#out + 1] = block('效果', g('effect'))
    out[#out + 1] = block('伤害', g('damage'))
    out[#out + 1] = block('休眠效果', g('dormancy'))
    out[#out + 1] = block('摧毁', g('destruction'))
    local desc = g('description')
    if desc ~= '' then out[#out + 1] = '<div class="item-desc">\n' .. desc .. '\n</div>' end
    if g('source') ~= '' then
        out[#out + 1] = '<div class="item-source"><span class="key">来源</span> <span class="value">' .. sources(g('source')) .. '</span></div>'
    end
    out[#out + 1] = '</div>'
    if title.namespace == 0 then
        out[#out + 1] = '[[分类:危害]]' .. (kind ~= '' and ('[[分类:' .. kind .. ']]') or '')
    end
    return table.concat(out)
end

return p