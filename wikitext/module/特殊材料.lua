-- 特殊材料：挂链＋悬停小卡（2026-10-01；用户：「用lua做一次全站挂链，并且试试做一下每种材料的tooltip」）。
-- 源文件在仓库 design/material.lua，站上是 模块:特殊材料；数据在 模块:特殊材料/数据（tools/material_data.py 生成，mw.loadData）。
--
--   {{材料|精金}}  {{材料|精金|精金打造}}        -> 链接＋悬停小卡（模板:材料）
--   require('模块:特殊材料').auto(text)          -> 卡片模块（模块:武器 的武器／防具卡、模板:物品 的描述）在渲染时调用：
--                                                  正文里每种材料第一次出现的地方挂上链接和小卡，不改页面源码
--   {{#invoke:特殊材料|auto|正文}}               -> 同上，给 wikitext 模板用
--
-- 小卡内容渲染在页面里（hover 时由 CSS 显示，Common.css「特殊材料小卡」一节），不异步加载（灰机基石准则 4）。
-- 自动挂链只认特殊材料（精金、秘银、寒铁……）；原始材料（骨头、青铜、玻璃、黄金、黑曜石、石头）是常用词，不自动挂，要链就写 {{材料|青铜}}。
local p = {}
local U = mw.ustring

local function data()
    return mw.loadData('模块:特殊材料/数据')
end

-- 一种材料的链接＋小卡
local function tip(m, shown)
    local stats = {}
    if m.hardness and m.hardness ~= '' then stats[#stats + 1] = '硬度 ' .. m.hardness end
    if m.hp and m.hp ~= '' then stats[#stats + 1] = '每寸 ' .. m.hp .. ' 点生命值' end
    local card = '<span class="pf-mat-tip" style="display:none"><span class="pf-mat-h"><b>' .. m.zh .. '</b> <i>' .. m.en .. '</i></span>'
    if #stats > 0 then card = card .. '<span class="pf-mat-s">' .. table.concat(stats, ' · ') .. '</span>' end
    if m.summary and m.summary ~= '' then card = card .. '<span class="pf-mat-d">' .. m.summary .. '</span>' end
    if m.applies and m.applies ~= '' then card = card .. '<span class="pf-mat-a">可制：' .. m.applies .. '</span>' end
    card = card .. '</span>'
    local link = (m.page == shown) and ('[[' .. m.page .. ']]') or ('[[' .. m.page .. '|' .. shown .. ']]')
    return '<span class="pf-mat" tabindex="0">' .. link .. card .. '</span>'
end

function p.link(frame)
    local a = frame:getParent().args
    local name = mw.text.trim(a[1] or '')
    local m = data().by[name]
    if not m then return '[[' .. name .. ']]' end
    local shown = mw.text.trim(a[2] or '')
    return tip(m, shown ~= '' and shown or name)
end

-- 正文自动挂链：[[…]]、{{…}}、<…> 里的不动；每种材料只挂第一次出现
function p.auto(text)
    if type(text) == 'table' then text = text.args[1] or '' end      -- {{#invoke:特殊材料|auto|…}}
    if not text or text == '' then return text end
    local d = data()
    -- 先把不能动的片段换成占位符
    local keep = {}
    local function hold(s)
        keep[#keep + 1] = s
        return '\127' .. #keep .. '\127'
    end
    local t = text
    local done = {}
    -- 已经写好的材料链接（[[精金]]、[[秘银|秘银打造]]）也包上小卡，算这种材料已挂过
    t = U.gsub(t, '%[%[([^%]|#]+)|?([^%]]*)%]%]', function(target, shown)
        local m = d.by[mw.text.trim(target)]
        if m and m.page == mw.text.trim(target) and not done[m.page] then
            done[m.page] = true
            return hold(tip(m, shown ~= '' and shown or target))
        end
        return nil
    end)
    t = U.gsub(t, '%[%[.-%]%]', hold)
    t = U.gsub(t, '{{.-}}', hold)
    t = U.gsub(t, '<[^>]->', hold)
    for _, name in ipairs(d.auto) do                  -- 长名在前（「暗叶布」先于「暗木」）
        local m = d.by[name]
        local from = 1
        while not done[m.page] do
            local i, j = U.find(t, name, from, true)
            if not i then break end
            -- 别的东西的名字里带着材料名（虚铅魔像、血汞外衣）：跳过这一处，接着找
            local after = U.sub(t, j + 1, j + 2)
            if d.skip_after[after] then
                from = j + 1
            else
                done[m.page] = true
                t = U.sub(t, 1, i - 1) .. hold(tip(m, name)) .. U.sub(t, j + 1)
            end
        end
    end
    -- 占位符换回（小卡里本身不含占位符，一遍就够；嵌套的再来一遍）
    for _ = 1, 2 do
        t = U.gsub(t, '\127(%d+)\127', function(n) return keep[tonumber(n)] end)
    end
    return t
end

-- 怪物属性块的伤害减免栏（模板:怪物 的 dr）：「5/寒铁」「10/精金和善良」「5/银」——
-- 这里的「银」是炼银（alchemical silver），单独一个字只在 / 和 或 后面认；其余照 auto
function p.dr(frame)
    local v = frame.args[1] or ''
    if mw.text.trim(v) == '' then return v end
    local d = data()
    local silver = d.by['炼银']
    local marks = {}
    if silver then
        v = U.gsub(v, '([/和或、])银', function(pre)
            marks[#marks + 1] = tip(silver, '银')
            return pre .. '\126' .. #marks .. '\126'
        end)
    end
    v = p.auto(v)
    return (U.gsub(v, '\126(%d+)\126', function(n) return marks[tonumber(n)] end))
end

return p