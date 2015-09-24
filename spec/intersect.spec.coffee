m = require("../index.coffee")
braces = require("braces")
debug = false

matchers =
  toMatchArray: (util) ->
    compare: (actual, expected) ->
      pass: util.equals(actual.sort?(), expected.sort?())
      message: "Expected #{jasmine.pp(expected)} to match #{actual} ignoring order"

beforeEach ->
  jasmine.addMatchers(matchers)

tests = [

  # * patterns
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

  # * patterns with /
  ["/", "*", false]
  ["a/", "*", false]
  ["/*", "/a", "/a"]
  ["/hello/*", "/*/world", "/hello/world"]
  ["/hello/*/*", "/*/world/*", "/hello/world/*"]

  # ? patterns
  ["?", "a", "a"]
  ["?", "", false]
  ["?", "/", false]
  ["??", "a?", "a?"]
  ["?a?", "b??", "ba?"]
  ["???", "??", false]
  ["*?", "a", "a"]
  ["***?***?**", "ab", "ab"]
  ["***?***?**?**", "ab", false]

  # ** patterns
  ["**", "", ""]
  ["**", "a", "a"]
  ["**", "*", "*"]
  ["**", "/a", "/a"]
  ["**", "/a/*/c/*/e", "/a/*/c/*/e"]
  ["/hello/**/*.js", "/hello/world/*", "/hello/world/*.js"]

  # {} patterns
  ["{a,b,c}", "a", "a"]
  ["{a,}", "a", "a"]
  ["{,a}", "a", "a"]
  ["{,a}", "", ""]
  ["{}", "*", ""]
  ["{a}", "a", "a"]
  ["{a,b}", "*", "{a,b}"]
  ["x{a,b}", "*", "x{a,b}"]
  ["{a,b}yy", "*", "{a,b}yy"]
  ["{a,b}", "{b,c}", "b"]
  ["{a,b}", "{c,d}", false]
  ["{a,b,cx}", "{y,a,x,c,cx}", "{a,cx}"]
  ["{xaa,yaa,yawn}", "{x,y}*a", "{x,y}aa"]
  ["{aaaab,aaab}", "*", "{a,}aaab"]
  ["{x,{a,b}}", "*", "{x,a,b}"]
  ["{{x,y},{ab{bc,{de}}}}", "*", "{x,y,ab{bc,de}}"]
  ["{{{},{{}}},{{{},{{}}}}}", "*", ""]
]

brace_tests = [
  ["*a*", "*b*", ["*a*b*", "*b*a*"]]
  ["*a*b*", "*c*", ["*a*b*c*", "*a*c*b*", "*c*a*b*"]]
  ["*a*b*", "*c*d*", ["*a*b*c*d*","*a*c*b*d*","*a*c*d*b*","*c*a*b*d*","*c*a*d*b*","*c*d*a*b*"]]
]

describe "glob-intersect", ->
  for entry in tests
    do (entry) ->
      it "('#{entry[0]}', '#{entry[1]}')", ->
        expect(m(entry[0], entry[1], {debug})).toBe(entry[2])
        expect(m(entry[1], entry[0])).toBe(entry[2])


  for entry in brace_tests
    do (entry) ->
      it "('#{entry[0]}', '#{entry[1]}')", ->
        expect(braces(m(entry[0], entry[1], {debug}))).toMatchArray(entry[2])
        expect(braces(m(entry[1], entry[0]))).toMatchArray(entry[2])
