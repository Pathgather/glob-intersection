m = require("../index")

tests = [

  # basic patterns
  ["", "", ""]
  ["", "*", ""]
  ["a", "", false]
  ["a", "b", false]
  ["a", "*", "a"]
  ["a", "a*", "a"]
  ["a*", "a*", "a*"]
  ["a*", "ab", "ab"]
  ["a*", "ab*", "ab*"]
  ["a*", "*b", "a*b"]
  ["b", "*b", "b"]
  ["*b", "*b", "*b"]
  ["*b", "ab", "ab"]
  ["*b", "*ab", "*ab"]
  ["a*b", "ab", "ab"]
  ["a*b", "a*", "a*b"]
  ["a*b", "ab", "ab"]

  # bracket patterns
  ["{a,b,c}", "a", "a"]
  ["{a,}", "a", "a"]
  ["{,a}", "a", "a"]
  ["{,a}", "", ""]
  ["{a}", "a", "a"]
  ["{a,b}", "*", "{a,b}"]
  ["x{a,b}", "*", "x{a,b}"]
  ["{a,b}yy", "*", "{a,b}yy"]
  ["{a,b}", "{b,c}", "b"]
  ["{a,b}", "{c,d}", false]
  ["{a,b,c}", "{y,a,x,c}", "{a,c}"]
  ["{xaa,yaa,yawn}", "{x,y}*a", "{x,y}aa"]
]

describe "glob-intersect", ->
  for entry in tests
    do (entry) ->
      it "('#{entry[0]}', '#{entry[1]}')", ->
        expect(m(entry[0], entry[1])).toBe(entry[2])
        expect(m(entry[1], entry[0])).toBe(entry[2])

