-- [[首页]] 用的小零件。源文件在仓库 design/mainpage/Module_首页.lua，改这里要同步回去。
--
-- 今日法术：{{#invoke:首页|spell|{{CURRENTYEAR}}{{CURRENTMONTH}}{{CURRENTDAY2}}}}
--   从 Data:Spells.tab（站点 MongoDB）里按日期挑一条已汉化的法术，排成首页右栏那张小卡。
--   日期由页面传进来（页面用了 CURRENTDAY 这类魔术字，MediaWiki 才知道这页的缓存要按天过期）。
--   挑法：第 N 天取第 (N × 7919) mod 总数 条——乘一个大质数，相邻两天不会挑到相邻的法术。
local p = {}

local SPELLS = { _id = { ['$regex'] = '^Data:Spells\\.tab#' }, untr = 0 }

local function daynum(ymd)
    local y, m, d = (ymd or ''):match('^(%d%d%d%d)(%d%d)(%d%d)$')
    local t = y and os.time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 }) or os.time()
    return math.floor(t / 86400)
end

local function pick(ymd)
    local n = mw.huiji.db.count(SPELLS)
    if not n or n == 0 then return nil end
    local idx = (daynum(ymd) * 7919) % n
    local rows = mw.huiji.db.find(SPELLS, { sort = { _id = 1 }, skip = idx, limit = 1 })
    return rows and rows[1]
end

local function nonempty(s)
    return s ~= nil and s ~= '' and s
end

local function cut(s, n)
    if mw.ustring.len(s or '') > n then return mw.ustring.sub(s, 1, n - 1) .. '…' end
    return s
end

-- 环位一长就折行（第二行常常只剩一个「8」），右栏也跟着变高、左边抽屉变空：
-- 只列前三个职业，多的用「…」，完整的放进悬停提示
local function shortLevels(s)
    if not nonempty(s) then return s end
    local parts = mw.text.split(s, '、', true)
    if #parts <= 3 then return s end
    return string.format('<span title="%s">%s …</span>', mw.text.encode(s),
        table.concat({ parts[1], parts[2], parts[3] }, '、'))
end

function p.spell(frame)
    local ok, r = pcall(pick, frame.args[1])
    if not ok or not r then
        return '[[法术速查|到法术速查里随便翻翻 →]]'
    end
    local school = r.school or ''
    local what = school
    if nonempty(r.sub) then what = what .. '（' .. r.sub .. '）' end
    if nonempty(r.tags) then what = what .. '〔' .. r.tags .. '〕' end
    local fields = {
        { '学派', what }, { '环位', shortLevels(r.classlv) }, { '施法时间', r.action },
        { '距离', r.range }, { '持续时间', r.duration }, { '豁免', r.save },
    }
    local out = {
        '<div class="mpa-spell"><div class="mpa-sp-h"><span class="mpi mpi-', school, '"></span>[[',
        r.page or r.name, '|', r.name, ']]',
        nonempty(r.en) and ('<small>' .. r.en .. '</small>') or '',
        '</div><div class="mpa-sp-f">',
    }
    for _, f in ipairs(fields) do
        if nonempty(f[2]) then
            table.insert(out, '<span><i>' .. f[1] .. '</i>' .. f[2] .. '</span>')
        end
    end
    table.insert(out, '</div></div>')
    return table.concat(out)
end

-- 今日怪物（2026-10-02）：{{#invoke:首页|monster|{{CURRENTYEAR}}{{CURRENTMONTH}}{{CURRENTDAY2}}}}
--   挑法同今日法术，换一个质数（6151），法术和怪物不会总是同一个序号；只挑已汉化的。
local MONSTERS = { _id = { ['$regex'] = '^Data:Monsters\\.tab#' }, untr = 0 }

function p.monster(frame)
    local ok, r = pcall(function()
        local n = mw.huiji.db.count(MONSTERS)
        if not n or n == 0 then return nil end
        local rows = mw.huiji.db.find(MONSTERS, { sort = { _id = 1 }, skip = (daynum(frame.args[1]) * 6151) % n, limit = 1 })
        return rows and rows[1]
    end)
    if not ok or not r then
        return '[[怪物速查|到怪物速查里随便翻翻 →]]'
    end
    local cr = nonempty(r.cr) and ('CR ' .. r.cr .. (nonempty(r.mr) and (' / MR ' .. r.mr) or '')) or nil
    local what = table.concat({ r.size or '', r.ctype or '' }, '')
    local fields = { { '挑战等级', cr }, { '类型', nonempty(what) }, { '阵营', r.align }, { '环境', r.env } }
    local out = {
        '<div class="mpa-spell mpa-mon"><div class="mpa-sp-h">[[', r.page or r.name, '|', r.name, ']]',
        nonempty(r.en) and ('<small>' .. r.en .. '</small>') or '', '</div><div class="mpa-sp-f">',
    }
    for _, f in ipairs(fields) do
        if nonempty(f[2]) then table.insert(out, '<span><i>' .. f[1] .. '</i>' .. f[2] .. '</span>') end
    end
    table.insert(out, '</div>')
    if nonempty(r.desc) then table.insert(out, '<div class="mpa-mon-d">' .. cut(r.desc, 80) .. '</div>') end
    table.insert(out, '</div>')
    return table.concat(out)
end

-- 随机条目（2026-10-02）：{{#invoke:首页|random|{{CURRENTYEAR}}{{CURRENTMONTH}}{{CURRENTDAY2}}}}
--   从专长、背景特性、物品、怪物、危害、神祇里各按日期挑 4 条（共 24 条）排进页面，没脚本时只露第一条；
--   Common.js 的「首页随机条目」一段随机显示其中一条，「换一个」再换——都是页面里已有的内容，不异步加载（基石准则 4）。
local function tab(re) return { _id = { ['$regex'] = re }, untr = 0 } end
-- kind 在几张表之间会撞（物品卡片和物品总表都是 item），按表名圈
local POOLS = {
    { '专长', tab('^Data:Feats\\.tab#'), 'desc' },
    { '背景特性', tab('^Data:Traits\\.tab#'), 'desc' },
    { '物品', tab('^Data:ItemCards[12]\\.tab#'), 'x' },
    { '怪物', MONSTERS, 'desc' },
    { '危害', tab('^Data:Hazards\\.tab#'), 'x' },
    { '神祇', tab('^Data:Deities\\.tab#'), 'portfolio' },
}
local PRIMES = { 7907, 7901, 7883, 7879 }

function p.random(frame)
    local day = daynum(frame.args[1])
    local counts = {}
    for pi, pool in ipairs(POOLS) do
        local ok, n = pcall(mw.huiji.db.count, pool[2])
        counts[pi] = ok and n or 0
    end
    -- 轮着排（专长、背景特性、物品……再一轮），开头那条按日期轮换类别；没脚本时只露开头那条
    local items = {}
    for k, pr in ipairs(PRIMES) do
        for pi, pool in ipairs(POOLS) do
            local n = counts[pi]
            if n > 0 then
                local ok, rows = pcall(mw.huiji.db.find, pool[2], { sort = { _id = 1 }, skip = (day * pr + pi * 131 + k * 977) % n, limit = 1 })
                local r = ok and rows and rows[1]
                if r and nonempty(r.name) then
                    local d = r[pool[3]] or ''
                    if pool[1] == '神祇' and nonempty(d) then d = '神职：' .. d end
                    items[#items + 1] = { pool[1], r, cut(d, 60) }
                end
            end
        end
    end
    if #items == 0 then return '[[Special:随机页面|随便看一页 →]]' end
    local out = { '<div class="mpa-rnd">' }
    for i = 1, #items do
        local it = items[(i - 1 + day) % #items + 1]
        local r = it[2]
        table.insert(out, '<div class="mpa-rnd-i"><div class="mpa-sp-h">[[' .. (r.page or r.name) .. '|' .. r.name .. ']]'
            .. '<span class="mpa-rnd-k">' .. it[1] .. '</span></div>'
            .. (nonempty(it[3]) and ('<div class="mpa-mon-d">' .. it[3] .. '</div>') or '') .. '</div>')
    end
    table.insert(out, '</div>')
    return table.concat(out)
end

-- 核对用：{{#invoke:首页|probe|20260922}} -> 总数、当天的序号、挑中的法术
function p.probe(frame)
    local n = mw.huiji.db.count(SPELLS)
    local idx = (daynum(frame.args[1]) * 7919) % n
    local r = pick(frame.args[1])
    return string.format('总数 %d；序号 %d；%s', n, idx, r and (r.name .. ' / ' .. (r._id or '')) or '无')
end

return p