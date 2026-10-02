# 开拓者 1 版中文维基数据（pf1-zh-wiki-data）

[开拓者1版中文维基](https://pf1.huijiwiki.com/)（Pathfinder 1st Edition，灰机 wiki）的内容导出：每类条目的结构化 JSON、站上的速查数据表，以及全部页面的 wikitext 源码。给想做离线速查、角色卡、骰子机器人之类工具的同好用。

快照时间见 [`SNAPSHOT`](SNAPSHOT)（UTC）。数据以原站为准；发现错漏请到原站改，或在本仓库提 issue。

## 目录

| 路径 | 内容 |
|---|---|
| `data/entries/<类型>.json` | 条目卡片的全部字段，一类一个文件（见下表） |
| `data/tables/<表>.json` | 站上速查页用的数据表（法术、专长、怪物、物品、神祇……），已经是扁平的对象数组 |
| `wikitext/main/` | 主命名空间每页一个 `.wiki` 文件（不含重定向） |
| `wikitext/redirects.json` | 重定向：`{"来源页": "目标页"}` |
| `wikitext/template/`、`wikitext/module/` | 模板源码、Lua 模块源码 |
| `index.json` | 全部页面：标题、文件路径、条目类型、是否含 AI 翻译、分类 |
| `docs/FIELDS.md` | 各类条目的字段一览（字段名、出现次数、示例） |

### 条目类型

| 文件 | 卡片模板 | 内容 |
|---|---|---|
| `spells.json` | Spell | 法术 |
| `feats.json` | Feat | 专长 |
| `traits.json` | Trait | 背景特性 |
| `creatures.json` | 怪物 | 怪物和 NPC 属性块（一页可有多块，每块一条） |
| `creature_templates.json` | 怪物模板 | 生物模板 |
| `creature_lore.json` | 怪物绪论 | 怪物族群绪论 |
| `magic_items.json` | 魔法物品 | 魔法物品、武器／防具附魔、神器等 |
| `equipment.json` | 装备 | 冒险装备、炼金物品等 |
| `weapons.json`、`armor.json` | 武器、防具 | 普通武器、防具 |
| `items_misc.json` | 物品 | 旧式物品卡片 |
| `technology.json` | 科技物品 | 科技指南的科技物品 |
| `hazards.json` | 危害 | 毒药、疾病、诅咒、陷阱、作祟等 |
| `deities.json` | 神祇 | 神祇 |
| `classes.json` | Class | 基础、混合、异能、进阶职业等的职业卡片 |
| `rage_powers.json` | 狂暴之力 | 狂暴之力 |
| `rituals.json` | 仪式 | 仪式 |
| `races.json` | 种族卡 | 种族 |
| `masterpieces.json` | 传世名作 | 传世名作 |
| `books.json` | 书页 | 书目 |
| `animal_companions.json` | 动物伙伴卡片 | 动物伙伴 |
| `familiar_archetypes.json` | 魔宠变体 | 魔宠变体 |

职业的等级表和职业特性、变体职业、规则页等没有卡片的内容只在 `wikitext/main/` 里。

### 条目格式

```json
{
  "title": "火球术",
  "url": "https://pf1.huijiwiki.com/wiki/火球术",
  "template": "Spell",
  "ai": false,
  "categories": ["塑能系法术", "法术"],
  "raw":  { "name": "火球术", "english_name": "Fireball", "description": "……[[接触攻击]]……" },
  "text": { "name": "火球术", "english_name": "Fireball", "description": "……接触攻击……" }
}
```

- `raw`：卡片参数的 wikitext 原样（链接、加粗、内嵌模板都在）。
- `text`：自动转成的纯文本（去掉链接方括号和标记，内嵌模板展开成文字）。转换是机械的，有疑问以 `raw` 为准。
- `ai`：这一条有 AI 翻译的内容（站上挂了「AI 翻译」标注的：民间汉化里没有现成译文、由 AI 照英文原文译出、未经人工校对）。
- `categories`：页面所在的分类（含模板自动加的）。
- 字段名的含义见各模板的说明：`wikitext/template/<模板名>.wiki`。

### 文件名

页面标题里 Windows 不允许的字符在文件名中转义：`\` → `_0_`、`/` → `_1_`、`:` → `_2_`、`*` → `_3_`、`"` → `_4_`、`?` → `_5_`、`<` → `_6_`、`>` → `_7_`、`|` → `_8_`。`index.json` 里有标题和文件的对应。

### 已知限制

- 站上不少模板用了灰机平台特有的 Lua 数据接口（`mw.huiji.db`），在普通 MediaWiki 上不能原样渲染；wikitext 适合当原始材料解析，不适合直接搭镜像站。
- 不含：用户页、站务待办页、图片。

## 许可与来源

- 本站文字：[知识共享 署名-相同方式共享 4.0](https://creativecommons.org/licenses/by-sa/4.0/)（CC BY-SA，全文见 [`LICENSE`](LICENSE)）。再分发请署名「开拓者1版中文维基」并附原站链接，衍生作品沿用同一许可。各页贡献者见原站页面历史。
- 规则内容：Paizo 的开放游戏内容依 [开放游戏许可 1.0a](OGL.txt) 使用；神名、地名、人物等产品标识依 Paizo 社区使用政策使用，见 [`NOTICE.md`](NOTICE.md)。**只限免费、非商业用途。**
- 译文来源：大量译文来自民间汉化 CHM（[pf1chm.pages.dev](https://pf1chm.pages.dev/)），感谢各位译者；规则原文对照 [Archives of Nethys](https://aonprd.com/)；书目简介译自 [PathfinderWiki](https://pathfinderwiki.com/)（CC BY-SA）。
