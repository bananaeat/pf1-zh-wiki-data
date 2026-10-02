-- 首页书架和 [[书库]]（2026-09-29 改版，用户选的「A 分线书柜＋C 书库卡片墙」）。
-- 源文件在仓库 design/shelf.lua，站上是 模块:书架。
--   {{#invoke:书架|shelf}}        首页书架（模板:首页/书架）：五条产品线一线一面书柜，冒险之路按套摆
--   {{#invoke:书架|library}}      书库页：五条线的入口卡＋全部书的卡片墙
-- 数据：Data:Shelf.tab（tools/export_data_tab.py --what 书架，一行一本，中文名取自书目表 data/book_en_map.json）；
-- 规则书详情里的「站上的规则页」取 Data:ShelfRules.tab（--what 书架规则，分组来自各书二级导航）。
-- 给书定了中文名（tools/apply_book_names.py），重导 Data:Shelf.tab，书架和书库就跟着变，这里不用动。
-- 样式在 MediaWiki:Common.css 的「书架与书库」一节（design/shelf.css）。
local p = {}

local LINES = { '规则书', '战役设定', '玩家伴侣', '冒险之路', '模组' }
local LINE_EN = { ['规则书'] = 'Rulebook', ['战役设定'] = 'Campaign Setting', ['玩家伴侣'] = 'Player Companion',
    ['冒险之路'] = 'Adventure Path', ['模组'] = 'Module' }
-- 书库入口卡的底色（每条线书脊色系里最有代表性的一个）
local GATE = { ['规则书'] = '#6e2a1f', ['战役设定'] = '#2f4a5c', ['玩家伴侣'] = '#8a5a2b', ['冒险之路'] = '#3f3a6b',
    ['模组'] = '#5b5a3a' }
local WHAT = { '法术', '专长', '物品', '怪物' }

local enc = mw.text.encode

local function books()
    local rows = mw.huiji.db.find({ kind = 'shelf' }, { limit = 2000 })
    table.sort(rows, function(a, b)
        if a.date ~= b.date then return (a.date or '') < (b.date or '') end
        if (a.n or 0) ~= (b.n or 0) then return (a.n or 0) < (b.n or 0) end
        return (a.en or '') < (b.en or '')
    end)
    return rows
end

local function byLine(rows)
    local t = {}
    for _, l in ipairs(LINES) do t[l] = {} end
    for _, r in ipairs(rows) do
        if t[r.line] then table.insert(t[r.line], r) end
    end
    return t
end

local function name(r)
    if r.zh and r.name ~= '' then return r.name end
    return r.en
end

-- 书脊上的短名：冒险之路分册只写副标题
local function short(r)
    if r.zh and r.name ~= '' then return (r.name:gsub('^冒险之路%d+：', '')) end
    return (r.en:gsub('^Pathfinder #%d+: ', ''))
end

local function year(r) return (r.date or ''):sub(1, 4) end

-- 各线的「领头书」：站上收条目最多的那本（切页签时详情栏默认显示它）
local function top(list)
    local best = list[1]
    for _, r in ipairs(list) do
        if (r.tot or 0) > (best.tot or 0) then best = r end
    end
    return best
end

local function jitter(r)
    if r.line == '规则书' then return 0 end
    local h = 0
    for i = 1, #r.en do h = (h * 31 + r.en:byte(i)) % 9973 end
    return h % 10
end

------------------------------------------------------------------------
-- 详情栏
------------------------------------------------------------------------
-- 规则书的分组：书名 -> 按序的组（一次取全表）
local RULES
local function rulesOf(book)
    if not RULES then
        RULES = {}
        for _, g in ipairs(mw.huiji.db.find({ kind = 'shelfrule' }, { limit = 1000 })) do
            RULES[g.book] = RULES[g.book] or {}
            table.insert(RULES[g.book], g)
        end
        for _, gs in pairs(RULES) do table.sort(gs, function(a, b) return a.i < b.i end) end
    end
    return RULES[book] or {}
end

local function rulesBlock(book)
    local gs = rulesOf(book)
    if #gs == 0 then return '' end
    local out, n = {}, 0
    for _, g in ipairs(gs) do
        local items = {}
        for it in mw.text.gsplit(g.pages, ';', true) do
            local pg, disp = it:match('^(.-)|(.*)$')
            items[#items + 1] = '<span>' .. (pg and ('[[' .. pg .. '|' .. disp .. ']]') or ('[[' .. it .. ']]')) .. '</span>'
            n = n + 1
        end
        local head = g.link ~= '' and ('[[' .. g.link .. '|' .. g.name .. ']]') or g.name
        -- 项之间留空格当断行点（项里 nowrap），不然整组断不开
        out[#out + 1] = '<div class="pfs-g"><span class="pfs-gk">' .. head .. '</span>' .. table.concat(items, ' ') .. '</div>'
    end
    return '<div class="pfs-rules"><div class="pfs-rh">站上的规则页 · ' .. n .. '</div>' .. table.concat(out) .. '</div>'
end

local function detail(r, on)
    local title = r.page and ('[[' .. r.name .. '|' .. name(r) .. ']]') or enc(name(r))
    local sub = (r.zh and r.name ~= '') and ('<small>' .. enc(r.en) .. '</small>') or ''
    local nums = {}
    for part in mw.text.gsplit(r.cnt or '', '|', true) do
        local k, v = part:match('^(%D+)(%d+)$')
        if k then nums[#nums + 1] = '<span><b>' .. v .. '</b>' .. k .. '</span>' end
    end
    local meta = { r.line .. '<small>' .. LINE_EN[r.line] .. '</small>' }
    if r.set and r.set ~= '' then
        meta[#meta + 1] = '「' .. r.set .. '」' .. ((r.n or 0) > 0 and ('第 ' .. ((r.n - 1) % 6 + 1) .. ' 册') or '')
    end
    local y, m = (r.date or ''):match('^(%d+)-(%d+)')
    if y then meta[#meta + 1] = y .. ' 年 ' .. tonumber(m) .. ' 月' end
    if r.abbr and r.abbr ~= '' then meta[#meta + 1] = r.abbr end
    local more = r.page and ('<div class="pfs-more">[[' .. r.name .. '|这本书在站上的全部内容]]</div>') or ''
    return '<div class="pfs-dt' .. (on and '' or ' pfs-off') .. '" data-d="' .. enc(r.en) .. '" style="--bc:' .. r.col
        .. '"><div class="pfs-dh"><div class="pfs-dn">' .. title .. sub .. '</div>'
        .. (#nums > 0 and ('<div class="pfs-nums">' .. table.concat(nums) .. '</div>') or '') .. '</div>'
        .. '<div class="pfs-meta">' .. table.concat(meta, '<i>·</i>') .. '</div>'
        .. ((r.line == '规则书' and r.zh) and rulesBlock(r.name) or '') .. more .. '</div>'
end

-- 全部书的详情都在页面里（默认只显示 first 那本），点书时 MediaWiki:Shelf.js 只切换显示：
-- 灰机开发者基石准则第 4 条，不用脚本异步往页面里加内容（链接、搜索都认页面里的）
local function details(rows, first)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = detail(r, r == first) end
    return '<div class="pfs-detail">' .. table.concat(out) .. '</div>'
end

------------------------------------------------------------------------
-- 首页书架
------------------------------------------------------------------------
local function spine(r, bare)
    return (bare and '' or '<span class="pfs-cell">') .. '<span class="pfs-sp' .. (r.zh and '' or ' pfs-en') .. '" tabindex="0" data-b="' .. enc(r.en)
        .. '" style="--bc:' .. r.col .. ';--j:' .. jitter(r) .. 'px" title="' .. enc(name(r)) .. '（' .. year(r) .. '）"><b>'
        .. enc(short(r)) .. '</b><i>' .. ((r.n or 0) > 0 and ('#' .. r.n) or year(r):sub(3, 4)) .. '</i></span>'
        .. (bare and '' or '</span>')
end

local function apSets(list, render, wrap)
    local sets, order = {}, {}
    for _, r in ipairs(list) do
        local k = r.seti or -1
        if not sets[k] then sets[k] = {}; order[#order + 1] = k end
        table.insert(sets[k], r)
    end
    table.sort(order)
    local out = {}
    for _, k in ipairs(order) do
        local bs = sets[k]
        table.sort(bs, function(a, b) return (a.n or 0) < (b.n or 0) end)   -- 玩家手册（期号 0）排最前
        out[#out + 1] = wrap(bs[1].set ~= '' and bs[1].set or '其他', bs, render)
    end
    return table.concat(out)
end

function p.shelf(frame)
    local all = books()
    local L = byLine(all)
    local tabs, panes = {}, {}
    for i, l in ipairs(LINES) do
        local list = L[l]
        local act = i == 1
        tabs[#tabs + 1] = '<li' .. (act and ' class="active"' or '') .. '><span data-toggle="tab" data-target="#pfs-l' .. i
            .. '">' .. l .. '<i>' .. #list .. '</i></span></li>'
        local body
        if l == '冒险之路' then
            body = apSets(list, spine, function(set, bs, render)
                local sp = {}
                -- 成套的书不套各自的单元格，整套作为一格立在横板上
                for _, r in ipairs(bs) do sp[#sp + 1] = render(r, true) end
                return '<span class="pfs-set"><span class="pfs-lbl">' .. set .. '</span><span class="pfs-row">'
                    .. table.concat(sp) .. '</span></span>'
            end)
        else
            local sp = {}
            for _, r in ipairs(list) do sp[#sp + 1] = spine(r) end
            body = table.concat(sp)
        end
        panes[#panes + 1] = '<div id="pfs-l' .. i .. '" class="tab-pane pfs-L' .. i .. (act and ' active' or '') .. '" data-top="'
            .. enc(top(list).en) .. '"><div class="pfs-shelves">' .. body .. '</div></div>'
    end
    return '<div class="pfs-case"><div class="pfs-cap"><b>书架</b><span>五条产品线，按出版先后排；点一本，下面是它在站上有什么。'
        .. '全部书的卡片见[[书库]]。</span><ul class="nav pfs-tabs">' .. table.concat(tabs) .. '</ul></div>'
        .. '<div class="tab-content">' .. table.concat(panes) .. '</div>'
        .. details(all, top(L[LINES[1]])) .. '</div>'
end

------------------------------------------------------------------------
-- 书库
------------------------------------------------------------------------
local function card(r)
    local nm = name(r)
    local title = r.page and ('[[' .. r.name .. '|' .. nm .. ']]') or enc(nm)
    return '<div class="pfs-card" tabindex="0" data-b="' .. enc(r.en) .. '" data-q="' .. enc(mw.ustring.lower(nm .. ' ' .. r.en))
        .. '" style="--bc:' .. r.col .. '"><div class="pfs-cv"><b>' .. r.line .. '</b><span>'
        .. ((r.n or 0) > 0 and ('#' .. r.n) or year(r)) .. '</span></div><div class="pfs-bd"><strong>' .. title .. '</strong>'
        .. ((r.zh and r.name ~= '') and ('<small>' .. enc(r.en) .. '</small>') or '')
        .. ((r.tot or 0) > 0 and ('<em>站上 ' .. r.tot .. ' 条</em>') or '') .. '</div></div>'
end

function p.library(frame)
    local all = books()
    local L = byLine(all)
    local gates, panes = {}, {}
    for i, l in ipairs(LINES) do
        local list = L[l]
        local zh = 0
        for _, r in ipairs(list) do if r.zh then zh = zh + 1 end end
        gates[#gates + 1] = '<li' .. (i == 1 and ' class="active"' or '') .. '><span data-toggle="tab" data-target="#pfs-k' .. i
            .. '" style="--g:' .. GATE[l] .. '"><b>' .. l .. '</b><small>' .. LINE_EN[l] .. '</small><em>' .. #list
            .. '</em><small>本 · 有中文名 ' .. zh .. '</small></span></li>'
        local body
        if l == '冒险之路' then
            body = apSets(list, card, function(set, bs, render)
                local cs = {}
                for _, r in ipairs(bs) do cs[#cs + 1] = render(r) end
                return '<div class="pfs-sh">' .. set .. '</div><div class="pfs-cards">' .. table.concat(cs) .. '</div>'
            end)
        else
            local cs = {}
            for _, r in ipairs(list) do cs[#cs + 1] = card(r) end
            body = '<div class="pfs-cards">' .. table.concat(cs) .. '</div>'
        end
        panes[#panes + 1] = '<div id="pfs-k' .. i .. '" class="tab-pane' .. (i == 1 and ' active' or '') .. '" data-top="'
            .. enc(top(list).en) .. '"><div class="pfs-ph">' .. l .. '</div>' .. body .. '</div>'
    end
    return '<div class="pfs-lib"><ul class="nav pfs-gates">' .. table.concat(gates) .. '</ul>'
        .. '<div class="pfs-libbar"></div><div class="pfs-libbody"><div class="tab-content">' .. table.concat(panes) .. '</div>'
        .. details(all, top(L[LINES[1]])) .. '</div></div>'
end

------------------------------------------------------------------------
-- 书页（2026-10-01 改版，用户：「给所有书目建页，做一个更好的排版」；文字译自 PathfinderWiki）
--   {{书页|en=Monster Codex|authors=…|pages=256}}      页头卡（封面块＋书目信息＋本站收录）＋同系列条（＋规则书的站上规则页）
--   {{书页/目录|…}}                                    目录（一行一节「名称 @ 页码」，子节行首加「-」）
--   {{书页尾|pfw=Monster Codex|releases=…}}            出版信息（各版本「格式¦货号¦日期¦ISBN」用「；」隔开）＋资料来源
-- 书的中文名、产品线、期号、系列、书脊色、站上条目数都取 Data:Shelf.tab（kind＝shelf，按英文名认），页上只写译文和书目信息。
-- 样式在 MediaWiki:Common.css 的「书页」一节（design/book_page.css）。
------------------------------------------------------------------------
local WHAT_PAGE = { ['法术'] = '法术速查', ['专长'] = '专长速查', ['物品'] = '物品速查', ['怪物'] = '怪物速查' }

local function trim(s) return mw.text.trim(s or '') end

local function shelfRow(en, title)
    local r = en ~= '' and mw.huiji.db.findOne({ kind = 'shelf', en = en }) or nil
    if not r and title then r = mw.huiji.db.findOne({ kind = 'shelf', name = title }) end
    return r
end

local function ym(d)
    local y, m, dd = (d or ''):match('^(%d%d%d%d)-?(%d*)-?(%d*)')
    if not y then return d or '' end
    if m ~= '' and dd ~= '' and tonumber(dd) > 1 then return y .. ' 年 ' .. tonumber(m) .. ' 月 ' .. tonumber(dd) .. ' 日' end
    if m ~= '' then return y .. ' 年 ' .. tonumber(m) .. ' 月' end
    return y .. ' 年'
end

-- 同系列条：冒险之路一套按期号排；别的线取出版前后各两本
local function seriesStrip(r)
    local list, label
    local isSet = r.set and r.set ~= ''
    if isSet then
        list = mw.huiji.db.find({ kind = 'shelf', set = r.set }, { limit = 20 })
        table.sort(list, function(a, b) return (a.n or 0) < (b.n or 0) end)
        local t = mw.title.new(r.set)
        label = '「' .. ((t and t.exists) and ('[[' .. r.set .. ']]') or r.set) .. '」<small>冒险之路 · 全 ' .. #list .. ' 册</small>'
    else
        -- 没有产品线的（博客、漫画、PFS 指南、GM 屏这类，2026-10-02）不出同系列条：line 为空时查询会把整个书架都查出来
        if not r.line or r.line == '' then return '' end
        local all = mw.huiji.db.find({ kind = 'shelf', line = r.line }, { limit = 500 })
        table.sort(all, function(a, b)
            if (a.date or '') ~= (b.date or '') then return (a.date or '') < (b.date or '') end
            return (a.en or '') < (b.en or '')
        end)
        local at = 1
        for i, x in ipairs(all) do if x.en == r.en then at = i end end
        list = {}
        for i = math.max(1, at - 2), math.min(#all, at + 2) do list[#list + 1] = all[i] end
        label = r.line .. '<small>按出版先后 · 第 ' .. at .. ' / ' .. #all .. ' 本</small>'
    end
    if #list < 2 then return '' end
    local out = {}
    for _, x in ipairs(list) do
        local num = (x.n or 0) > 0 and ('#' .. x.n) or (isSet and '手册' or year(x))
        local inner = '<i>' .. num .. '</i><b>' .. enc(short(x)) .. '</b>'
        if x.en == r.en then
            out[#out + 1] = '<span class="bk-s bk-cur" style="--bc:' .. x.col .. '">' .. inner .. '</span>'
        elseif x.page and x.name ~= '' then
            out[#out + 1] = '<span class="bk-s" style="--bc:' .. x.col .. '">[[' .. x.name .. '|' .. inner .. ']]</span>'
        else
            out[#out + 1] = '<span class="bk-s bk-nolink" style="--bc:' .. x.col .. '">' .. inner .. '</span>'
        end
    end
    return '<div class="bk-series"><div class="bk-sl">' .. label .. '</div><div class="bk-ss">' .. table.concat(out) .. '</div></div>'
end

function p.book(frame)
    local a = frame:getParent().args
    local title = trim(a.name) ~= '' and trim(a.name) or mw.title.getCurrentTitle().text   -- name：样例页、改过名的页用
    local en = trim(a.en)
    local r = shelfRow(en, title)
    local line = r and r.line or trim(a.line)
    local col = r and r.col or '#4a4f5c'
    local num = r and ((r.n or 0) > 0 and ('第 ' .. r.n .. ' 期') or year(r)) or ''
    local cover = '<div class="bk-cover"><span class="bk-cl">' .. (line ~= '' and line or '书目') .. '</span><b class="bk-ct">'
        .. enc(title) .. '</b><span class="bk-ce">' .. enc(en) .. '</span><span class="bk-cn">' .. num .. '</span></div>'
    local facts = {}
    local function fact(k, v) if v and v ~= '' then facts[#facts + 1] = '<div><dt>' .. k .. '</dt><dd>' .. v .. '</dd></div>' end end
    if r and r.set and r.set ~= '' then
        fact('系列', '「' .. r.set .. '」' .. ((r.n or 0) > 0 and ('第 ' .. ((r.n - 1) % 6 + 1) .. ' 册') or '玩家手册'))
    end
    fact('出版', ym(trim(a.date) ~= '' and trim(a.date) or (r and r.date)))
    fact('页数', trim(a.pages) ~= '' and (trim(a.pages) .. ' 页') or '')
    fact('作者', trim(a.authors))
    fact('缩写', r and r.abbr ~= '' and r.abbr or trim(a.abbr))
    local nums = {}
    if r then
        for part in mw.text.gsplit(r.cnt or '', '|', true) do
            local k, v = part:match('^(%D+)(%d+)$')
            if k then nums[#nums + 1] = '<span class="bk-n">[[' .. (WHAT_PAGE[k] or k) .. '|<b>' .. v .. '</b>' .. k .. ']]</span>' end
        end
    end
    local head = '<div class="bk-head" style="--bc:' .. col .. '">' .. cover .. '<div class="bk-main">'
        .. '<div class="bk-kicker">' .. (line ~= '' and (line .. (LINE_EN[line] and (' · ' .. LINE_EN[line]) or '')) or '书目') .. '</div>'
        .. '<div class="bk-title">' .. enc(title) .. '</div>'
        .. ((en ~= '' and en ~= title) and ('<div class="bk-en">' .. enc(en) .. '</div>') or '')
        .. (#facts > 0 and ('<dl class="bk-facts">' .. table.concat(facts) .. '</dl>') or '')
        .. (#nums > 0 and ('<div class="bk-nums"><span class="bk-nk">本站收录</span>' .. table.concat(nums) .. '</div>') or '')
        .. '</div></div>'
    local strip = r and seriesStrip(r) or ''
    local rules = (line == '规则书') and rulesBlock(title) or ''
    if rules ~= '' then rules = '<div class="bk-rules">' .. rules .. '</div>' end
    return '<div class="bk">' .. head .. strip .. rules .. '</div>'
end

function p.toc(frame)
    local src = trim(frame:getParent().args[1])
    local out = {}
    for line in mw.text.gsplit(src, '\n', true) do
        line = trim(line)
        if line ~= '' then
            local sub = line:sub(1, 1) == '-'
            if sub then line = trim(line:sub(2)) end
            local nm, pg = line:match('^(.-)%s*@%s*(%S*)$')
            nm = nm or line
            out[#out + 1] = '<li class="' .. (sub and 'bk-t2' or 'bk-t1') .. '"><span class="bk-tn">' .. nm .. '</span>'
                .. ((pg and pg ~= '') and ('<span class="bk-tp">' .. pg .. '</span>') or '') .. '</li>'
        end
    end
    if #out == 0 then return '' end
    return '<ol class="bk-toc">' .. table.concat(out) .. '</ol>'
end

local FORMAT = { ['Hardcover'] = '精装', ['Softcover'] = '平装', ['PDF'] = 'PDF', ['Paperback'] = '平装', ['Print'] = '纸本',
    ['Softcover (Pocket Edition)'] = '口袋版（平装）', ['Hardcover (Pocket Edition)'] = '口袋版（精装）' }
function p.foot(frame)
    local a = frame:getParent().args
    local rows = {}
    for part in mw.text.gsplit(trim(a.releases), '；', true) do
        local f = mw.text.split(part, '¦', true)
        if trim(f[1]) ~= '' then
            rows[#rows + 1] = '<tr><td>' .. enc(FORMAT[trim(f[1])] or trim(f[1])) .. '</td><td>' .. enc(trim(f[2] or '')) .. '</td><td>'
                .. ym(trim(f[3] or '')) .. '</td><td>' .. enc(trim(f[4] or '')) .. '</td></tr>'
        end
    end
    local out = {}
    if #rows > 0 then
        out[#out + 1] = '<div class="bk-rel"><div class="bk-rh">出版信息</div><table><tr><th>版本</th><th>货号</th><th>出版</th><th>ISBN</th></tr>'
            .. table.concat(rows) .. '</table></div>'
    end
    local pfw = trim(a.pfw)
    if pfw ~= '' then
        out[#out + 1] = '<div class="bk-src">简介、导语和目录译自 PathfinderWiki 的「[https://pathfinderwiki.com/wiki/'
            .. mw.uri.encode(pfw, 'WIKI') .. ' ' .. enc(pfw) .. ']」（CC BY-SA 3.0），由 AI 翻译，未经人工校对。</div>'
    end
    if #out == 0 then return '' end
    return '<div class="bk-foot">' .. table.concat(out) .. '</div>'
end

return p