-- 速查筛选表：从 Data:*.tab（站点 MongoDB）出整张表，每行带 data-f-* 属性，
-- 筛选按钮由前端脚本（试验期在 用户:Bananaeat/filter.js，源文件 design/pf_filter.js）读这些属性现生成。
-- 源文件在仓库 design/quick_filter.lua，改这里要同步回去。
--
--   {{#invoke:速查筛选|feat}}              专长（Data:Feats.tab）
--   {{#invoke:速查筛选|trait}}             背景特性（Data:Traits.tab）
--   {{#invoke:速查筛选|spell}}             法术（Data:Spells.tab）
--   |id=xxx      表格 id，要和筛选面板的 data-target 对上（默认 feat-list / trait-list）
--   |type=战斗   只出某一类
--
-- 输出＝筛选面板＋表格，页面上只写一行 invoke。面板也由这里出，是因为「出处」的书要按
-- 系列→出版日期排，这个顺序只有查过 Data:Books.tab 才知道。
-- 行属性的多值用 | 分隔；筛选组的名字（type/book/…）和面板里的 data-key 对应。
local p = {}

local function nonempty(s)
    return s ~= nil and s ~= '' and s
end

-- 单元格里的 | 会被表格语法当成分隔符
local function cell(s)
    return (tostring(s or ''):gsub('|', '&#124;'))
end

local function attr(s)
    return mw.text.encode(tostring(s or ''))
end

local function split(s)
    local out = {}
    if nonempty(s) then
        for _, x in ipairs(mw.text.split(s, '、', true)) do
            x = mw.text.trim(x)
            if x ~= '' then out[#out + 1] = x end
        end
    end
    return out
end

local function has(list, v)
    for _, x in ipairs(list) do
        if x == v then return true end
    end
    return false
end

-- 行属性：{ {'type', {'战斗','团队'}}, … } -> '|- data-f-type="战斗|团队" …'
local function rowline(f)
    local parts = { '|-' }
    for _, kv in ipairs(f) do
        local v = kv[2]
        if type(v) == 'table' then v = table.concat(v, '|') end
        parts[#parts + 1] = string.format('data-f-%s="%s"', kv[1], attr(v))
    end
    return table.concat(parts, ' ')
end

-- ---------- 出处：按系列两层 ----------
-- Data:Books.tab（tools/export_data_tab.py --what 书目）：书名 -> 系列、出版日期。
-- 行上写「系列/书名」，筛选面板第一层按系列成批选、第二层逐本；系列按「是否核心」从前往后
local LINES = { '规则书', '战役设定', '玩家伴侣', '冒险之路', '模组', '其他' }
local LINE_RANK = {}
for i, l in ipairs(LINES) do LINE_RANK[l] = i end

local bookInfo
local function books()
    if not bookInfo then
        bookInfo = {}
        for _, r in ipairs(mw.huiji.db.find({ kind = 'book' }, { limit = 2000 })) do
            bookInfo[r.name] = r
        end
    end
    return bookInfo
end

-- 书名 -> '系列/书名'，并记进 used（出面板时排顺序用）
local function bookVal(name, used)
    local info = books()[name] or {}
    local v = (nonempty(info.line) or '其他') .. '/' .. name
    used[v] = info
    return v
end

-- used 里的书排成面板要的顺序：系列（核心在前）→ 出版日期 → 书名
local function bookOrder(used)
    local keys = {}
    for v in pairs(used) do keys[#keys + 1] = v end
    table.sort(keys, function(a, b)
        local la, lb = a:match('^(.-)/'), b:match('^(.-)/')
        local ra, rb = LINE_RANK[la] or 99, LINE_RANK[lb] or 99
        if ra ~= rb then return ra < rb end
        local da, db = nonempty(used[a].date) or '9999', nonempty(used[b].date) or '9999'
        if da ~= db then return da < db end
        return a < b
    end)
    return table.concat(keys, '|')
end

-- 筛选面板：groups = { {key, 标签, {属性=值…}}, … }
-- total：表格行数，加载器（MediaWiki:Common.js）显示「正在加载 N / 总数」用
local function panel(id, search, groups, total)
    local out = { string.format('<div class="pf-filter" data-target="%s" data-search="%s" data-total="%d">',
        attr(id), attr(search), total or 0) }
    for _, g in ipairs(groups) do
        local extra = {}
        for k, v in pairs(g[3] or {}) do
            extra[#extra + 1] = string.format(' data-%s="%s"', k, attr(v))
        end
        table.sort(extra)
        -- 组名 div 只是给脚本读的配置；脚本没加载（站点 JS 有约 4 小时 CDN 缓存）时别露出一串光秃秃的组名
        out[#out + 1] = string.format('<div data-key="%s"%s style="display:none">%s</div>',
            g[1], table.concat(extra), g[2])
    end
    out[#out + 1] = '</div>'
    return table.concat(out, '\n')
end

local function bookGroup(used, key)
    return { key or 'book', '出处', { tree = '1', parents = table.concat(LINES, '|'), order = bookOrder(used),
        pick = '按书挑选', unit = '本' } }
end

local function byEn(rows)
    table.sort(rows, function(x, y)
        if (x.untr or 0) ~= (y.untr or 0) then return (x.untr or 0) < (y.untr or 0) end
        return (x.en or ''):lower() < (y.en or ''):lower()
    end)
    return rows
end

local function namecell(r, tip, tag)
    local page = r.page or r.name
    local link = string.format('[[%s|%s]]', page, cell(r.name or page))
    if tip then
        link = string.format('<span class="huiji-tt" data-template="%s" data-params="%s">%s</span>',
            tip, attr(page), link)
    end
    link = link .. (tag or '')
    if nonempty(r.en) and r.en ~= r.name then
        link = link .. '<br><small>' .. cell(r.en) .. '</small>'
    end
    return '| ' .. link
end

function p.feat(frame)
    local a = frame.args
    local only = nonempty(a.type)
    local id = nonempty(a.id) or 'feat-list'
    local rows = byEn(mw.huiji.db.find({ kind = 'feat' }, { limit = 5000 }))
    local used, count = {}, 0
    local out = {
        '{| class="wikitable sortable pf-ftable pf-feat" id="' .. attr(id) .. '"',
        '! 专长 !! 类型 !! 先决条件 !! 简介 !! 出处',
    }
    for _, r in ipairs(rows) do
        local types = split(r.cats)
        if not only or has(types, only) then
            local bks, abbrs = split(r.book), split(r.abbr)
            local bv = {}
            for _, b in ipairs(bks) do bv[#bv + 1] = bookVal(b, used) end
            local pre = mw.text.trim((r.prereq or ''):gsub('。$', ''))
            -- 前置专长（Data:Feats.tab 的 reqf，「|」且「~」或）：前置链、「我的专长」由 MediaWiki:FeatTree.js 在浏览器里算。
            -- 「我的专长」的初值按有无前置专长给，「已有／现在能学」要看读者勾了什么，脚本改完调 pfRefresh
            local reqf = nonempty(r.reqf)
            count = count + 1
            local line = rowline({
                { 'm', reqf and '还差前置' or '无前置专长' },
                { 'type', #types > 0 and types or '普通' }, { 'book', bv },
                { 'pfs', r.pfs and '可用' or '不可用' },
                { 'pre', pre == '' and '无先决条件' or (reqf and '要前置专长' or '无需专长') },
            })
            if reqf then line = line .. ' data-q="' .. attr(reqf) .. '"' end
            out[#out + 1] = line
            -- 神话专长和基础专长同名（诅咒巫术／诅咒巫术 (神话)），名字后加「（神话）」分开（用户 2026-09-29）
            local nm = r.name or r.page
            if (r.page or ''):find('神话', 1, true) and not (nm or ''):find('神话', 1, true) then
                nm = nm .. '（神话）'
            end
            out[#out + 1] = namecell({ page = r.page, name = nm, en = r.en }, '专长提示')
            out[#out + 1] = '| ' .. cell(table.concat(types, '、'))
            -- 先决条件的标准写法、挂准确的链（Data:Feats.tab 的 prestd，tools/build_feat_chain.py 生成，2026-09-29）；
            -- 没有的用原文。不在这里 require 模块:专长链：三千条全载要 43 MB，贴着 Lua 内存上限
            -- prestd 里只有 [[页|字]] 里的竖线，表格语法认得，不能过 cell()
            out[#out + 1] = '| ' .. (nonempty(r.prestd) or cell(pre ~= '' and pre or '—'))
            out[#out + 1] = '| ' .. cell(r.desc)
            local src = {}
            for i, b in ipairs(bks) do
                src[#src + 1] = string.format('<span title="%s">%s</span>', attr(b), cell(abbrs[i] or b))
            end
            out[#out + 1] = '| ' .. table.concat(src, ' ')
        end
    end
    out[#out + 1] = '|}'
    return panel(id, '搜名字、英文、先决条件、简介', {
        { 'm', '我的专长', { order = '已有|现在能学|还差前置|无前置专长', fixed = '1' } },
        { 'type', '类型', { top = '12' } },
        bookGroup(used),
        { 'pre', '先决条件', { order = '无先决条件|无需专长|要前置专长' } },
        { 'pfs', 'PFS可用', { order = '可用|不可用' } },
    }, count) .. '\n' .. table.concat(out, '\n')
end

local AI_TAG = ' <span title="这一条由 AI 从英文原文译出，CHM 汉化里没有现成译文，未经人工校对" '
    .. 'style="display:inline-block;padding:0 .35em;border:1px solid #b5452b;border-radius:3px;'
    .. 'background:#fbeee9;color:#8a2e1a;font-size:.75em;line-height:1.5;white-space:nowrap">AI 译</span>'

-- 背景特性的先决条件只分有／无。试过再细分出「信仰」一档：214 条里 213 条就是宗教类，
-- 和「类型」那一组重复；拿神名表去匹配更糟，宗教类以外命中的 22 条全是误判
-- （「奥斯」撞「奥斯里昂」、月份「奈斯」「黛丝娜斯」撞神名）。
local function preKind(pre)
    return nonempty(pre) and '有' or '无'
end

function p.trait(frame)
    local a = frame.args
    local only = nonempty(a.type)
    local id = nonempty(a.id) or 'trait-list'
    local rows = byEn(mw.huiji.db.find({ kind = 'trait' }, { limit = 5000 }))
    local used, count = {}, 0
    local out = {
        '{| class="wikitable sortable pf-ftable" id="' .. attr(id) .. '"',
        '! 背景特性 !! 类型 !! 先决条件 !! 效果 !! 出处',
    }
    for _, r in ipairs(rows) do
        if not only or r.type == only then
            local pre = mw.text.trim((r.prereq or ''):gsub('。$', ''))
            local zh = (r.untr or 0) ~= 0 and '未汉化' or (r.ai and 'AI 翻译' or '人工译文')
            count = count + 1
            out[#out + 1] = rowline({
                { 'type', nonempty(r.type) or '未分类' },
                { 'book', nonempty(r.book) and bookVal(r.book, used) or '' },
                { 'pre', preKind(pre) }, { 'pfs', r.pfs and '可用' or '不可用' },
                { 'zh', zh },
            })
            -- AI 译文要醒目标出（内容准则）：名字后面挂一枚小签
            out[#out + 1] = namecell(r, nil, r.ai and AI_TAG or nil)
            out[#out + 1] = '| ' .. cell(r.type)
            out[#out + 1] = '| ' .. cell(pre ~= '' and pre or '—')
            out[#out + 1] = '| ' .. cell(r.desc)
            out[#out + 1] = '| ' .. cell(r.book)
        end
    end
    out[#out + 1] = '|}'
    return panel(id, '搜名字、英文、先决条件、效果', {
        { 'type', '类型' },
        bookGroup(used),
        { 'pre', '先决条件', { order = '无|有' } },
        { 'pfs', 'PFS可用', { order = '可用|不可用' } },
        { 'zh', '译文', { order = '人工译文|AI 翻译|未汉化' } },
    }, count) .. '\n' .. table.concat(out, '\n')
end

-- ---------- 法术（Data:Spells.tab，2026-09-29） ----------
-- 职业和环位做成两层（「法师/3环」）：先选职业＝这个职业能施放的全部法术，展开再挑具体环位；
-- 大表 3300 行贴着 2 MB 展开上限：组名用单字母、行里不套悬停提示、不出持续时间列（2026-09-29 实测超限）。
-- 分成两个独立组的话「法师」＋「3环」会把「牧师 3、法师 5」这种也筛进来。
local CLASS_ORDER = { '法师', '术士', '奥能师', '牧师', '先知', '德鲁伊', '吟游诗人', '圣武士', '游侠', '女巫',
    '炼金术师', '审判者', '魔战士', '召唤师', '召唤师（掉链）', '反圣武士', '猎人', '萨满', '战斗祭司', '歌者',
    '调查员', '血脉狂怒者', '异能者', '秘学士', '唤魂师', '通灵者', '催眠师', '红螳螂杀手', '导师', '萨希尔·菲恩' }
local SCHOOLS = '防护系|咒法系|预言系|惑控系|塑能系|幻术系|死灵系|变化系|通用系'

local function starts(s, pre)
    return s:sub(1, #pre) == pre
end

local function actKind(s)
    s = s or ''
    if s == '' then return '未注明' end
    for _, k in ipairs({ '标准动作', '迅捷动作', '直觉动作', '整轮动作' }) do
        if starts(s, k) then return k end
    end
    if starts(s, '立即动作') then return '直觉动作' end
    if s:find('分钟') then return '数分钟' end
    if s:find('小时') or s:find('天') or s:find('周') then return '一小时以上' end
    if s:find('轮') then return '数轮' end
    return '其他'
end

local function rangeKind(s)
    s = s or ''
    if s == '' then return '未注明' end
    for _, k in ipairs({ '个人', '接触', '近距', '中距', '远距', '无限' }) do
        if starts(s, k) then return k end
    end
    if s:find('^%d') then return '固定距离' end
    return '其他'
end

local function saveKinds(s)
    s = s or ''
    if s == '' then return { '未注明' } end
    local out = {}
    for _, k in ipairs({ '意志', '强韧', '反射' }) do
        if s:find(k, 1, true) then out[#out + 1] = k end
    end
    if #out == 0 then out[1] = starts(s, '无') and '无' or '见后文' end
    return out
end

local function srKind(s)
    s = s or ''
    if s == '' then return '未注明' end
    if starts(s, '是') then return '是' end
    if starts(s, '否') then return '否' end
    return '见后文'
end

local function compKinds(s)
    s = s or ''
    local out = {}
    for _, k in ipairs({ '语言', '姿势', '材料', '法器', '圣徽' }) do
        if s:find(k, 1, true) then out[#out + 1] = k end
    end
    if s:find('%d[%d,]*%s*gp') then out[#out + 1] = '昂贵材料' end
    if #out == 0 then out[1] = '未注明' end
    return out
end

local function classLevels(s)
    local vals, disp = {}, {}
    for _, item in ipairs(split(s)) do
        local c, n = item:match('^(.-)%s*(%d+)$')
        if c then
            vals[#vals + 1] = c .. '/' .. n
            disp[#disp + 1] = item
        end
    end
    return vals, disp
end

function p.spell(frame)
    local a = frame.args
    local id = nonempty(a.id) or 'spell-list'
    local rows = mw.huiji.db.find({ kind = 'spell' }, { limit = 5000 })
    -- 没有职业环位的（领域专属、多环位神话法术）排到最后，别占默认视图的开头
    local function lvk(r) return nonempty(r.classlv) and (r.lvmin or 99) or 99 end
    table.sort(rows, function(x, y)
        if (x.untr or 0) ~= (y.untr or 0) then return (x.untr or 0) < (y.untr or 0) end
        if lvk(x) ~= lvk(y) then return lvk(x) < lvk(y) end
        return (x.en or ''):lower() < (y.en or ''):lower()
    end)
    local used, count, clsSeen, domSeen = {}, 0, {}, {}
    local out = {
        '{| class="wikitable sortable pf-ftable pf-spell" id="' .. attr(id) .. '"',
        '! 法术 !! 学派 !! 职业环位/领域 !! 施法时间 !! 距离 !! 豁免 !! 抗力 !! 出处',
    }
    for _, r in ipairs(rows) do
        local cls, disp = classLevels(r.classlv)
        for _, v in ipairs(cls) do clsSeen[v] = true end
        -- 领域／子域（tools/domain_spells.py）：domf 是「领域/4环」「领域/子域」，子域算上继承的领域法术
        local dom = nonempty(r.domf) and mw.text.split(r.domf, '|', true) or {}
        for _, v in ipairs(dom) do domSeen[v] = true end
        local tags = {}
        for _, t in ipairs(mw.text.split(r.tags or '', '[;；、，]')) do
            t = mw.text.trim(t)
            if t ~= '' then tags[#tags + 1] = t end
        end
        count = count + 1
        out[#out + 1] = rowline({
            { 'c', cls }, { 'd', dom }, { 's', nonempty(r.school) or '未注明' },
            { 't', #tags > 0 and tags or '无' }, { 'a', actKind(r.action) },
            { 'm', compKinds(r.comps) }, { 'r', rangeKind(r.range) },
            { 'v', saveKinds(r.save) }, { 'x', srKind(r.sr) },
            { 'b', nonempty(r.source) and bookVal(r.source, used) or '' },
            { 'z', (r.untr or 0) ~= 0 and '未汉化' or '已汉化' },
        })
        out[#out + 1] = namecell(r)
        local sch = r.school or ''
        if nonempty(r.sub) then sch = sch .. '<br><small>' .. cell(r.sub) .. '</small>' end
        out[#out + 1] = '| ' .. cell(sch)
        local lv = '<small>' .. cell(table.concat(disp, ' ')) .. '</small>'
        if nonempty(r.domlv) then
            lv = lv .. (#disp > 0 and '<br>' or '') .. '<small class="pf-dom">' .. cell(r.domlv) .. '</small>'
        end
        out[#out + 1] = '| ' .. lv
        out[#out + 1] = '| ' .. cell(r.action)
        out[#out + 1] = '| ' .. cell(r.range)
        out[#out + 1] = '| ' .. cell(r.save)
        out[#out + 1] = '| ' .. cell(r.sr)
        out[#out + 1] = '| ' .. cell(r.source)
    end
    out[#out + 1] = '|}'
    -- 职业环位子项顺序：职业按 CLASS_ORDER、环位 0→9
    local ck = {}
    for v in pairs(clsSeen) do ck[#ck + 1] = v end
    local rank = {}
    for i, c in ipairs(CLASS_ORDER) do rank[c] = i end
    table.sort(ck, function(x, y)
        local cx, nx = x:match('^(.-)/(%d+)')
        local cy, ny = y:match('^(.-)/(%d+)')
        local rx, ry = rank[cx] or 99, rank[cy] or 99
        if rx ~= ry then return rx < ry end
        if cx ~= cy then return cx < cy end
        return tonumber(nx) < tonumber(ny)
    end)
    -- 领域：父项＝领域（按拼音不好排，就按 UTF-8 字节序）；子项先 1～9 环、再子域
    local dk, dps, dpSeen = {}, {}, {}
    for v in pairs(domSeen) do
        dk[#dk + 1] = v
        local d = v:match('^(.-)/')
        if not dpSeen[d] then dpSeen[d] = true; dps[#dps + 1] = d end
    end
    table.sort(dps)
    table.sort(dk, function(x, y)
        local dx, kx = x:match('^(.-)/(.*)$')
        local dy, ky = y:match('^(.-)/(.*)$')
        if dx ~= dy then return dx < dy end
        local nx, ny = kx:match('^(%d)环$'), ky:match('^(%d)环$')
        if (nx ~= nil) ~= (ny ~= nil) then return nx ~= nil end
        return kx < ky
    end)
    return panel(id, '搜名字、英文、学派、距离、持续时间', {
        { 'c', '职业', { tree = '1', parents = table.concat(CLASS_ORDER, '|'), order = table.concat(ck, '|'),
            pick = '按环位挑选', unit = '项' } },
        { 'd', '领域', { tree = '1', parents = table.concat(dps, '|'), order = table.concat(dk, '|'),
            pick = '按环位／子域挑选', unit = '项' } },
        { 's', '学派', { order = SCHOOLS } },
        { 't', '描述符', { top = '14' } },
        { 'a', '施法时间', { order = '标准动作|迅捷动作|直觉动作|整轮动作|数轮|数分钟|一小时以上|其他|未注明' } },
        { 'm', '成分', { order = '语言|姿势|材料|法器|圣徽|昂贵材料|未注明' } },
        { 'r', '距离', { order = '个人|接触|近距|中距|远距|无限|固定距离|其他|未注明' } },
        { 'v', '豁免', { order = '无|意志|强韧|反射|见后文|未注明' } },
        { 'x', '法术抗力', { order = '是|否|见后文|未注明' } },
        bookGroup(used, 'b'),
        { 'z', '译文', { order = '已汉化|未汉化' } },
    }, count) .. '\n' .. table.concat(out, '\n')
end

return p