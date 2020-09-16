
local function isBST(node,  minKey,  maxKey) 
    if (node == nil) then return true end
    if (node._data < minKey or node._data > maxKey) then return false end
    assert(minKey <= maxKey)
    return isBST(node.left, minKey, node._data) and isBST(node.right, node._data, maxKey);
end

local function Node_new(data,parent)
    local self = {}
    
    self._data = data
    self.left = nil
    self.right = nil
	self.parent = parent
   
    return self
end


local Tree = {}

Tree.__index = Tree

function Tree:new()
    self = {}
    self._root = nil
    
    setmetatable(self, Tree)
    return self
end

local function contains(node, data)
    if node._data == data then
        return true,node
    elseif data < node._data then
        if node.left ~= nil then
            return contains(node.left, data)
        end
    else
        if node.right ~= nil then
            return contains(node.right, data)
        end
    end
    
    return false
end

function Tree:contains(data)
    if self._root == nil then
        return false
    end
    
    return contains(self._root, data)
end

local function find_min(node)
    --"""Get minimum node in a subtree."""
    local current_node = node
    while current_node.left do
        current_node = current_node.left
    end
    return current_node
end

local function find_max(node)
    --"""Get maximum node in a subtree."""
    local current_node = node
    while current_node.right do
        current_node = current_node.right
    end
    return current_node
end

function Tree:prev(data)
    local ok,node = self:contains(data)
	if not ok then return nil end
	if node.left then return find_max(node.left)._data end
	local current_node = node
	local parent = current_node.parent
	while parent and parent.right ~= current_node do
		current_node = parent
		parent = current_node.parent
	end
	return parent and parent._data
end

function Tree:next(data)
    local ok,node = self:contains(data)
	if not ok then return nil end
	if node.right then return find_min(node.right)._data end
	local current_node = node
	local parent = current_node.parent
	while parent and parent.left ~= current_node do
		current_node = parent
		parent = current_node.parent
	end
	return parent and parent._data
end



function Tree:first()
	if self._root == nil then
		return nil
	end
	return find_min(self._root)._data
end

function Tree:last()
	if self._root == nil then
		return nil
	end
	return find_max(self._root)._data
end

local function insert(node, data)
	local nodeNew
    if data >= node._data then
        if node.right == nil then
            nodeNew = Node_new(data,node)
            node.right = nodeNew
        else
            node.right, nodeNew = insert(node.right, data)
        end
    else
        if node.left == nil then
            nodeNew = Node_new(data,node)
            node.left = nodeNew
        else
            node.left, nodeNew = insert(node.left, data)
        end
    end

    return node, nodeNew
end

function Tree:insert(data)
    if self._root == nil then
        local node = Node_new(data)
        self._root = node
        return node
    end
    
    self._root, newnode = insert(self._root, data)
	return newnode
end



local function replace_node_in_parent(node, new_value,tree) 
    if node.parent then
        if node == node.parent.left then
            node.parent.left = new_value
        else
            node.parent.right = new_value
		end
	else
		--print"not parent-------------"
		assert(node == tree._root)
		tree._root = new_value
	end
    if new_value then
        new_value.parent = node.parent
	end
end

--require"anima.utils"
local function binary_tree_delete(node, data, tree, br) 
--print("bsdel",node,node._data,data,tree,tree._root, br)
--prtable(node)

    if data < node._data then
        if node.left then return binary_tree_delete(node.left,data,tree,1) end
        return nil, 1
	end
    if data > node._data then
        if node.right then return binary_tree_delete(node.right,data,tree,2) end
        return nil, 2
	end
	
    -- Delete the key here
    if node.left and node.right then --  # If both children are present
        local successor = find_min(node.right)
		--node._data = successor._data
        --return binary_tree_delete(successor, successor._data, tree,3)
		
		node._data, successor._data = successor._data, node._data 
		--assert(isBST(successor,-1,200))
		return binary_tree_delete(successor, successor._data, tree,3)
		--return node,2.5
    elseif node.left then --  # If the node has only a *left* child
        replace_node_in_parent(node, node.left, tree)
		return node, 3
    elseif node.right then --  # If the node has only a *right* child
        replace_node_in_parent(node, node.right, tree)
		return node, 4
    else
        replace_node_in_parent(node, nil, tree)  --# This node has no children
		return node, 5
	end
end

function Tree:remove(data)
    if self._root == nil then
        return nil,0
    end
    return binary_tree_delete(self._root, data, self)
end

local function traverse_binary_tree(node, callback)
    if node == nil then return end
    traverse_binary_tree(node.left, callback)
    callback(node._data)
    traverse_binary_tree(node.right, callback)
end

local function traverse_binary_tree_width_first(node, callback)
    if node == nil then return end
	callback(node._data)
    traverse_binary_tree_width_first(node.left, callback)
    traverse_binary_tree_width_first(node.right, callback)
end

--require"anima.utils"
local function BFS(root,callback,levcb)
    local Q = {}
	local lev = 0
    table.insert(Q,{root,0})
    while #Q > 0 do
		--print("BFS",#Q)
        local w = table.remove(Q,1)
		if lev < w[2] then
			lev = w[2]
			levcb(lev)
		end
		local v = w[1]
        callback(v)
		if v.left then
           table.insert(Q,{v.left,w[2]+1})
        end
		if v.right then
           table.insert(Q,{v.right,w[2]+1})
        end
		--prtable(v)
		--print("BFS2",v.left,v.right,#Q)
	end
end

function Tree:print()
	print"Tree:"
	BFS(self._root, 
		function(v) io.write(tostring(v._data).."("..(v.parent and tostring(v.parent._data) or "")..")"..",") end,
		function(lev) print() end)
	print()
end

function Tree:traverse(callback)
	traverse_binary_tree(self._root,callback)
end

function Tree:count()
	local count = 0
	self:traverse(function() count = count + 1 end)
	return count
end


if ... then return Tree end

------------------------------
local t = Tree:new()
local tt = {21,20,28,29,23,24} --22
for i,v in ipairs(tt) do t:insert(v) end
print("t:count()",t:count())
t:traverse(function(v) io.write(v.."\n") end)
t:print()
--t:remove(21)
--t:print()

local data = t:first()
repeat
	print(data)
	data = t:next(data)
until(not data)

print"----------"

local data = t:last()
repeat
	print(data)
	data = t:prev(data)
until(not data)

--do return end
----------------------------------------
-- local t = Tree:new()
-- for i=1,10 do t:insert(i) end
-- t:remove(2)
-- print"again-------"
-- t:remove(2)
-- do return end
print"----------test----------------"



local t = Tree:new()
for i=0,1000 do
	local val = math.floor(math.random()*100)
	--if val==8 then val=9 end
	local nn = t:insert(val)
	assert(nn._data == val)
end
-- print("t:contains(8)",t:contains(8))
-- print("t:count()",t:count())
-- local nn, cual = t:remove(200)
-- print("t:count()",t:count())
-- print("200",nn,nn._data,200,cual)


for i=0,1000 do
	local val = math.floor(math.random()*100)
	local docontains,nn1 = t:contains(val)
	local nn, cual = t:remove(val)
	if docontains then 
		--print(nn,nn._data,val,cual)
		assert(nn._data == val) 
	else 
		assert(nn==nil) 
	end
	--print(docontains,nn1,nn)
	assert(isBST(t._root,0,100))
end
t:print()
print("isBST_INT",isBST(t._root,0,100))

local count = 0
local oldvalue
t:traverse(function(dd) 
	assert(t:contains(dd))
	print(dd);
	count = count + 1 
	assert((oldvalue==nil) or (oldvalue <= dd), (oldvalue or "nil")..","..dd)
	oldvalue = dd
end)
print("count",count)
-----------------------------------
local t = Tree:new()
local function do_t()
	print"begin---------"
	t:traverse(function(v) print(v) end)
	print"end---------"
end
--t:insert"a"
t:insert"c"
do_t()
t:insert"c"
do_t()
t:remove"c"
do_t()
--do return end
-----------------------------
local tree = Tree --require("bstree")

do
    local t = tree:new()
    assert(t:contains("a") == false)
    
    t:insert("a")
    assert(t:contains("a") == true)
    
    t:insert("c")
    assert(t:contains("a") == true)
    assert(t:contains("c") == true)
    
    t:insert("X")
    assert(t:contains("X") == true)
    assert(t:contains("a") == true)
    assert(t:contains("c") == true)
end

do
    local t = tree:new()
    
    t:insert("a")
    local popped = t:remove("a")
    
	t:traverse(function(v) print("232",v) end)
    --assert(popped == "a")
    assert(t:contains("a") == false)
end

do
    local t = tree:new()
    
    t:insert(10)
    t:insert(50)
    t:insert(99)
    
    local popped = t:remove(50)
    
    --assert(popped == 50)
    assert(t:contains(10) == true)
    assert(t:contains(50) == false)
    assert(t:contains(99) == true)
end

do
    local t = tree:new()
    
    t:insert(10)
    t:insert(5)
    t:insert(1)
    
    local popped = t:remove(5)
    
   -- assert(popped == 5)
    assert(t:contains(10) == true)
    assert(t:contains(5) == false)
    assert(t:contains(1) == true)
end

do
    local t = tree:new()
    
    t:insert(10)
    t:insert(5)
    t:insert(50)
    
    local popped = t:remove(10)
    
    --assert(popped == 10)
    assert(t:contains(10) == false)
    assert(t:contains(5) == true)
    assert(t:contains(50) == true)
end
---------------


local Node = {}
Node.__index = Node
Node.__lt = function(p,q)
	return p.v < q.v
end
--Node.__eq = function(p,q)
--	return p.v == q.v
--end

local function Node1(o)
	setmetatable(o,Node)
	return o
end

local t = Tree:new()
for i=1,10 do
	t:insert(Node1{v=i,a="a"..i})
end
for i=1,10 do
	t:insert(Node1{v=i,a="b"..i})
end

t:traverse(function(n) print(n.v,n.a) end)

--[[
local ok,node = t:contains(Node1{v=3,a="b3"})
print(ok,node._data.v,node._data.a)
local ok,node = t:contains(Node1{v=3,a="b3"})
print(ok,node._data.v,node._data.a)


local prev = t:prev(Node1{v=3})
print(prev.v, prev.a)
local next = t:next(Node1{v=3})
print(next.v, next.a)
--]]

print"not deleting"

local ee = t:first()
while ee do
	print(ee.a)
	ee = t:next(ee)
end
--do return end
---[[
print"dleteing------------"

local first = t:first()
while first do
	print(first.a)
	t:remove(first)
	first = t:first()
end
--]]




