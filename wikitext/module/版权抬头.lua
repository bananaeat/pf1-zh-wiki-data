-- 版权抬头（2026-09-30 深夜；用户：「用 lua 做一下版权抬头吧，可以仿照 pf2 维基的——在每一页内容页上根据来源贴上这样的一段信息」）。
-- 源文件在仓库 design/copyright_banner.lua，站上是 模块:版权抬头。
--   {{#invoke:版权抬头|main}}
-- 由各条目模板（Spell、Feat、物品、Trait、怪物、神祇、狂暴之力、Class、仪式、传世名作、动物伙伴卡片、魔宠变体、种族卡、Source）
-- 在输出最前面调用。出处不从模板参数取，而是读**当前页自己的源码**：页上所有 |source= |source_name= |出处= 和 {{Source|书}}
-- 收齐成一条——这样
--   * 一页几个块（怪物族群页、几张专长卡）每次调用输出同一条，重复的由 CSS 藏掉（Common.css「版权抬头」一节）；
--   * 汇总页把条目页整页嵌进来时，汇总页自己的源码里没有出处，就不出抬头。
-- 书名、英文名、缩写都按 Data:Books.tab（kind=book）认；有缩写的书名后面带（缩写），没有就不带（用户定）。
-- 只在主命名空间出；AI 翻译标注是另一条（{{AI翻译}}），不合并（用户定）。
local p = {}
local U = mw.ustring

local LICENSE = '本条目为非官方授权的民间翻译，原内容版权为 Paizo 所有，使用和分享时请遵守 Paizo 的'
    .. '[https://paizo.com/licenses/communityuse 社区使用政策]与[https://opengamingfoundation.org/ogl.html 开放游戏许可（OGL）]'
local MAXBOOKS = 6            -- 列表页（全部动物伙伴、种族页一堆卡片）书太多：列前几本，后面写「等 N 本」

-- 书目：模块:版权抬头/书目（tools/copyright_books.py 从 Data:Books.tab 生成）。用 mw.loadData——一页上百张卡片时每张都调一次本模块，
-- 每次读数据库会撞每页 7 秒的上限（「动物伙伴/全部伙伴」7.004 秒）；loadData 一页只加载一次。
-- by：中文书名／小写英文名／缩写 -> {name, abbr}；sep：书名本身带顿号、逗号、斜杠的（「冒险之路69：少女、母亲、老妪」），切之前先整个认
local function books()
    local d = mw.loadData('模块:版权抬头/书目')
    return d.by, d.sep
end

-- 一栏出处 -> 书名串（「内海诸神、正义编年史」「UW、HotW」「FoP/FoB/FoC」「Ultimate Equipment pg. 9」「[[书]]」）
local function tokens(v, out, sep)
    v = U.gsub(v, '%[%[([^%]|]*)|?[^%]]*%]%]', '%1')
    v = U.gsub(v, "'''?", '')
    for _, k in ipairs(sep) do
        local i = string.find(v, k, 1, true)
        if i then
            out[#out + 1] = k
            v = v:sub(1, i - 1) .. '、' .. v:sub(i + #k)
        end
    end
    for part in mw.text.gsplit(v, '[、，,；;／/]', false) do          -- mw.text.gsplit 按 Unicode 字符切
        part = U.gsub(part, '%s+pg%.%s*%d+.*$', '')
        part = U.gsub(part, '（[^）]*）$', '')
        part = mw.text.trim(part)
        if part ~= '' then out[#out + 1] = part end
    end
end

-- 算本页的抬头。一页上每张卡片都调一次 main，结果都一样：真正的计算放在 模块:版权抬头/本页 里，由 mw.loadData 加载——
-- 同一页的解析里只执行一次，后面的调用直接取结果（「动物伙伴/全部伙伴」214 张卡，每张重扫整页源码会撞 7 秒上限）
function p.compute()
    local title = mw.title.getCurrentTitle()
    if title.namespace ~= 0 then return '' end
    local src = title:getContent() or ''
    local vals = {}
    -- source_name（中文书名）排在 source（缩写）前：缩写有撞的（PotR＝河域子民／正义之路），书名先认上，同缩写的就不再另算一本
    for _, pat in ipairs({ '\n|%s*source_name%s*=%s*([^\n]+)', '\n|%s*source%s*=%s*([^\n]+)', '\n|%s*出处%s*=%s*([^\n]+)',
                           '{{%s*Source%s*|%s*([^|}]+)' }) do
        for v in U.gmatch(src, pat) do vals[#vals + 1] = v end
    end
    local by, sep = books()
    if #vals == 0 then
        -- 页上没写出处栏：认开头一句「'''X'''是《书》的一章」「汇总《书》……」「'''X'''是[[书]]的规则」（书目章节页、汇总页、各书规则页），书要在书目表里
        local head = U.sub(src, 1, 400)
        local bk = U.match(head, '是《%[?%[?([^》%]|]+)') or U.match(head, '汇总《%[?%[?([^》%]|]+)')
            or U.match(head, "'''是%[%[([^%]|]+)%]%]的规则")             -- 「'''APG规则'''是[[进阶玩家指南]]的规则」
        if bk and by[bk] then vals[1] = bk else return '' end
    end
    local raw = {}
    for _, v in ipairs(vals) do tokens(v, raw, sep) end
    local seen, seenAbbr, list = {}, {}, {}
    for _, t in ipairs(raw) do
        local b = by[t] or by[U.lower(t)]
        local name = b and b.name or t
        local ab = b and b.abbr ~= '' and b.abbr or nil
        if not seen[name] and not (ab and seenAbbr[ab]) then
            seen[name] = true
            if ab then seenAbbr[ab] = true end
            -- 不查页面在不在（exists 是高开销函数，一页上百张卡片会超每页 500 次的上限）：
            -- 书目表认出来的中文书名就是书页名，挂链；认不出的、只有英文名的不挂
            local shown = (b and U.find(name, '[一-鿿]')) and ('《[[' .. name .. ']]》') or ('《' .. name .. '》')
            if b and b.abbr and b.abbr ~= '' then shown = shown .. '（' .. b.abbr .. '）' end
            list[#list + 1] = shown
        end
    end
    if #list == 0 then return '' end
    local books_s = table.concat(list, '、', 1, math.min(#list, MAXBOOKS)) .. (#list > MAXBOOKS and ('等 ' .. #list .. ' 本') or '')
    return '<div class="pf-cr"><div class="pf-cr-t"><b>' .. mw.text.nowiki(title.text) .. '</b>：本条目内容来自'
        .. books_s .. '</div><div class="pf-cr-l">' .. LICENSE .. '</div></div>'
end

function p.main(frame)
    return mw.loadData('模块:版权抬头/本页').html
end

return p