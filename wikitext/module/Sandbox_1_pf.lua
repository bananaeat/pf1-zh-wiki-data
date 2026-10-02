-- 沙盒：测试本站能不能用 Lua 模块
local p = {}
function p.hello(frame)
    return '模块跑起来了：' .. (frame.args[1] or '无参数')
end
return p