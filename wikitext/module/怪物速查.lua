-- 怪物速查：卡片墙＋遭遇栏（2026-09-30；用户从四个方向里选了「图鉴卡墙＋遭遇构筑台」合并版）。
-- 源文件在仓库 design/monster_quick.lua，站上是 模块:怪物速查。
--   {{#invoke:怪物速查|main}}     怪物（Data:Monsters.tab）
--   {{#invoke:怪物速查|npc}}      NPC（Data:NPCs.tab；2026-09-30 [[NPC速查]] 改成同一套卡片墙＋遭遇栏，脚本按外层 data-mode=npc 换左栏）
--   {{#invoke:怪物速查|deity}}    神祇（Data:Deities.tab；2026-09-30 晚 [[神祇速查]]，data-mode=deity：没有 CR 和遭遇栏，左栏是种类／阵营／领域）
-- 从 Data:Monsters.tab（tools/export_data_tab.py --what 怪物）出全部属性块，一块一张卡；筛选用的值写在卡片的 data-* 上
-- （名字、搜索文字不另写属性，脚本从卡片上现成的字取：整页展开后的体积有 2MB 上限，2962 块压到约 1.6MB），
-- 左栏筛选、搜索、排序、卡片／列表切换、右栏遭遇计算都是 MediaWiki:MonsterQuick.js（design/monster_quick.js）读这些属性现做的，
-- 不往页面里异步加内容（灰机开发者基石准则第 4 条）。样式在 MediaWiki:Common.css 的「怪物速查」一节（design/monster_quick.css）。
local p = {}

-- 类型色（卡片上改用 class t1…t13，颜色在 CSS；这张表留给以后别的用处）
local TC = { ['异界生物'] = '#5b3a8a', ['魔法兽'] = '#8a5a2b', ['动物'] = '#5e7a3a', ['龙类'] = '#a3342b',
    ['不死生物'] = '#4a4f5c', ['类人生物'] = '#9a6b3f', ['异怪'] = '#2f6b6b', ['虫类'] = '#7a6a2a',
    ['人形怪物'] = '#7d4a5a', ['构装体'] = '#5a6a7a', ['精类'] = '#2f7d68', ['植物'] = '#4f7a2f', ['泥形生物'] = '#6a7a3f' }
local MV = { ['飞'] = '飞行', ['游'] = '游泳', ['掘'] = '掘穴', ['攀'] = '攀爬' }

local enc = mw.text.encode

local function crv(c)
    local a, b = tostring(c or ''):match('^(%d+)/(%d+)')
    if a then return tonumber(a) / tonumber(b) end
    return tonumber(c) or 0
end

-- 卡片标记尽量短（2026-09-30 晚：补了 1130 只后 2962 块，旧标记每张约 860 字节，整页展开超过 2MB 上限、速查整个没了）：
-- 筛选值并成一个 data-d（cr;类型;体型;阵营;地形;移动;子类型;出处序号;经验;hp，多值用 |），出处写序号、书名表在外层 data-src；
-- 类型色用 class t1…t13；页名|名字（遭遇栏的键）、「＋遭遇」按钮、移动方式小标签都由脚本从卡片现成的内容建
local TI = { ['异界生物'] = 1, ['魔法兽'] = 2, ['动物'] = 3, ['龙类'] = 4, ['不死生物'] = 5, ['类人生物'] = 6, ['异怪'] = 7,
    ['虫类'] = 8, ['人形怪物'] = 9, ['构装体'] = 10, ['精类'] = 11, ['植物'] = 12, ['泥形生物'] = 13 }

local function card(r, srcIdx)
    local mv = {}
    for k in mw.text.gsplit(r.mv or '', '|', true) do
        if MV[k] then mv[#mv + 1] = MV[k] end
    end
    local title = r.name == r.page and ('[[' .. r.page .. ']]') or ('[[' .. r.page .. '|' .. r.name .. ']]')
    local st = (r.st and r.st ~= '') and ('（' .. r.st .. '）') or ''
    -- 子类型筛选值：页上子类型栏 2026-09-30 已统一成亚种名（tools_archive/monster_subtypes_0930.py），「增强（类人生物）」归「增强」
    local sts = {}
    for x in mw.text.gsplit(r.st or '', ';', true) do
        x = mw.text.trim(x):gsub('（.*$', '')
        if x ~= '' then sts[#sts + 1] = x end
    end
    local d = table.concat({ r.cr or '', r.ctype or '', r.size or '', r.align or '', r.ter or '', r.mv or '',
        table.concat(sts, '|'), srcIdx or '', r.xp or 0, r.hp or 0 }, ';')
    return '<div class="mq-c t' .. (TI[r.ctype] or 0) .. '" data-d="' .. enc(d) .. '">'
        .. '<div class="q-h"><div class="q-n">' .. title .. '<small>' .. enc(r.en or '') .. '</small></div>'
        .. '<span class="q-r">CR ' .. enc(r.cr) .. ((r.mr and r.mr ~= '') and ('<small>/MR ' .. enc(r.mr) .. '</small>') or '') .. '</span></div>'
        .. '<div class="q-m">' .. enc(r.size or '') .. ' ' .. enc(r.ctype or '') .. enc(st) .. ' · ' .. enc(r.align or '') .. '</div>'
        .. '<div class="q-s"><span>AC <b>' .. ((r.ac or 0) > 0 and r.ac or '—') .. '</b></span><span>HP <b>'
        .. ((r.hp or 0) > 0 and r.hp or '—') .. '</b></span><i>' .. table.concat(mv, ' ') .. '</i><u>'
        .. mw.getContentLanguage():formatNum(r.xp or 0) .. ' 经验</u></div>'
        .. ((r.desc and r.desc ~= '') and ('<div class="q-d">' .. enc(r.desc) .. '</div>') or '')
        .. '<div class="q-f"><span class="q-e">' .. enc(r.env or '') .. '</span></div></div>'
end

-- 出处筛选分组（2026-09-30 晚，用户：「来源 filter 少了一些，长尾难搞，可以 group 一下」）：
-- 块数占全部 5% 以上的书单独一个按钮（怪物：怪物图鉴 1–6；NPC：NPC志、怪物志……），其余按 Data:Books.tab 的系列归组
-- （规则书、战役设定、玩家伴侣、冒险之路、模组、其他）。卡片 data-d 的出处槽写组的序号，组名表在外层 data-src
local LINE_ORDER = { '规则书', '战役设定', '玩家伴侣', '冒险之路', '模组', '其他' }

local function srcGroups(rows)
    local line = {}
    for _, b in ipairs(mw.huiji.db.find({ kind = 'book' }, { limit = 2000 })) do
        if b.name then line[b.name] = b.line end
    end
    local cnt = {}
    for _, r in ipairs(rows) do
        local k = mw.text.trim(mw.text.split(r.src or '', '；', true)[1] or '')
        r._src = k
        cnt[k] = (cnt[k] or 0) + 1
    end
    local big, names, gi, of = {}, {}, {}, {}
    for k, n in pairs(cnt) do
        if k ~= '' and n >= #rows * 0.05 then big[#big + 1] = k end
    end
    table.sort(big)                                    -- 按书名：怪物图鉴、怪物图鉴2…6
    local function add(nm) if not gi[nm] then names[#names + 1] = nm; gi[nm] = #names end return gi[nm] end
    for _, k in ipairs(big) do add(k); of[k] = gi[k] end
    local used = {}
    for k in pairs(cnt) do
        if k ~= '' and not of[k] then
            local l = line[k]
            if not l or l == '' then
                l = (k:find('^冒险之路%d') or k:find('^Pathfinder #')) and '冒险之路' or '其他'
            end
            -- 大书都是规则书时，剩下的规则书叫「其他规则书」
            of[k] = l
            used[l] = true
        end
    end
    for _, l in ipairs(LINE_ORDER) do
        if used[l] then
            local label = (l == '规则书' and #big > 0) and '其他规则书' or l
            add(label)
            for k, v in pairs(of) do if v == l then of[k] = gi[label] end end
        end
    end
    local idx = {}
    for k, v in pairs(of) do idx[k] = v end
    return names, idx
end

function p.main(frame)
    local rows = mw.huiji.db.find({ kind = 'monster' }, { limit = 5000 })
    table.sort(rows, function(a, b)
        local x, y = crv(a.cr), crv(b.cr)
        if x ~= y then return x < y end
        return (a.name or '') < (b.name or '')
    end)
    local srcs, si = srcGroups(rows)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = card(r, si[r._src]) end
    -- 左栏、搜索条、遭遇栏由脚本建（wikitext 不能写 input／button）；没脚本时卡片照样全在
    return '<div class="mq" id="mq" data-count="' .. #rows .. '" data-src="' .. enc(table.concat(srcs, '|')) .. '"><div class="mq-grid"><div class="mq-facets"></div>'
        .. '<div class="mq-main"><div class="mq-bar"></div><div class="mq-active"></div><div class="mq-cards">'
        .. table.concat(out) .. '</div></div><div class="mq-tray"></div></div></div>'
end

-- NPC 卡：data-d 的槽位照怪物卡，意思换成 NPC 的——类型槽放主职业、体型槽放种族、子类型槽放全部职业（兼职），地形／移动留空
local function npcCard(r, srcIdx)
    local title = r.name == r.page and ('[[' .. r.page .. ']]') or ('[[' .. r.page .. '|' .. r.name .. ']]')
    local d = table.concat({ r.cr or '', r.cls_name or '', r.race or '', r.align or '', '', '',
        r.clss or '', srcIdx or '', r.xp or 0, r.hp or 0 }, ';')
    local fam = (r.fam and r.fam ~= '') and r.fam or (r.src or '')
    return '<div class="mq-c t' .. (TI[r.ctype] or 0) .. '" data-d="' .. enc(d) .. '">'
        .. '<div class="q-h"><div class="q-n">' .. title .. '<small>' .. enc(r.en or '') .. '</small></div>'
        .. '<span class="q-r">CR ' .. enc(r.cr) .. '</span></div>'
        .. '<div class="q-m">' .. enc(r.cls or '') .. ' · ' .. enc(r.align or '') .. '</div>'
        .. '<div class="q-s"><span>AC <b>' .. ((r.ac or 0) > 0 and r.ac or '—') .. '</b></span><span>HP <b>'
        .. ((r.hp or 0) > 0 and r.hp or '—') .. '</b></span><i></i><u>'
        .. mw.getContentLanguage():formatNum(r.xp or 0) .. ' 经验</u></div>'
        .. ((r.desc and r.desc ~= '') and ('<div class="q-d">' .. enc(r.desc) .. '</div>') or '')
        .. '<div class="q-f"><span class="q-e">' .. enc(fam) .. '</span></div></div>'
end

function p.npc(frame)
    local rows = mw.huiji.db.find({ kind = 'npc' }, { limit = 5000 })
    table.sort(rows, function(a, b)
        local x, y = crv(a.cr), crv(b.cr)
        if x ~= y then return x < y end
        return (a.name or '') < (b.name or '')
    end)
    local srcs, si = srcGroups(rows)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = npcCard(r, si[r._src]) end
    return '<div class="mq" id="mq" data-mode="npc" data-count="' .. #rows .. '" data-src="' .. enc(table.concat(srcs, '|')) .. '"><div class="mq-grid"><div class="mq-facets"></div>'
        .. '<div class="mq-main"><div class="mq-bar"></div><div class="mq-active"></div><div class="mq-cards">'
        .. table.concat(out) .. '</div></div><div class="mq-tray"></div></div></div>'
end

-- 神祇卡：data-d 槽位——类型槽＝真神／半神、体型槽＝分类（核心神祇、恶魔领主……）、阵营槽＝阵营、移动槽＝领域（| 分隔，筛选「都要有」）、
-- 出处槽＝已汉化／未汉化（序号）。颜色按阵营（class a0…a8，LG…CE）。AoN 有、站上还没页的神 page 记作「未汉化神祇」（Data:Deities.tab 的约定），卡片链 AoN
local function deityCard(r, zi)
    local title
    if r.page == '未汉化神祇' then                 -- 站上还没页：链 AoN 原文（「未汉化神祇」那张表 2026-09-30 晚删了，并进这里）
        title = '[https://aonprd.com/DeityDisplay.aspx?ItemName=' .. mw.uri.encode(r.en or r.name, 'PATH') .. ' ' .. r.name .. ']'
    else
        title = r.name == r.page and ('[[' .. r.page .. ']]') or ('[[' .. r.page .. '|' .. r.name .. ']]')
    end
    local doms = {}
    for x in mw.text.gsplit(r.domains or '', '、', true) do
        x = mw.text.trim(x)
        if x ~= '' then doms[#doms + 1] = x end
    end
    local d = table.concat({ '', r.dtype or '', r.pan or '', r.align or '', '', table.concat(doms, '|'), '', zi, 0, 0 }, ';')
    return '<div class="mq-c a' .. (r.ak or 9) .. '" data-d="' .. enc(d) .. '">'
        .. '<div class="q-h"><div class="q-n">' .. title .. '<small>' .. enc(r.name ~= r.en and r.en or '') .. '</small></div>'
        .. '<span class="q-r" title="' .. enc(r.align or '') .. '">' .. enc(r.ab or '—') .. '</span></div>'
        .. '<div class="q-m">' .. enc(r.dtype or '') .. ' · ' .. (r.pan == '核心神祇' and '★ ' or '') .. enc(r.pan or '') .. '</div>'
        .. ((#doms > 0) and ('<div class="q-dm">' .. enc(table.concat(doms, ' · ')) .. '</div>') or '')
        .. ((r.portfolio and r.portfolio ~= '') and ('<div class="q-d">' .. enc(r.portfolio) .. '</div>') or '')
        .. '<div class="q-f"><span class="q-e">' .. ((r.weapon and r.weapon ~= '') and ('偏好武器：' .. enc(r.weapon)) or '') .. '</span></div></div>'
end

function p.deity(frame)
    local rows = mw.huiji.db.find({ kind = 'deity' }, { limit = 2000 })
    table.sort(rows, function(a, b)
        local x, y = (a.untr or 0), (b.untr or 0)
        if x ~= y then return x < y end
        if (a.ak or 9) ~= (b.ak or 9) then return (a.ak or 9) < (b.ak or 9) end
        return (a.en or '') < (b.en or '')
    end)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = deityCard(r, (r.page == '未汉化神祇') and 2 or 1) end
    return '<div class="mq" id="mq" data-mode="deity" data-count="' .. #rows .. '" data-src="已汉化|未汉化"><div class="mq-grid"><div class="mq-facets"></div>'
        .. '<div class="mq-main"><div class="mq-bar"></div><div class="mq-active"></div><div class="mq-cards">'
        .. table.concat(out) .. '</div></div><div class="mq-tray"></div></div></div>'
end

return p