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
  ["**/b", "*/b", "*/b"]
  ["a/**", "a/*", "a/*"]
  ["a/**/b", "a/*/b", "a/*/b"]
  ["**", "/a", "/a"]
  ["**", "/a/*/c/*/e", "/a/*/c/*/e"]

  ["/hello/**/*.js", "/hello/world/*", "/hello/world/*.js"]
  ["/hello/**", "/**/*.js", "/hello/**/*.js"]
  ["/hello/**", "**/*.js", "/hello/**/*.js"]

  ["/**/*.js", "hello.js", false]
  ["/**/*.js", "/hello.js", "/hello.js"]
  ["**/*.js", "hello.js", "hello.js"]
  ["**/*.js", "/hello.js", "/hello.js"]
  ["**.js", "hello.js", "hello.js"]
  ["**.js", "/hello.js", "/hello.js"]
  ["/**.js", "hello.js", false]
  ["/**.js", "/hello.js", "/hello.js"] # not a compatible intersection
  ["/**", "**", "/**"]
  ["/**", "*", false]
  ["**/", "*", false]

  # Copyright (c) 2014-2015, Jon Schlinkert. From https://github.com/jonschlinkert/micromatch
  ['**/*.js', 'a/b/c/z.js', 'a/b/c/z.js']
  ['**/*.js', 'a/b/z.js', 'a/b/z.js']
  ['**/*.js', 'a/z.js', 'a/z.js']
  ['**/*.js', 'z.js', 'z.js']
  ['**/z*', 'z.js', 'z.js']

  ['a/b/**/*.js', 'a/b/c/d/e/z.js', 'a/b/c/d/e/z.js']
  ['a/b/**/*.js', 'a/b/c/d/z.js', 'a/b/c/d/z.js']
  ['a/b/c/**/*.js', 'a/b/c/z.js', 'a/b/c/z.js']
  ['a/b/c**/*.js', 'a/b/c/z.js', 'a/b/c/z.js']
  ['a/b/**/*.js', 'a/b/c/z.js', 'a/b/c/z.js']
  ['a/b/**/*.js', 'a/b/z.js', 'a/b/z.js']

  ['a/b/**/*.js', 'a/z.js', false]
  ['a/b/**/*.js', 'z.js', false]

  ['**/z*.js', 'z.js', 'z.js']
  ['a/b-*/**/z.js', 'a/b-c/z.js', 'a/b-c/z.js']
  ['a/b-*/**/z.js', 'a/b-c/d/e/z.js', 'a/b-c/d/e/z.js']

  ['**', 'a/b/c/d', 'a/b/c/d']
  ['**', 'a/b/c/d/', 'a/b/c/d/']
  ['**/**', 'a/b/c/d/', 'a/b/c/d/']
  ['**/b/**', 'a/b/c/d/', 'a/b/c/d/']
  ['a/b/**', 'a/b/c/d/', 'a/b/c/d/']
  ['a/b/**/', 'a/b/c/d/', 'a/b/c/d/']
  ['a/b/**/c/**/', 'a/b/c/d/', 'a/b/c/d/']
  ['a/b/**/c/**/d/', 'a/b/c/d/', 'a/b/c/d/']
  ['a/b/**/f', 'a/b/c/d/', false]
  ['a/b/**/**/*.*', 'a/b/c/d/e.f', 'a/b/c/d/e.f']
  ['a/b/**/*.*', 'a/b/c/d/e.f', 'a/b/c/d/e.f']
  ['a/b/**/c/**/d/*.*', 'a/b/c/d/e.f', 'a/b/c/d/e.f']
  ['a/b/**/d/**/*.*', 'a/b/c/d/e.f', 'a/b/c/d/e.f']
  ['a/b/**/d/**/*.*', 'a/b/c/d/g/e.f', 'a/b/c/d/g/e.f']
  ['a/b/**/d/**/*.*', 'a/b/c/d/g/g/e.f', 'a/b/c/d/g/g/e.f']
  # /Copyright

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

capture_tests = [
  ["**/*.js", "b.js", ["", "b"]]
  ["**/*.js", "/b.js", ["/", "b"]]
  ["**/*.js", "a/b.js", ["a/", "b"]]
  ["**/*.js", "a/b/c.js", ["a/b/", "c"]]

  ["**/*.coffee", "/src/*", ["/src/", "*"]]
  ["**/*.coffee", "/src/**/*", ["/src/**/", "*"]]

  ["a*b", "aa*bb", ["a*b"]]
  ["a*b", "aa/bb", false]
  ["**ab", "abab", ["ab"]]
  ["**ab", "/ab/ab", ["/ab/"]]
  ["**/", "ab", false]
  ["**/", "*", false]
  ["**/", "ab/", ["ab"]]
  ["**", "*", ["*"]]

  ["??", "ab", ["a", "b"]]
  ["?", "*", ["*"]]

  # some of the weirder cases.
  ["?", "*", ["*"]]
  ["?", "*a", ["a"]]
  ["?", "**/*", ["**/*"]]
  ["*", "*", ["*"]]
  ["*", "**", ["**"]]
  ["*", "**/", false]
  ["*", "**/*", ["**/*"]]
  ["**/*", "**/*", ["**/", "*"]]

  # buggy!
  ["*/*", "**/*", ["**/*","**/*"]]
]

describe "glob-intersect", ->
  describe "patterns", ->
    for entry in tests
      do (entry) ->
        it "('#{entry[0]}', '#{entry[1]}')", ->
          expect(m(entry[0], entry[1], {debug})).toBe(entry[2])
          expect(m(entry[1], entry[0])).toBe(entry[2])

  describe "expanded braces", ->
    for entry in brace_tests
      do (entry) ->
        it "('#{entry[0]}', '#{entry[1]}')", ->
          expect(braces(m(entry[0], entry[1], {debug}))).toMatchArray(entry[2])
          expect(braces(m(entry[1], entry[0]))).toMatchArray(entry[2])

  describe "capture", ->
    capture = null
    beforeEach ->
      capture = jasmine.createSpy("capture callback")

    for entry in capture_tests
      do (entry) ->
        it "('#{entry[0]}', '#{entry[1]}', capture: ...)", ->
          m(entry[0], entry[1], {debug, capture})
          if entry[2]
            expect(capture).toHaveBeenCalledWith(entry[2]...)
          else
            expect(capture).not.toHaveBeenCalled()

    it "should work with array.push as argument", ->
      captured = []
      m("**/*", "hello/cruel/world", capture: [].push.bind(captured))
      expect(captured).toEqual(["hello/cruel/", "world"])
