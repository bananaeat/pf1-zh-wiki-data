-- 科技物品卡片（2026-10-02；AoN「Technology」一章全量导入，一件一页）。
-- 源文件在仓库 design/tech_card.lua，站上是 模块:科技物品；由 模板:科技物品 调用：{{#invoke:科技物品|card}}（参数取模板的）。
-- 外观沿用物品卡（Common.css「物品卡片」一节的 .item 类），一栏一项，页上的参数就是数据（物品速查「科技」分册从这里导）。
--
-- kind（进同名分类，另进 分类:科技物品）：科技武器、科技护甲、科技神器、电子殖装物、合成药物、科技装置（＝站上《科技指南》各章页名）；
--   sub 细类（科技武器：简易／军用／异种／火器／重型武器；科技护甲：轻型／中型／重型／盾牌；科技装置：门禁与锁、电池与能源、
--   手雷与炸药、植入物、医疗器械与纳米科技、其他工具与配件；电子殖装物：装备位置）。
-- 通用：name、english_name（AoN 条目名，自动链到 AoN 该类详情页；地址不同写 aon=，aon=无 不挂）、price、weight、slot、
--   capacity 容量、usage 消耗、description、source（书名，几本用「、」）、construction 制造需求、craft_dc 制造 DC、cost 造价。
-- 武器：wtype 类型（轻型近战、远程……）、prof 擅长、dmg_s、dmg_m、dmg_type、crit、range、special。
-- 防具：atype 类型、ac 护甲加值、maxdex、acp、asf、speed。
-- 电子殖装物（和神器里的殖装件）：install 安装 DC、implant 植入值。
local p = {}
local U = mw.ustring

local AON = {
    ['科技武器'] = 'EquipmentTechWeaponsDisplay.aspx?ItemName=', ['科技护甲'] = 'EquipmentTechArmorDisplay.aspx?ItemName=',
    ['科技神器'] = 'EquipmentTechArtifactsDisplay.aspx?ItemName=', ['电子殖装物'] = 'EquipmentTechCybertechDisplay.aspx?ItemName=',
    ['合成药物'] = 'EquipmentTechPharmaceuticalsDisplay.aspx?ItemName=', ['科技装置'] = 'EquipmentTechMiscDisplay.aspx?ItemName=',
}
-- 类别名就是《科技指南》各章的站上页名（章节页讲这一类的规则、列全部物品）

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
    local kind, sub = g('kind'), g('sub')
    local tags = '<span class="tag">' .. (kind ~= '' and ('[[' .. kind .. ']]') or '科技物品') .. '</span>'
    if sub ~= '' then tags = tags .. '<span class="tag">' .. sub .. '</span>' end

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

    local dmg = ''
    if g('dmg_s') ~= '' or g('dmg_m') ~= '' then
        dmg = (g('dmg_s') ~= '' and g('dmg_s') or '—') .. '／' .. (g('dmg_m') ~= '' and g('dmg_m') or '—')
    end
    local s = {
        stat('价格', g('price')),
        stat('重量', g('weight')),
        stat('部位', g('slot')),
        -- 武器
        stat('类型', g('wtype')),
        stat('擅长', g('prof')),
        stat('伤害 小/中', dmg),
        stat('伤害类型', g('dmg_type')),
        stat('重击', g('crit')),
        stat('射程', g('range')),
        -- 防具
        stat('类型', g('atype')),
        stat('护甲加值', g('ac')),
        stat('最大敏捷', g('maxdex')),
        stat('检定减值', g('acp')),
        stat('奥术失败', g('asf')),
        stat('速度', g('speed')),
        -- 赛博
        stat('安装 DC', g('install')),
        stat('植入值', g('implant')),
        stat('容量', g('capacity')),
        stat('消耗', g('usage')),
        stat('特性', g('special'), true),
    }
    local out = { '<div class="item item-tech"><div class="item-head"><div class="item-name">', name,
                  '<span class="item-cats">', tags, '</span></div>', enline, '</div>',
                  '<div class="item-stats">', table.concat(s), '</div>' }
    local desc = g('description')
    if desc ~= '' then out[#out + 1] = '<div class="item-desc">\n' .. desc .. '\n</div>' end
    out[#out + 1] = block('制造需求', g('construction'))
    local craft = {}
    if g('craft_dc') ~= '' then craft[#craft + 1] = '制造 DC ' .. g('craft_dc') end
    if g('cost') ~= '' then craft[#craft + 1] = '造价 ' .. g('cost') end
    out[#out + 1] = block('制造', table.concat(craft, '；'))
    if g('source') ~= '' then
        out[#out + 1] = '<div class="item-source"><span class="key">来源</span> <span class="value">' .. sources(g('source')) .. '</span></div>'
    end
    out[#out + 1] = '</div>'
    if title.namespace == 0 then
        out[#out + 1] = '[[分类:物品]][[分类:科技物品]]' .. (kind ~= '' and ('[[分类:' .. kind .. ']]') or '')
    end
    return table.concat(out)
end

return p