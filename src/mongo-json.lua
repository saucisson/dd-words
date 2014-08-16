--[[
[
  '{{repeat(5, 7)}}',
  {
    _id: '{{objectId()}}',
    index: '{{index()}}',
    guid: '{{guid()}}',
    isActive: '{{bool()}}',
    age: '{{integer(20, 40)}}',
    eyeColor: '{{random("blue", "brown", "green")}}',
    name: '{{firstName()}} {{surname()}}',
    gender: '{{gender()}}',
    email: '{{email()}}',
    phone: '+1 {{phone()}}',
    address: '{{integer(100, 999)}} {{street()}}, {{city()}}, {{state()}}, {{integer(100, 10000)}}',
    tags: [
      '{{repeat(7)}}',
      '{{lorem(1, "words")}}'
    ],
    friends: [
      '{{repeat(3)}}',
      '{{firstName()}} {{surname()}}'
    ],
    greeting: function (tags) {
      return 'Hello, ' + this.name + '! You have ' + tags.integer(1, 10) + ' unread messages.';
    },
    favoriteFruit: function (tags) {
      var fruits = ['apple', 'banana', 'strawberry'];
      return fruits[tags.integer(0, fruits.length - 1)];
    }
  }
]
--]]

local json  = require "dkjson"
local mongo = require "mongo"

local db = assert (mongo.Connection.New ())
assert (db:connect "localhost")
assert (db:remove ("test.values", {}))


for _, name in ipairs (arg) do
  print ("Inserting data contained in " .. name .. "...")
  local file = io.open (name, "r")
  local contents = file:read ("*all")
  local data = json.decode (contents)
  assert (db:insert_batch ("test.values", data))
  file:close ()
  print ("Inserted " .. (db:count "test.values") .. " entries.")
end

