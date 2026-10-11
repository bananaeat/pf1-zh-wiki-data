-- 物品速查：分册信息卡（2026-09-30 改版；用户从四个方向里选了 A「分册卡墙」，再在两种卡片里选了 A1「信息卡」，不要购物单）。
-- 源文件在仓库 design/item_quick.lua，站上是 模块:物品速查。
--   {{#invoke:物品速查|main|分册名}}   分册名见 BOOKS；第一个分册在 [[物品速查]] 本页，其余是 [[物品速查/分册名]]
-- 数据是 Data:ItemCards1.tab、ItemCards2.tab（kind＝itemcard；tools/export_data_tab.py --what 物品卡片1／物品卡片2；派生列见 tools/item_quick_data.py）：
--   grp 分册、pv 数值价格（gp，-1＝没有）、sn 排序值（武器平均伤害／护甲加值／制作 DC／施法者等级）、
--   fd 筛选值「细类;槽2;槽3;槽4;槽5」（多值用逗号）、st 属性串「标签＝值‖…」、tags 标签、x 描述首句。
-- 卡片的筛选值并成一个 data-d（pv;sn;fd 五槽;出处序号），出处书名表在外层 data-src；左栏、搜索、排序、分页都是
-- MediaWiki:ItemQuick.js（design/item_quick.js）读这些属性现做的，不往页里异步加内容（灰机开发者基石准则第 4 条）。
-- 样式是 MediaWiki:ItemQuick.css（design/item_quick.css），由 Common.js 在这几页拉。
local p = {}
local enc = mw.text.encode

-- 分册：名字、所属大类、卡片色类、左栏筛选槽的名字（槽 1 固定是细类；空串＝这一槽不用）、排序项（sn 的名字和方向）
local BOOKS = {
    { '武器', '普通物品', 'k-w', { '细类', '用法', '伤害类型', '武器组', '特性' }, '伤害↓', -1 },
    { '防具', '普通物品', 'k-a', { '类别', '', '', '', '' }, '护甲加值↓', -1 },
    { '其他物品', '普通物品', 'k-g', { '细类', '有无制作 DC', '', '', '' }, '制作 DC↑', 1 },
    -- 科技物品（2026-10-02，AoN Technology 一章）：类别＝科技武器／科技护甲／科技神器／电子殖装物／合成药物／科技装置
    { '科技', '普通物品', 'k-t', { '类别', '细类', '伤害类型', '', '' }, '制造 DC↑', 1 },
    { '魔法武器与防具', '魔法物品', 'k-m', { '细类', '部位', '灵氲强度', '学派', '' }, '施法者等级↑', 1 },
    -- 武器／防具附魔（特殊能力）单开一页（用户 2026-10-01）；排序值是价格修正（+N 加值记 N，按金币算的排后面）
    { '附魔', '魔法物品', 'k-m', { '细类', '适用', '灵氲强度', '学派', '' }, '价格修正↑', 1 },
    { '戒指·权杖·法杖', '魔法物品', 'k-m', { '细类', '部位', '灵氲强度', '学派', '' }, '施法者等级↑', 1 },
    { '奇物', '魔法物品', 'k-m', { '部位', '', '灵氲强度', '学派', '' }, '施法者等级↑', 1 },
    { '其他魔法物品', '魔法物品', 'k-m', { '细类', '部位', '灵氲强度', '学派', '' }, '施法者等级↑', 1 },
}
-- 属性格子的宽度（一行三格）
local WIDE = { ['特性'] = 2, ['速度'] = 2, ['灵氲'] = 2, ['造价'] = 2, ['神祇'] = 2, ['坐骑数据'] = 2, ['关联技能'] = 3, ['制造需求'] = 3, ['基础物品'] = 3, ['价格修正'] = 2, ['适用'] = 1,
    -- 危害速查（2026-10-02）
    ['效果'] = 3, ['初始效果'] = 3, ['次要效果'] = 3, ['频率'] = 2, ['成瘾性'] = 2, ['治愈'] = 2, ['触发'] = 2 }

local function pageOf(i, name)
    return i == 1 and '物品速查' or ('物品速查/' .. name)
end

local function nav(cur)
    local out, part = {}, nil
    for i, b in ipairs(BOOKS) do
        if b[2] ~= part then
            out[#out + 1] = '<span class="iq-part">' .. b[2] .. '</span>'
            part = b[2]
        end
        local n = mw.huiji.db.count({ kind = 'itemcard', grp = b[1] })
        local label = b[1] .. '<small>' .. mw.getContentLanguage():formatNum(n) .. ' 条</small>'
        if i == cur then
            out[#out + 1] = '<strong class="iq-bk iq-on">' .. label .. '</strong>'
        else
            out[#out + 1] = '<span class="iq-bk">[[' .. pageOf(i, b[1]) .. '|' .. label .. ']]</span>'
        end
    end
    return '<div class="iq-books">' .. table.concat(out) .. '</div>'
end

local function books(src)
    local t = {}
    for x in mw.text.gsplit(src or '', '、', true) do
        x = mw.text.trim(x)
        if x ~= '' then t[#t + 1] = x end
    end
    return t
end

local function card(r, kc, bi)
    local title = r.name == r.page and ('[[' .. r.page .. ']]') or ('[[' .. r.page .. '|' .. r.name .. ']]')
    local price = r.price or ''
    local cut = price:find('；', 1, true) or price:find(';', 1, true)
    local first = mw.text.trim(cut and price:sub(1, cut - 1) or price)
    local multi = first ~= mw.text.trim(price)
    local bs = books(r.source)
    local idx = {}
    for _, b in ipairs(bs) do idx[#idx + 1] = bi[b] end
    local d = table.concat({ r.pv or -1, r.sn or -1, r.fd or ';;;;', table.concat(idx, ',') }, ';')
    local st = {}
    for kv in mw.text.gsplit(r.st or '', '‖', true) do
        local k, v = kv:match('^(.-)＝(.*)$')
        if k and v ~= '' then
            local w = WIDE[k]
            st[#st + 1] = '<div' .. (w and (' class="w' .. w .. '"') or '') .. '><i>' .. enc(k) .. '</i><b>' .. enc(v) .. '</b></div>'
        end
    end
    local tags = { '<span>' .. enc(r.sub or '') .. '</span>' }
    for x in mw.text.gsplit(r.tags or '', '、', true) do
        if x ~= '' then tags[#tags + 1] = '<span>' .. enc(x) .. '</span>' end
    end
    local w = (r.weight and r.weight ~= '' and r.weight ~= '—') and r.weight or ''
    local foot = w
    if multi then foot = foot .. (foot ~= '' and ' · ' or '') .. '多档价格' end
    local src = bs[1] or ''
    if #bs > 1 then src = src .. ' 等 ' .. #bs .. ' 本' end
    return '<div class="iq-c ' .. kc .. '" data-d="' .. enc(d) .. '">'
        .. '<div class="iq-h"><div class="iq-n">' .. title .. ((r.en and r.en ~= '' and r.en ~= r.name) and ('<small>' .. enc(r.en) .. '</small>') or '') .. '</div>'
        .. '<span class="iq-p"' .. (multi and (' title="' .. enc(price) .. '"') or '') .. '>' .. enc(first ~= '' and first or '—') .. '</span></div>'
        .. '<div class="iq-t">' .. table.concat(tags) .. '</div>'
        .. (#st > 0 and ('<div class="iq-s">' .. table.concat(st) .. '</div>') or '')
        .. ((r.x and r.x ~= '') and ('<div class="iq-x">' .. enc(r.x) .. '</div>') or '')
        .. '<div class="iq-ft"><span>' .. enc(foot) .. '</span><span' .. (#bs > 1 and (' title="' .. enc(table.concat(bs, '、')) .. '"') or '') .. '>' .. enc(src) .. '</span></div></div>'
end

function p.main(frame)
    local want = mw.text.trim(frame.args[1] or '')
    local cur = 1
    for i, b in ipairs(BOOKS) do
        if b[1] == want then cur = i end
    end
    local B = BOOKS[cur]
    local rows = mw.huiji.db.find({ kind = 'itemcard', grp = B[1] }, { limit = 3000 })
    -- 出处书名表：按条数从多到少（脚本左栏照这个顺序列、只显示前几本）
    local cnt, names = {}, {}
    for _, r in ipairs(rows) do
        for _, b in ipairs(books(r.source)) do
            if not cnt[b] then names[#names + 1] = b end
            cnt[b] = (cnt[b] or 0) + 1
        end
    end
    table.sort(names, function(a, b) if cnt[a] ~= cnt[b] then return cnt[a] > cnt[b] end return a < b end)
    local bi = {}
    for i, b in ipairs(names) do bi[b] = i end
    table.sort(rows, function(a, b) return (a.name or '') < (b.name or '') end)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = card(r, B[3], bi) end
    local sorts = 'name:按名字|pa:价格↑|pd:价格↓|' .. (B[6] > 0 and 'sa' or 'sd') .. ':' .. B[5]
    return nav(cur)
        .. '<div class="iq" id="iq" data-grp="' .. enc(B[1]) .. '" data-count="' .. #rows .. '" data-src="' .. enc(table.concat(names, '|'))
        .. '" data-facets="' .. enc(table.concat(B[4], '|')) .. '" data-sorts="' .. enc(sorts) .. '" data-magic="' .. (B[2] == '魔法物品' and 1 or 0) .. '">'
        .. '<div class="iq-grid"><div class="iq-facets"></div><div class="iq-main"><div class="iq-bar"></div><div class="iq-active"></div>'
        .. '<div class="iq-cards">' .. table.concat(out) .. '</div><div class="iq-pager"></div></div></div></div>'
end

-- 危害速查（2026-10-02；AoN「Afflictions/Hazards」一章：毒药、疾病、诅咒、毒品、疯狂、腐化、作祟、陷阱，用户定名「危害速查」）。
--   {{#invoke:物品速查|hazard}}
-- 数据是 Data:Hazards.tab（kind＝hazard；tools/export_data_tab.py --what 危害，站上 {{危害}} 卡片现拉）。列和物品卡片一样，
-- 卡片、左栏、搜索、排序都和物品速查共用（MediaWiki:ItemQuick.js／.css）：sub＝类别，sn＝豁免 DC（作祟、陷阱是 CR）。
local HAZARD_FACETS = { '类别', '类型', '豁免', '涉及属性', '' }
local HAZARD_KC = { ['毒药'] = 'k-h1', ['疾病'] = 'k-h2', ['诅咒'] = 'k-h3', ['毒品'] = 'k-h4', ['疯狂'] = 'k-h5', ['腐化'] = 'k-h6', ['作祟'] = 'k-h7', ['陷阱'] = 'k-h8' }

function p.hazard(frame)
    local rows = mw.huiji.db.find({ kind = 'hazard' }, { limit = 3000 })
    local cnt, names = {}, {}
    for _, r in ipairs(rows) do
        for _, b in ipairs(books(r.source)) do
            if not cnt[b] then names[#names + 1] = b end
            cnt[b] = (cnt[b] or 0) + 1
        end
    end
    table.sort(names, function(a, b) if cnt[a] ~= cnt[b] then return cnt[a] > cnt[b] end return a < b end)
    local bi = {}
    for i, b in ipairs(names) do bi[b] = i end
    table.sort(rows, function(a, b) return (a.name or '') < (b.name or '') end)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = card(r, HAZARD_KC[r.sub or ''] or 'k-h1', bi) end
    return '<div class="iq" id="iq" data-grp="危害" data-count="' .. #rows .. '" data-src="' .. enc(table.concat(names, '|'))
        .. '" data-facets="' .. enc(table.concat(HAZARD_FACETS, '|')) .. '" data-sorts="name:按名字|pa:价格↑|pd:价格↓|sa:DC／CR↑|sd:DC／CR↓" data-magic="0">'
        .. '<div class="iq-grid"><div class="iq-facets"></div><div class="iq-main"><div class="iq-bar"></div><div class="iq-active"></div>'
        .. '<div class="iq-cards">' .. table.concat(out) .. '</div><div class="iq-pager"></div></div></div></div>'
end

-- 科技物品一览表（《科技指南》各章页用，2026-10-02 一件一页之后，原来的逐件小节换成这张表）
--   {{#invoke:物品速查|techlist|科技武器}}   参数＝类别（科技武器／科技护甲／科技神器／电子殖装物／合成药物／科技装置）
function p.techlist(frame)
    local kind = mw.text.trim(frame.args[1] or '科技武器')
    local rows = mw.huiji.db.find({ kind = 'itemcard', grp = '科技', sub = kind }, { limit = 1000 })
    table.sort(rows, function(a, b) return (a.name or '') < (b.name or '') end)
    local out = { '{| class="wikitable sortable" style="width:100%"\n! 名称 !! 价格 !! 重量 !! 要点 !! 出处' }
    for _, r in ipairs(rows) do
        local st = {}
        for kv in mw.text.gsplit(r.st or '', '‖', true) do
            local k, v = kv:match('^(.-)＝(.*)$')
            if k and v ~= '' and k ~= '特性' then st[#st + 1] = k .. ' ' .. v end
        end
        local title = r.name == r.page and ('[[' .. r.page .. ']]') or ('[[' .. r.page .. '|' .. r.name .. ']]')
        local src = mw.text.split(r.source or '', '、', true)[1] or ''
        out[#out + 1] = '|-\n| ' .. title .. ((r.en and r.en ~= '') and ('<br><small>' .. mw.text.encode(r.en) .. '</small>') or '')
            .. '\n| data-sort-value="' .. (r.pv or -1) .. '" | ' .. (r.price or '')
            .. '\n| ' .. (r.weight or '') .. '\n| ' .. table.concat(st, '；')
            .. '\n| ' .. ((src ~= '') and ('[[' .. src .. ']]') or '')
    end
    out[#out + 1] = '|}'
    return frame:preprocess(table.concat(out, '\n'))
end

-- 附魔一览表（[[武器附魔]]／[[防具附魔]] 页用；2026-10-01 附魔一种一页之后，原来的逐条小节换成这张表）
--   {{#invoke:物品速查|enchant|武器附魔}}
function p.enchant(frame)
    local cat = mw.text.trim(frame.args[1] or '武器附魔')
    local rows = mw.huiji.db.find({ kind = 'itemcard', grp = '附魔', sub = cat }, { limit = 1000 })
    table.sort(rows, function(a, b)
        if (a.sn or -1) ~= (b.sn or -1) then return (a.sn or -1) < (b.sn or -1) end
        return (a.name or '') < (b.name or '')
    end)
    local out = { '{| class="wikitable sortable" style="width:100%"\n! 名称 !! 价格修正 !! 适用 !! 灵氲 !! 施法者等级 !! 出处' }
    for _, r in ipairs(rows) do
        local st = {}
        for kv in mw.text.gsplit(r.st or '', '‖', true) do
            local k, v = kv:match('^(.-)＝(.*)$')
            if k then st[k] = v end
        end
        local title = r.name == r.page and ('[[' .. r.page .. ']]') or ('[[' .. r.page .. '|' .. r.name .. ']]')
        local src = mw.text.split(r.source or '', '、', true)[1] or ''
        out[#out + 1] = '|-\n| ' .. title .. ((r.en and r.en ~= '') and ('<br><small>' .. mw.text.encode(r.en) .. '</small>') or '')
            .. '\n| data-sort-value="' .. (r.sn or -1) .. '" | ' .. (st['价格修正'] or r.price or '')
            .. '\n| ' .. (st['适用'] or '') .. '\n| ' .. (st['灵氲'] or '') .. '\n| ' .. (st['施法者等级'] or '')
            .. '\n| ' .. ((src ~= '') and ('[[' .. src .. ']]') or '')
    end
    out[#out + 1] = '|}'
    return frame:preprocess(table.concat(out, '\n'))
end

return p