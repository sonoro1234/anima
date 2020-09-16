local M = {}
function M.permutation(N)
	local _shuffled = {}
	for i=1,N do
		local randPos = math.ceil(math.random()*i)
		_shuffled[i] = _shuffled[randPos]
        _shuffled[randPos] = i
	end
	return _shuffled
end

return M