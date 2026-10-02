-- 模块:待办 —— 待办条目的卡片、列表页顶部的总览、首页和总入口的计数。
--
-- 条目就写在列表页 [[待办事项]] 的源码里（2026-09-30 起人类、AI 两张单子合成一张）：
--   == P0 · 马上做 ==
--   {{待办条目|标题=…|优先级=P0|规模=中|概要=…|背景=…|…}}
-- 本模块读列表页的源码（title:getContent()）把这些调用解析出来，所以：
--   * 卡片上的「认领」直接打开这一条所在小节的编辑框（按源码里的标题行数出小节号）；
--   * 总览、首页计数不用另存数据，改了列表页就跟着变。
-- 样式全写成行内 style：站点 CSS 被 CDN 缓 4 小时，行内的改了立刻生效。

local p = {}

local TPL = '待办条目'
local LIST = '待办事项'

local PRI = {
	P0 = { name = 'P0', label = '马上做', fg = '#a8322d', bg = '#fbeceb' },
	P1 = { name = 'P1', label = '该做', fg = '#9a6412', bg = '#fbf2e2' },
	P2 = { name = 'P2', label = '有空再做', fg = '#4f6479', bg = '#edf1f5' },
}
local SIZE = {
	['大'] = { bars = 3, hint = '要拆成几步、多次做完' },
	['中'] = { bars = 2, hint = '一次能做完' },
	['小'] = { bars = 1, hint = '半小时以内' },
}
-- AI 加的条目必须写全的几栏
local REQUIRED_AI = { '背景', '现状', '做法', '验收' }
local FIELDS = { '背景', '现状', '范围', '做法', '验收', '参考' }

local function trim(s) return s and mw.text.trim(s) or '' end
local function blank(s) return trim(s) == '' end

-- ------------------------------------------------------------ 解析列表页源码

-- 把 text 里所有 {{待办条目|…}} 找出来：{ pos = 起点字节, args = {参数} }
local function findCalls(text)
	local out, i = {}, 1
	while true do
		local a = text:find('{{%s*' .. TPL, i)
		if not a then break end
		local depth, j, n = 0, a, #text
		while j <= n do
			local two = text:sub(j, j + 1)
			if two == '{{' then depth = depth + 1; j = j + 2
			elseif two == '}}' then
				depth = depth - 1; j = j + 2
				if depth == 0 then break end
			else j = j + 1 end
		end
		local body = text:sub(a + 2, j - 3)
		local parts, buf, d1, d2, k = {}, {}, 0, 0, 1
		while k <= #body do
			local two = body:sub(k, k + 1)
			if two == '{{' then d1 = d1 + 1; buf[#buf + 1] = two; k = k + 2
			elseif two == '}}' then d1 = d1 - 1; buf[#buf + 1] = two; k = k + 2
			elseif two == '[[' then d2 = d2 + 1; buf[#buf + 1] = two; k = k + 2
			elseif two == ']]' then d2 = d2 - 1; buf[#buf + 1] = two; k = k + 2
			else
				local c = body:sub(k, k)
				if c == '|' and d1 == 0 and d2 == 0 then
					parts[#parts + 1] = table.concat(buf); buf = {}
				else buf[#buf + 1] = c end
				k = k + 1
			end
		end
		parts[#parts + 1] = table.concat(buf)
		local args = {}
		for idx = 2, #parts do
			local key, val = parts[idx]:match('^%s*([^=]-)%s*=(.*)$')
			-- 预填骨架里的提示写在注释里，渲染时模板参数看不到注释，这里也得剥掉，两边才对得上
			if key then args[trim(key)] = trim((val:gsub('<!%-%-.-%-%->', ''))) end
		end
		out[#out + 1] = { pos = a, args = args }
		i = j
	end
	return out
end

-- 源码里 pos 之前有几个标题行 = 这一条所在小节的编号（0 是页顶）
local function sectionAt(text, pos)
	local n, start = 0, 1
	while start <= pos do
		local e = text:find('\n', start, true) or (#text + 1)
		local line = text:sub(start, e - 1)
		if line:match('^=+.+=+%s*$') and line:sub(1, 1) == '=' then n = n + 1 end
		start = e + 1
	end
	return n
end

local function status(a)
	local s = trim(a['状态'])
	if s ~= '' then return s end
	if not blank(a['认领']) then return '进行中' end
	return '待认领'
end

-- 标题里要是写了链接、粗体，锚点和目录里只用字面
local function plain(s)
	s = (s or ''):gsub('%[%[[^%]|]*|([^%]]*)%]%]', '%1'):gsub('%[%[([^%]]*)%]%]', '%1')
	s = s:gsub("'''?", ''):gsub('<[^>]+>', '')
	return trim(s)
end

local function anchor(title) return '待办-' .. plain(title) end

-- 栏里的内容：以列表、缩进、表格开头的前面得换行才认得出来；别的不换行，
-- 否则 MediaWiki 会把它包成一个新段落，和栏名错开一行
local function val(v)
	v = trim(v)
	if v:match('^[%*#:;]') or v:match('^{|') then return '\n' .. v .. '\n' end
	return v
end

-- ------------------------------------------------------------ 小零件

local function chipPri(pr)
	local c = PRI[pr] or PRI.P2
	return mw.html.create('span'):attr('title', c.label)
		:css({ display = 'inline-block', padding = '0 .45em', ['border-radius'] = '3px',
			background = c.fg, color = '#fff', ['font-weight'] = '700', ['font-size'] = '.8em',
			['line-height'] = '1.6', ['letter-spacing'] = '.03em' })
		:wikitext(c.name)
end

local function chipSize(sz)
	local s = SIZE[sz] or SIZE['中']
	local wrap = mw.html.create('span'):attr('title', (sz or '中') .. '：' .. s.hint)
		:css({ display = 'inline-flex', ['align-items'] = 'center', gap = '2px', padding = '0 .4em',
			border = '1px solid #cfc6b8', ['border-radius'] = '3px', ['font-size'] = '.8em',
			['line-height'] = '1.5', color = '#5c5348', background = '#fff' })
	for k = 1, 3 do
		wrap:tag('span'):css({ display = 'inline-block', width = '4px', height = (4 + k * 3) .. 'px',
			background = (k <= s.bars) and '#5c5348' or '#ddd5c9', ['border-radius'] = '1px' })
	end
	wrap:tag('span'):css('margin-left', '3px'):wikitext(sz or '中')
	return wrap
end

local function chipStatus(a, editUrl)
	local st = status(a)
	-- plainlinks：「认领」是外链写法（编辑地址），去掉皮肤加的外链小箭头
	local box = mw.html.create('span'):addClass('plainlinks'):css({ ['margin-left'] = 'auto', ['font-size'] = '.85em',
		['white-space'] = 'nowrap' })
	if st == '待认领' then
		box:wikitext(string.format('[%s <span style="display:inline-block;padding:0 .6em;border:1px solid #3f7a4f;border-radius:3px;color:#3f7a4f;font-weight:600">认领</span>]', editUrl))
	elseif st == '已完成' then
		box:tag('span'):css({ color = '#3f7a4f', ['font-weight'] = '600' }):wikitext('✓ 已完成')
	else
		local who = trim(a['认领'])
		local when = trim(a['认领日期'])
		box:tag('span'):css({ color = (st == '搁置') and '#8a8175' or '#2f5f8a', ['font-weight'] = '600' })
			:wikitext(st)
		if who ~= '' then
			box:tag('span'):css('color', '#5c5348'):wikitext(' · ' .. who .. (when ~= '' and (' · ' .. when) or ''))
		end
	end
	return box
end

-- 子项：「* [x] 做完的」「* [ ] 没做的」-> 勾选框 + 进度
local function subtasks(text)
	local done, total, items = 0, 0, {}
	for line in (text .. '\n'):gmatch('([^\n]*)\n') do
		local mark, rest = line:match('^%*%s*%[([ xX✓]?)%]%s*(.*)$')
		if mark then
			total = total + 1
			local ok = (mark ~= '' and mark ~= ' ')
			if ok then done = done + 1 end
			items[#items + 1] = { ok = ok, text = rest }
		elseif trim(line) ~= '' then
			items[#items + 1] = { text = trim(line:gsub('^%*%s*', '')) }
		end
	end
	return items, done, total
end

-- ------------------------------------------------------------ 卡片

local function missingContext(a)
	-- 「添加」以 AI 开头的才算 AI 加的（人名里碰巧带 AI 的不算）
	if not tostring(a['添加'] or ''):match('^%s*AI') then return {} end
	local miss = {}
	for _, f in ipairs(REQUIRED_AI) do
		if blank(a[f]) then miss[#miss + 1] = f end
	end
	return miss
end

local function renderCard(a, editUrl)
	local title = trim(a['标题'])
	local pr = PRI[trim(a['优先级'])] and trim(a['优先级']) or 'P2'
	local sz = SIZE[trim(a['规模'])] and trim(a['规模']) or '中'
	local c = PRI[pr]
	local st = status(a)
	local small = (sz == '小')
	local card = mw.html.create('div'):addClass('todo-card'):attr('id', anchor(title))
		:attr('data-pri', pr):attr('data-size', sz):attr('data-status', st)
		:css({ margin = small and '.35em 0' or '.7em 0', padding = small and '.4em .75em' or '.7em .95em',
			border = '1px solid #e2dbcf', ['border-left'] = (small and '3px' or '5px') .. ' solid ' .. c.fg,
			['border-radius'] = '5px', background = (st == '已完成') and '#f4f7f3' or '#fffdf9' })
	if sz == '大' then card:css('box-shadow', '0 1px 3px rgba(60,45,20,.12)') end

	local head = card:tag('div'):css({ display = 'flex', ['flex-wrap'] = 'wrap', ['align-items'] = 'center',
		gap = '.45em' })
	head:tag('span'):css({ flex = 'none', display = 'inline-flex', gap = '.35em', ['align-items'] = 'center' })
		:node(chipPri(pr)):node(chipSize(sz))
	head:tag('span'):css({ flex = '1 1 12em', ['min-width'] = '0', ['font-weight'] = '700',
		['font-size'] = small and '1em' or '1.08em', color = '#2f2a23',
		['text-decoration'] = (st == '已完成') and 'line-through' or nil })
		:wikitext(title)
	if not blank(a['阻塞']) then
		head:tag('span'):css({ ['font-size'] = '.78em', padding = '0 .4em', ['border-radius'] = '3px',
			background = '#f1e7d6', color = '#7a5a21' }):wikitext('卡在：' .. trim(a['阻塞']))
	end
	local miss = missingContext(a)
	if #miss > 0 then
		head:tag('span'):css({ ['font-size'] = '.78em', padding = '0 .4em', ['border-radius'] = '3px',
			background = '#a8322d', color = '#fff' }):wikitext('背景不全：缺' .. table.concat(miss, '、'))
	end
	head:node(chipStatus(a, editUrl))

	if not blank(a['概要']) then
		card:tag('div'):css({ margin = small and '.2em 0 0' or '.4em 0 .1em', color = '#3b352d' })
			:wikitext(val(a['概要']))
	end

	-- 背景这几栏：大、中条目排成两列（栏名｜内容），小条目收成一段小字
	local rows = {}
	for _, f in ipairs(FIELDS) do
		if not blank(a[f]) then rows[#rows + 1] = { f, trim(a[f]) } end
	end
	if #rows > 0 then
		if small then
			local box = card:tag('div'):css({ ['font-size'] = '.86em', color = '#5c5348', margin = '.2em 0 0' })
			for _, r in ipairs(rows) do
				box:tag('div'):css('margin', '.1em 0'):tag('b'):css('color', '#8a6d3b'):wikitext(r[1] .. '　'):done()
					:wikitext(val(r[2]))
			end
		else
			-- 行内 style 里的 minmax()／repeat() 会被站点滤掉，只能写死两列
			local grid = card:tag('div'):css({ display = 'grid', ['grid-template-columns'] = '3.2em 1fr',
				gap = '.3em .8em', margin = '.55em 0 .1em', ['font-size'] = '.93em', ['line-height'] = '1.65' })
			for _, r in ipairs(rows) do
				grid:tag('div'):css({ color = '#8a6d3b', ['font-weight'] = '700', ['padding-top'] = '.05em' })
					:wikitext(r[1])
				grid:tag('div'):css({ ['min-width'] = '0', ['overflow-wrap'] = 'anywhere' })
					:wikitext(val(r[2]))
			end
		end
	end

	if not blank(a['子项']) then
		local items, done, total = subtasks(a['子项'])
		local box = card:tag('div'):css({ margin = '.6em 0 .1em', padding = '.5em .7em',
			background = '#f7f2ea', ['border-radius'] = '4px', ['font-size'] = '.93em' })
		local hd = box:tag('div'):css({ display = 'flex', ['align-items'] = 'center', gap = '.6em',
			['margin-bottom'] = '.3em', ['font-weight'] = '700', color = '#5c5348' })
		hd:wikitext('拆成几步')
		if total > 0 then
			hd:tag('span'):css({ flex = '1', ['max-width'] = '12em', height = '6px', background = '#e2d8c8',
				['border-radius'] = '3px', overflow = 'hidden' })
				:tag('span'):css({ display = 'block', height = '100%', width = math.floor(done * 100 / total) .. '%',
					background = '#3f7a4f' })
			hd:tag('span'):css({ ['font-weight'] = '400', ['font-size'] = '.9em' })
				:wikitext(done .. ' / ' .. total)
		end
		for _, it in ipairs(items) do
			local row = box:tag('div'):css({ display = 'flex', gap = '.45em', margin = '.15em 0' })
			row:tag('span'):css({ color = it.ok and '#3f7a4f' or '#b3a896', ['flex'] = 'none' })
				:wikitext(it.ok == nil and '·' or (it.ok and '☑' or '☐'))
			row:tag('span'):css({ color = it.ok and '#8a8175' or nil, ['text-decoration'] = it.ok and 'line-through' or nil })
				:wikitext(it.text)
		end
	end

	local foot = {}
	if not blank(a['添加']) then foot[#foot + 1] = '添加：' .. trim(a['添加']) .. (blank(a['添加日期']) and '' or (' · ' .. trim(a['添加日期']))) end
	if #foot > 0 then
		card:tag('div'):css({ margin = '.45em 0 0', ['font-size'] = '.78em', color = '#9a9083' })
			:wikitext(table.concat(foot, '　'))
	end
	return card, miss
end

-- {{待办条目|…}} 调这个
function p.card(frame)
	local a = frame:getParent().args
	local here = mw.title.getCurrentTitle()
	local text = here:getContent() or ''
	local sec = 0
	local want = trim(a['标题'])
	for _, call in ipairs(findCalls(text)) do
		if trim(call.args['标题']) == want then sec = sectionAt(text, call.pos); break end
	end
	local url = here:fullUrl(sec > 0 and { action = 'edit', section = sec } or { action = 'edit' })
	local card, miss = renderCard(a, url)
	local out = tostring(card)
	if #miss > 0 and here.namespace == 0 then out = out .. '[[分类:待办背景不全]]' end
	return out
end

-- ------------------------------------------------------------ 列表页顶部的总览

local function collect(pageName)
	local t = mw.title.new(pageName)
	local text = t and t:getContent() or ''
	local items = {}
	for n, call in ipairs(findCalls(text)) do
		local a = call.args
		items[#items + 1] = { n = n, title = plain(a['标题']), pri = PRI[trim(a['优先级'])] and trim(a['优先级']) or 'P2',
			size = SIZE[trim(a['规模'])] and trim(a['规模']) or '中', status = status(a), who = trim(a['认领']),
			sum = trim(a['概要']) }
	end
	return items, t
end

local function counts(items)
	local c = { P0 = 0, P1 = 0, P2 = 0, open = 0, doing = 0, done = 0 }
	for _, it in ipairs(items) do
		if it.status ~= '已完成' then
			c[it.pri] = c[it.pri] + 1
			if it.status == '待认领' then c.open = c.open + 1 else c.doing = c.doing + 1 end
		else c.done = c.done + 1 end
	end
	return c
end

function p.summary(frame)
	local page = trim(frame.args[1])
	local items, t = collect(page ~= '' and page or mw.title.getCurrentTitle().prefixedText)
	local c = counts(items)
	local box = mw.html.create('div'):css({ margin = '.4em 0 1em', padding = '.7em .9em',
		border = '1px solid #e2dbcf', ['border-radius'] = '6px', background = '#faf6ef' })
	local top = box:tag('div'):css({ display = 'flex', ['flex-wrap'] = 'wrap', gap = '.4em 1.2em',
		['align-items'] = 'baseline', ['margin-bottom'] = '.5em' })
	for _, pr in ipairs({ 'P0', 'P1', 'P2' }) do
		local s = top:tag('span')
		s:node(chipPri(pr))
		s:tag('span'):css({ ['font-size'] = '1.25em', ['font-weight'] = '700', margin = '0 .15em 0 .35em',
			color = PRI[pr].fg }):wikitext(c[pr])
		s:tag('span'):css({ color = '#8a8175', ['font-size'] = '.85em' }):wikitext(PRI[pr].label)
	end
	top:tag('span'):css({ ['margin-left'] = 'auto', color = '#5c5348', ['font-size'] = '.9em' })
		:wikitext(string.format('待认领 <b>%d</b> · 进行中 <b>%d</b>', c.open, c.doing))
	-- 按优先级、再按规模（大在前）排的一张目录
	local order = { P0 = 0, P1 = 1, P2 = 2 }
	local sorder = { ['大'] = 0, ['中'] = 1, ['小'] = 2 }
	table.sort(items, function(x, y)
		if order[x.pri] ~= order[y.pri] then return order[x.pri] < order[y.pri] end
		if sorder[x.size] ~= sorder[y.size] then return sorder[x.size] < sorder[y.size] end
		return x.n < y.n
	end)
	local list = box:tag('div'):css({ display = 'flex', ['flex-direction'] = 'column', gap = '.2em' })
	for _, it in ipairs(items) do
		if it.status ~= '已完成' then
			-- 标签不换行，标题在标签右边自己折行（手机上不会整行掉到下一行）
			local row = list:tag('div'):css({ display = 'flex', ['align-items'] = 'baseline',
				gap = '.4em', ['font-size'] = '.92em' })
			row:tag('span'):css({ flex = 'none', display = 'inline-flex', gap = '.3em', ['align-items'] = 'center' })
				:node(chipPri(it.pri)):node(chipSize(it.size))
			local t = row:tag('span'):css({ flex = '1 1 auto', ['min-width'] = '0' })
			t:wikitext(string.format('[[#%s|%s]]', anchor(it.title), it.title))
			if it.status ~= '待认领' then
				t:tag('span'):css({ color = '#2f5f8a', ['font-size'] = '.9em', ['margin-left'] = '.4em' })
					:wikitext(it.status .. (it.who ~= '' and (' · ' .. it.who) or ''))
			end
		end
	end
	return tostring(box)
end

-- ------------------------------------------------------------ 「加一条」按钮

-- 加一条：打开列表页「新段落」的编辑框，预填骨架（模板:待办条目/新条目），
-- 写一句话就能保存；新条目落在页尾「新条目（待分级）」一节，接手的人（或 AI）补齐四栏再挪进对应优先级。
local PRELOAD = '模板:待办条目/新条目'
local NEW_SECTION = '新条目（待分级）'

local function addButton(page, label, small)
	local t = mw.title.new(page)
	if not t then return '' end
	local url = t:fullUrl({ action = 'edit', section = 'new', preload = PRELOAD, preloadtitle = NEW_SECTION })
	return string.format('<span class="plainlinks">[%s <span style="display:inline-block;padding:%s;'
		.. 'border-radius:4px;background:#3f7a4f;color:#fff;font-weight:600;white-space:nowrap%s">%s</span>]</span>',
		url, small and '0 .55em' or '.2em .9em', small and ';font-size:.9em' or '', label)
end

function p.add(frame)
	local page = trim(frame.args[1]) ~= '' and trim(frame.args[1]) or LIST
	local label = trim(frame.args['文字']) ~= '' and trim(frame.args['文字']) or '＋ 加一条待办'
	return addButton(page, label, trim(frame.args['小']) ~= '')
end

-- ------------------------------------------------------------ 首页右栏：一行计数
-- 「加一条」按钮放在首页那一块的标题行里（{{#invoke:待办|add|小=1}}），这里只出一行，右栏越矮，左边的抽屉越不空

local function countRow(page, label)
	local c = counts(collect(page))
	local row = mw.html.create('div'):css({ display = 'flex', ['align-items'] = 'center', gap = '.5em',
		padding = '.3em 0', ['border-bottom'] = '1px dotted #e0d8ca', ['font-size'] = '.92em' })
	row:tag('span'):css({ ['font-weight'] = '600', ['white-space'] = 'nowrap' })
		:wikitext(string.format('[[%s|%s]]', page, label))
	local cs = row:tag('span'):css({ ['margin-left'] = 'auto', display = 'inline-flex', gap = '.5em',
		['align-items'] = 'center' })
	for _, pr in ipairs({ 'P0', 'P1', 'P2' }) do
		local s = cs:tag('span'):css({ display = 'inline-flex', ['align-items'] = 'center', gap = '.2em' })
		s:node(chipPri(pr))
		s:tag('span'):css({ ['font-weight'] = '700', ['font-variant-numeric'] = 'tabular-nums',
			color = (c[pr] > 0) and PRI[pr].fg or '#b3a896' }):wikitext(c[pr])
	end
	return row, c
end

function p.rail(frame)
	local page = trim(frame.args[1]) ~= '' and trim(frame.args[1]) or LIST
	local row, c = countRow(page, '全部待办')
	local box = mw.html.create('div'):node(row)
	box:tag('div'):css({ ['font-size'] = '.82em', color = '#8a8175', padding = '.2em 0' })
		:wikitext(string.format('待认领 %d · 进行中 %d', c.open, c.doing))
	return tostring(box)
end

-- 旧的总入口牌子（两张单子各一块）；合成一张后只剩一块，留着给还在调它的页
function p.entry(frame)
	return p.rail(frame)
end

return p