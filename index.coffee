chalk = require("chalk")
util = require("util")

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

    # console.log ch

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
      console.log "blank", state, "->", to_state
      state = findFirst(state)
      if merge[to_state]
        console.log "already merging", state, "to", merge[to_state]
        if state != merge[to_state]
          merge[state] = merge[to_state]
      else
        merge[to_state] = state

  console.log "merge", merge

  # copy over all transitions
  eachTransition nfa, (state, input, to_state) ->
    if input != ""
      if merge[state] or merge[to_state]
        state = merge[state] || state
        to_state = merge[to_state] || to_state
        console.log "copy", {state, input, to_state}
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

  if pattern
    last = compileFragment(@, pattern)
    @accept[last] = true

  return

clone = (object) ->
  ret = {}
  for key of object
    ret[key] = object[key]
  ret

toGlob = (nfa) ->

  inverse = inverseTransitions(nfa)
  console.log "inverse", inverse

  cache = {}
  patterns = {}
  states = []
  visited = {}

  for state of nfa.accept
    cache[state] = [""]
    states.push(state)

  while states.length > 0
    state = states.pop()
    visited[state] = true

    console.log chalk.cyan("processing state"), state

    if inverse[state]
      console.log "states leading to this", inverse[state]
      for from_state of inverse[state]
        continue if cache[from_state]
        prefixes = []

        for input, to_states of nfa.transitions[from_state]
          if to_states[state]
            console.log "input", {from_state, state, input}

            for prefix in cache[state]
              prefixes.push(input + prefix)

        states.push(from_state) unless state == from_state

        console.log "state", from_state, "prefixes are", prefixes
        cache[from_state] = prefixes

  console.log cache
  # iterate = (state, pattern) ->
    # console.log "iterate", {state, pattern, last}

    # if nfa.accept[state]
    #   console.log "accepting", pattern
    #   patterns[pattern] = true

    # if nfa.transitions[state]

    #   cycle = state == last

    #   console.log "cycle", cycle

    #   if not visited[state] or cycle
    #     visited[state] = true

    #     if depth++ > 10
    #       throw new Error("iteration limit")

    #     for input in order
    #       if to_states = nfa.transitions[state][input]
    #         for to_state of to_states
    #           console.log "order iterate", input, to_state
    #           if not cycle or to_state != state
    #             iterate(to_state, pattern + input, clone(visited), state)

    #     for input, to_states of nfa.transitions[state]
    #       if not input in order
    #         for to_state of to_states
    #           console.log "other iterate", input, to_state
    #           if not cycle or to_state != state
    #             iterate(to_state, pattern + input, clone(visited), state)

  # iterate("0:0", "")

  # patterns = Object.keys(patterns)

  # if patterns.length > 1
  #   "{" + patterns.join(",") + "}"
  # else if patterns.length == 1
  #   patterns[0]
  # else
  #   ""

  # str = []
  # curr = 0

  # loop
  #   if not @transitions[curr]
  #     break

  #   inputs = Object.keys(@transitions[curr])

  #   if inputs.length == 0
  #     break

  #   if inputs[0] == ".*"
  #     str.push "*"
  #     input = ""
  #   else
  #     input = inputs[0]
  #     str.push input

  #   curr = @transitions[curr][input]

  # return str.join("")

# toCacheKey = (a_states, b_states) ->
#   Object.keys(a_states).sort().join() + "|" + Object.keys(b_states).sort()

intersect = (anfa, bnfa) ->
  console.log "intersecting"
  console.log util.inspect(anfa, false, null)
  console.log util.inspect(bnfa, false, null)

  nfa = new NFA()

  for i in [0..anfa.sid]
    for j in [0..bnfa.sid]

      # if one of the states has an ε transition, allow the nfa to transition between the compund states
      if (a_eps = anfa.transitions[i]?[""]) or (b_eps = bnfa.transitions[j]?[""])
        if a_eps and not b_eps
          for to_state of a_eps
            addTransition(nfa, "#{i}:#{j}", "", "#{to_state}:#{j}")
        else if not a_eps and b_eps
          for to_state of a_eps
            addTransition(nfa, "#{i}:#{j}", "", "#{j}:#{to_state}")

      for [a_input, b_input, ab_input] in matchTransitions(anfa.transitions[i], bnfa.transitions[j])
        for [a, b] in stateProduct(anfa.transitions[i][a_input], bnfa.transitions[j][b_input])
          addTransition(nfa, "#{i}:#{j}", ab_input, "#{a}:#{b}")

  for a of anfa.accept
    for b of bnfa.accept
      nfa.accept["#{a}:#{b}"] = true

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

  console.log util.inspect(nfa, false, null)

  mergeEpsStates(nfa)

  return nfa

module.exports = (apat, bpat) ->

  anfa = new NFA(apat)
  bnfa = new NFA(bpat)

  if nfa = intersect(anfa, bnfa)
    console.log util.inspect(nfa, false, null)
  else
    return false
