![npm](https://img.shields.io/npm/v/glob-intersection.svg)
![build](https://img.shields.io/circleci/project/Pathgather/glob-intersection/master.svg)
![dependencies](https://img.shields.io/david/Pathgather/glob-intersection.svg)
![devDependencies](https://img.shields.io/david/dev/Pathgather/glob-intersection.svg)

# glob-intersection
Find the intersection of two glob patterns

```javascript
intersect = require("glob-intersection")

intersect("**/*.{js,coffee}", "/hello/world/*.??")
# => "/hello/world/*.js"

intersect("hello", "world")
# => false

intersect("{a,b,c,x,d}", "{x,y,z,c,w}")
# => "{c,x}"

intersect("*a*b*", "*x*y*")
# => "*{a*{b*x*y,x*{b*y,y*b}},x*{a*{b*y,y*b},y*a*b}}*"
# braces(_) => '["*a*b*x*y*","*x*a*b*y*","*a*x*b*y*","*x*y*a*b*","*x*a*y*b*","*a*x*y*b*"]'
```

## Caveats

Full compatability with Bash or other globbing libraries was not a design goal. In a lot of ways this library is more permissive. For example, `*` will match dotfiles and `**` will simply match any character, so a pattern like `**cd` will intersect with `/abcd` while the glob match itself would fail.

Please see the tests for more examples.

Supported glob features:

  1. `*` matches any number of non `/` character
  2. `**` matches any number of characters
  3. `?` maches exactly one non `/` character
  4. `{a,b}` matches either `a` or `b` and brackets can be nested

Any and all issue reports are appreciated!
