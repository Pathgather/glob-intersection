addEpsilonStates = (nfa, states) ->
  # add all epsilon states
  changed = true
  while changed
    changed = false
    for state of states
      if (s = nfa.transitions[state][""])?
        if not states[s]
          changed = true
          states[s] = true

# union all transitions from states
unionTransitions = (nfa, states) ->
  tr = {}

  for state of states
    for input, to_state of nfa.transitions[state]
      tr[input] ||= []
      tr[input].push(to_state)

  return tr

# match all inputs from atr and btr using the following:
# * and *  ->  *
# * and ch -> ch
matchTransitions = (atr, btr) ->
  tr = []

  if atr[".*"] and btr[".*"]
    tr.push [".*", ".*", ".*"]

  for a_input of atr
    if not (a_input == ".*" || a_input == "")
      if btr[a_input]
        tr.push [a_input, a_input, a_input]
      else if btr[".*"]
        tr.push [a_input, ".*", a_input]

  for b_input of btr
    if not (b_input == ".*" || b_input == "" || atr[b_input])
      if atr[".*"]
        tr.push [".*", b_input, b_input]

  return tr

# take an array of states and return a state object where keys
# are the state numbers and valu is always true
stateHash = (states) ->
  st = {}
  for state in states
    st[state] = true
  return st

# return true if any of the states (hash) are in nfa.accept
acceptAny = (nfa, states) ->
  accept = false
  for state of states
    if parseInt(state) in nfa.accept
      accept = true

  return accept

class NFA
  constructor: ->
    @sid = 0
    @accept = []
    @transitions = {}

    return

  compile: (pattern) ->
    curr = @sid++

    for ch in pattern
      next = @sid++
      tr = {}

      if ch == "*"
        tr[".*"] = curr
        tr[""] = next
      else
        tr[ch] = next

      @transitions[curr] = tr
      curr = next

    @transitions[curr] = {}
    @accept.push(curr)

    return @

  toString: ->
    str = []
    curr = 0

    loop
      if not @transitions[curr]
        break

      inputs = Object.keys(@transitions[curr])

      if inputs.length == 0
        break

      if inputs[0] == ".*"
        str.push "*"
        input = ""
      else
        input = inputs[0]
        str.push input

      curr = @transitions[curr][input]

    return str.join("")

  @intersect: (anfa, bnfa) ->

    nfa = new NFA()
    curr = nfa.sid++

    ast = {0: true}
    bst = {0: true}

    iters = 0

    loop

      next = nfa.sid++
      tr = {}

      if iters++ > 10
        throw new Error("iteration limit")

      addEpsilonStates(anfa, ast)
      addEpsilonStates(bnfa, bst)

      atr = unionTransitions(anfa, ast)
      btr = unionTransitions(bnfa, bst)

      # check if both NFAs are in accepting states. do this after
      # unionTransitions as it adds the epsilon states, too.
      if acceptAny(anfa, ast) and acceptAny(bnfa, bst)
        nfa.accept.push(curr)

      matches = matchTransitions(atr, btr)

      if matches.length > 1
        throw new Error("matchTransitions has more than 1 match: #{JSON.stringify(matches)}")

      if matches.length == 0
        break

      [a_input, b_input, ab_input] = matches[0]

      if ab_input == ".*"
        tr[".*"] = curr
        tr[""] = next
      else
        tr[ab_input] = next

      nfa.transitions[curr] = tr
      curr = next

      # since .* transition to themselves, force a step forward
      if ab_input == ".*"
        a_input = ""
        b_input = ""

      ast = stateHash(atr[a_input])
      bst = stateHash(btr[b_input])

    if nfa.accept.length
      nfa.toString()
    else
      false

module.exports = (apat, bpat) ->

  anfa = new NFA().compile(apat)
  bnfa = new NFA().compile(bpat)

  return NFA.intersect(anfa, bnfa)
