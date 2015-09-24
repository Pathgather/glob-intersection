chalk = require("chalk")
util = require("util")

debug = false

# match transitions from a and b:
# 1) char and char -> char
# 4) char and "" -> char
# 2) glob and char -> char
# 3) glob and "" -> glob
# 4) ""   and "" -> ""
matchInput = (a, b) ->
  switch
    when a == b and a != ""
      a
    when a == ".*" and b.length == 1
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

removeTransition = (nfa, from, input, to) ->
  delete nfa.transitions[from][input][to]
  delete nfa.transitions[from][input] if empty(nfa.transitions[from][input])
  delete nfa.transitions[from] if empty(nfa.transitions[from])

# compile fragment by adding transitions to nfa, return last state
compileFragment = (nfa, pattern, curr = null) ->

  if not curr?
    curr = nfa.sid++

  i = 0
  while i < pattern.length
    ch = pattern[i]
    next = null

    switch ch
      when "{"
        # find closing }, split on ",", compile fragments
        split_patterns = splitBrackets(pattern, i)

        last = for _pattern in split_patterns
          compileFragment(nfa, _pattern, curr)

        next = nfa.sid++

        for state in last
          addTransition(nfa, state, "", next)

        # jump to the closing }, and keep compiling
        i = split_patterns.closing_offset

      when "*"
        next = nfa.sid++
        addTransition(nfa, curr, ".*", curr)
        addTransition(nfa, curr, "", next)

      else
        # it's a literal character
        next = nfa.sid++
        addTransition(nfa, curr, ch, next)

    # add an epsilon transition to the same state to help with intersection later
    # addTransition(nfa, curr, "", curr)

    if next
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

assertNoEpsStates = (nfa) ->
  eachTransition nfa, (from, input, to) ->
    if input == ""
      throw new Error("assertion failed: nfa has epsilon states")

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

NFA = (pattern) ->
  @accept = {}
  @sid = 0
  @start = "0"
  @transitions = {}

  if pattern?
    last = compileFragment(@, pattern)
    @accept[last] = true

  return

clone = (object) ->
  ret = {}
  for key of object
    ret[key] = object[key]
  ret

hasMultipleTransitionsTo = (nfa, state, inverse) ->
  from_states = Object.keys(inverse[state] || {})

  if not from_states? or from_states.length == 0
    return false

  if from_states.length > 1
    return true

  count = 0

  for input, to_states of nfa.transitions[from_states[0]]
    if to_states[state]
      count++

  return count > 1


REST_MISMATCH = new Error("mismatched rest segments")

to_glob_helper = (nfa, inverse, match_brackets = true) ->

  cache = {}
  states = Object.keys(nfa.accept)

  for state in states
    cache[state] = ""

  process_state = (state) ->
    console.log new Array(40).join("=") if debug
    console.log "looking at", chalk.red(state) if debug

    patterns = []

    for input of nfa.transitions[state]
      if input.length != 1 and input != ""
        continue

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
          # if to_state in states
            # this state must not have been processed, move this state to the end of the queue
          #   console.log "no cache entry for #{to_state}, trying to delay #{state}"
          #   return states.push(state)
          # else
          #   throw new Error("no cache entry for #{to_state} and one is not being processed")

        for pat in cache[to_state]
          new_pat = input + pat
          patterns.push(new_pat) unless new_pat in patterns

    if patterns.length > 1 and match_brackets
      # we just got multiple patterns. find the nearest parent state for both
      # and use the {x,y} syntax to compress the pattern.
      console.log chalk.yellow("this has multiple patterns"), patterns if debug

      suffix = findSuffix(patterns)

      console.log {suffix} if debug

      sub_patterns = patterns.map (pat) -> pat.substring(0, pat.length - suffix.length)
      patterns = [ "{" + sub_patterns.join(",") + "}" + suffix ]

    if patterns.length == 0
      patterns.push("")

    if nfa.transitions[state]?[".*"]?[state]
      console.log "self * transition" if debug
      patterns = patterns.map (pat) -> "*" + pat

    console.log "after processing", {state, patterns} if debug

    # if inverse[state] and match_brackets
    #   if hasMultipleTransitionsTo(nfa, state, inverse)
    #     console.log chalk.yellow("state has multiple incoming"), Object.keys(inverse[state]) if debug
    #     patterns[0] = "}" + patterns[0]

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
      console.log chalk.magenta("retrying due to rest mismatch") if debug
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


intersect = (anfa, bnfa) ->
  console.log "intersecting" if debug
  console.log util.inspect(anfa, false, null) if debug
  console.log util.inspect(bnfa, false, null) if debug

  nfa = new NFA()

  for i in [0..anfa.sid]
    for j in [0..bnfa.sid]

      console.log chalk.cyan("processing: #{i}:#{j}") if debug

      # if one of the states has an ε transition, allow the nfa to transition between the compund states
      addEpsilonTransitions(nfa, i, j, anfa.transitions[i]?[""], bnfa.transitions[j]?[""])

      for [a_input, b_input, ab_input] in matchTransitions(anfa.transitions[i], bnfa.transitions[j])
        console.log chalk.cyan("matched #{a_input} and #{b_input} as #{ab_input}") if debug
        for [a, b] in stateProduct(anfa.transitions[i][a_input], bnfa.transitions[j][b_input])
          console.log chalk.cyan("adding transition from #{i}:#{j} with '#{ab_input}' to #{a}:#{b}") if debug
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

  # mergeEpsStates(nfa)
  # assertNoEpsStates(nfa)

  return nfa

module.exports = (apat, bpat, options = {}) ->

  if options.debug
    debug = true

  try

    anfa = new NFA(apat)
    bnfa = new NFA(bpat)
    nfa = intersect(anfa, bnfa)

    console.log chalk.green("intersection"), util.inspect(nfa, false, null) if debug

    glob = toGlob(nfa) if nfa

  finally
    debug = false

  if glob?
    return glob
  else
    return false
