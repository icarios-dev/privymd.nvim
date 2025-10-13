-- Module utilitaire pour tables séquentielles façon JS/Lodash

--[[ Exemple d'utilisation

local list = require("list")

local nums = {1, 2, 3, 4, 5}

-- usage direct
local squares = list.map(nums, function(value) return value^2 end)
local evens = list.filter(nums, function(value) return value % 2 == 0 end)

-- Chaînable
local result = list.wrap(nums)
  :map(function(value) return value * 2 end)
  :filter(function(value) return value > 5 end)
  :flatMap(function(value) return {value, value+1} end)
  :value()

-- result == {6, 7, 8, 9, 10, 11}

-- includes / concat
local has_eight = list.includes(result, 8)  -- true
local combined = list.concat(result, {100, 200})  -- {6,7,8,9,10,11,100,200}
]]

local list = {}

-- Fonctions de base
function list.map(table_, lambda)
	local result = {}
	for index, value in ipairs(table_) do
		result[index] = lambda(value, index)
	end
	return result
end

function list.filter(table_, lambda)
	local result = {}
	for index, value in ipairs(table_) do
		if lambda(value, index) then
			table.insert(result, value)
		end
	end
	return result
end

function list.reduce(table_, lambda, acc)
	for index, value in ipairs(table_) do
		acc = lambda(acc, value, index)
	end
	return acc
end

function list.find(table_, lambda)
	for index, value in ipairs(table_) do
		if lambda(value, index) then
			return value, index
		end
	end
end

function list.some(table_, lambda)
	for _, value in ipairs(table_) do
		if lambda(value) then
			return true
		end
	end
	return false
end

function list.every(table_, lambda)
	for _, value in ipairs(table_) do
		if not lambda(value) then
			return false
		end
	end
	return true
end

-- Nouvelles méthodes JS-style
function list.concat(table_, other_table)
	local result = {}
	for _, value in ipairs(table_) do
		table.insert(result, value)
	end
	for _, value in ipairs(other_table) do
		table.insert(result, value)
	end
	return result
end

function list.includes(table_, value_to_find)
	for _, value in ipairs(table_) do
		if value == value_to_find then
			return true
		end
	end
	return false
end

function list.flatMap(table_, lambda)
	local result = {}
	for index, value in ipairs(table_) do
		local mapped = lambda(value, index)
		if type(mapped) == "table" then
			for _, v in ipairs(mapped) do
				table.insert(result, v)
			end
		else
			table.insert(result, mapped)
		end
	end
	return result
end

-- Wrapper chaînable
function list.wrap(table_)
	local self = { _ = table_ }

	local methods = {
		"map",
		"filter",
		"reduce",
		"find",
		"some",
		"every",
		"concat",
		"includes",
		"flatMap",
	}

	for _, method in ipairs(methods) do
		self[method] = function(self_, ...)
			self_._ = list[method](self_._, ...)
			return self_
		end
	end

	function self:value()
		return self._
	end

	return self
end

return list
