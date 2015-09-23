# chalk = require("chalk")
# util = require("util")

debug = false

# match transitions from a and b:
# 1) char and char -> char
# 4) char and "" -> char
# 2) glob and char -> char
# 3) glob and "" -> glob
# 4) ""   and "" -> ""
matchTransitions = (atr, btr) ->
  matches = []

  if not atr or not btr
    return matches

  for a of atr
    for b of btr
      ab = null

      ab = switch
        when a == b
          ab = a
        when (a == ".*" || a == "") and (b.length == 1 || b == "")
          ab = b
        when (a.length == 1 || b == "") and (b == ".*" || b == "")
          ab = a

      if ab?
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

    console.log ch if debug

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

# merge all state groups that are connected via an epsilon state
# into the first state that was added. this essentially converts
# the automata to a DFA.
mergeEpsStates = (nfa) ->
  merge = {}

  findFirst = (state) ->
    if merge[state]
      findFirst(merge[state])
    else
      state

  # collect groups of epsilon states
  eachTransition nfa, (state, input, to_state) ->
    if input == ""
      console.log "blank", state, "->", to_state if debug
      state = findFirst(state)
      if merge[to_state]
        console.log "already merging", state, "to", merge[to_state] if debug
        if state != merge[to_state]
          merge[state] = merge[to_state]
      else
        merge[to_state] = state

  console.log "merge", merge if debug

  # copy over all transitions
  eachTransition nfa, (state, input, to_state) ->
    if input != ""
      if merge[state] or merge[to_state]
        state = merge[state] || state
        to_state = merge[to_state] || to_state
        console.log "copy", {state, input, to_state} if debug
        addTransition(nfa, state, input, to_state)

  # remove transtions and targets
  eachTransition nfa, (state, input, to_state) ->
    if merge[to_state] or merge[state]
      removeTransition(nfa, state, input, to_state)

  # update accept states
  for state of nfa.accept
    if merge[state]
      nfa.accept[merge[state]] = true
      delete nfa.accept[state]

stateProduct = (a_states, b_states) ->
  states = []

  for a of a_states
    for b of b_states
      states.push [a,b]

  return states

NFA = (pattern) ->
  @sid = 0
  @accept = {}
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

  while states.length > 0
    state = states.shift()

    console.log new Array(40).join("=") if debug
    console.log "looking at", chalk.red(state) if debug

    patterns = []

    for input of nfa.transitions[state]
      continue if input.length != 1
      console.log "considering", {input} if debug

      for to_state of nfa.transitions[state][input]
        # ignore self transitions for the moment since we only
        # support * and not + so far.
        if to_state == state
          continue

        if not cache[to_state]
          throw new Error("no cache for to_state: #{to_state}")
        for pat in cache[to_state]
          patterns.push input + pat

    if patterns.length > 1 and match_brackets
      # we just got multiple patterns. find the nearest parent state for both
      # and use the {x,y} syntax to compress the pattern.
      console.log chalk.yellow("this has multiple patterns"), patterns if debug

      rest = {}

      sub_patterns = patterns.map (pat) ->
        sub = splitBrackets(pat, -1)
        rest[pat.substring(sub.closing_offset+1)] = true
        return sub[0]

      rest = Object.keys(rest)

      # in case the ends are mismatched, assume that this glob doesn't have a compact
      # representation and retry without adding brackets
      if rest.length > 1
        throw REST_MISMATCH

      patterns.splice(0)
      patterns[0] = "{" + sub_patterns.join(",") + "}" + rest

    if patterns.length == 0
      patterns.push("")

    if nfa.transitions[state]?[".*"]?[state]
      console.log "self * transition" if debug
      patterns = patterns.map (pat) -> "*" + pat

    console.log "after processing", {state, patterns} if debug

    if inverse[state] and match_brackets
      if hasMultipleTransitionsTo(nfa, state, inverse)
        console.log chalk.yellow("state has multiple incoming"), Object.keys(inverse[state]) if debug
        patterns[0] = "}" + patterns[0]

    cache[state] = patterns

    for from_state of inverse[state]
      states.push(from_state) unless (from_state in states) or from_state == state

  final = cache["0:0"]

  if final.length > 1
    "{" + final.join(",") + "}"
  else
    final[0]

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

intersect = (anfa, bnfa) ->
  console.log "intersecting" if debug
  console.log util.inspect(anfa, false, null) if debug
  console.log util.inspect(bnfa, false, null) if debug

  nfa = new NFA()

  for i in [0..anfa.sid]
    for j in [0..bnfa.sid]

      console.log "constructing #{i}:#{j}" if debug

      # if one of the states has an ε transition, allow the nfa to transition between the compund states
      if (a_eps = anfa.transitions[i]?[""]) or (b_eps = bnfa.transitions[j]?[""])
        console.log {a_eps, b_eps} if debug
        if a_eps and not b_eps
          for to_state of a_eps
            addTransition(nfa, "#{i}:#{j}", "", "#{to_state}:#{j}")
        else if not a_eps and b_eps
          for to_state of b_eps
            addTransition(nfa, "#{i}:#{j}", "", "#{j}:#{to_state}")

      for [a_input, b_input, ab_input] in matchTransitions(anfa.transitions[i], bnfa.transitions[j])
        for [a, b] in stateProduct(anfa.transitions[i][a_input], bnfa.transitions[j][b_input])
          addTransition(nfa, "#{i}:#{j}", ab_input, "#{a}:#{b}")

  for a of anfa.accept
    for b of bnfa.accept
      nfa.accept["#{a}:#{b}"] = true

  console.log util.inspect(nfa, false, null) if debug

  # list all states reachable from 0:0
  forward = reachFrom(nfa, "0:0")

  # if we can't reach any accept states, there's no intersection
  if not common(nfa.accept, forward)
    return false

  # same for states reachable backwards from any accept states
  backward = reachAccept(nfa)

  if not backward["0:0"]
    return false

  eachTransition nfa, (state, input, to_state) ->
    keep_state = forward[state] and backward[state]
    keep_to = forward[to_state] and backward[to_state]

    if not keep_state or not keep_to
      removeTransition(nfa, state, input, to_state)

  console.log util.inspect(nfa, false, null) if debug

  mergeEpsStates(nfa)

  return nfa

module.exports = (apat, bpat) ->

  anfa = new NFA(apat)
  bnfa = new NFA(bpat)
  nfa = intersect(anfa, bnfa)

  console.log util.inspect(nfa, false, null) if debug

  if nfa
    return toGlob(nfa)
  else
    return false
