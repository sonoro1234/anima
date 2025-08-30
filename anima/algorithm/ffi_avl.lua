--
-- Copyright (c) 2020 lalawue
--
-- This library is free software; you can redistribute it and/or modify it
-- under the terms of the MIT license. See LICENSE for details.
--

--[[
   ffi_avl will keep only one value instance, for node <-> value mapping,
   code sample from https://github.com/skywind3000/avlmini
]]
local ffi = require("ffi")
ffi.cdef [[
struct _avl_node {
    struct _avl_node *left;
    struct _avl_node *right;
    struct _avl_node *parent;
    int height;
    double key;
};
struct _avl_root {
    struct _avl_node *node;
};
void* calloc(size_t count, size_t size);
void free(void *ptr);
]]

local C = ffi.C

local _M = {}
_M.__index = _M

-- key for node <-> value mapping
local function _nextKey(self)
    local key = self._key + 1e-32 -- ignore significant digit
    while self._nvmap[key] do
        key = key + math.random()
    end
    self._key = key
    return key
end

local function _calloc(str)
    return ffi.cast(str .. "*", C.calloc(1, ffi.sizeof(str)))
end

-- node manipulation
--

local function _leftHeight(node)
    return (node.left ~= nil) and node.left.height or 0
end

local function _rightHeight(node)
    return (node.right ~= nil) and node.right.height or 0
end

local function _childReplace(oldnode, newnode, parent, root)
    if parent ~= nil then
        if parent.left == oldnode then
            parent.left = newnode
        else
            parent.right = newnode
        end
    else
        root.node = newnode
    end
end

local function _rotateLeft(node, root)
    local right = node.right
    local parent = node.parent
    node.right = right.left
    if right.left ~= nil then
        right.left.parent = node
    end
    right.left = node
    right.parent = parent
    _childReplace(node, right, parent, root)
    node.parent = right
    return right
end

local function _rotateRight(node, root)
    local left = node.left
    local parent = node.parent
    node.left = left.right
    if left.right ~= nil then
        left.right.parent = node
    end
    left.right = node
    left.parent = parent
    _childReplace(node, left, parent, root)
    node.parent = left
    return left
end

local function _updateHeight(node)
    local h0 = _leftHeight(node)
    local h1 = _rightHeight(node)
    node.height = math.max(h0, h1) + 1
end

local function _fixLeft(node, root)
    local right = node.right
    local rh0 = _leftHeight(right)
    local rh1 = _rightHeight(right)
    if rh0 > rh1 then
        right = _rotateRight(right, root)
        _updateHeight(right.right)
        _updateHeight(right)
    end
    node = _rotateLeft(node, root)
    _updateHeight(node.left)
    _updateHeight(node)
    return node
end

local function _fixRight(node, root)
    local left = node.left
    local rh0 = _leftHeight(left)
    local rh1 = _rightHeight(left)
    if rh0 < rh1 then
        left = _rotateLeft(left, root)
        _updateHeight(left.left)
        _updateHeight(left)
    end
    node = _rotateRight(node, root)
    _updateHeight(node.right)
    _updateHeight(node)
    return node
end

local function _rebalance(node, root)
    while node ~= nil do
        local h0 = _leftHeight(node)
        local h1 = _rightHeight(node)
        local diff = h0 - h1
        local height = math.max(h0, h1) + 1
        if node.height ~= height then
            node.height = height
        elseif diff >= -1 and diff < 1 then
            break
        end
        if diff <= -2 then
            node = _fixLeft(node, root)
        elseif diff >= 2 then
            node = _fixRight(node, root)
        end
        if node ~= nil then
            node = node.parent
        end
    end
end

local function _remove(node, root)
    local child = nil
    local parent = nil
    if node.left ~= nil and node.right ~= nil then
        local old = node
        local left = nil
        node = node.right
        while true do
            left = node.left
            if left == nil then
                break
            end
            node = left
        end
        child = node.right
        parent = node.parent
        if child ~= nil then
            child.parent = parent
        end
        _childReplace(node, child, parent, root)
        if node.parent == old then
            parent = node
        end
        node.left = old.left
        node.right = old.right
        node.parent = old.parent
        node.height = old.height
        _childReplace(old, node, old.parent, root)
        old.left.parent = node
        if old.right ~= nil then
            old.right.parent = node
        end
    else
        if node.left == nil then
            child = node.right
        else
            child = node.left
        end
        parent = node.parent
        _childReplace(node, child, parent, root)
        if child ~= nil then
            child.parent = parent
        end
    end
    if parent ~= nil then
        _rebalance(parent, root)
    end
end

-- link parent
--

local _sw = 0
local _parent = nil

-- init parent value
local function _linkInit()
    _sw = 0
    _parent = nil
end

-- get parent node children, or set parent children
local function _linkChild(self, sw, node)
    _sw = sw
    if node == nil then
        if _sw == 0 then
            return self._root.node
        elseif _sw < 0 then
            return _parent.left
        else
            return _parent.right
        end
    else
        if _sw == 0 then
            self._root.node = node
        elseif _sw < 0 then
            _parent.left = node
        else
            _parent.right = node
        end
    end
end

-- update parent node
local function _linkUpdate(parent)
    _parent = parent
end

-- public interface
--

function _M:first()
    if self._count > 0 then
        local node = self._root.node
        while node.left ~= nil do
            node = node.left
        end
        return self._nvmap[node.key], node.height
    end
end

function _M:last()
    if self._count > 0 then
        local node = self._root.node
        while node.right ~= nil do
            node = node.right
        end
        return self._nvmap[node.key], node.height
    end
end

function _M:next(value)
    if value == nil then
        return nil
    end
    local node = self._vnmap[value]
    if node == nil then
        return nil
    end
    if node.right ~= nil then
        node = node.right
        while node.left ~= nil do
            node = node.left
        end
    else
        while true do
            local last = node
            node = node.parent
            if node == nil then
                break
            end
            if node.left == last then
                break
            end
        end
    end
    if node == nil then
        return nil
    end
    return self._nvmap[node.key], node.height
end

function _M:prev(value)
    if value == nil then
        return nil
    end
    local node = self._vnmap[value]
    if node == nil then
        return nil
    end
    if node.left ~= nil then
        node = node.left
        while node.right ~= nil do
            node = node.right
        end
    else
        while true do
            local last = node
            node = node.parent
            if node == nil then
                break
            end
            if node.right == last then
                break
            end
        end
    end
    if node == nil then
        return nil
    end
    return self._nvmap[node.key], node.height
end

local _dummy_tbl = {}
function _M:range(from, to)
    from = from or 1
    to = to or self._count
    if self._count <= 0 or from < 1 or from > self._count or from > to then
        return _dummy_tbl
    end
    to = math.min(self._count, to)
    local range = {}
    local idx = 1
    local value = self:first()
    repeat
        if idx >= from and idx <= to then
            range[#range + 1] = value
        end
        idx = idx + 1
        value = self:next(value)
    until (value == nil) or (idx > to)
    return range
end

-- return height, value pairs
function _M:walk()
    if self._count <= 0 then
        return function()
            return nil
        end
    end
    local value, height = self:first()
    return function()
        if value ~= nil then
            local ret_value = value
            local ret_height = height
            value, height = self:next(value)
            return ret_value, ret_height
        else
            return nil
        end
    end
end

-- if value exist, return original value, return nil for sucess
function _M:insert(value)
    if value == nil then
        return nil
    end
    local parent = nil
    local compare = self._compare
    _linkInit()
    while true do
        parent = _linkChild(self, _sw, nil)
        if parent == nil then
            break
        end
        _linkUpdate(parent)
        local parent_value = self._nvmap[parent.key]
        local hr = compare(value, parent_value)
        if hr == 0 then
            return parent_value
        elseif _linkChild(self, hr, nil) == nil then
            break -- check next parent
        end
    end
    -- create node
    local node = _calloc("struct _avl_node")
    node.key = _nextKey(self)
    self._vnmap[value] = node
    self._nvmap[node.key] = value
    -- update node
    node.parent = parent
    node.height = 1
    node.left = nil
    node.right = nil
    -- link node
    _linkChild(self, _sw, node)
    _rebalance(parent, self._root)
    self._count = self._count + 1
end

function _M:remove(value)
    if value == nil then
        return nil
    end
    local node = self._vnmap[value]
    if node == nil or node.parent == node then
        return nil
    end
    _remove(node, self._root)
    node.parent = node
    self._nvmap[node.key] = nil
    self._vnmap[value] = nil
    C.free(node)
    self._count = self._count - 1
    return value
end

function _M:clear()
    if self._count <= 0 then
        return
    end
    for _, n in pairs(self._vnmap) do
        C.free(n)
    end
    self._root.node = nil
    self._vnmap = {} -- value to node
    self._nvmap = {} -- node to value
    self._count = 0 -- total count
    self._key = 0
end

function _M:count()
    return self._count
end


-- compare function should be (v1, v2), reutrn -1 for v1 < v2,
-- 0 for v1 == v2, 1 for v1 > v2
local function _new(compare_func)
    local ins = setmetatable({}, _M)
    ins._root = _calloc("struct _avl_root")
    ins._vnmap = {} -- value to node
    ins._nvmap = {} -- node to value
    ins._count = 0 -- total count
    ins._key = 0
    ins.contains = function(self, val)
        if self._vnmap[val] then
			return true, self._vnmap[val]
		else
			return false, nil
		end
    end
    ins.traverse = function(self, cb)
		local ee = self:first()
		while ee do
			cb(ee)
			ee = self:next(ee)
		end
	end
    ins._compare = compare_func -- compare function     
    ffi.gc(
        ins._root,
        function(root)
            for _, n in pairs(ins._vnmap) do
                C.free(n)
            end
            C.free(root)
        end
    )
    return ins
end

if ... then 
return {
    new = _new
}
end
-----------------------------

local N=10000

local comb = require"combinatorics"
local uniquevalues_r1 = comb.permutation(N)
local uniquevalues_r2 = comb.permutation(N)
print"test------"

local function checkSLS(t)
	local previ
	local ee = t:first()
	while ee do
		if previ then
			assert(previ<ee)
		end
		--io.write(ee..",")
		previ = ee
		ee = t:next(ee)
	end
end
local function checkSLS2(t)
	local previ
	t:traverse(function(v)
		if previ then
			assert(previ<v)
		end
		--io.write(v..",")
		previ=v
	end)
end
require"anima"
local t = _new(function(a, b)
    return a - b
end)

local init_t = secs_now()
for i=1,N do
	local val = uniquevalues_r1[i] --Node1{v=i,a="a"..i}
	t:insert(val)
end

--remove in random order
for i=1,N do
	t:remove(uniquevalues_r2[i])
	checkSLS2(t)
end

print("time1",secs_now()-init_t)

local Tree = require"avl_tree"

local t = Tree:new()

local init_t = secs_now()
for i=1,N do
	local val = uniquevalues_r1[i] 
	t:insert(val)
end

--remove in random order
for i=1,N do
	t:remove(uniquevalues_r2[i])
	checkSLS2(t)
end

print("time2",secs_now()-init_t)