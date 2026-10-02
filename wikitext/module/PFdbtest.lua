-- 数据层探针：各张 Data:*.tab 进 MongoDB 的条数
local p = {}
local function cnt(prefix)
    local ok, res = pcall(function()
        return mw.huiji.db.count({ _id = { ['$regex'] = '^' .. prefix } })
    end)
    if ok then return tostring(res) else return 'ERR' end
end
function p.probe(frame)
    local out = {}
    for _, name in ipairs({ 'Monsters', 'NPCs', 'Spells', 'Feats', 'Items' }) do
        table.insert(out, name .. '=' .. cnt('Data:' .. name))
    end
    table.insert(out, '合计=' .. cnt(''))
    return table.concat(out, ' | ')
end
return p