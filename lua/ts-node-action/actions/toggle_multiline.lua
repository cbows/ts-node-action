local helpers = require("ts-node-action.helpers")

---@param padding table Used to specify string formatting for unnamed nodes
---@param uncollapsible table Used to specify "base" types that shouldn't be collapsed further.
---@return function
local function collapse_child_nodes(padding, uncollapsible)
  local function can_be_collapsed(child)
    return child:named_child_count() > 0 and not uncollapsible[child:type()]
  end

  return function(node)
    local replacement = {}

    for child, _ in node:iter_children() do
      if can_be_collapsed(child) then
        local child_text = collapse_child_nodes(padding, uncollapsible)(child)
        if not child_text then
          return
        end -- We found a comment, abort

        table.insert(replacement, child_text)
      elseif child:type() == "comment" then -- TODO: use child:extra() when that API gets merged into stable
        return
      else
        table.insert(replacement, helpers.padded_node_text(child, padding))
      end
    end

    return table.concat(vim.tbl_flatten(replacement))
  end
end

---@param node TSNode
---@return table
local function expand_child_nodes(node)
  local replacement = {}

  for child in node:iter_children() do
    local text = helpers.node_text(child)
    local is_delimiter = not child:named()
        and child:prev_sibling()
        and child:next_sibling()
    if is_delimiter then
      replacement[#replacement] = replacement[#replacement] .. text
    else
      replacement[#replacement + 1] = text
    end
  end
  return replacement
end

---@param padding table
---@param uncollapsible table
---@return table
return function(padding, uncollapsible)
  padding = padding or {}
  uncollapsible = uncollapsible or {}

  local function action(node)
    local fn
    if helpers.node_is_multiline(node) then
      fn = collapse_child_nodes(padding, uncollapsible)
    else
      fn = expand_child_nodes
    end
    return fn(node), { cursor = {}, format = true }
  end

  return { { action, name = "Toggle Multiline" } }
end
