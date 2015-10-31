util = require("util")

debug = false

# find the least specific common pattern between a and b
# single length characters are literal inputs.
matchInput = (a, b) ->
  switch
    when a == b and a != ""
      a
    when a == "**/*" and b == "**"
      a
    when a == "**/*"
      b
    when a == "**/" and b == "**"
      a
    when a == "**/" and b == ".*"
      b
    when a == "**/" and b.length == 1
      b
    when a == "**" and (b == ".*" or b.length == 1)
      b
    when a == ".*" and b.length == 1 and b != "/"
      b

matchTransitions = (atr, btr) ->
  matches = []

  if not atr or not btr
    return matches

  for a of atr
    for b of btr
      if ab = matchInput(a, b)
        matches.push([a, b, ab])
      else if ab = matchInput(b, a)
        matches.push([a, b, ab])

  return matches

# find closing } from offset, return an array of patterns in it
splitBrackets = (pattern, opening_offset) ->
  results = []
  depth = 1
  i = last = opening_offset + 1

  while i < pattern.length
    ch = pattern[i]

    if ch == "{"
      depth++

    else if ch == ","
      if depth == 1
        results.push(pattern.substring(last,i))
        last = i + 1

    else if ch == "}"
      depth--

      if depth == 0
        results.push(pattern.substring(last,i))
        break

    i++

  results.closing_offset = i
  return results

addTransition = (nfa, from, input, to) ->
  tr = nfa.transitions[from] ||= {}
  st = nfa.transitions[from][input] ||= {}
  st[to] = true

empty = (object) ->
  for k of object
    return false
  return true

# return true if there are any keys shared between a and b
common = (obj_a, obj_b) ->
  for a of obj_a
    if a of obj_b
      return true
  return false

# shallow-clone the object
clone = (obj) ->
  _obj = {}
  for k,v of obj
    _obj[k] = v
  return _obj

# shallow flatten the array
flatten = (arr) ->
  return [].concat.apply([], arr)

removeTransition = (nfa, from, input, to) ->
  delete nfa.transitions[from][input][to]
  delete nfa.transitions[from][input] if empty(nfa.transitions[from][input])
  delete nfa.transitions[from] if empty(nfa.transitions[from])

# compile fragment by adding transitions to nfa, return last state
compileFragment = (nfa, pattern, curr = null, offset) ->

  if not curr?
    curr = nfa.sid++

  i = 0

  logOffset = (input) ->
    if nfa.offsets
      nfa.offsets.push(input: input, state: curr, offset: offset + i)

  while i < pattern.length

    ch = pattern[i]
    next = null

    switch ch
      when "{"
        # find closing }, split on ",", compile fragments
        split_patterns = splitBrackets(pattern, i)

        bracket_offset = 1 # the { bracket

        last = for _pattern in split_patterns
          _last = compileFragment(nfa, _pattern, curr, offset + i + bracket_offset)
          bracket_offset += _pattern.length + 1 # add length of the pattern + a ,
          _last

        next = nfa.sid++

        for state in last
          addTransition(nfa, state, "", next)

        # jump to the closing }, and keep compiling
        i = split_patterns.closing_offset

      when "*"
        # check if this is a globstar
        if pattern[i+1] == "*"

          # check if we can consume the next / as well, but only if it's not the last character
          if pattern[i+2] == "/" and pattern[i+3] != undefined

            # special case **/*
            if pattern[i+3] == "*"
              addTransition(nfa, curr, "**/*", curr)
              logOffset("**/*")
              i += 3
            else
              addTransition(nfa, curr, "**/", curr)
              logOffset("**/")
              i += 2

          else
            addTransition(nfa, curr, "**", curr)
            logOffset("**")
            i++

        else
          addTransition(nfa, curr, ".*", curr)
          logOffset(".*")

        next = curr unless next?

      when "?"
        next = nfa.sid++
        addTransition(nfa, curr, ".*", next)
        logOffset(".*")

      else
        # it's a literal character
        next = nfa.sid++
        addTransition(nfa, curr, ch, next)

    if next?
      curr = next
    else
      curr = nfa.sid++

    i++

  return curr

# iterate over every transition and return [from_state, input, to_state]
eachTransition = (nfa, callback) ->
  for state of nfa.transitions
    for input, to_states of nfa.transitions[state]
      for to_state of to_states
        callback(state, input, to_state)

  return

# find all states that can be reached from the initial state
reachFrom = (nfa, initial) ->
  states = [initial]
  visited = {}

  while states.length > 0
    state = states.pop()
    visited[state] = true
    for input of nfa.transitions[state]
      for dest of nfa.transitions[state][input]
        states.push(dest) unless visited[dest]

  return visited

# build an inverse transition map, i.e., what states lead to this state
inverseTransitions = (nfa) ->
  inverse = {}

  eachTransition nfa, (state, _, to_state) ->
    inverse[to_state] ||= {}
    inverse[to_state][state] = true

  return inverse

# find all states that can end up in the accepted state
reachAccept = (nfa) ->
  inverse = inverseTransitions(nfa)

  visited = {}
  states = Object.keys(nfa.accept)

  while states.length > 0
    state = states.pop()
    visited[state] = true
    if inverse[state]
      for from_state of inverse[state]
        states.push(from_state) unless visited[from_state]

  visited

# test if the nfa has a state in transitions or accept
hasState = (nfa, state) ->
  state of nfa.transitions or state of nfa.accept

stateProduct = (a_states, b_states) ->
  states = []

  for a of a_states
    for b of b_states
      states.push [a,b]

  return states

# find the longest shared suffix in patterns
findSuffix = (patterns) ->
  first = patterns[0]
  if patterns.length == 1
    return first

  shortest = patterns.map((pat) -> pat.length).sort()[0] || 0
  i = 0

  console.log {shortest} if debug

  while i <= shortest
    ch = first[first.length-i-1]

    console.log {ch} if debug

    for pat in patterns
      console.log "looking at", pat[pat.length-i-1] if debug
      if pat[pat.length-i-1] != ch
        done = true
        break

    if done
      break
    else
      i++

  return first.substring(first.length - i)

NFA = (pattern, options) ->
  @accept = {}
  @sid = 0
  @start = "0"
  @transitions = {}

  # if we're going to record captures, create an array to describe
  # all wildcards, their states and offsets in the pattern
  if options?.capture
    @offsets = []

  if pattern?
    last = compileFragment(@, pattern, null, 0)
    @accept[last] = true

  return

REST_MISMATCH = new Error("mismatched rest segments")

to_glob_helper = (nfa, inverse, match_brackets = true) ->

  cache = {}
  states = Object.keys(nfa.accept)

  for state in states
    cache[state] = ""

  process_state = (state) ->
    console.log new Array(40).join("=") if debug
    console.log "looking at", state if debug

    patterns = []

    for input of nfa.transitions[state]
      console.log "considering", {input, patterns} if debug

      for to_state of nfa.transitions[state][input]
        # ignore self transitions for the moment since we only
        # support * and not + so far.
        if to_state == state
          continue

        console.log {to_state}, "cache =", cache[to_state] if debug

        if not cache[to_state]
          # to_state hasn't been processed yet. add it to the stack and then retry this state
          console.log "to_state", to_state, "not in cache yet, retrying" if debug
          states.push(to_state) unless to_state in states
          states.push(state)
          return

        # a transition to the next state that matches any character (not /) is ?
        if input == ".*"
          input = "?"

        for pat in cache[to_state]
          new_pat = input + pat
          patterns.push(new_pat) unless new_pat in patterns

    if patterns.length > 1 and match_brackets
      # we just got multiple patterns. find the nearest parent state for both
      # and use the {x,y} syntax to compress the pattern.
      console.log "this has multiple patterns", patterns if debug

      suffix = findSuffix(patterns)

      # roll back to the first non } character. otherwise, the {} will be mismatched.
      while suffix[0] == "}"
        suffix = suffix.substring(1)

      console.log {suffix} if debug

      sub_patterns = patterns.map (pat) -> pat.substring(0, pat.length - suffix.length)
      patterns = [ "{" + sub_patterns.join(",") + "}" + suffix ]

    if patterns.length == 0
      patterns.push("")

    if nfa.transitions[state]?["**/*"]?[state]
      console.log "self **/* transition" if debug
      patterns = patterns.map (pat) ->
        if pat.substring(0,4) == "**/*" then pat else "**/*" + pat
    else
      if nfa.transitions[state]?[".*"]?[state]
        console.log "self * transition" if debug
        patterns = patterns.map (pat) ->
          if pat[0] == "*" then pat else "*" + pat

      if nfa.transitions[state]?["**/"]?[state]
        console.log "self **/ transition" if debug
        patterns = patterns.map (pat) ->
          if pat.substring(0,3) == "**/" then pat else "**/" + pat

      else if nfa.transitions[state]?["**"]?[state]
        console.log "self ** transition" if debug
        patterns = patterns.map (pat) ->
          if pat.substring(0,2) == "**" then pat else "**" + pat

    console.log "saving cache for #{state}", patterns if debug
    cache[state] = patterns

    for from_state of inverse[state]
      states.push(from_state) unless (from_state in states) or from_state == state


  while states.length > 0
    state = states.shift()
    process_state(state)

  result = cache[nfa.start]

  if not result?
    throw new Error("missing cache for start state")

  if result.length > 1
    "{" + result.join(",") + "}"
  else
    result[0]

# generate the glob expression
toGlob = (nfa) ->

  inverse = inverseTransitions(nfa)
  # remove self transitions from the index
  for state of inverse
    delete inverse[state][state]

  console.log "inverse", inverse if debug

  try
    result = to_glob_helper(nfa, inverse)
  catch e
    if e == REST_MISMATCH
      # without trying to match brackets
      console.log "retrying due to rest mismatch" if debug
      result = to_glob_helper(nfa, inverse, false)
    else
      console.log "got some strange error" if debug
      throw e

  console.log "the final", result if debug

  return result

addEpsilonTransitions = (nfa, i, j, a_eps, b_eps) ->
  if a_eps
    for to_state of a_eps
      addTransition(nfa, "#{i}:#{j}", "", "#{to_state}:#{j}")

  if b_eps
    for to_state of b_eps
      addTransition(nfa, "#{i}:#{j}", "", "#{i}:#{to_state}")

# convert input like .* to the pattern representation -> *
inputToPattern = (input) ->
  switch input
    when ".*"
      "*"
    else
      input

# split path into directory and base components
# similar to [path.dirname, path.basename], but preserve trailing / in dirname and
# also return empty string when no directory instead of returning "."
dirBaseSplit = (path) ->
  last = path.lastIndexOf("/")
  if last == -1
    return ["", path]
  else
    return [path.substring(0,last+1), path.substring(last+1)]

# given the final nfa, offsets for all globs in the first pattern and capturing transitions
# return an array of captured segments in their source order
extractCaptures = (nfa, anfa, captures) ->
  console.log "extracting captures\n", captures, anfa.offsets if debug

  # create an index of capturing globs found in the first pattern indexed by state-input
  globs = {}
  for glob in anfa.offsets
    glob = clone(glob)
    globs[glob.state + "/" + glob.input] = glob
    glob.captured = []

  for capture in captures
    # check if the transition is still alive in the NFA, if so, add to the corresponding glob above
    if hasState(nfa, capture.state) and hasState(nfa, capture.to_state)
      console.log "capture alive", capture.captured if debug

      [i,j] = capture.state.split(":")

      if glob = globs[i + "/" + capture.input]
        glob.captured.push(capture.captured)

  final_captures = []
  for key, glob of globs
    final_captures.push(offset: glob.offset, capture: glob.captured.map(inputToPattern).join(""), input: glob.input)

  final_captures = final_captures.sort((a,b) -> a.offset - b.offset).map (glob) ->
    # split **/* captures into two, one for the ** part, the other for *
    if glob.input == "**/*"
      return dirBaseSplit(glob.capture)
    else
      return glob.capture

  return flatten(final_captures)

intersectNFAs = (anfa, bnfa, options) ->
  console.log "intersecting" if debug
  console.log util.inspect(anfa, false, null) if debug
  console.log util.inspect(bnfa, false, null) if debug

  nfa = new NFA()

  if options?.capture
    capture = options?.capture

  for i in [0..anfa.sid]
    for j in [0..bnfa.sid]

      console.log "processing: #{i}:#{j}" if debug

      # if one of the states has an ε transition, allow the nfa to transition between the compund states
      addEpsilonTransitions(nfa, i, j, anfa.transitions[i]?[""], bnfa.transitions[j]?[""])

      for [a_input, b_input, ab_input] in matchTransitions(anfa.transitions[i], bnfa.transitions[j])
        console.log "matched #{a_input} and #{b_input} as #{ab_input}" if debug

        for [a, b] in stateProduct(anfa.transitions[i][a_input], bnfa.transitions[j][b_input])
          console.log "adding transition from #{i}:#{j} with '#{ab_input}' to #{a}:#{b}" if debug

          if capture and a_input in [".*", "**", "**/", "**/*"]
            capture.push(input: a_input, state: "#{i}:#{j}", to_state: "#{a}:#{b}", captured: b_input)

          addTransition(nfa, "#{i}:#{j}", ab_input, "#{a}:#{b}")

  for a of anfa.accept
    for b of bnfa.accept
      nfa.accept["#{a}:#{b}"] = true

  nfa.start = "0:0"

  console.log util.inspect(nfa, false, null) if debug

  # list all states reachable from the start
  forward = reachFrom(nfa, nfa.start)

  console.log "foward", forward if debug

  # remove final states not accesible from the start
  for state of nfa.accept
    if not forward[state]
      delete nfa.accept[state]

  # if we can't reach any accept states, there's no intersection
  if not common(nfa.accept, forward)
    console.log "there are no accept states reachable from start" if debug
    return false

  # same for states reachable backwards from any accept states
  backward = reachAccept(nfa)

  if not backward[nfa.start]
    console.log "start state cannot be reached from any acept states" if debug
    return false

  eachTransition nfa, (state, input, to_state) ->
    keep_state = forward[state] and backward[state]
    keep_to = forward[to_state] and backward[to_state]

    if not keep_state or not keep_to
      removeTransition(nfa, state, input, to_state)

  console.log util.inspect(nfa, false, null) if debug

  return nfa

intersect = (apat, bpat, options = {}) ->

  if options.debug
    debug = true

  if options.capture
    if typeof options.capture != "function"
      throw new Error("glob-intersect: capture option should be a function, was '#{typeof options.capture}'")

    capture = []

  try

    anfa = new NFA(apat, {capture})
    bnfa = new NFA(bpat, {capture})
    nfa = intersectNFAs(anfa, bnfa, {capture})

    console.log "intersection", util.inspect(nfa, false, null) if debug

    if nfa
      glob = toGlob(nfa)

      if capture
        options.capture(extractCaptures(nfa, anfa, capture)...)

  finally
    debug = false

  if glob?
    return glob
  else
    return false

module.exports = intersect
