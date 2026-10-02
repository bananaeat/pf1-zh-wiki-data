local p = {}
local OrderedTable = require('Module:OrderedTable')
------------------------------------------------------
-------------------SMongo v0.1.13----------------------
-----------Semantic-Style MongoDB Query---------------
------------------------------------------------------
local getArgs = require('Module:Arguments').getArgs
------------------------------------------------------
function p._ask(frame)
	local args = getArgs(frame)
	local template_args_debug = {}
	local namedArgs_debug = 'unkown'
	local q_string = mw.text.split(args['query'],';')
	local c_string = ''
    local query, options = {}, {}
	local scode1, scode2 = '0' ,'0'
    local res = ''
    local addClass = args['class'] or ''
	------------------import data table and schema------------------
	local schema_table = {}
	if args['table'] then
		-------------------方法1-------------------------
		-------读取指定tab/tabx文件的schema确定字段类型
		local db_title = mw.title.makeTitle('Data', args['table'])
		local json = mw.text.jsonDecode(db_title:getContent())
		schema_table = json['schema']['fields']
		------指定的table查询----
		query['_id'] = {
			 ["$regex"] = 'Data:'..args['table']..'\#.*',
		}
	else
		--------------------方法2----------------------
		-------使用在query/data的'schema'确定字段类型
		local json = mw.loadData('module:Query/data')
		schema_table = json['schema']
	end
		------------------ Query--------------------
		for i,v in ipairs(q_string) do
			c_string = mw.text.split(v,'::')
            if #c_string == 2 then
            local c_1 = mw.ustring.sub(c_string[2],1,1)
            local c_2 = c_string[2]
            local special_enums = {
	        	['!'] = 'not',
	        	['+'] = 'any',
	        	['>'] = 'gt',
	        	['<'] = 'lt',
	        	['@'] = 'regex',
	        	['~'] = 'not exist',
	        	['&'] = 'between',
	        }
                if special_enums[c_1] then
                ------------处理特殊的查询条件-----------------
                    c_2 = mw.ustring.sub(c_string[2],2,-1)                   
                end
                ------------根据schema来处理字段的类型 --------------
				local s_key =''
				local s_type = 'string'
                if args['table'] then
                	----------方法1--------------------------
	                s_key = mw.ustring.gsub(c_string[1]," ","")
	                s_key = mw.ustring.lower(s_key)
	                s_type = 'string'
	                for _i, item in ipairs(schema_table) do
	                    if item['name'] == s_key then
	                        s_type = item['type']
	                    end
	                end
	                scode1 = '101'
	                --------------------------------------
	            else
	            	------------方法2------------
					s_key = c_string[1]
					s_type = 'string'
					for k in pairs(schema_table) do
						if k == s_key then
							s_type = schema_table[k]
						end
					end	
					scode1 = '201'
					---------------------------
	        	end
                -----handle type ------------	
                c_4 = mw.text.split(c_2,",")
                c_3 = {}
                if s_type == 'number' then
                	for _i,v in ipairs(c_4)do
                		table.insert(c_3, tonumber(v))
                	end
                	scode2 = '101'
                elseif s_type == 'boolean' then
                	for _i,v in ipairs(c_4)do
                		if v == "true" then
                			table.insert(c_3,true)
                			table.insert(c_3,1)
                        else
                        	table.insert(c_3,false)
                        	table.insert(c_3,0)
                    	end
                	end
                	scode2 = '201'
                elseif s_type == 'string' then
                	for _i,v in ipairs(c_4)do
                		if tonumber(v) ~= nil then
                			table.insert(c_3, tonumber(v))
                			scode2 = scode2..'('.._i..v..'303'..')'
                		else
                			table.insert(c_3, v)
    			        	scode2 = scode2..'('.._i..v..'301'..')'
                		end
                	end
                end
                -----assemble conditon------------      
                ------------!-------------
                if c_1 == "!" then
                    query[c_string[1]] = {
                        ['$exists'] = true,
                        ['$nin'] = c_3,
                    }
                ------------+-------------
                elseif c_1 == "+" then
                    query[c_string[1]] = {
                        ['$exists'] = true,
                    }
                ------------>-------------
                elseif c_1 == ">" then
                    query[c_string[1]] = {
                        ['$gte'] = c_3[1],
                    }
                ------------<-------------
                elseif c_1 == "<" then
                    query[c_string[1]] = {
                        ['$lte'] = c_3[1],
                    }
                ------------&在两个值中间-------------
                elseif c_1 == "&" then
                	local min_max = mw.text.split(c_2,"~")
                	local min = min_max[1]
            		local max = min_max[2]
                    query[c_string[1]] = {
                        ['$gte'] = tonumber(min),
                    }
                    if max then
                    	query[c_string[1]]['$lte'] = tonumber(max)
                    end
                ------------@------------
                elseif c_1 == "@" then
					query[c_string[1]] = {
	                    ["$regex"] = c_2,
	                }
                elseif c_1 == "~" then
                	if args['table'] then
	                	query[c_string[1]] = null
	                else
						query[c_string[1]] = {
		                    ["$exists"] = false,
		                }
                	end
                else
                    query[c_string[1]] = {
                        ['$in'] = c_3,
                    }
                end                   
			end
        end
        ---------------Options----------------------------
        local order_enum = {
			['asc'] = 1,
			['ascending'] = 1,
			['1'] = 1,
			['desc'] = -1,
			['descending'] = -1,
			['revers'] = -1,
			['reverse'] = -1,
			['-1'] = -1
		}
        if args['format'] ~= 'count' then
        	options['limit'] = 200
        end
	    if args['limit'] and (args['format'] ~= 'count') then
	        options['limit'] = tonumber(args['limit'])
	    end
    ------------------sort--------------------------
        if args['sort'] then
			options['sort'] = OrderedTable()
	        local sorts = mw.text.split(args['sort'],',')
        	local orders = {}
	    	if args['order'] then
	    		orders = mw.text.split(args['order'],',')
	    	else
	    		orders = {'1'}
	    	end
		    for _i,v in ipairs(sorts) do
		    	------有与 sort 匹配的order参数-------
		    	local order = 1
		        if orders[_i] then
	        		order = order_enum[orders[_i]] or 1
		            ------------------------------------------------
		        	else
		        	--------没有与 sort 匹配的order参数，补全 1---
		            order = 1
		        end
            ---------------------------------------------------
	            if options['sort'] then
	            	options['sort'][tostring(v)] = order
	            else
	            	options['sort']={
	            		[tostring(v)] = order
	            	}
	            end
	            --------------------------------
    		end
	    else
	        options['sort'] = { ['_id'] = 1 }
	    end
		--------------offset---------------------------------------
	    if args['offset'] then
	    	options['skip'] = tonumber(args['offset']) or 0
	    end
        ------------------------------------------------------------
        --mw.logObject(query)
        data = mw.huiji.db.find(query,options)
        --mw.logObject(data)
        -------if result is empty, return "default" --------
		if #data == 0 then
			res = (args['default'] or '')
        else
            ------------------------handle result-----------------------------
            local display = {}
            for key in pairs(args) do
                if mw.ustring.sub(key,1,1) == "?" then
                    local new_key = mw.ustring.sub(key,2,-1)
                    table.insert(display, new_key)
                end
            end
            -------------------------handle format---------------------
            if #display == 0 then
                res = 'error:无效的查询字段,正确格式：|?参数=xxx，查询条件不能是空值'
            elseif args['format']  == 'template' then
                if args['template'] then
                    local template = args['template']
                    local namedArgs = args['named args'] or args['named_args'] or false
                    local userparam = args['userparam'] or ''
                    -----------------------intro template---------------------
                    if args['introtemplate'] then
		                local intro_template = '{{'..args['introtemplate']..'}}'
		                res = res .. frame:preprocess(intro_template)
                    end
		            ----------------- template --------------------------
					for _i, d in ipairs(data) do
		                local template_args = {}
		                local title = mw.title.makeTitle('template', template)
		                if title['id'] == 0 then
		                    res = res .. '[[template:'..template..']]'
		                else
		                    if namedArgs then
		                    ---------------命名参----------------
		                        for _i,k in ipairs(display) do
		                            local args_key = "?"..k
		                            template_args[args_key] = d[k]
		                        end
		                    else
		                   -----------------序号参---------------
		                		-------{{{1}}}-----------------
		                        template_args[1] = d['_id']
		                        for _i,k in ipairs(display) do
		                            local args_key = _i+1
		                            template_args[args_key] = d[k]
		                        end
		                    end
		                    	------{{{userparam}}}--------------
		                    	template_args['userparam'] = userparam
		                    -------------------------------------------------------------------------
		                    res = res ..frame:expandTemplate{ title = template, args = template_args }
		                end
		                template_args_debug = template_args
		                namedArgs_debug = namedArgs
		            end
		            ---------------outrotemplate-----------------------------------
	                if args['outrotemplate'] then
	                	local outro_template = '{{'..args['outrotemplate']..'}}'
	                    res = res .. frame:preprocess(outro_template)
	                end
                    --------------------------------------------------------------
                else
                    res = res .. 'error:没有指定template'
                end
            elseif args['format']  == 'count' then
                res = mw.huiji.db.count(query,options)
            else
            	---------------  format = table --------------------------
                local intro = args['intro'] or ''
                local outro = args['outro'] or ''
                local headers = ''
                local header1 = '<th>'..(args['mainlabel'] or '')..'</th>'
                if args['mainlabel'] then
                    if args['mainlabel'] == '-' then
                        header1 = ''
                    end
                end
                res = res .. intro .. '<table class="wikitable '..addClass..'">'
                headers = headers ..'<tr>'..header1
                for _i, k in ipairs(display) do
                    local key = '?'..k
                    headers = headers ..'<th>'.. (args[key] or k) ..'</th>'
                end
                headers = headers ..'</tr>'
                
                if args['headers'] then
                    if args['headers'] == 'hide' then
                        headers = ''
                    end
                end
                res = res .. headers
                for _i,d in ipairs(data) do
                    local row1 ='<td>'.. d['_id']..'</td>'
                    if args['mainlabel'] then
                        if args['mainlabel'] == '-' then
                            row1 = ''
                        end
                    end
                    res = res..'<tr>'..row1
                    for _i, k in ipairs(display) do
                    	local v = type(d[k])=='table' and table.concat(d[k],';') or d[k] or ''
                        res = res ..'<td>'.. v ..'</td>'
                    end
                    res = res .. '</tr>'
                end
                res = res .. '</table>' ..outro
            end
            -----------------------------------------------------------
        end
        ---------------------------------------------------------------
	------------------------------debug----------------------------------------
	if args['debug'] then
		res  =  res .. '<div style = "border:2px dashed #000;padding:0px 12px;"><div style="padding:12px;text-align:center;">DEBUG信息</div>'
		res  =  res..p._collapse('查询条件（query）', mw.dumpObject(query), '1')
		res  =  res..p._collapse('查询选项（options）', mw.dumpObject(options), '2')
		res  =  res..p._collapse('查询返回数据（nil为空）', mw.dumpObject(data), '3')
		res  =  res..p._collapse('传入的参数（args）', mw.dumpObject(args), '4')
		res  =  res..p._collapse('传入的模板参数（format=template）', mw.dumpObject(template_args_debug), '5')
		res  =  res..p._collapse('模板参数是否为命名参（namedArgs）', mw.dumpObject(namedArgs_debug), '5')
		res  =  res..p._collapse('Schema Table', mw.dumpObject(schema_table), '6')
		res  =  res..p._collapse('检查代码1', mw.dumpObject(scode1), '7')
		res  =  res..p._collapse('检查代码2', mw.dumpObject(scode2), '7')
		res  =  res..'</div>'
	end
	return res
end

function p._collapse(title,content,id)
	local html = mw.html.create()
	local res_html = html
	:tag('div'):addClass('mw-customtoggle-'..id or ''..' mw-customtoggle'):cssText('overflow:hidden;margin-bottom:12px;font-size:12px')
		:tag('div'):addClass('bg-primary'):cssText('text-align:center;padding:12px;overflow:auto;'):wikitext(title):done()
		:tag('div'):addClass('darken mw-collapsible mw-collapsed'):attr('id','mw-customcollapsible-'..id or ''):cssText('text-align: left; padding: 1em 1em 2em;'):wikitext(content):done()
	:done()
	return tostring(res_html)
end
return p