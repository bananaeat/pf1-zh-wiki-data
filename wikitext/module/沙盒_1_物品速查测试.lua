local p = {}
function p.t()
  local out = {}
  local ok, n = pcall(function() return mw.huiji.db.count({ kind = 'item' }) end)
  out[#out+1] = 'count:' .. tostring(ok) .. ':' .. tostring(n)
  local keys = {}
  for k in pairs(mw.huiji.db) do keys[#keys+1] = k end
  out[#out+1] = 'fns:' .. table.concat(keys, ',')
  local ok2, r = pcall(function() return mw.huiji.db.find({ kind = 'item', grp = '防具' }, { limit = 5 }) end)
  out[#out+1] = 'grp:' .. tostring(ok2) .. ':' .. tostring(ok2 and #r)
  local ok3, r3 = pcall(function() return mw.huiji.db.find({ kind = 'monster' }, { limit = 3, projection = { name = 1 } }) end)
  if ok3 then local ks = {} for k in pairs(r3[1] or {}) do ks[#ks+1]=k end out[#out+1] = 'proj:' .. table.concat(ks, ',') else out[#out+1]='proj err '..tostring(r3) end
  return table.concat(out, ' ;; ')
end
return p