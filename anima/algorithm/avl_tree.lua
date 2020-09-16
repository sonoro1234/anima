
--https://sites.google.com/site/mytechnicalcollection/algorithms/trees/avl-tree
--[[
// An AVL tree node
struct node
{
    int key;
    struct node *left;
    struct node *right;
    int height;
};
--]]
local max = math.max
 
-- A utility function to get height of the tree
local function height(node)
    if not node then return 0 end
    return node.height;
end
 
 
--/* Helper function that allocates a new node with the given key and
--    NULL left and right pointers. */
local function newNode( key)
    local node = {}
    node.key   = key;
    node.left   = nil;
    node.right  = nil;
    node.height = 1;  -- new node is initially added at leaf
    return(node);
end
 
--// A utility function to right rotate subtree rooted with y
--// See the diagram given above.
local function rightRotate(y)
    local x = y.left;
    local T2 = x.right;
 
    -- Perform rotation
    x.right = y;
    y.left = T2;
 
    -- Update heights
    y.height = max(height(y.left), height(y.right))+1;
    x.height = max(height(x.left), height(x.right))+1;
 
    -- Return new root
    return x;
end
 
--// A utility function to left rotate subtree rooted with x
--// See the diagram given above.
local function leftRotate(x)
    local y = x.right;
    local T2 = y.left;
 
    --// Perform rotation
    y.left = x;
    x.right = T2;
 
    --//  Update heights
    x.height = max(height(x.left), height(x.right))+1;
    y.height = max(height(y.left), height(y.right))+1;
 
    --// Return new root
    return y;
end
 
--// Get Balance factor of node N
local function getBalance(N)
    if (N == nil) then return 0 end
    return height(N.left) - height(N.right);
end
 
local function insert(node, key)
    --/* 1.  Perform the normal BST rotation */
    if (node == nil) then
        return(newNode(key));
	end
 
    if (key < node.key) then
        node.left  = insert(node.left, key);
    else
        node.right = insert(node.right, key);
	end
 
    --/* 2. Update height of this ancestor node */
    node.height = max(height(node.left), height(node.right)) + 1;
 
    --/* 3. Get the balance factor of this ancestor node to check whether
    --   this node became unbalanced */
    local balance = getBalance(node);
 
    --// If this node becomes unbalanced, then there are 4 cases
 
    --// Left Left Case
    if (balance > 1 and key < node.left.key) then
        return rightRotate(node);
	end
 
    --// Right Right Case
    if (balance < -1 and key > node.right.key) then
        return leftRotate(node);
	end
 
    --// Left Right Case
    if (balance > 1 and key > node.left.key) then
        node.left =  leftRotate(node.left);
        return rightRotate(node);
    end
 
    --// Right Left Case
    if (balance < -1 and key < node.right.key) then
        node.right = rightRotate(node.right);
        return leftRotate(node);
    end
 
    --/* return the (unchanged) node pointer */
    return node;
end
 
--[[/* Given a non-empty binary search tree, return the node with minimum
   key value found in that tree. Note that the entire tree does not
   need to be searched. */
   --]]
local function minValueNode(node)
    local current = node;
 
    --/* loop down to find the leftmost leaf */
    while (current.left) do
        current = current.left;
	end
 
    return current;
end
 
local function deleteNode(root, key)
    --// STEP 1: PERFORM STANDARD BST DELETE
 
    if (root == nil) then
        return root;
	end
 
    --// If the key to be deleted is smaller than the root's key,
    --// then it lies in left subtree
    if ( key < root.key ) then
        root.left = deleteNode(root.left, key);
 
    --// If the key to be deleted is greater than the root's key,
    --// then it lies in right subtree
    elseif( key > root.key ) then
        root.right = deleteNode(root.right, key);
 
    --// if key is same as root's key, then This is the node
    --// to be deleted
    else
        --// node with only one child or no child
        if( (root.left == nil) or (root.right == nil) ) then
            local temp = root.left and root.left or root.right;
            --// No child case
            if(temp == nil) then
				 --print"caso-----------1"
                temp = root;
                root = nil;
            else --// One child case
				 --print"caso-----------2"
             --*root = *temp; --// Copy the contents of the non-empty child
				root.key = temp.key
				root.left = temp.left
				root.right = temp.right
				root.height = temp.height
				--root = temp
			end
        else
            --// node with two children: Get the inorder successor (smallest
            --// in the right subtree)
            local temp = minValueNode(root.right);
 
            --// Copy the inorder successor's data to this node
            root.key = temp.key;
 
            --// Delete the inorder successor
            root.right = deleteNode(root.right, temp.key);
        end
    end
 
    --// If the tree had only one node then return
    if (root == nil) then
      return root;
	end
 
    --// STEP 2: UPDATE HEIGHT OF THE CURRENT NODE
    root.height = max(height(root.left), height(root.right)) + 1;
 
    --// STEP 3: GET THE BALANCE FACTOR OF THIS NODE (to check whether
    --//  this node became unbalanced)
    local balance = getBalance(root);
 
    --// If this node becomes unbalanced, then there are 4 cases
 
    --// Left Left Case
    if (balance > 1 and getBalance(root.left) >= 0) then
        return rightRotate(root);
	end
 
    --// Left Right Case
    if (balance > 1 and getBalance(root.left) < 0) then
        root.left =  leftRotate(root.left);
        return rightRotate(root);
    end
 
    --// Right Right Case
    if (balance < -1 and getBalance(root.right) <= 0) then
        return leftRotate(root);
	end
 
    --// Right Left Case
    if (balance < -1 and getBalance(root.right) > 0) then
        root.right = rightRotate(root.right);
        return leftRotate(root);
    end
 
    return root;
end
 
--// A utility function to print preorder traversal of the tree.
--// The function also prints height of every node
local function preOrder(root)
    if root then
        io.write(string.format("%s ", tostring(root.key)));
        preOrder(root.left);
        preOrder(root.right);
    end
end
--------------
local function printTree(self,depth)
	depth = depth or 1
	if self then 
		local leaf = (not self.right) and (not self.left)
		printTree(self.right,depth+1)
		print(string.format("%s%s",string.rep("  ",depth), tostring(self.key)..(leaf and "--" or "")))
		printTree(self.left,depth+1)
	else
		--print(string.format("%s%s",string.rep("  ",depth), "--"))
	end	
end

local Tree = {}
Tree.__index = Tree
function Tree:new()
    self = {}
    self.root = nil
    setmetatable(self, Tree)
    return self
end

local function traverse_binary_tree(node, callback)
    if node == nil then return end
    traverse_binary_tree(node.left, callback)
    callback(node.key)
    traverse_binary_tree(node.right, callback)
end
function Tree:traverse(callback)
	traverse_binary_tree(self.root,callback)
end

function Tree:count()
	local count = 0
	self:traverse(function() count = count + 1 end)
	return count
end

function Tree:insert(data)
    -- if self.root == nil then
        -- local node = {}
        -- self.root = node
        -- return node
    -- end
    self.root = insert(self.root,data)
end

function Tree:remove(data)
    self.root = deleteNode(self.root,data)
end

function Tree:print()
	printTree(self.root)
end

local function find_min(node)
    local current_node = node
    while current_node.left do
        current_node = current_node.left
    end
    return current_node
end

local function find_max(node)
    local current_node = node
    while current_node.right do
        current_node = current_node.right
    end
    return current_node
end

function Tree:first()
	if not self.root then return nil end
	return find_min(self.root).key
end

function Tree:last()
	if not self.root then return nil end
	return find_max(self.root).key
end


local function node_contains(node,a)
	if node.key == a then
        return true,node
    elseif a < node.key then
        if node.left ~= nil then
            return node_contains(node.left,a)
        end
    else
        if node.right ~= nil then
            return node_contains(node.right,a)
        end
    end
    
    return false
end

function Tree:contains(key)
	if not self.root then return nil end
	return node_contains(self.root,key)
end

local function tree_next(self,data)
    local ok,node = self:contains(data)
	if not ok then return nil end
	if node.right then return find_min(node.right).key end
	
	local succ 
	local root = self.root
    while (root) do
        if (node.key < root.key) then 
            succ = root; 
            root = root.left; 
        elseif (node.key > root.key) then
            root = root.right; 
        else
            break;
		end
    end 
  
    return succ and succ.key
end

local function tree_prev(self,data)
    local ok,node = self:contains(data)
	if not ok then return nil end
	if node.left then return find_max(node.left).key end
	
	local succ 
	local root = self.root
    while (root) do
        if (node.key > root.key) then 
            succ = root; 
            root = root.right; 
        elseif (node.key < root.key) then
            root = root.left; 
        else
            break;
		end
    end 
  
    return succ and succ.key
end

Tree.prev = tree_prev
Tree.next = tree_next

if ... then return Tree end
--------------- test
local t = Tree:new()

print(t:first())
--t:dump()
local allNodes = {}
--for i=1,10 do
for _,i in ipairs{9,8,4,5,2,3,6,1,7,10} do
	local node = i --Node1{v=i,a="a"..i}
	t:insert(node)
	table.insert(allNodes,node)
end
for i=1,10 do
	local node = 100+i --Node1{v=i,a="b"..i}
	t:insert(node)
	table.insert(allNodes,node)
end

print"not deleting"

local ee = t:first()
while ee do
	print(ee)
	ee = t:next(ee)
end

print"deleting------"

local function checkSLS(SLS)
	local previ
		SLS:traverse(function(v)
			if previ then
				assert(previ<v)
			end
			previ=v
		end)
end
--remove in random order
math.randomseed(2)
while #allNodes>0 do
	local ind = math.ceil(#allNodes*math.random())
	print("--------------------------#allNodes",#allNodes,ind,allNodes[ind])
	--t:print()
	--local ind = math.ceil(#allNodes*0.25)
	print"-----"
	t:remove(allNodes[ind])
	table.remove(allNodes,ind)
	--t:print()
	checkSLS(t)
end
