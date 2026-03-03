local utils = require("libs/utility")

local memfs = {}
memfs.__index = memfs

local inode = {}
inode.__index = inode

function inode.new(name, is_dir)
	local self = {
		name = name,
		is_dir = is_dir,
		content = is_dir and {} or "",
		permissions = 755,
		created_at = os.time(),
		modified_at = os.time(),
		accessed_at = os.time()
	}
	return setmetatable(self, inode)
end

function memfs.new()
	local self = {
		root = inode.new("/", true),
		current_dir = "/"
	}
	return setmetatable(self, memfs)
end

function memfs:export()
	local function serialize_inode(node)
		local node_type = node.is_dir and 1 or 0
		local name = node.name or ""
		local name_size = #name
		local content_size = #node.content

		if node.is_dir then
			content_size = 0
			for _ in node.content do
				content_size = content_size + 1
			end
		end

		return string.pack("BI2", node_type, name_size) .. name ..
			   string.pack("I2I8I8I8I8", node.permissions, node.created_at, node.modified_at, node.accessed_at, content_size) .. 
			   (node.is_dir and "" or node.content)
	end

	local serialized_data = ""
	local function serialize_recursively(node)
		serialized_data = serialized_data .. serialize_inode(node)
		if node.is_dir then
			for _, child in pairs(node.content) do
				serialize_recursively(child)
			end
		end
	end

	serialize_recursively(self.root)
	return serialized_data
end

function memfs:import(data)
	local function deserialize_inode(offset)
		local node_type, inode_name_size = string.unpack("BI2", data, offset)
		local inode_name = string.sub(data, offset + 3, offset + 3 + inode_name_size - 1)
		local permissions, created_at, modified_at, accessed_at, content_size = string.unpack("I2I8I8I8I8", data, offset + 3 + inode_name_size)
				
		local is_dir = node_type == 1
		local new_offset = offset + inode_name_size + 37

		local content
		if is_dir then
			content = {}
			for _ = 1, content_size do
				local child_inode, new_child_offset = deserialize_inode(new_offset)
				if child_inode then
					content[child_inode.name] = child_inode
					new_offset = new_child_offset
				else
					break
				end
			end
		else
			content = string.sub(data, new_offset, new_offset + content_size - 1)
			new_offset = new_offset + content_size
		end

		local new_inode = inode.new(inode_name, is_dir)
		new_inode.permissions = permissions
		new_inode.created_at = created_at
		new_inode.modified_at = modified_at
		new_inode.accessed_at = accessed_at
		new_inode.content = content

		return new_inode, new_offset
	end

	self.root = select(1, deserialize_inode(1))
end

function memfs:get_inode(path)
	if path == "/" then
		return self.root
	end

	local parts = self:split_path(path)
	local current = self.root

	for _, part in ipairs(parts) do
		if current.is_dir and current.content[part] then
			current = current.content[part]
		else
			return nil
		end
	end

	return current
end

function memfs:split_path(path)
	if not path or path == "" then
		return {}
	end

	return utils.split(path, "/")
end

function memfs:normalize_path(path)
	local parts = self:split_path(path)
	local normalized = {}

	for _, part in ipairs(parts) do
		if part == ".." then
			table.remove(normalized)
		elseif part ~= "" then
			table.insert(normalized, part)
		end
	end

	if #normalized == 0 then
		return "/"
	end

	return table.concat(normalized, "/")
end

function memfs:resolve_path(path)
	if path == "" then
		return self.current_dir
	end

	local is_absolute = string.sub(path, 1, 1) == "/"
	local normalized_path = self:normalize_path(is_absolute and path or (self.current_dir .. "/" .. path))

	local split_path = self:split_path(normalized_path)
	local file_name = split_path[#split_path] 
	local parent_path = table.concat(split_path, "/", 1, #split_path - 1)

	if parent_path == "" then
		parent_path = "/"
	end

	return normalized_path, file_name, parent_path
end

function memfs:create_file(path, is_dir)
	local file_name, parent_path
	path, file_name, parent_path = self:resolve_path(path)

	local parent = self:get_inode(parent_path)
	if not parent or not parent.is_dir then return nil end

	if parent.content[file_name] then return nil end

	local new_node = inode.new(file_name, is_dir)
	parent.content[file_name] = new_node
	parent.modified_at = os.time()

	return true
end

function memfs:write_file(path, data)
	path = self:resolve_path(path)
	local file = self:get_inode(path)
	if not file or file.is_dir then return nil end

	file.content = data
	file.modified_at = os.time()

	return true
end

function memfs:read_file(path)
	path = self:resolve_path(path)
	local file = self:get_inode(path)
	if not file or file.is_dir then return nil end

	file.accessed_at = os.time()
	return file.content
end

function memfs:list_dir(path)
	path = self:resolve_path(path)
	local dir = self:get_inode(path)
	if not dir or not dir.is_dir then return nil end

	local files = {}
	for name, _ in pairs(dir.content) do
		table.insert(files, name)
	end
	dir.accessed_at = os.time()

	return files
end

function memfs:remove(path)
	local file_name, parent_path
	path, file_name, parent_path = self:resolve_path(path)

	local parent = self:get_inode(parent_path)
	if not parent or not parent.is_dir then return nil end

	if parent.content[file_name] then
		parent.content[file_name] = nil
		parent.modified_at = os.time()
		return true
	end

	return false
end

return memfs