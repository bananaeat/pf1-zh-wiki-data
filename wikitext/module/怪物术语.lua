-- 模块:怪物术语 —— 怪物属性块（[[模板:怪物]]）里的规则词一步链到对应单页：
-- 生物类型、亚种、通用怪物规则（感官、灵光、防御能力、免疫里的「X特性」、弱点、移动方式、特殊攻击、特殊特质、
-- 近战／远程攻击括号里的附带效果）。2026-09-30 起渲染时挂链，怪物页源码不用改；词表在 [[模块:怪物术语/数据]]
-- （tools/monster_terms_data.py 生成，别手改）。
--   {{#invoke:怪物术语|field|senses|{{{senses|}}}}}   一栏：按顶层逗号分项，每项开头认得出的词挂链
--   {{#invoke:怪物术语|type|{{{type|}}}}}               类型
--   {{#invoke:怪物术语|subtypes|{{{subtypes|}}}}}       亚种（分号分隔 → 「，」连起来）
--   {{#invoke:怪物术语|label|DR}}                       栏名本身链到规则页（DR、SR、免疫、抗力、弱点……）
-- 已经挂了链的项不动，只把指向总页锚点的老链接（[[通用怪物规则#攫抓|…]]）改指单页。

local p = {}
local D = mw.loadData('模块:怪物术语/数据')
local U = mw.ustring

local function trim(s) return (s and mw.text.trim(s)) or '' end

local function link(target, text)
	if target == text then return '[[' .. text .. ']]' end
	return '[[' .. target .. '|' .. text .. ']]'
end

-- 老链接 [[通用怪物规则#X|Y]] / [[生物类型与怪物亚种#X|Y]] / [[特殊能力#X|Y]] → 单页
local function retarget(s)
	return (s:gsub('%[%[([^%]|#]+)#([^%]|]+)(|?)', function(pg, anc, bar)
		local t = D.anchors[pg .. '#' .. anc]
		if t then return '[[' .. t .. (bar ~= '' and '|' or '|' .. anc) end
		return nil
	end))
end

-- 顶层分项：括号、[[ ]]、{{ }} 里面的逗号不算
local SEP = { ['，'] = true, [','] = true, ['；'] = true, [';'] = true, ['、'] = true }
local OPEN = { ['（'] = true, ['('] = true, ['['] = true, ['{'] = true }
local CLOSE = { ['）'] = true, [')'] = true, [']'] = true, ['}'] = true }

local function splitTop(s)
	local items, seps, buf, depth = {}, {}, {}, 0
	for ch in U.gmatch(s, '.') do
		if OPEN[ch] then depth = depth + 1 elseif CLOSE[ch] then depth = depth - 1 end
		if SEP[ch] and depth <= 0 then
			items[#items + 1] = table.concat(buf); seps[#seps + 1] = ch; buf = {}
		else
			buf[#buf + 1] = ch
		end
	end
	items[#items + 1] = table.concat(buf)
	return items, seps
end

-- 一项开头认词：最长前缀匹配（先跳过开头的空白和「附带」「随意」这类虚词）
local function linkHead(item, dict)
	if item:find('[[', 1, true) then return retarget(item) end
	local lead, rest = U.match(item, '^(%s*)(.-)$')
	local pre = ''
	for _, w in ipairs(D.skip) do
		if U.sub(rest, 1, U.len(w)) == w then pre = w; rest = U.sub(rest, U.len(w) + 1); break end
	end
	local n = math.min(D.maxlen, U.len(rest))
	for k = n, 1, -1 do
		local head = U.sub(rest, 1, k)
		local t = dict[head]
		if t then
			return lead .. pre .. link(t, head) .. U.sub(rest, k + 1)
		end
	end
	return item
end

local function joinBack(items, seps)
	local out = {}
	for i, it in ipairs(items) do
		out[#out + 1] = it
		if seps[i] then out[#out + 1] = seps[i] end
	end
	return table.concat(out)
end

-- 近战／远程：只动括号里的附带效果，不动武器名
local function linkRiders(s)
	s = retarget(s)
	return (U.gsub(s, '([（(])([^（()）]*)([)）])', function(a, inner, b)
		if inner:find('[[', 1, true) then return nil end
		local items, seps = splitTop(inner)
		for i, it in ipairs(items) do
			-- 「1d6+4 附加 攫抓」「附带毒素」：从第一个非数字、非虚词处开始认
			local pre, word = U.match(it, '^([%s%dd+%-–×/x]*[附加外和及上带与並并]*%s*)(.*)$')
			if word and word ~= '' then
				local linked = linkHead(word, D.riders)
				if linked ~= word then items[i] = pre .. linked end
			end
		end
		return a .. joinBack(items, seps) .. b
	end))
end

function p.field(frame)
	local name, val = trim(frame.args[1]), frame.args[2] or ''
	if trim(val) == '' then return '' end
	if name == 'melee' or name == 'ranged' then return linkRiders(val) end
	local dict = D.fields[name]
	if not dict then return retarget(val) end
	local items, seps = splitTop(val)
	for i, it in ipairs(items) do items[i] = linkHead(it, D.terms[dict]) end
	return joinBack(items, seps)
end

function p.type(frame)
	local v = trim(frame.args[1])
	local t = D.types[v]
	if t then return link(t, v) end
	return retarget(v)
end

function p.subtypes(frame)
	local v = trim(frame.args[1])
	if v == '' then return '' end
	local out = {}
	for _, it in ipairs(mw.text.split(v, '%s*;%s*')) do
		it = trim(it)
		if it ~= '' then
			if it:find('[[', 1, true) then
				out[#out + 1] = retarget(it)
			else
				local key = U.gsub(it, '亚种$', '')
				local t = D.subtypes[key]
				out[#out + 1] = t and link(t, it) or it
			end
		end
	end
	return table.concat(out, '，')
end

function p.label(frame)
	local v = trim(frame.args[1])
	local t = D.labels[v]
	return t and link(t, v) or v
end

return p