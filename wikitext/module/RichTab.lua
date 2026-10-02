local p = {}

function p.render(frame) -- =p.render{args={'a1','a2','b1','b2','c1','c2'}}
	local args = (frame.getParent and frame:getParent() or frame).args
	local tabParams = {}
	local i = 1
	while args[i] and args[i + 1] do
		table.insert(tabParams, args[i])
		table.insert(tabParams, args[i + 1])
		i = i + 2
	end
	if #tabParams == 0 then
		return ''
	end
	local htmlNav = ''
	local htmlContent = ''
	local index = 1
	local hash = mw.hash.hashValue('sha1', table.concat(tabParams))
	local prefix = 'tab-' .. (args['prefix'] and args['prefix']..'-' or '') .. hash .. '-'
	local a2 = mw.ext.mustache.render('RichTab/a2', {})
	for index = 1,#tabParams,2 do
		local id = prefix .. (index - 1) / 2
		local state = index==1 and 'active' or ''
		local a1 = mw.ext.mustache.render('RichTab/a1', {tabId=id})
		htmlNav = htmlNav..'<li role="presentation" class="'..state..'">'..a1..mw.getCurrentFrame():preprocess(tabParams[index])..a2..'</li>'
		htmlContent = htmlContent..'<div role="tabpanel" class="tab-pane '..state..'" id="'..id..'">'..mw.getCurrentFrame():preprocess(tabParams[index + 1])..'</div>'
	end
	return '<div>'
		..'<ul class="nav '..(args['class'] or 'nav-tabs')..'" role="tablist">'
			..htmlNav
		..'</ul>'
		..'<div class="tab-content">'
			..htmlContent
		..'</div>'
	..'</div>'
end

return p