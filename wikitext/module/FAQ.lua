-- 官方 FAQ 小卡片（2026-10-02；用户：「做 faq 的全量导入和校对……把这些 faq 以小卡片的形式插入到合适的页面里」）。
-- 源文件在仓库 design/faq.lua，站上是 模块:FAQ。数据在 模块:FAQ/数据/NN（mw.loadData 分片，tools/faq_apply.py 生成，别手改），
-- 编号 -> 分片 的索引在 模块:FAQ/数据/索引。一条 FAQ：
--   { t = 短标题, q = 问题, a = 回答（wikitext）, book = 出处书名, date = '2015/01/04', paizo = Paizo 原文地址,
--     cat = 'FAQ'／'PFS', ai = true（AI 照 AoN 译）, pages = { '页名', … }（插了这张卡的页） }
--   {{FAQ|编号|编号…}}            -> 一张或几张小卡片（模板:FAQ）
--   {{#invoke:FAQ|book|书名}}     -> 这本书的全部 FAQ（[[官方FAQ]] 下各书的页）
local p = {}

local function load(id)
    local idx = mw.loadData('模块:FAQ/数据/索引')
    local shard = idx[id]
    if not shard then return nil end
    return mw.loadData('模块:FAQ/数据/' .. shard)[id]
end

local function card(frame, id, e, withPages)
    if not e then
        return '<div class="faq-card faq-miss">找不到编号为 ' .. mw.text.encode(id) .. ' 的 FAQ</div>'
    end
    local foot = {}
    if e.book and e.book ~= '' then
        local b = e.book
        foot[#foot + 1] = mw.ustring.find(b, '[一-鿿]') and ('《[[' .. b .. ']]》') or ('《' .. b .. '》')
    end
    if e.date and e.date ~= '' then foot[#foot + 1] = (e.date:gsub('/', '-')) end
    if e.paizo and e.paizo ~= '' then
        foot[#foot + 1] = '[' .. e.paizo .. ' Paizo 原文]'
    else
        foot[#foot + 1] = '<span class="faq-ai">站上旧 FAQ 页留下的条目，AoN 现行 FAQ 未收录</span>'   -- old-NN（2026-10-02 核对旧页时补的）
    end
    if e.ai then foot[#foot + 1] = '<span class="faq-ai">AI 照 AoN 译，未经人工校对</span>' end
    if withPages and e.pages and #e.pages > 0 then
        local ls = {}
        for _, pg in ipairs(e.pages) do ls[#ls + 1] = '[[' .. pg .. ']]' end
        foot[#foot + 1] = '见 ' .. table.concat(ls, '、')
    end
    return '<div class="faq-card" id="faq-' .. id .. '"><div class="faq-h"><span class="faq-tag">'
        .. (e.cat == 'PFS' and 'PFS 裁定' or '官方 FAQ') .. '</span><span class="faq-t">' .. (e.t or '') .. '</span></div>'
        .. '<div class="faq-q">' .. (e.q or '') .. '</div>'
        .. '<div class="faq-a">\n' .. (e.a or '') .. '\n</div>'
        .. '<div class="faq-f">' .. table.concat(foot, ' · ') .. '</div></div>'
end

function p.cards(frame)
    local a = frame:getParent().args
    local out = {}
    for i = 1, 50 do
        local id = a[i] and mw.text.trim(a[i]) or ''
        if id == '' then break end
        out[#out + 1] = card(frame, id, load(id), false)
    end
    return '<div class="faq-cards">' .. table.concat(out) .. '</div>'
end

function p.book(frame)
    local want = mw.text.trim(frame.args[1] or '')
    local idx = mw.loadData('模块:FAQ/数据/索引')
    local rows = {}
    for id, shard in pairs(idx) do
        local e = mw.loadData('模块:FAQ/数据/' .. shard)[id]
        if e and (e.book == want or (want == 'PFS' and e.cat == 'PFS')) then rows[#rows + 1] = { id, e } end
    end
    table.sort(rows, function(x, y)
        if (x[2].t or '') ~= (y[2].t or '') then return (x[2].t or '') < (y[2].t or '') end
        return x[1] < y[1]
    end)
    local out = {}
    for _, r in ipairs(rows) do out[#out + 1] = card(frame, r[1], r[2], true) end
    return '<div class="faq-cards faq-list">' .. table.concat(out) .. '</div>'
end

return p