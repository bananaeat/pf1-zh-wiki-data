local p = {}
getArgs = require('module:Arguments').getArgs
function p.config(frame)
    local output = ''
    local args = getArgs(frame)
    local formlist = {}

    local outputTable = {
        forms = {},
        resultTemplate = args['template'] or 'ItemListEntry',
        class = args['class']
    }
    if args['searchonload'] == 'true' then
        outputTable['searchOnLoad'] = true
    else
        outputTable['searchOnLoad'] = false
    end
    if args['pagesize'] ~= nil and tonumber(args['pagesize']) ~= nil then
        outputTable['pagesize'] = tonumber(args['pagesize'])
    else
        outputTable['pagesize'] = 20
    end
    for i, v in ipairs(args) do
        if type(i) == 'number' and v ~= nil then
            local parsedValue = string.gsub(v, '\n//', '')
            table.insert(formlist, parsedValue)
        end
    end

    --------add:selection---------
    local selection = args['selection']
    if selection then
        local selectionTable = "type:hidden;value:" ..
                                   mw.text.split(selection, '::')[2] ..
                                   ';model:' ..
                                   mw.text.split(selection, '::')[1]
        table.insert(formlist, selectionTable)
    end
    ------------------------------
    --------add:sort--------
    local sortlist = {}

    if args['sort'] then
        local sortkeys = mw.text.split(args['sort'], ',')
        local orders = {} -- initial order list 
        if args['order'] then orders = mw.text.split(args['order'], ',') end
        for i, v in ipairs(sortkeys) do
            sortlist[v] = 1
            if orders[i] == '-1' then
                sortlist[v] = -1 -- be ware of data type
            end
        end
            outputTable['sortkeys'] = sortlist
    end


    for i, compStr in ipairs(formlist) do
        -- 单个组件
        local comp = {}

        local compOptionList = mw.text.split(compStr, ';')
        for k, compOptionStr in ipairs(compOptionList) do
            -- 组件的单个属性
            local argKey = mw.text.split(compOptionStr, ':')[1]
            local argValue = mw.text.split(compOptionStr, ':')[2]
            if argKey ~= 'options' then
                comp[argKey] = argValue
                -- 如果不是option则扁平化处理
            else
                comp[argKey] = {}
                -- 如果是option则再次分割
                local options = mw.text.split(argValue, ',')
                for i, option in ipairs(options) do
                    local oneOption = {
                        value = mw.text.split(option, '-')[1],
                        text = mw.text.split(option, '-')[2]
                    }

                    if mw.text.split(oneOption.text, '@')[2] == 'default' then
                        oneOption.default = true
                        oneOption.text = mw.text.split(oneOption.text, '@')[1]
                    end

                    table.insert(comp[argKey], oneOption)
                end
            end

        end
        table.insert(outputTable.forms, comp)

    end
    output = mw.text.jsonEncode(outputTable)

    return output

end

function p._defaultList(frame)
    local res = '<div style="display: grid;gap: 4px;grid-template-columns: repeat(auto-fill,minmax(300px,auto));font-size:10px;padding:12px;margin:6px 0;background: #000;">'
    local args = getArgs(frame)
    for i,v in pairs(args) do
    	res = res ..'<div style = "margin:2px 0px;"><span style="background: #264687;    color: #fff;    padding: 2px;">' ..i..'</span>：<span style="color: #e6e6e6;">'..v..'</span></div>'
    end
    return res..'</div>'
end
return p