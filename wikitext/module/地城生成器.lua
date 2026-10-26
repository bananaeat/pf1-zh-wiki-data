-- 模块:地城生成器（2026-10-14）：[[地城生成器]] 的页面骨架。界面和生成都在 MediaWiki:DungeonGen.js。
-- 第二期（房间内容）要的数据原样写进页面里的隐藏文字（同宝藏、遭遇生成器，基石准则 4：脚本不另外请求）：
-- * .dg-mon：怪物，模块:遭遇生成器/数据（tools/build_encounter_data.py）
-- * .dg-trap：陷阱，模块:地城生成器/陷阱（tools/build_dungeon_data.py）
-- * .dg-npc、.dg-haunt：NPC 与作祟，模块:地城生成器/NPC、/作祟（tools/build_dungeon_data.py，2026-10-15）
-- * .dg-dress：房间陈设描述，模块:地城生成器/陈设（Gemini 撰写、Claude 校对事实错误，tools_archive/dungeon_dressing_build.py）
-- * 另放一个隐藏的 .tg-app（data-mode="lib"）装 模块:宝藏生成器/数据：Common.js 见到 .tg-app 会拉 TreasureGen.js，
--   它在 lib 模式下不画界面，只用 mw.hook('pf.treasure') 把掷宝藏的函数交给地城脚本。
-- JSON 里的 [[ ]] { } | 转成实体，免得解析器当成链接／模板。没开脚本时显示 fallback。
local p = {}

local function hidden(cls, data)
	return '<div class="' .. cls .. '" style="display:none">' .. mw.text.encode(data, "<>&\"'%[%]{}|") .. '</div>'
end

-- exp=1：[[实验性地城生成器]]（多层、高差、立体图，2026-10-15），同一个脚本按 data-exp 打开那组选项
function p.main(frame)
	local exp = frame.args.exp == '1'
	return '<div class="dg-app"' .. (exp and ' data-exp="1"' or '') .. '><div class="tg-fallback">生成器需要浏览器开启 JavaScript'
		.. (exp and '，立体图还需要支持 WebGL 的浏览器' or '') .. '。地城的门、墙、陷阱等规则见[[地下城]]和[[陷阱]]。</div>'
		.. hidden('dg-mon', require('Module:遭遇生成器/数据'))
		.. hidden('dg-trap', require('Module:地城生成器/陷阱'))
		.. hidden('dg-dress', require('Module:地城生成器/陈设'))
		.. hidden('dg-npc', require('Module:地城生成器/NPC'))
		.. hidden('dg-haunt', require('Module:地城生成器/作祟'))
		.. '</div><div class="tg-app" data-mode="lib" style="display:none">'
		.. hidden('tg-data', require('Module:宝藏生成器/数据')) .. '</div>'
end

return p