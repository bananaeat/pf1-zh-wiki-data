-- [[职业]] 总览（2026-10-02 改版：卡片分组＋对比表两个标签页）。源文件在仓库 design/class_overview.lua。
-- {{#invoke:职业总览|main}}
-- 生命骰、攻击加值、优势豁免、技能点、施法、职业定位都现读各职业页的 {{Class}} 卡片（改了职业页这里跟着变）；
-- 下面这张表只管分组、顺序、母职业、附带能力页、法术列表页——都是事实和链接，不写文案。
local p = {}

local GROUPS = {
    { '核心职业', '#8a6d3b', {
        { '野蛮人' }, { '吟游诗人' }, { '牧师' }, { '德鲁伊' }, { '战士', more = { '拓展武器组', '进阶武器训练', '进阶盔甲训练' } },
        { '武僧' }, { '圣武士', more = { '圣武士准则' }, spells = '法术列表（圣武士）' },
        { '游侠', spells = '法术列表（游侠）' }, { '盗贼' }, { '术士' }, { '法师' } } },
    { '基础职业', '#6d5a8a', {
        { '炼金术师', more = { '科研发现' } },
        { '反圣武士', alt = '圣武士', more = { '反圣武士准则' }, spells = '法术列表（反圣武士）' },
        { '骑士', more = { '骑士团' } }, { '枪手', more = { '炫技', '勇气挑战' } },
        { '审判者', more = { '裁决域' }, spells = '法术列表（审判者）' },
        { '魔战士', more = { '奥能' }, spells = '法术列表（魔战士）' },
        { '忍者', alt = '盗贼', more = { '忍术' } }, { '先知', more = { '先知诅咒', '秘示域' } },
        { '武士', alt = '骑士', more = { '武士团' } },
        { '召唤师', more = { '幻灵' }, spells = '法术列表（召唤师）' },
        { '女巫', more = { '巫术' }, spells = '法术列表（女巫）' } } },
    { '混合职业', '#3f6e6a', {
        { '奥能师', parents = { '术士', '法师' }, more = { '奥能技艺' }, spells = '法术列表（奥能师）' },
        { '血脉狂怒者', parents = { '野蛮人', '术士' }, more = { '血脉狂怒者血脉' }, spells = '法术列表（血脉狂怒者）' },
        { '拳师', parents = { '战士', '武僧' } },
        { '猎人', parents = { '德鲁伊', '游侠' }, spells = '法术列表（猎人）' },
        { '调查员', parents = { '炼金术师', '盗贼' }, more = { '调查员天赋' } },
        { '萨满', parents = { '先知', '女巫' }, more = { '魂兽与魂域' }, spells = '法术列表（萨满）' },
        { '歌者', parents = { '野蛮人', '吟游诗人' }, spells = '法术列表（歌者）' },
        { '杀手', parents = { '游侠', '盗贼' }, more = { '杀手天赋' } },
        { '游荡剑客', parents = { '战士', '枪手' } },
        { '战斗祭司', parents = { '牧师', '战士' }, more = { '祝福' }, spells = '法术列表（战斗祭司）' } } },
    { '掉链职业', '#7a3e2e', {
        { '掉链召唤师', base = '召唤师', more = { '掉链幻灵' }, spells = '法术列表（掉链召唤师）' },
        { '掉链武僧', base = '武僧', more = { '绝学' } },
        { '掉链野蛮人', base = '野蛮人', more = { '掉链狂暴之力' } },
        { '掉链盗贼', base = '盗贼', more = { '掉链盗贼天赋', '技能解放' } } } },
    { '异能职业', '#4a4f8a', {
        { '操念使', more = { '元素与原力' } }, { '通灵者', more = { '英灵' }, spells = '法术列表（通灵者）' },
        { '催眠师', more = { '催眠师诡计' }, spells = '法术列表（催眠师）' },
        { '秘学士', more = { '灵器学派' }, spells = '法术列表（秘学士）' },
        { '异能者', more = { '精神境界', '精神增幅' }, spells = '法术列表（异能者）' },
        { '唤魂师', more = { '魅影', '情感羁绊' }, spells = '法术列表（唤魂师）' } } },
    { '其他职业', '#5b6b3a', {
        { '侠客', more = { '社交天赋', '侠客天赋' } }, { '变形者' } } },
}
-- 小卡片（不出属性条）
local MINOR = {
    { '神话道途', '#9a6b2e', { '大法师', '斗士', '守护者', '圣者', '统帅', '诡术大师' }, { '通用道途能力' } },
    { 'NPC职业', '#7d7466', { '导师', '望族', '平民', '专家', '武者' } },
    { 'AoN未收职业', '#7d7466', { '吸血鬼猎人', '导魂者' } },
}

local CAST = { ['奥术'] = 'arc', ['神术'] = 'div', ['异能'] = 'psy', ['炼金药剂'] = 'alc' }
local BAB = { ['完全'] = 3, ['中等'] = 2, ['较差'] = 1 }

local function nonempty(s) return s ~= nil and s ~= '' and s end

local function plain(s)
    s = (s or ''):gsub('%[%[[^%]|]*|([^%]]*)%]%]', '%1'):gsub('%[%[([^%]]*)%]%]', '%1')
    return mw.text.trim(s)
end

local function cut(s, n)
    s = plain(s)
    if mw.ustring.len(s) > n then return mw.ustring.sub(s, 1, n - 1) .. '…' end
    return s
end

-- 职业页 {{Class}} 卡片 -> 参数表
local cache, src = {}, {}
local function card(name)
    if cache[name] then return cache[name] end
    local t = mw.title.new(name)
    local s = t and t:getContent() or ''
    src[name] = s
    local blk = s:match('{{Class%s*\n(.-)\n}}') or ''
    local d = {}
    for line in (blk .. '\n'):gmatch('([^\n]*)\n') do
        local k, v = line:match('^|([%w_]+)=(.*)$')
        if k then d[k] = mw.text.trim(v) end
    end
    cache[name] = d
    return d
end

-- 技能点「4+[[智力]]修正」「4 + 智力调整值」-> 「4＋智」
local function ranks(s)
    local n = plain(s):match('^(%d+)')
    return n and (n .. '＋智') or plain(s)
end

local function saves(s)
    local out = {}
    for _, k in ipairs({ { '强韧', '强' }, { '反射', '反' }, { '意志', '意' } }) do
        local on = (s or ''):find(k[1], 1, true)
        out[#out + 1] = '<span class="cov-s' .. (on and ' on' or '') .. '" title="' .. k[1] .. (on and '（优势）' or '') .. '">' .. k[2] .. '</span>'
    end
    return table.concat(out)
end

local function babbar(s)
    local n = BAB[plain(s)] or 0
    local out = {}
    for i = 1, 3 do out[#out + 1] = '<span class="cov-pip' .. (i <= n and ' on' or '') .. '"></span>' end
    return table.concat(out)
end

-- 「9 环奥术，准备施法；智力」-> chip
local function casting(s)
    s = plain(s)
    if s == '' then return '' end
    local lv, kind = s:match('^(%d+)%s*环(%S-)，')
    local cls = kind and CAST[kind] or 'arc'
    return '<span class="cov-cast cov-' .. cls .. '">' .. s:gsub('，', ' · '):gsub('；', ' · ') .. '</span>'
end

local function links(list)
    local out = {}
    for _, x in ipairs(list) do out[#out + 1] = '[[' .. x .. ']]' end
    return table.concat(out, ' ')
end

local vcache = {}
local function variants(name)            -- 卡片和对比表各要一次：记住，昂贵函数只算一遍
    if vcache[name] == nil then vcache[name] = mw.site.stats.pagesInCategory(name .. '变体职业', 'pages') end
    return vcache[name]
end

local function strip(d)
    return '<div class="cov-st">'
        .. '<div><b>' .. (d.hd or '—') .. '</b><small>生命骰</small></div>'
        .. '<div><b>' .. plain(d.bab or '—') .. '<span class="cov-pips">' .. babbar(d.bab) .. '</span></b><small>攻击加值</small></div>'
        .. '<div><b class="cov-sv">' .. saves(d.saves) .. '</b><small>优势豁免</small></div>'
        .. '<div><b>' .. ranks(d.ranks) .. '</b><small>技能点</small></div></div>'
end

local function fullcard(e, color)
    local name = e[1]
    local d = card(name)
    local out = { '<div class="cov-card" style="--cc:' .. color .. '">' }
    out[#out + 1] = '<div class="cov-h"><b>[[' .. name .. ']]</b><i>' .. (d.english_name or '') .. '</i></div>'
    out[#out + 1] = strip(d)
    local tags = {}
    if nonempty(d.casting) then tags[#tags + 1] = casting(d.casting) end
    if e.parents then tags[#tags + 1] = '<span class="cov-rel">母职业 [[' .. e.parents[1] .. ']]＋[[' .. e.parents[2] .. ']]</span>' end
    if e.base then tags[#tags + 1] = '<span class="cov-rel">改版自 [[' .. e.base .. ']]</span>' end
    if e.alt then tags[#tags + 1] = '<span class="cov-rel">替代 [[' .. e.alt .. ']]</span>' end
    if #tags > 0 then out[#out + 1] = '<div class="cov-tags">' .. table.concat(tags) .. '</div>' end
    if nonempty(d.role) then out[#out + 1] = '<div class="cov-role">' .. cut(d.role, 46) .. '</div>' end
    local foot = {}
    local nv = variants(name)
    if nv and nv > 0 then foot[#foot + 1] = '[[:分类:' .. name .. '变体职业|变体 ' .. nv .. ']]' end
    for _, x in ipairs(e.more or {}) do foot[#foot + 1] = '[[' .. x .. ']]' end
    if e.spells then foot[#foot + 1] = '[[' .. e.spells .. '|法术列表]]' end
    if #foot > 0 then out[#out + 1] = '<div class="cov-f">' .. table.concat(foot, '') .. '</div>' end
    out[#out + 1] = '</div>'
    return table.concat(out)
end

local function smallcard(name, color, stats)
    local d = card(name)
    local out = '<div class="cov-mini" style="--cc:' .. color .. '"><b>[[' .. name .. ']]</b><i>' .. (d.english_name or '') .. '</i>'
    if stats and nonempty(d.hd) then
        out = out .. '<span class="cov-ms">' .. d.hd .. ' · ' .. plain(d.bab) .. ' · ' .. plain(d.saves) .. ' · ' .. ranks(d.ranks)
            .. (nonempty(d.casting) and (' · ' .. plain(d.casting)) or '') .. '</span>'
    end
    return out .. '</div>'
end

local function cardsView()
    local out = {}
    for _, g in ipairs(GROUPS) do
        out[#out + 1] = '<div class="cov-g"><div class="cov-gh" style="--cc:' .. g[2] .. '">[[:分类:' .. g[1] .. '|' .. g[1] .. ']]<span>' .. #g[3] .. '</span></div><div class="cov-grid">'
        for _, e in ipairs(g[3]) do out[#out + 1] = fullcard(e, g[2]) end
        out[#out + 1] = '</div></div>'
    end
    for _, g in ipairs(MINOR) do
        local label = g[1] == 'AoN未收职业' and 'AoN 未收录' or g[1]
        out[#out + 1] = '<div class="cov-g"><div class="cov-gh" style="--cc:' .. g[2] .. '">[[:分类:' .. g[1] .. '|' .. label .. ']]<span>' .. #g[3] .. '</span>'
            .. (g[4] and ('<em>' .. links(g[4]) .. '</em>') or '') .. '</div><div class="cov-minis">'
        for _, n in ipairs(g[3]) do out[#out + 1] = smallcard(n, g[2], g[1] ~= '神话道途') end
        out[#out + 1] = '</div></div>'
    end
    return table.concat(out)
end

local function tableView()
    local out = { '{| class="wikitable sortable cov-table"\n! 职业 !! 类别 !! 生命骰 !! 攻击加值 !! 优势豁免 !! 技能点 !! 施法 !! 出处 !! 变体' }
    local function row(name, group)
        local d = card(name)
        local nv = variants(name)
        out[#out + 1] = '|-\n| [[' .. name .. ']] || ' .. group .. ' || data-sort-value="' .. ((d.hd or ''):match('%d+') or 0) .. '" | ' .. (d.hd or '—')
            .. ' || data-sort-value="' .. (BAB[plain(d.bab)] or 0) .. '" | ' .. plain(d.bab or '—') .. ' || ' .. plain(d.saves or '')
            .. ' || data-sort-value="' .. (plain(d.ranks):match('^(%d+)') or 0) .. '" | ' .. ranks(d.ranks)
            .. ' || ' .. plain(d.casting or '') .. ' || ' .. (nonempty(d.source) and ('[[' .. d.source .. ']]') or '')
            .. ' || ' .. ((nv and nv > 0) and ('[[:分类:' .. name .. '变体职业|' .. nv .. ']]') or '—')
    end
    for _, g in ipairs(GROUPS) do for _, e in ipairs(g[3]) do row(e[1], g[1]) end end
    for _, g in ipairs(MINOR) do
        if g[1] ~= '神话道途' then for _, n in ipairs(g[3]) do row(n, g[1] == 'AoN未收职业' and 'AoN 未收录' or g[1]) end end
    end
    out[#out + 1] = '|}'
    return table.concat(out, '\n')
end

function p.main(frame)
    local html = '<div class="cov">'
        .. '<ul class="nav nav-tabs cov-tabs"><li class="active"><span data-toggle="tab" data-target="#cov-cards">卡片</span></li>'
        .. '<li><span data-toggle="tab" data-target="#cov-table">对比表</span></li></ul>'
        .. '<div class="tab-content"><div id="cov-cards" class="tab-pane active">' .. cardsView() .. '</div>'
        .. '<div id="cov-table" class="tab-pane">\n' .. tableView() .. '\n</div></div></div>'
    return frame:preprocess(html)
end

-- ================================================================ 进阶职业（[[进阶职业]] 总页，2026-10-02）
-- {{#invoke:职业总览|prestige}}：按出处的产品线分组（Data:Books.tab 的 line），组内按出版日期排；
-- 卡片：属性条、等级数、推进施法的级数（等级表最后一栏「现有施法职业等级+1」这类的行数）、进阶条件开头（原文截断）、出处。
local PRESTIGE = {
    '解放者(进阶职业)', '镣铐海盗', '寻光者', '阿巴达尔平衡天平', '代维拉特', '魔射手', '诡术师', '刺客',
    '龙脉术士', '决斗家', '奥法骑士', '博学士', '秘术师', '历史探索者', '影舞者', '臃肿法师',
    '先锋', '神圣辩护者', '大地旅者', '炼金大师（进阶职业）', '间谍大师', '自然守望者', '怒火先知', '坚定防卫者',
    '半身人投机客', '卑怯圣堂武士', '哈罗牌大师', '红螳螂杀手', '密文法师', '神嗣', '内海海盗(进阶职业)', '无眠侦探',
    '冬女巫', '死斗战士', '晨花讨逆者', '卡利斯拉德先知', '阴影代理人', '贵族后裔（进阶职业）', '刺青秘法师', '拉兹密安牧师',
    '灰花匠', '密封修士', '义洛理的勇士', '匕痕施毒者', '迷纱幻者', '黑炎使者', '裂隙守卫', '奈克斯弧光领主',
    '苍翠修道者', '奥泽姆骑士', '盾勋执法官', '寻天者', '神秘教徒', '协会外勤探员', '活体石像', '苏比亚炼金师',
    '均衡密使', '灵魂守卫（亡灵杀手手册）', '精纯卫队执行者', '乌尔芬卫士', '传音者', '颂教者', '卫道者', '饮痛者',
    '科技法师', '妩媚交际花', '狮子剑', '伊沙-瓦舞者', '酿酒师', '绯红十字军', '挑战者', '晨花隐者',
    '誓诚缪斯', '继业骑士', '戍乡人', '玫瑰戍卫', '符文守卫', '虔圣保卫者', '负痕求道者', '天体颂唱者',
    '观星者', '妖精誓缚者', '地狱骑士', '盾徽专员', '玛伽姆比亚秘术师', '铃花耕作人', '掌灯人', '奥多里剑豪',
    '风暴朝拜者', '巨兽驭手', '黄金军团士兵', '地狱骑士持节士', '西冠魔鬼', '银之编剧', '亚萨维尔', '安息杀手',
    '灰海盗', '协会探究者', '协会博学者', '钉魂密使', '染血天使', '钢隼', '完美门徒', '战争学徒',
    '暮光之爪', '束缚巨灵', '恶魔狂信者', '魔鬼大师', '吮魂者', '督察', '密传骑士', '仪式师',
    '天体行者', '执法官', '谢瓦利耶', '后继者远征骑士', '墓穴使徒', '切尔纳萨多守望者', '凡世渡魂人',
}

local LINES = { { '规则书', '#8a6d3b' }, { '战役设定', '#3f6e6a' }, { '玩家伴侣', '#6d5a8a' }, { '冒险之路', '#7a3e2e' }, { '其他', '#7d7466' } }

local books = {}
local function book(name)
    if not nonempty(name) then return {} end
    if books[name] == nil then
        local ok, r = pcall(mw.huiji.db.find, { _id = { ['$regex'] = '^Data:Books\\.tab#' }, name = name }, { limit = 1 })
        books[name] = (ok and r and r[1]) or {}
    end
    return books[name]
end

local function section(s, h)
    return ('\n' .. s .. '\n==x'):match('\n==%s*' .. h .. '%s*==[^\n]*\n(.-)\n==[^=]') or ''
end

-- 等级表 -> 等级数、推进施法的级数、施法传统（只有奥术或只有神术时给名字）
local function levels(s)
    local tb = section(s, '等级表'):match('{|.-\n|}') or ''
    local n, adv, arc, div = 0, 0, false, false
    for line in tb:gmatch("\n|%s*'*%d+[^\n]*") do
        n = n + 1
        local cells = mw.text.split(line, '||', true)
        local last = cells[#cells] or ''
        if last:find('等级%s*%+%d') or last:find('^%s*%+%d[^%[]*等级') then
            adv = adv + 1
            if last:find('奥术', 1, true) or last:find('女巫', 1, true) then arc = true end
            if last:find('神术', 1, true) then div = true end
        end
    end
    return n, adv, (arc and not div) and '奥术' or ((div and not arc) and '神术' or nil)
end

local function prereq(s)
    local sec = '\n' .. section(s, '进阶条件')
    local items = {}
    for b in sec:gmatch('\n%*%s*([^\n]+)') do items[#items + 1] = plain((b:gsub("'''", ''))) end
    if #items == 0 then                  -- 影舞者、卫道者这几页一项一个三级标题：「=== 技能 ===」下一段是内容
        local label
        for line in (sec .. '\n'):gmatch('([^\n]*)\n') do
            local h = line:match('^===%s*(.-)%s*===%s*$')
            local text = mw.text.trim((line:gsub('<span[^>]*></span>', '')))
            if h then
                label = mw.text.trim((h:gsub('%s*%(.*%)', '')))
            elseif label and text ~= '' then
                items[#items + 1] = label .. '：' .. plain((text:gsub("'''", '')))
                label = nil
            end
        end
    end
    if #items == 0 then return nil end
    return cut(table.concat(items, ' '), 64)
end

local function pcard(name, color)
    local d = card(name)
    local s = src[name] or ''
    local n, adv, trad = levels(s)
    local out = { '<div class="cov-card cov-pc" style="--cc:' .. color .. '">' }
    out[#out + 1] = '<div class="cov-h"><b>[[' .. name .. '|' .. (nonempty(d.name) or name) .. ']]</b><i>' .. (d.english_name or '') .. '</i></div>'
    out[#out + 1] = strip(d)
    local tags = {}
    if n > 0 then tags[#tags + 1] = '<span class="cov-lv">' .. n .. ' 级</span>' end
    if adv > 0 then
        tags[#tags + 1] = '<span class="cov-cast cov-' .. (trad == '神术' and 'div' or 'arc') .. '">推进' .. (trad or '') .. '施法 ' .. adv .. '/' .. n .. '</span>'
    end
    if #tags > 0 then out[#out + 1] = '<div class="cov-tags">' .. table.concat(tags) .. '</div>' end
    local pr = prereq(s)
    if pr then out[#out + 1] = '<div class="cov-role cov-pre">' .. pr .. '</div>' end
    if nonempty(d.source) then out[#out + 1] = '<div class="cov-f">[[' .. d.source .. ']]</div>' end
    out[#out + 1] = '</div>'
    return table.concat(out), n, adv
end

function p.prestige(frame)
    local groups = {}
    for _, name in ipairs(PRESTIGE) do
        local d = card(name)
        local b = book(d.source)
        local line = nonempty(b.line) or '其他'
        groups[line] = groups[line] or {}
        table.insert(groups[line], { name = name, date = b.date or '9999' })
    end
    local cards = {}
    local trows = { '{| class="wikitable sortable cov-table"\n! 进阶职业 !! 产品线 !! 出处 !! 等级 !! 生命骰 !! 攻击加值 !! 优势豁免 !! 技能点 !! 推进施法' }
    for _, L in ipairs(LINES) do
        local list = groups[L[1]]
        if list then
            table.sort(list, function(a, b) if a.date ~= b.date then return a.date < b.date end return a.name < b.name end)
            cards[#cards + 1] = '<div class="cov-g"><div class="cov-gh" style="--cc:' .. L[2] .. '">' .. L[1] .. '<span>' .. #list .. '</span></div><div class="cov-grid">'
            for _, e in ipairs(list) do
                local html, n, adv = pcard(e.name, L[2])
                cards[#cards + 1] = html
                local d = card(e.name)
                trows[#trows + 1] = '|-\n| [[' .. e.name .. '|' .. (nonempty(d.name) or e.name) .. ']] || ' .. L[1]
                    .. ' || data-sort-value="' .. e.date .. '" | ' .. (nonempty(d.source) and ('[[' .. d.source .. ']]') or '')
                    .. ' || ' .. n
                    .. ' || data-sort-value="' .. ((d.hd or ''):match('%d+') or 0) .. '" | ' .. (d.hd or '—')
                    .. ' || data-sort-value="' .. (BAB[plain(d.bab)] or 0) .. '" | ' .. plain(d.bab or '—') .. ' || ' .. plain(d.saves or '')
                    .. ' || data-sort-value="' .. (plain(d.ranks):match('^(%d+)') or 0) .. '" | ' .. ranks(d.ranks)
                    .. ' || ' .. (adv > 0 and adv or '—')
            end
            cards[#cards + 1] = '</div></div>'
        end
    end
    trows[#trows + 1] = '|}'
    local html = '<div class="cov">'
        .. '<ul class="nav nav-tabs cov-tabs"><li class="active"><span data-toggle="tab" data-target="#cov-cards">卡片</span></li>'
        .. '<li><span data-toggle="tab" data-target="#cov-table">对比表</span></li></ul>'
        .. '<div class="tab-content"><div id="cov-cards" class="tab-pane active">' .. table.concat(cards) .. '</div>'
        .. '<div id="cov-table" class="tab-pane">\n' .. table.concat(trows, '\n') .. '\n</div></div></div>'
    return frame:preprocess(html)
end

return p