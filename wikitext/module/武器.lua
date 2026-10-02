-- 武器卡片（2026-10-01；物品全量校对第一块「武器」，用户定：新建 {{武器}}，参数一栏一项，就是数据）。
-- 源文件在仓库 design/weapon_card.lua，站上是 模块:武器；由 模板:武器 调用：{{#invoke:武器|card}}（参数取模板的）。
-- 外观沿用物品卡（Common.css「物品卡片」一节的 .item 类）。和 {{物品}} 比多做的事：
--   * 伤害只填小型、中型（dmg_s / dmg_m，双头武器写 1d6/1d6），超小型、大型按 CRB 表 6-5 现算；
--   * 特性（special）、武器组（groups）写成列表，各词挂到规则小节：特性 -> [[装备]] 武器量值里的「特性-X」锚点，
--     武器组 -> [[拓展武器组]] 各节；老写法（长触及、淤伤、摔绊、见下文……）在这里归一；
--   * 熟练（prof）、类别（wcat）进标签和分类（分类:简易武器 等）；
--   * 出处（source）可写几本书，按书目认成「《[[书]]》（缩写）」。
local p = {}
local U = mw.ustring

-- CRB 表 6-5「不同型号武器伤害」：超小、小、中、大
local SIZES = {
    { '—', '1', '1d2', '1d3' },
    { '1', '1d2', '1d3', '1d4' },
    { '1d2', '1d3', '1d4', '1d6' },
    { '1d3', '1d4', '1d6', '1d8' },
    { '1d4', '1d6', '1d8', '2d6' },
    { '1d6', '1d8', '1d10', '2d8' },
    { '1d8', '1d10', '1d12', '3d6' },
    { '1d4', '1d6', '2d4', '2d6' },
    { '1d8', '1d10', '2d6', '3d6' },
    { '1d10', '2d6', '2d8', '3d8' },
    { '2d6', '2d8', '2d10', '4d8' },
}

-- 特性：写法 -> 规范名；规范名 -> [[装备]] 里的锚点（没有锚点的不挂链）
local SPECIAL_ALIAS = {
    ['长触及'] = '长武', ['触及'] = '长武', ['淤伤'] = '瘀伤', ['非致命'] = '瘀伤', ['摔绊'] = '绊摔',
    ['反冲锋'] = '迎击', ['致命'] = '处决', ['脆弱'] = '易碎', ['擒拿'] = '擒抱',
    ['见下文'] = '见正文', ['见描述'] = '见正文', ['见下'] = '见正文', ['见文'] = '见正文',
    ['临时'] = '临时武器', ['散射'] = '霰弹',
}
local SPECIAL_LINK = {
    ['格挡'] = '装备#特性-格挡', ['迎击'] = '装备#特性-迎击', ['处决'] = '装备#特性-处决', ['卸武'] = '装备#特性-卸武',
    ['虚实'] = '装备#特性-虚实', ['双头'] = '装备#特性-双头', ['易碎'] = '装备#特性-易碎', ['擒抱'] = '装备#特性-擒抱',
    ['武僧'] = '装备#特性-武僧', ['瘀伤'] = '装备#特性-瘀伤', ['演武'] = '装备#特性-演武', ['长武'] = '装备#特性-长武',
    ['破武'] = '装备#特性-破武', ['绊摔'] = '装备#特性-绊摔', ['临时武器'] = '装备#临时武器',
}

-- 武器组：短名 -> [[拓展武器组]] 的小节
local GROUPS = {
    ['斧'] = '斧 (Axes)', ['重刃'] = '重刃 (Blades, Heavy)', ['轻刃'] = '轻刃 (Blades, Light)', ['弓'] = '弓 (Bows)',
    ['贴身'] = '贴身 (Close)', ['弩'] = '弩 (Crossbows)', ['双头'] = '双头 (Double)', ['火器'] = '火器 (Firearms)',
    ['链索'] = '链索 (Flails)', ['锤'] = '锤 (Hammers)', ['武僧'] = '武僧 (Monk)', ['天生武器'] = '天生武器 (Natural)',
    ['长柄'] = '长柄 (Polearms)', ['攻城兵器'] = '攻城兵器 (Siege Engines)', ['矛'] = '矛 (Spears)',
    ['投掷'] = '投掷 (Thrown)', ['部落'] = '部落 (Tribal)',
}

local WCAT = { ['轻型'] = '轻型近战', ['单手'] = '单手近战', ['双手'] = '双手近战', ['远程'] = '远程', ['弹药'] = '弹药' }
local PROF_CAT = { ['简易'] = '简易武器', ['军用'] = '军用武器', ['异种'] = '异种武器' }

local function trim(s) return s and mw.text.trim(s) or '' end

local function list(v)
    local out = {}
    for part in mw.text.gsplit(v or '', '[，,、；;]', false) do
        part = trim(part)
        if part ~= '' then out[#out + 1] = part end
    end
    return out
end

-- 一端的伤害 -> 超小、大（查不到表就 nil）
local function sizes(s, m)
    for _, r in ipairs(SIZES) do
        if r[2] == s and r[3] == m then return r[1], r[4] end
    end
    for _, r in ipairs(SIZES) do
        if r[3] == m then return nil, r[4] end
    end
end

local function damage(ds, dm)
    ds, dm = trim(ds), trim(dm)
    if ds == '' and dm == '' then return nil end
    if ds == dm and not U.find(dm, '%d') then return dm end      -- 「见正文」「特殊」只写一次
    if ds == '' then return dm end                                -- 只有一档（攻城兵器、一战枪械）：不标体型、不换算
    local main = (ds ~= '' and (ds .. '（小）') or '') .. ((ds ~= '' and dm ~= '') and '／' or '') .. (dm ~= '' and (dm .. '（中）') or '')
    -- 双头武器两端各算
    local ss, ms = mw.text.split(ds, '/', true), mw.text.split(dm, '/', true)
    local tiny, large = {}, {}
    for i = 1, #ms do
        local t, l = sizes(trim(ss[i] or ''), trim(ms[i]))
        if not l then tiny, large = nil, nil break end
        tiny[#tiny + 1] = t or '—'
        large[#large + 1] = l
    end
    if large and #large > 0 then
        main = main .. '<span class="item-dmg-more">超小 ' .. table.concat(tiny, '/') .. ' · 大 ' .. table.concat(large, '/') .. '</span>'
    end
    return main
end

local function specials(v)
    local out = {}
    for _, raw in ipairs(list(v)) do
        local s = U.gsub(raw, '%[%[([^%]|]*)|?([^%]]*)%]%]', function(a, b) return b ~= '' and b or a end)
        s = SPECIAL_ALIAS[s] or s
        local link = SPECIAL_LINK[s]
        out[#out + 1] = link and ('[[' .. link .. '|' .. s .. ']]') or s
    end
    return table.concat(out, '、')
end

local function groups(v)
    local out = {}
    for _, g in ipairs(list(v)) do
        g = U.gsub(g, '[类组用]$', '')
        local sec = GROUPS[g]
        out[#out + 1] = sec and ('[[拓展武器组#' .. sec .. '|' .. g .. ']]') or g
    end
    return table.concat(out, '、')
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

-- 描述里的特殊材料名自动挂链＋悬停小卡（模块:特殊材料，2026-10-01）；模块出错时原样返回，不影响卡片
local function matlink(text)
    if text == '' then return text end
    local ok, r = pcall(function() return require('模块:特殊材料').auto(text) end)
    return ok and r or text
end

local function stat(k, v, wide)
    if not v or v == '' then return '' end
    return '<span class="item-stat' .. (wide and ' wide' or '') .. '"><span class="k">' .. k .. '</span>' .. v .. '</span>'
end

function p.card(frame)
    local a = frame:getParent().args
    local g = function(k) return trim(a[k]) end
    local title = mw.title.getCurrentTitle()
    local name = g('name') ~= '' and g('name') or title.text
    local cat = g('category') ~= '' and g('category') or '武器'
    local prof, wcat = g('prof'), g('wcat')

    local tags = '<span class="tag">' .. cat .. '</span>'
    if PROF_CAT[prof] then tags = tags .. '<span class="tag">' .. prof .. '</span>' end
    if wcat ~= '' then tags = tags .. '<span class="tag">' .. (WCAT[wcat] or wcat) .. '</span>' end   -- 攻城兵器的「直射型（大型）」等原样显示

    local en = g('english_name')
    local aon = g('aon')
    local enline = ''
    if en ~= '' then
        if aon == '无' then
            enline = en
        else
            local url = aon ~= '' and aon or ('EquipmentWeaponsDisplay.aspx?ItemName=' .. mw.uri.encode(en, 'PATH'))
            enline = '[https://aonprd.com/' .. url .. ' ' .. en .. ']'
        end
        enline = '<div class="item-en">' .. enline .. '</div>'
    end

    local s = {
        stat('价格', g('price')),
        stat('重量', g('weight')),
        stat('伤害', damage(g('dmg_s'), g('dmg_m'))),
        stat('重击', g('crit')),
        stat('射程', g('range')),
        stat('类型', g('type')),
        stat('哑火', g('misfire')),
        stat('容弹量', g('capacity')),
        stat('机师组', g('crew')),
        stat('瞄准', g('aim')),
        stat('装填', g('load')),
        stat('速度', g('speed')),
        stat('特性', specials(g('special')), true),
        stat('武器组', groups(g('groups')), true),
    }

    local out = { '<div class="item item-wpn"><div class="item-head"><div class="item-name">', name,
                  '<span class="item-cats">', tags, '</span></div>', enline, '</div>',
                  '<div class="item-stats">', table.concat(s), '</div>' }
    local desc = matlink(g('description'))
    if desc ~= '' then out[#out + 1] = '<div class="item-desc">\n' .. desc .. '\n</div>' end
    -- 各体型对照（攻城兵器按体型并页）：sizes=体型｜价格｜机师组；大型｜500 gp｜5；超大型｜…（全角｜隔栏、；隔行，避开模板的竖线）
    local sz = g('sizes')
    if sz ~= '' then
        local t = { '<table class="wikitable item-sizes">' }
        for i, row in ipairs(mw.text.split(sz, '；', true)) do
            local cells = mw.text.split(row, '｜', true)
            local tag = i == 1 and 'th' or 'td'
            t[#t + 1] = '<tr>'
            for _, c in ipairs(cells) do t[#t + 1] = '<' .. tag .. '>' .. trim(c) .. '</' .. tag .. '>' end
            t[#t + 1] = '</tr>'
        end
        t[#t + 1] = '</table>'
        out[#out + 1] = table.concat(t)
    end
    if g('source') ~= '' then
        out[#out + 1] = '<div class="item-source"><span class="key">来源</span> <span class="value">' .. sources(g('source')) .. '</span></div>'
    end
    out[#out + 1] = '</div>'

    if title.namespace == 0 then
        out[#out + 1] = '[[分类:物品]][[分类:' .. cat .. ']]'
        if cat ~= '武器' and (PROF_CAT[prof] or cat == '火器') then out[#out + 1] = '[[分类:武器]]' end
        if PROF_CAT[prof] then out[#out + 1] = '[[分类:' .. PROF_CAT[prof] .. ']]' end
    end
    return table.concat(out)
end

-- 装备卡片（物品全量校对第三块「其他物品」，2026-10-01）：{{装备}} -> {{#invoke:武器|gear}}。
-- cat：AoN 其他物品的 24 类（冒险装备、炼金药剂、炼金工具、炼金武器、……、地城指南、开拓者编年史），进同名分类，另进 分类:装备。
-- 炼金武器另有 dmg／crit／range／type／special；草药 gather／yield／terrain／prep／use；炼金配方 recipe／recipe_time／recipe_tools；
-- 引导法器 deity；交通 passage；地城指南 accuracy／skill；坐骑与宠物 creature（它的怪物页）。
function p.gear(frame)
    local a = frame:getParent().args
    local g = function(k) return trim(a[k]) end
    local title = mw.title.getCurrentTitle()
    local name = g('name') ~= '' and g('name') or title.text
    local cat = g('cat')
    local tags = '<span class="tag">装备</span>' .. (cat ~= '' and ('<span class="tag">' .. cat .. '</span>') or '')

    local en, aon, enline = g('english_name'), g('aon'), ''
    if en ~= '' then
        if aon == '无' then
            enline = en
        else
            local url = aon ~= '' and aon or ('EquipmentMiscDisplay.aspx?ItemName=' .. mw.uri.encode(en, 'PATH'))
            enline = '[https://aonprd.com/' .. url .. ' ' .. en .. ']'
        end
        enline = '<div class="item-en">' .. enline .. '</div>'
    end

    local creature = g('creature')
    local s = {
        stat('价格', g('price')),
        stat('重量', g('weight')),
        stat('制作DC', g('craft_dc')),
        stat('伤害', g('dmg')),
        stat('重击', g('crit')),
        stat('射程', g('range')),
        stat('类型', g('type')),
        stat('路费（每英里）', g('passage')),
        stat('准确度', g('accuracy')),
        stat('关联技能', g('skill'), true),
        stat('神祇', g('deity'), true),
        stat('特性', g('special'), true),
        stat('属性', creature ~= '' and ('[[' .. creature .. ']]') or '', true),
    }
    local out = { '<div class="item item-gear"><div class="item-head"><div class="item-name">', name,
                  '<span class="item-cats">', tags, '</span></div>', enline, '</div>',
                  '<div class="item-stats">', table.concat(s), '</div>' }
    local desc = matlink(g('description'))
    if desc ~= '' then out[#out + 1] = '<div class="item-desc">\n' .. desc .. '\n</div>' end
    -- 草药（采集……）和炼金配方：正文后面的附注块
    for _, kv in ipairs({ { 'gather', '采集' }, { 'yield', '产量' }, { 'terrain', '地形' }, { 'prep', '制备' }, { 'use', '用法' },
                          { 'recipe', '炼金配方' }, { 'recipe_time', '配制时间' }, { 'recipe_tools', '所需工具' } }) do
        local v = g(kv[1])
        if v ~= '' then out[#out + 1] = '<div class="item-block"><span class="k">' .. kv[2] .. '</span>' .. v .. '</div>' end
    end
    if g('source') ~= '' then
        out[#out + 1] = '<div class="item-source"><span class="key">来源</span> <span class="value">' .. sources(g('source')) .. '</span></div>'
    end
    out[#out + 1] = '</div>'
    if title.namespace == 0 then
        out[#out + 1] = '[[分类:物品]][[分类:装备]]' .. (cat ~= '' and ('[[分类:' .. cat .. ']]') or '')
    end
    return table.concat(out)
end

-- 防具卡片（物品全量校对第二块，2026-10-01）：{{防具}} -> {{#invoke:武器|armor}}。
-- acat：轻型盔甲／中型盔甲／重型盔甲／盾牌／防具附件（进同名分类，另进 分类:防具）；
-- speed 写「20尺／15尺」＝基础速度 30 尺、20 尺的生物穿上之后的速度。
-- 魔法物品卡（{{魔法物品}}，2026-10-01 起：先是魔法武器与防具）。
-- cat：武器附魔、防具附魔（特殊能力，一种一页）／特殊魔法武器、特殊魔法护甲、特殊魔法盾牌（特定物品）；
-- 附魔另有 apply 适用（近战、远程／护甲、盾牌）、bonus 价格修正（「+1 加值」「+2,000 gp」）；
-- 特定物品另有 base 基础物品（页名或 wikitext）、enh 增强（「+1 焰爆」）。
-- 第二批（戒指、权杖、法杖、奇物、艾恩石、神器、诅咒物品、智能物品……）：aon 写 AoN 详情页地址；神器另有 tier
-- （次级神器／高等神器，进同名分类）、destruction 毁灭方式；智能物品另有 intel（阵营、自我值、感官、属性、交流方式）。
local MAGIC_CAT = { ['武器附魔'] = '魔法武器', ['特殊魔法武器'] = '魔法武器', ['防具附魔'] = '魔法防具',
                    ['特殊魔法护甲'] = '魔法防具', ['特殊魔法盾牌'] = '魔法防具' }
function p.magic(frame)
    local a = frame:getParent().args
    local g = function(k) return trim(a[k]) end
    local title = mw.title.getCurrentTitle()
    local name = g('name') ~= '' and g('name') or title.text
    local cat = g('cat')
    local tags = '<span class="tag">魔法物品</span>' .. (cat ~= '' and ('<span class="tag">' .. cat .. '</span>') or '')
    if g('mythic') ~= '' then tags = tags .. '<span class="tag">神话物品</span>' end

    local en, aon, enline = g('english_name'), g('aon'), ''
    if en ~= '' then
        if aon == '无' then
            enline = en
        else
            local disp = (MAGIC_CAT[cat] == '魔法防具') and 'MagicArmorDisplay' or 'MagicWeaponsDisplay'
            local url = aon ~= '' and (aon:gsub(' ', '%%20')) or (disp .. '.aspx?ItemName=' .. mw.uri.encode(en, 'PATH'))
            enline = '[https://aonprd.com/' .. url .. ' ' .. en .. ']'
        end
        enline = '<div class="item-en">' .. enline .. '</div>'
    end
    local base = g('base')
    if base ~= '' and not base:find('[[', 1, true) then base = '[[' .. base .. ']]' end
    if base ~= '' and g('enh') ~= '' then base = g('enh') .. ' · ' .. base end
    local s = {
        stat('价格修正', g('bonus')),
        stat('价格', g('price')),
        stat('重量', g('weight')),
        stat('部位', g('slot')),
        stat('灵光', g('aura')),
        stat('施法者等级', g('cl')),
        stat('适用', g('apply')),
        stat('神器等级', g('tier')),
        stat('基础物品', base, true),
    }
    local out = { '<div class="item item-magic"><div class="item-head"><div class="item-name">', name,
                  '<span class="item-cats">', tags, '</span></div>', enline, '</div>',
                  '<div class="item-stats">', table.concat(s), '</div>' }
    -- 智能物品的数据（阵营、自我值、感官、属性、交流方式），AoN 放在描述前
    if g('intel') ~= '' then out[#out + 1] = '<div class="item-block"><span class="k">智能物品</span>\n' .. g('intel') .. '\n</div>' end
    local desc = matlink(g('description'))
    if desc ~= '' then out[#out + 1] = '<div class="item-desc">\n' .. desc .. '\n</div>' end
    if g('destruction') ~= '' then out[#out + 1] = '<div class="item-block"><span class="k">毁灭方式</span>' .. g('destruction') .. '</div>' end
    if g('req') ~= '' then out[#out + 1] = '<div class="item-block"><span class="k">制造需求</span>' .. g('req') .. '</div>' end
    if g('cost') ~= '' then out[#out + 1] = '<div class="item-block"><span class="k">造价</span>' .. g('cost') .. '</div>' end
    if g('source') ~= '' then
        out[#out + 1] = '<div class="item-source"><span class="key">来源</span> <span class="value">' .. sources(g('source')) .. '</span></div>'
    end
    out[#out + 1] = '</div>'
    if title.namespace == 0 then
        out[#out + 1] = '[[分类:物品]][[分类:魔法物品]]' .. (MAGIC_CAT[cat] and ('[[分类:' .. MAGIC_CAT[cat] .. ']]') or '')
            .. (cat ~= '' and ('[[分类:' .. cat .. ']]') or '') .. (g('tier') ~= '' and ('[[分类:' .. g('tier') .. ']]') or '')
            .. (g('mythic') ~= '' and '[[分类:神话物品]]' or '')
    end
    return table.concat(out)
end

function p.armor(frame)
    local a = frame:getParent().args
    local g = function(k) return trim(a[k]) end
    local title = mw.title.getCurrentTitle()
    local name = g('name') ~= '' and g('name') or title.text
    local acat = g('acat')
    local tags = '<span class="tag">防具</span>' .. (acat ~= '' and ('<span class="tag">' .. acat .. '</span>') or '')

    local en, aon, enline = g('english_name'), g('aon'), ''
    if en ~= '' then
        if aon == '无' then
            enline = en
        else
            local url = aon ~= '' and aon or ('EquipmentArmorDisplay.aspx?ItemName=' .. mw.uri.encode(en, 'PATH'))
            enline = '[https://aonprd.com/' .. url .. ' ' .. en .. ']'
        end
        enline = '<div class="item-en">' .. enline .. '</div>'
    end

    local s = {
        stat('价格', g('price')),
        stat('重量', g('weight')),
        stat(acat == '盾牌' and '盾牌加值' or '护甲加值', g('ac')),
        stat('最大敏捷', g('maxdex')),
        stat('检定减值', g('acp')),
        stat('奥术失败', g('asf')),
        stat('速度（30尺／20尺）', g('speed')),
    }
    local out = { '<div class="item item-arm"><div class="item-head"><div class="item-name">', name,
                  '<span class="item-cats">', tags, '</span></div>', enline, '</div>',
                  '<div class="item-stats">', table.concat(s), '</div>' }
    local desc = matlink(g('description'))
    if desc ~= '' then out[#out + 1] = '<div class="item-desc">\n' .. desc .. '\n</div>' end
    if g('source') ~= '' then
        out[#out + 1] = '<div class="item-source"><span class="key">来源</span> <span class="value">' .. sources(g('source')) .. '</span></div>'
    end
    out[#out + 1] = '</div>'
    if title.namespace == 0 then
        out[#out + 1] = '[[分类:物品]][[分类:防具]]' .. (acat ~= '' and ('[[分类:' .. acat .. ']]') or '')
    end
    return table.concat(out)
end

return p