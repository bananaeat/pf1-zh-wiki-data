-- 模块:法术书生成器（2026-10-15）：[[法术书生成器]] 的页面骨架。源文件在仓库 design/spellbook_gen.lua。
-- 法术数据（模块:法术书生成器/数据，tools/build_spellbook_data.py 由 Data:法术 生成）原样写进 .sb-app 里隐藏的 .sb-data（文字），
-- 界面和掷骰由 MediaWiki:SpellbookGen.js 做（基石准则 4：内容在页里，脚本不另外请求）。JSON 里的 [[ ]] { } | 转成实体。
local p = {}

function p.main(frame)
	local data = require('Module:法术书生成器/数据')
	local fallback = '<div class="tg-fallback">生成器需要浏览器开启 JavaScript。手动挑法术见[[法术速查]]，抄写费用见[[魔法]]。</div>'
	return '<div class="sb-app">' .. fallback .. '<div class="sb-data" style="display:none">'
		.. mw.text.encode(data, "<>&\"'%[%]{}|") .. '</div></div>'
end

return p