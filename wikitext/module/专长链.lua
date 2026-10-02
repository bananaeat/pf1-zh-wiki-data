-- 专长卡片的「先决条件树」和「后续专长」（2026-09-29）。源文件在仓库 design/feat_chain.lua。
-- {{Feat}} 模板里 {{#invoke:专长链|show}}；数据 模块:专长链/数据/0…15（tools/build_feat_chain.py 从 data/feat_prereqs.json 生成）；
-- 样式在 MediaWiki:Common.css（源 design/feat_chain.css）。
--
-- 用户定的：先决条件做成可按需展开的树（前置的前置也能点开，含全部种类的条件），整个面板默认收起；后续专长一行，超过 12 条收起。
-- 折叠用皮肤自带的 Bootstrap 3（data-toggle="collapse"），不用 mw-collapsible（本站是坏的）。
-- 「全部展开／收起」靠 data-target 写选择器：Bootstrap 在点击时才解析，只作用于当前还关着／开着的那些。
local p = {}

local SHARDS = 16
local ROMAN = { 'Ⅰ', 'Ⅱ', 'Ⅲ', 'Ⅳ', 'Ⅴ', 'Ⅵ', 'Ⅶ' }
local LIMIT = 12
-- 类型 -> 标签文字、颜色类（同一大类同一种颜色）
local TY = {
    feat = { '专长', 'feat' }, feat_count = { '专长', 'feat' },
    ability = { '属性', 'num' }, bab = { 'BAB', 'num' }, character_level = { '等级', 'num' },
    caster_level = { '施法者', 'num' }, hit_dice = { '生命骰', 'num' }, mythic = { '神话', 'num' },
    skill = { '技能', 'skill' },
    class_level = { '职业', 'cls' }, class_feature = { '职业特性', 'cls' }, companion = { '伙伴', 'cls' },
    race = { '种族', 'race' }, racial_trait = { '种族特性', 'race' }, subtype = { '生物类型', 'race' },
    size = { '体型', 'race' }, monster_ability = { '特殊能力', 'race' },
    deity = { '信仰', 'faith' }, alignment = { '阵营', 'faith' }, organization = { '组织', 'faith' },
    spellcasting = { '施法', 'magic' }, spell_like = { '类法术', 'magic' },
    proficiency = { '擅长', 'prof' }, language = { '语言', '' }, other = { '其他', '' },
}
local NUMS = { 'bab', 'character_level', 'caster_level', 'hit_dice', 'mythic' }
local ABIL = { 'str', 'dex', 'con', 'int', 'wis', 'cha' }

-- mw.loadData 返回的只读表不支持 # 取长度（恒为 0），一律用它数
local function len(t)
    local n = 0
    if t then for _ in ipairs(t) do n = n + 1 end end
    return n
end

local shards = {}
local function hash(s)
    local h = 0
    for i = 1, #s do h = (h + s:byte(i)) % SHARDS end
    return h
end
local function get(page)
    if not page then return nil end
    local h = hash(page)
    if shards[h] == nil then
        local ok, d = pcall(mw.loadData, '模块:专长链/数据/' .. h)
        shards[h] = ok and d or false
    end
    return shards[h] and shards[h][page] or nil
end

local function esc(s)
    return mw.text.nowiki(tostring(s or ''))
end
local function link(pg, text)
    if pg and pg ~= '' then
        return '[[' .. pg .. '|' .. esc(text) .. ']]'
    end
    return esc(text)
end

-- ---------- 树 ----------
local idn, prefix = 0, 'fc'
local function newid()
    idn = idn + 1
    return prefix .. idn
end
local function tag(y)
    local t = TY[y] or TY.other
    return string.format('<span class="fc-ty %s">%s</span>', t[2], t[1])
end
local function tierBadge(t)
    return string.format('<span class="fc-t" title="第 %d 阶">%s</span>', t, ROMAN[t] or t)
end

local render
local function list(nodes, path, out)
    out[#out + 1] = '<ul>'
    for _, n in ipairs(nodes) do render(n, path, out) end
    out[#out + 1] = '</ul>'
end
render = function(n, path, out)
    if n.o or n.l then
        out[#out + 1] = string.format('<li><span class="fc-row"><span class="fc-sp"></span><span class="fc-ty %s">%s</span></span>',
            n.o and 'or' or 'and', n.o and '任选其一' or '同时满足')
        list(n.o or n.l, path, out)
        out[#out + 1] = '</li>'
        return
    end
    local f = n.y == 'feat' and get(n.p) or nil
    local ai = n.ai and ' <span class="fc-ai" title="站上原文没有这一项，按 AoN 译">AI 译</span>' or ''
    if not f then
        out[#out + 1] = '<li><span class="fc-row"><span class="fc-sp"></span>' .. tag(n.y) .. link(n.p, n.z) .. ai .. '</span></li>'
        return
    end
    local deeper = f.r and len(f.r) > 0 and not path[n.p]
    if not deeper then
        out[#out + 1] = '<li><span class="fc-row"><span class="fc-sp"></span>' .. tag('feat') .. tierBadge(f.t) .. link(n.p, n.z)
            .. ((not f.r or len(f.r) == 0) and ' <span class="fc-cnt">无先决条件</span>' or '') .. '</span></li>'
        return
    end
    local id = newid()
    out[#out + 1] = string.format('<li><span class="fc-row"><span class="fc-tg collapsed" role="button" tabindex="0" data-toggle="collapse" data-target="#%s" aria-expanded="false" title="展开 %s 的先决条件"></span>%s%s%s <span class="fc-cnt">%d 项</span></span>',
        id, esc(f.n), tag('feat'), tierBadge(f.t), link(n.p, n.z), len(f.r))
    path[n.p] = true
    out[#out + 1] = string.format('<div id="%s" class="collapse fc-sub">', id)
    list(f.r, path, out)
    out[#out + 1] = '</div></li>'
    path[n.p] = nil
end

-- ---------- 整条链合计：不在「或」里的全部硬性条件，同类取最高 ----------
local function rollup(page)
    local num, abil, skill, skillOrder, cls, clsOrder = {}, {}, {}, {}, {}, {}
    local misc, miscOrder, feats, seen, ors, orSeen = {}, {}, {}, {}, {}, {}
    local function orText(n)
        local parts = {}
        for _, c in ipairs(n.o) do
            if c.l then
                local sub = {}
                for _, x in ipairs(c.l) do sub[#sub + 1] = x.z or '' end
                parts[#parts + 1] = table.concat(sub, '＋')
            else
                parts[#parts + 1] = c.z or ''
            end
        end
        return table.concat(parts, ' 或 ')
    end
    local walk
    walk = function(nodes)
        for _, n in ipairs(nodes or {}) do
            if n.o then
                local t = orText(n)
                if not orSeen[t] then orSeen[t] = true; ors[#ors + 1] = t end
            elseif n.l then
                walk(n.l)
            elseif n.y == 'feat' and get(n.p) then
                if not seen[n.p] then
                    seen[n.p] = true
                    feats[#feats + 1] = n.z
                    walk(get(n.p).r)
                end
            elseif n.y == 'ability' and n.a then
                if not abil[n.a] or (n.m or 0) > abil[n.a].m then abil[n.a] = { m = n.m or 0, z = n.z } end
            elseif n.y == 'skill' and n.k then
                if not skill[n.k] then skillOrder[#skillOrder + 1] = n.k end
                if not skill[n.k] or (n.m or 0) > skill[n.k].m then skill[n.k] = { m = n.m or 0, z = n.z } end
            elseif n.y == 'class_level' and n.k then
                if not cls[n.k] then clsOrder[#clsOrder + 1] = n.k end
                if not cls[n.k] or (n.m or 0) > cls[n.k].m then cls[n.k] = { m = n.m or 0, z = n.z } end
            elseif num[n.y] ~= nil or n.y == 'bab' or n.y == 'character_level' or n.y == 'caster_level' or n.y == 'hit_dice' or n.y == 'mythic' then
                if not num[n.y] or (n.m or 0) > num[n.y].m then num[n.y] = { m = n.m or 0, z = n.z } end
            else
                local g = (TY[n.y] or TY.other)[1]
                if not misc[g] then misc[g] = {}; miscOrder[#miscOrder + 1] = g end
                local dup = false
                for _, z in ipairs(misc[g]) do if z == n.z then dup = true end end
                if not dup then misc[g][#misc[g] + 1] = n.z end
            end
        end
    end
    walk(get(page).r)
    local rows = {}
    local nums = {}
    for _, a in ipairs(ABIL) do if abil[a] then nums[#nums + 1] = abil[a].z end end
    for _, k in ipairs(NUMS) do if num[k] then nums[#nums + 1] = num[k].z end end
    if #nums > 0 then rows[#rows + 1] = { '数值', table.concat(nums, '、') } end
    local t = {}
    for _, k in ipairs(skillOrder) do t[#t + 1] = skill[k].z end
    if #t > 0 then rows[#rows + 1] = { '技能', table.concat(t, '、') } end
    t = {}
    for _, k in ipairs(clsOrder) do t[#t + 1] = cls[k].z end
    if #t > 0 then rows[#rows + 1] = { '职业', table.concat(t, '、') } end
    for _, g in ipairs(miscOrder) do rows[#rows + 1] = { g, table.concat(misc[g], '、') } end
    if #feats > 0 then rows[#rows + 1] = { '专长', #feats .. ' 条：' .. table.concat(feats, '、') } end
    if #ors > 0 then rows[#rows + 1] = { '另需其一', table.concat(ors, '；') } end
    return rows, #feats, #ors
end

local function tree(page, f)
    if not f.r or len(f.r) == 0 then return '' end
    local out = {}
    local path = { [page] = true }
    list(f.r, path, out)
    local body = table.concat(out)
    local rows, nfeat, nor = rollup(page)
    local bid = newid()
    local sum = ''
    if nfeat > 0 or nor > 0 then            -- 没有下层专长、也没有「或」的，合计就是第一层，不重复列
        local dl = {}
        for _, r in ipairs(rows) do dl[#dl + 1] = '<dt>' .. r[1] .. '</dt><dd>' .. esc(r[2]) .. '</dd>' end
        sum = '<div class="fc-sum"><span class="k">整条链合计</span><span class="fc-note">（树里所有必须满足的条件，同类取最高）</span><dl>'
            .. table.concat(dl) .. '</dl></div>'
    end
    local meta = '第 ' .. (ROMAN[f.t] or f.t) .. ' 阶 · ' .. len(f.r) .. ' 项条件' .. (nfeat > 0 and ('，整条链共 ' .. nfeat .. ' 条前置专长') or '')
    local btns = ''
    if body:find('fc-tg', 1, true) then
        btns = string.format('<span class="fc-btn" role="button" tabindex="0" data-toggle="collapse" data-target="#%s:not(.in), #%s .fc-sub:not(.in)">全部展开</span>'
            .. '<span class="fc-btn" role="button" tabindex="0" data-toggle="collapse" data-target="#%s .fc-sub.in">全部收起</span>', bid, bid, bid)
    end
    return string.format('<div class="fc-pt"><div class="fc-h"><span class="fc-h-tg collapsed" role="button" tabindex="0" data-toggle="collapse" data-target="#%s" aria-expanded="false">先决条件树</span><span class="fc-meta">%s</span><span class="fc-grow"></span>%s</div>'
        .. '<div id="%s" class="collapse fc-panel"><div class="fc-body">%s</div>%s</div></div>', bid, meta, btns, bid, body, sum)
end

local function nextRow(f)
    if not f.x or len(f.x) == 0 then return '' end
    local a, b = {}, {}
    for i, pg in ipairs(f.x) do
        local g = get(pg)
        local s = link(pg, g and g.n or pg)
        if i <= LIMIT then a[#a + 1] = s else b[#b + 1] = s end
    end
    local more = ''
    if #b > 0 then
        local id = newid()
        more = string.format('<span id="%s" class="collapse fc-more">、%s</span> <span class="fc-more-tg collapsed" role="button" tabindex="0" data-toggle="collapse" data-target="#%s" aria-expanded="false"><span class="on">展开全部 %d 条 ▾</span><span class="off">收起 ▴</span></span>',
            id, table.concat(b, '、'), id, len(f.x))
    end
    return '<div class="feat-block fc-next"><span class="k">后续专长</span>' .. table.concat(a, '、') .. more .. '</div>'
end

-- ---------- 标准写法的先决条件一行（2026-09-29 用户：「直接挂准确的链……也可以改文字本身」）----------
-- 拼句在 tools/build_feat_chain.py 里（专长速查的「先决条件」列也用同一份，存在 Data:Feats.tab 的 prestd），这里只取。
-- 给别的模块用（模块:条目提示、模块:速查筛选）：有数据就返回标准写法，没有返回 nil
function p.text(page)
    local f = get(page)
    if not f or not f.pre or f.pre == '' then return nil end
    return f.pre
end

-- {{Feat}} 用：{{#invoke:专长链|pre|fallback={{{prerequisites|}}}}}。数据里没有这条（新专长还没进数据）时原样用页面上写的
function p.pre(frame)
    local title = mw.title.getCurrentTitle()
    local s = title.namespace == 0 and p.text(title.text) or nil
    if not s then
        s = mw.text.trim(frame.args.fallback or '')
        if s == '' then return '' end
    end
    return '<div class="feat-block"><span class="k">先决条件</span>' .. s .. '</div>'
end

function p.show(frame)
    local title = mw.title.getCurrentTitle()
    local page = frame.args[1]
    if not page or page == '' then
        if title.namespace ~= 0 then return '' end
        page = title.text
    end
    local f = get(page)
    if not f then return '' end
    idn = 0
    prefix = 'fc' .. hash(page) .. 'x' .. (#page % 97) .. '-'
    return tree(page, f) .. nextRow(f)
end

return p