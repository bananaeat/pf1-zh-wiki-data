-- 模块:宝藏生成器（2026-10-03）：[[宝藏生成器/在线生成]] 的页面骨架。
-- 全部表格数据（模块:宝藏生成器/数据，build/b_ue/ue_gen_build.py 生成）原样写进 .tg-app 里一个隐藏的 .tg-data（文字，不放属性：
-- 66 万字节的属性值超出解析器认标签的正则，整个 <div> 会被当成文字转义掉，2026-10-03 试过），
-- 界面和掷骰由 MediaWiki:TreasureGen.js 做（基石准则 4：内容在页里，脚本不另外请求）。
-- JSON 里的 [[ ]] { } | 也转成实体，免得解析器当成链接／模板。没开脚本时显示下面这段，指向各张表。
local p = {}

function p.main(frame)
	local data = require('Module:宝藏生成器/数据')
	local fallback = '<div class="tg-fallback">生成器需要浏览器开启 JavaScript。手动掷骰用的表：[[宝藏生成器]]（规则）、'
		.. '[[宝藏生成器/宝藏类型]]、[[宝藏生成器/随机护甲、武器与药水]]、[[宝藏生成器/随机卷轴]]、[[宝藏生成器/随机魔杖]]、'
		.. '[[宝藏生成器/随机魔法防具与武器]]、[[宝藏生成器/随机戒指、权杖与法杖]]、[[宝藏生成器/随机奇物]]、[[宝石与珠宝]]、[[艺术品]]。</div>'
	-- {{#invoke:宝藏生成器|main|mode=adv}}：[[高阶宝藏生成器]]，脚本多画权重和法术筛选两步；
	-- 法术筛选要的站上全部法术（模块:宝藏生成器/法术，build/b_ue/ue_spell_pool.py 生成）只在这一页写进 .tg-spells
	local adv = frame.args.mode == 'adv'
	local spells = ''
	if adv then
		spells = '<div class="tg-spells" style="display:none">'
			.. mw.text.encode(require('Module:宝藏生成器/法术'), "<>&\"'%[%]{}|") .. '</div>'
	end
	return '<div class="tg-app"' .. (adv and ' data-mode="adv"' or '') .. '>' .. fallback .. '<div class="tg-data" style="display:none">'
		.. mw.text.encode(data, "<>&\"'%[%]{}|") .. '</div>' .. spells .. '</div>'
end

return p