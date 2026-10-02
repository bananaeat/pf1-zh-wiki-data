-- 卡片抬头英文名的 Archives of Nethys（AoN）原文链接（用户 2026-09-22 选的方案 C：英文名本身就是链接）。
-- 法术、专长、背景特性这几种对不上的少，用模板参数 aon= 管（模板:AoN链接）；
-- 怪物／NPC 名字多、写法和 AoN 差得远（站上是图鉴索引的倒装：Archon, Shield），对照表放在 模块:AoN链接/怪物。
-- 物品按类别走不同的 AoN 页，对照表放在 模块:AoN链接/物品/*。
-- 职业、神祇、仪式各有一张 AoN 列表页，对照表放在 模块:AoN链接/职业、/神祇、/仪式（named）。
-- 技能页按页名查 模块:AoN链接/技能（skill）。
local p = {}

local function link(page, name, text)
	return '[https://www.aonprd.com/' .. page .. '.aspx?ItemName=' .. mw.uri.encode(name, 'PATH') .. ' ' .. text .. ']'
end

-- {{#invoke:AoN链接|monster|英文名|npc 参数|aon=…}}
function p.monster(frame)
	local args = frame.args
	local en = mw.text.trim(args[1] or '')
	if en == '' then
		return ''
	end
	local npc = mw.text.trim(args[2] or '') ~= ''
	local page = npc and 'NPCDisplay' or 'MonsterDisplay'
	local aon = mw.text.trim(args.aon or '')
	if aon == '无' then
		return en
	elseif aon ~= '' then
		return link(page, aon, en)
	end
	local v = mw.loadData('模块:AoN链接/怪物')[(npc and 'N|' or 'M|') .. en]
	if v == '无' then
		return en
	elseif v then
		return link(v[1], v[2], en)
	end
	return link(page, en, en)
end

-- 物品：{{#invoke:AoN链接|item|英文名|aon=…}}
-- AoN 的物品按类别走不同的页、参数名也不一样，所以对照表里存的是 AoN 列表页上的原始链接（已编码），
-- 键是英文名的归一化写法（小写、只留字母和数字），按首字符分放在 模块:AoN链接/物品/a … /z、/0
-- （tools/build_item_aon_module.py 生成）。aon= 写一条原始链接（…Display.aspx?…）就用它，写「无」不挂。
function p.item(frame)
	local args = frame.args
	local en = mw.text.trim(args[1] or '')
	if en == '' then
		return ''
	end
	local aon = mw.text.trim(args.aon or '')
	if aon == '无' then
		return en
	elseif aon ~= '' then
		return '[https://www.aonprd.com/' .. aon .. ' ' .. en .. ']'
	end
	local key = (mw.ustring.lower(en):gsub('[^%w]', ''))
	if key == '' then
		return en
	end
	local first = key:sub(1, 1)
	if not first:match('%a') then
		first = '0'
	end
	local ok, data = pcall(mw.loadData, '模块:AoN链接/物品/' .. first)
	local href = ok and data[key]
	-- 站上常在神器名前加 The（The Shadowstaff），AoN 不加：查不到就去掉再查一次
	if not href and key:sub(1, 3) == 'the' and #key > 3 then
		local k2 = key:sub(4)
		local f2 = k2:sub(1, 1)
		if not f2:match('%a') then
			f2 = '0'
		end
		local ok2, data2 = pcall(mw.loadData, '模块:AoN链接/物品/' .. f2)
		href = ok2 and data2[k2]
	end
	if href then
		return '[https://www.aonprd.com/' .. href .. ' ' .. en .. ']'
	end
	return en
end

-- 职业、神祇、仪式：{{#invoke:AoN链接|named|职业|英文名|aon=…}}
-- 对照表 模块:AoN链接/<类> 存 AoN 列表页上的原始链接（已编码），键和物品一样：小写、只留字母和数字
-- （tools/build_aon_named_modules.py 生成；AoN 名字带 The 的、掉链职业的两种写法都做了键）。
-- aon= 写一条已编码的原始链接（DeityDisplay.aspx?ItemName=…）就用它，写「无」不挂。
function p.named(frame)
	local args = frame.args
	local kind = mw.text.trim(args[1] or '')
	local en = mw.text.trim(args[2] or '')
	if en == '' then
		return ''
	end
	local aon = mw.text.trim(args.aon or '')
	if aon == '无' then
		return en
	elseif aon ~= '' then
		return '[https://www.aonprd.com/' .. aon .. ' ' .. en .. ']'
	end
	local key = (mw.ustring.lower(en):gsub('[^%w]', ''))
	local ok, data = pcall(mw.loadData, '模块:AoN链接/' .. kind)
	local href = ok and key ~= '' and data[key]
	if href then
		return '[https://www.aonprd.com/' .. href .. ' ' .. en .. ']'
	end
	return en
end

-- 技能页：{{#invoke:AoN链接|skill|{{PAGENAME}}}}，{{技能头}} 用。
-- 技能页没有卡片、也没写英文名，按站上页名查 模块:AoN链接/技能（{AoN 技能名, 原始链接}），
-- 挂成技能条最右边一格斜体英文名；查不到就什么都不出。样式写行内（站点 CSS 有缓存）。
function p.skill(frame)
	local page = mw.text.trim(frame.args[1] or '')
	local ok, data = pcall(mw.loadData, '模块:AoN链接/技能')
	local v = ok and page ~= '' and data[page]
	if not v then
		return ''
	end
	return '<span class="sk-en" style="margin-left:auto;font-style:italic;font-size:.92em">'
		.. '[https://www.aonprd.com/' .. v[2] .. ' ' .. v[1] .. ']</span>'
end

return p