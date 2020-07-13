local in_rules = io.open(findfile(PROBLEM .. 'rules.txt'), 'r')
local lines = {}

for line in in_rules:lines() do
  lines[#lines + 1] = line
end

L = tonumber(lines[1]:match("(%d+)"))

print("rules: " .. L .. " labels")

Rleft   = {}
Rright  = {}
Rtop    = {}
Rbottom = {}

local next = 2
for l=1,L do
  Rleft[#Rleft+1] = lines[next]
  next = next + 1
end
for l=1,L do
  Rright[#Rright+1] = lines[next]
  next = next + 1
end
for l=1,L do
  Rtop[#Rtop+1] = lines[next]
  next = next + 1
end
for l=1,L do
  Rbottom[#Rbottom+1] = lines[next]
  next = next + 1
end
