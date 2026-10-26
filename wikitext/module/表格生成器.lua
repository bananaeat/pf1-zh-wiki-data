-- 模块:表格生成器（2026-10-15）：表格类生成器的页面骨架。源文件在仓库 design/table_gen.lua。
-- {{#invoke:表格生成器|main|mode=bg|wx|set|trap}}：把 模块:表格生成器/数据/<mode>（tools/build_tablegen_data.py 由站上规则页的随机表拆成）
-- 原样写进 .xg-app 里隐藏的 .xg-data（文字），界面和掷骰由 MediaWiki:TableGen.js 做（基石准则 4：内容在页里，脚本不另外请求）。
local p = {}

local FALLBACK = {
	bg = '手动掷骰见[[角色背景生成器]]。',
	wx = '手动掷骰见[[荒野天气]]、[[天气]]。',
	set = '手动设计见[[定居点]]、[[酒馆]]。',
	trap = '手动计算见[[陷阱#设计陷阱|设计陷阱]]。',
}

function p.main(frame)
	local mode = frame.args.mode or 'bg'
	local data = require('Module:表格生成器/数据/' .. mode)
	return '<div class="xg-app" data-mode="' .. mode .. '"><div class="tg-fallback">生成器需要浏览器开启 JavaScript。'
		.. (FALLBACK[mode] or '') .. '</div><div class="xg-data" style="display:none">'
		.. mw.text.encode(data, "<>&\"'%[%]{}|") .. '</div></div>'
end

return p