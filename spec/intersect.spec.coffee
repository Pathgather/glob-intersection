m = require("../index")

tests = [
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
]

describe "", ->
  it "", ->
    expect(m("*b", "ab")).toBe(false)

xdescribe "glob-intersect", ->
  for entry in tests
    do (entry) ->
      it "('#{entry[0]}', '#{entry[1]}')", ->
        expect(m(entry[0], entry[1])).toBe(entry[2])

