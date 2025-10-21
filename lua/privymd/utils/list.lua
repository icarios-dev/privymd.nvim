--- @module 'privymd.utils.list'
--- Utility module providing JavaScript-style functions for sequential Lua tables.
--- Inspired by Lodash / Array.prototype methods.
---
--- Features:
--- - Pure functional helpers (`map`, `filter`, `reduce`, `find`, `any`, `every`)
--- - JS-style helpers (`concat`, `includes`, `flatMap`)
--- - Chainable interface via `list.wrap()`
---
--- Example:
--- ```lua
--- local list = require('privymd.utils.list')
--- local nums = {1, 2, 3, 4, 5}
--- local result = list.wrap(nums)
---   :map(function(v) return v * 2 end)
---   :filter(function(v) return v > 5 end)
---   :value()
--- -- result == {6, 8, 10}
--- ```

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

--- Map a list to a new list using a transformation function.
--- The result preserves order.
---
--- Example:
--- ```lua
--- local doubled = list.map({1, 2, 3}, function(v) return v * 2 end)
--- -- doubled => { 2, 4, 6 }
--- ```
--- @generic T, R
--- @param table_ T[] Array-like table to map.
--- @param lambda fun(value: T): R Transformation applied to each element.
--- @return R[] result New table with transformed elements.
function list.map(table_, lambda)
  local result = {}
  for _, value in ipairs(table_) do
    table.insert(result, lambda(value))
  end
  return result
end

--- Filter a list using a predicate function.
--- Returns a new array containing all values for which `lambda` returns true.
---
--- Example:
--- ```lua
--- local evens = list.filter({1, 2, 3, 4}, function(v) return v % 2 == 0 end)
--- -- evens => { 2, 4 }
--- ```
--- @generic T
--- @param table_ T[] Array-like table to filter.
--- @param lambda fun(value: T): boolean Predicate returning true to keep the element.
--- @return T[] result New filtered table.
function list.filter(table_, lambda)
  local result = {}
  for _, value in ipairs(table_) do
    if lambda(value) then
      table.insert(result, value)
    end
  end
  return result
end

--- Reduce a list to a single accumulated value.
---
--- Example:
--- ```lua
--- local sum = list.reduce({1, 2, 3, 4}, function(acc, v) return acc + v end, 0)
--- -- sum => 10
--- ```
--- @generic T, R
--- @param table_ T[] Array-like table to reduce.
--- @param lambda fun(accumulator: R, value: T, index: integer): R Function applied on each element.
--- @param acc R Initial accumulator value.
--- @return R result Final accumulated value.
function list.reduce(table_, lambda, acc)
  for index, value in ipairs(table_) do
    acc = lambda(acc, value, index)
  end
  return acc
end

--- Find the first element matching a predicate.
--- Returns the value and its index, or nil if not found.
---
--- Example:
--- ```lua
--- local val, i = list.find({10, 20, 30}, function(v) return v == 20 end)
--- -- val => 20, i => 2
--- ```
---@generic T
---@param table_ T[] Array-like table to search.
---@param lambda fun(value: T, index: integer): boolean Predicate returning true to stop the search.
---@return T? value, integer? index The found value and its index, or nil.
function list.find(table_, lambda)
  for index, value in ipairs(table_) do
    if lambda(value, index) then
      return value, index
    end
  end
end

--- Test if *any* element matches the predicate.
---@generic T
---@param table_ T[] Array-like table to test.
---@param lambda fun(value: T): boolean
---@return boolean
function list.any(table_, lambda)
  for _, value in ipairs(table_) do
    if lambda(value) then
      return true
    end
  end
  return false
end

--- Test if *all* elements match the predicate.
---@generic T
---@param table_ T[] Array-like table to test.
---@param lambda fun(value: T): boolean
---@return boolean
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
    if type(mapped) == 'table' then
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
    'map',
    'filter',
    'reduce',
    'find',
    'some',
    'every',
    'concat',
    'includes',
    'flatMap',
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
