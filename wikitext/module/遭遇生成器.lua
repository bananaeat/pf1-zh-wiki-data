-- 模块:遭遇生成器（2026-10-14）：[[遭遇生成器]] 的页面骨架。
-- 怪物数据（模块:遭遇生成器/数据，tools/build_encounter_data.py 由 Data:Monsters 生成）原样写进 .eg-app 里隐藏的 .eg-data（文字，
-- 不放属性：大属性值会被解析器当文字转义，同宝藏生成器），界面和掷骰由 MediaWiki:EncounterGen.js 做（基石准则 4：内容在页里，
-- 脚本不另外请求）。JSON 里的 [[ ]] { } | 转成实体，免得解析器当成链接／模板。没开脚本时显示 fallback。
local p = {}

function p.main(frame)
	local data = require('Module:遭遇生成器/数据')
	local fallback = '<div class="tg-fallback">生成器需要浏览器开启 JavaScript。手动设计遭遇见[[游戏掌控]]（设计遭遇、表 12–1 与 12–2），'
		.. '怪物按挑战等级和环境查[[怪物速查]]。</div>'
	return '<div class="eg-app">' .. fallback .. '<div class="eg-data" style="display:none">'
		.. mw.text.encode(data, "<>&\"'%[%]{}|") .. '</div></div>'
end

return p