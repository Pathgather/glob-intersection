// Generated by CoffeeScript 1.10.0
(function() {
  var NFA, REST_MISMATCH, addEpsilonTransitions, addTransition, assertNoEpsStates, common, compileFragment, debug, eachTransition, empty, findSuffix, intersect, inverseTransitions, matchInput, matchTransitions, reachAccept, reachFrom, removeTransition, splitBrackets, stateProduct, toGlob, to_glob_helper, util,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  util = require("util");

  debug = false;

  matchInput = function(a, b) {
    switch (false) {
      case !(a === b && a !== ""):
        return a;
      case !(a === "**" && b === ".*"):
        return b;
      case !(a === "**" && b.length === 1):
        return b;
      case !(a === ".*" && b.length === 1 && b !== "/"):
        return b;
    }
  };

  matchTransitions = function(atr, btr) {
    var a, ab, b, matches;
    matches = [];
    if (!atr || !btr) {
      return matches;
    }
    for (a in atr) {
      for (b in btr) {
        if (ab = matchInput(a, b)) {
          matches.push([a, b, ab]);
        } else if (ab = matchInput(b, a)) {
          matches.push([a, b, ab]);
        }
      }
    }
    return matches;
  };

  splitBrackets = function(pattern, opening_offset) {
    var ch, depth, i, last, results;
    results = [];
    depth = 1;
    i = last = opening_offset + 1;
    while (i < pattern.length) {
      ch = pattern[i];
      if (ch === "{") {
        depth++;
      } else if (ch === ",") {
        if (depth === 1) {
          results.push(pattern.substring(last, i));
          last = i + 1;
        }
      } else if (ch === "}") {
        depth--;
        if (depth === 0) {
          results.push(pattern.substring(last, i));
          break;
        }
      }
      i++;
    }
    results.closing_offset = i;
    return results;
  };

  addTransition = function(nfa, from, input, to) {
    var base, base1, st, tr;
    tr = (base = nfa.transitions)[from] || (base[from] = {});
    st = (base1 = nfa.transitions[from])[input] || (base1[input] = {});
    return st[to] = true;
  };

  empty = function(object) {
    var k;
    for (k in object) {
      return false;
    }
    return true;
  };

  common = function(obj_a, obj_b) {
    var a;
    for (a in obj_a) {
      if (a in obj_b) {
        return true;
      }
    }
    return false;
  };

  removeTransition = function(nfa, from, input, to) {
    delete nfa.transitions[from][input][to];
    if (empty(nfa.transitions[from][input])) {
      delete nfa.transitions[from][input];
    }
    if (empty(nfa.transitions[from])) {
      return delete nfa.transitions[from];
    }
  };

  compileFragment = function(nfa, pattern, curr) {
    var _pattern, ch, i, l, last, len, next, split_patterns, state;
    if (curr == null) {
      curr = null;
    }
    if (curr == null) {
      curr = nfa.sid++;
    }
    i = 0;
    while (i < pattern.length) {
      ch = pattern[i];
      next = null;
      switch (ch) {
        case "{":
          split_patterns = splitBrackets(pattern, i);
          last = (function() {
            var l, len, results1;
            results1 = [];
            for (l = 0, len = split_patterns.length; l < len; l++) {
              _pattern = split_patterns[l];
              results1.push(compileFragment(nfa, _pattern, curr));
            }
            return results1;
          })();
          next = nfa.sid++;
          for (l = 0, len = last.length; l < len; l++) {
            state = last[l];
            addTransition(nfa, state, "", next);
          }
          i = split_patterns.closing_offset;
          break;
        case "*":
          next = nfa.sid++;
          if (pattern[i + 1] === "*") {
            addTransition(nfa, curr, "**", curr);
            i++;
          } else {
            addTransition(nfa, curr, ".*", curr);
          }
          addTransition(nfa, curr, "", next);
          break;
        case "?":
          next = nfa.sid++;
          addTransition(nfa, curr, ".*", next);
          break;
        default:
          next = nfa.sid++;
          addTransition(nfa, curr, ch, next);
      }
      if (next) {
        curr = next;
      } else {
        curr = nfa.sid++;
      }
      i++;
    }
    return curr;
  };

  eachTransition = function(nfa, callback) {
    var input, ref, state, to_state, to_states;
    for (state in nfa.transitions) {
      ref = nfa.transitions[state];
      for (input in ref) {
        to_states = ref[input];
        for (to_state in to_states) {
          callback(state, input, to_state);
        }
      }
    }
  };

  reachFrom = function(nfa, initial) {
    var dest, input, state, states, visited;
    states = [initial];
    visited = {};
    while (states.length > 0) {
      state = states.pop();
      visited[state] = true;
      for (input in nfa.transitions[state]) {
        for (dest in nfa.transitions[state][input]) {
          if (!visited[dest]) {
            states.push(dest);
          }
        }
      }
    }
    return visited;
  };

  inverseTransitions = function(nfa) {
    var inverse;
    inverse = {};
    eachTransition(nfa, function(state, _, to_state) {
      inverse[to_state] || (inverse[to_state] = {});
      return inverse[to_state][state] = true;
    });
    return inverse;
  };

  reachAccept = function(nfa) {
    var from_state, inverse, state, states, visited;
    inverse = inverseTransitions(nfa);
    visited = {};
    states = Object.keys(nfa.accept);
    while (states.length > 0) {
      state = states.pop();
      visited[state] = true;
      if (inverse[state]) {
        for (from_state in inverse[state]) {
          if (!visited[from_state]) {
            states.push(from_state);
          }
        }
      }
    }
    return visited;
  };

  assertNoEpsStates = function(nfa) {
    return eachTransition(nfa, function(from, input, to) {
      if (input === "") {
        throw new Error("assertion failed: nfa has epsilon states");
      }
    });
  };

  stateProduct = function(a_states, b_states) {
    var a, b, states;
    states = [];
    for (a in a_states) {
      for (b in b_states) {
        states.push([a, b]);
      }
    }
    return states;
  };

  findSuffix = function(patterns) {
    var ch, done, first, i, l, len, pat, shortest;
    first = patterns[0];
    if (patterns.length === 1) {
      return first;
    }
    shortest = patterns.map(function(pat) {
      return pat.length;
    }).sort()[0] || 0;
    i = 0;
    if (debug) {
      console.log({
        shortest: shortest
      });
    }
    while (i <= shortest) {
      ch = first[first.length - i - 1];
      if (debug) {
        console.log({
          ch: ch
        });
      }
      for (l = 0, len = patterns.length; l < len; l++) {
        pat = patterns[l];
        if (debug) {
          console.log("looking at", pat[pat.length - i - 1]);
        }
        if (pat[pat.length - i - 1] !== ch) {
          done = true;
          break;
        }
      }
      if (done) {
        break;
      } else {
        i++;
      }
    }
    return first.substring(first.length - i);
  };

  NFA = function(pattern) {
    var last;
    this.accept = {};
    this.sid = 0;
    this.start = "0";
    this.transitions = {};
    if (pattern != null) {
      last = compileFragment(this, pattern);
      this.accept[last] = true;
    }
  };

  REST_MISMATCH = new Error("mismatched rest segments");

  to_glob_helper = function(nfa, inverse, match_brackets) {
    var cache, l, len, process_state, result, state, states;
    if (match_brackets == null) {
      match_brackets = true;
    }
    cache = {};
    states = Object.keys(nfa.accept);
    for (l = 0, len = states.length; l < len; l++) {
      state = states[l];
      cache[state] = "";
    }
    process_state = function(state) {
      var from_state, input, len1, m, new_pat, pat, patterns, ref, ref1, ref2, results1, sub_patterns, suffix, to_state;
      if (debug) {
        console.log(new Array(40).join("="));
      }
      if (debug) {
        console.log("looking at", state);
      }
      patterns = [];
      for (input in nfa.transitions[state]) {
        if (input.length !== 1 && input !== "" && input !== ".*") {
          continue;
        }
        if (debug) {
          console.log("considering", {
            input: input,
            patterns: patterns
          });
        }
        for (to_state in nfa.transitions[state][input]) {
          if (to_state === state) {
            continue;
          }
          if (debug) {
            console.log({
              to_state: to_state
            }, "cache =", cache[to_state]);
          }
          if (!cache[to_state]) {
            if (debug) {
              console.log("to_state", to_state, "not in cache yet, retrying");
            }
            if (indexOf.call(states, to_state) < 0) {
              states.push(to_state);
            }
            states.push(state);
            return;
          }
          if (input === ".*") {
            input = "?";
          }
          ref = cache[to_state];
          for (m = 0, len1 = ref.length; m < len1; m++) {
            pat = ref[m];
            new_pat = input + pat;
            if (indexOf.call(patterns, new_pat) < 0) {
              patterns.push(new_pat);
            }
          }
        }
      }
      if (patterns.length > 1 && match_brackets) {
        if (debug) {
          console.log("this has multiple patterns", patterns);
        }
        suffix = findSuffix(patterns);
        while (suffix[0] === "}") {
          suffix = suffix.substring(1);
        }
        if (debug) {
          console.log({
            suffix: suffix
          });
        }
        sub_patterns = patterns.map(function(pat) {
          return pat.substring(0, pat.length - suffix.length);
        });
        patterns = ["{" + sub_patterns.join(",") + "}" + suffix];
      }
      if (patterns.length === 0) {
        patterns.push("");
      }
      if ((ref1 = nfa.transitions[state]) != null ? (ref2 = ref1[".*"]) != null ? ref2[state] : void 0 : void 0) {
        if (debug) {
          console.log("self * transition");
        }
        patterns = patterns.map(function(pat) {
          return "*" + pat;
        });
      }
      if (debug) {
        console.log("saving cache for " + state, patterns);
      }
      cache[state] = patterns;
      results1 = [];
      for (from_state in inverse[state]) {
        if (!((indexOf.call(states, from_state) >= 0) || from_state === state)) {
          results1.push(states.push(from_state));
        } else {
          results1.push(void 0);
        }
      }
      return results1;
    };
    while (states.length > 0) {
      state = states.shift();
      process_state(state);
    }
    result = cache[nfa.start];
    if (result == null) {
      throw new Error("missing cache for start state");
    }
    if (result.length > 1) {
      return "{" + result.join(",") + "}";
    } else {
      return result[0];
    }
  };

  toGlob = function(nfa) {
    var e, error, inverse, result, state;
    inverse = inverseTransitions(nfa);
    for (state in inverse) {
      delete inverse[state][state];
    }
    if (debug) {
      console.log("inverse", inverse);
    }
    try {
      result = to_glob_helper(nfa, inverse);
    } catch (error) {
      e = error;
      if (e === REST_MISMATCH) {
        if (debug) {
          console.log("retrying due to rest mismatch");
        }
        result = to_glob_helper(nfa, inverse, false);
      } else {
        if (debug) {
          console.log("got some strange error");
        }
        throw e;
      }
    }
    if (debug) {
      console.log("the final", result);
    }
    return result;
  };

  addEpsilonTransitions = function(nfa, i, j, a_eps, b_eps) {
    var results1, to_state;
    if (a_eps) {
      for (to_state in a_eps) {
        addTransition(nfa, i + ":" + j, "", to_state + ":" + j);
      }
    }
    if (b_eps) {
      results1 = [];
      for (to_state in b_eps) {
        results1.push(addTransition(nfa, i + ":" + j, "", i + ":" + to_state));
      }
      return results1;
    }
  };

  intersect = function(anfa, bnfa) {
    var a, a_input, ab_input, b, b_input, backward, forward, i, j, l, len, len1, m, n, nfa, o, ref, ref1, ref2, ref3, ref4, ref5, ref6, ref7, state;
    if (debug) {
      console.log("intersecting");
    }
    if (debug) {
      console.log(util.inspect(anfa, false, null));
    }
    if (debug) {
      console.log(util.inspect(bnfa, false, null));
    }
    nfa = new NFA();
    for (i = l = 0, ref = anfa.sid; 0 <= ref ? l <= ref : l >= ref; i = 0 <= ref ? ++l : --l) {
      for (j = m = 0, ref1 = bnfa.sid; 0 <= ref1 ? m <= ref1 : m >= ref1; j = 0 <= ref1 ? ++m : --m) {
        if (debug) {
          console.log("processing: " + i + ":" + j);
        }
        addEpsilonTransitions(nfa, i, j, (ref2 = anfa.transitions[i]) != null ? ref2[""] : void 0, (ref3 = bnfa.transitions[j]) != null ? ref3[""] : void 0);
        ref4 = matchTransitions(anfa.transitions[i], bnfa.transitions[j]);
        for (n = 0, len = ref4.length; n < len; n++) {
          ref5 = ref4[n], a_input = ref5[0], b_input = ref5[1], ab_input = ref5[2];
          if (debug) {
            console.log("matched " + a_input + " and " + b_input + " as " + ab_input);
          }
          ref6 = stateProduct(anfa.transitions[i][a_input], bnfa.transitions[j][b_input]);
          for (o = 0, len1 = ref6.length; o < len1; o++) {
            ref7 = ref6[o], a = ref7[0], b = ref7[1];
            if (debug) {
              console.log("adding transition from " + i + ":" + j + " with '" + ab_input + "' to " + a + ":" + b);
            }
            addTransition(nfa, i + ":" + j, ab_input, a + ":" + b);
          }
        }
      }
    }
    for (a in anfa.accept) {
      for (b in bnfa.accept) {
        nfa.accept[a + ":" + b] = true;
      }
    }
    nfa.start = "0:0";
    if (debug) {
      console.log(util.inspect(nfa, false, null));
    }
    forward = reachFrom(nfa, nfa.start);
    if (debug) {
      console.log("foward", forward);
    }
    for (state in nfa.accept) {
      if (!forward[state]) {
        delete nfa.accept[state];
      }
    }
    if (!common(nfa.accept, forward)) {
      if (debug) {
        console.log("there are no accept states reachable from start");
      }
      return false;
    }
    backward = reachAccept(nfa);
    if (!backward[nfa.start]) {
      if (debug) {
        console.log("start state cannot be reached from any acept states");
      }
      return false;
    }
    eachTransition(nfa, function(state, input, to_state) {
      var keep_state, keep_to;
      keep_state = forward[state] && backward[state];
      keep_to = forward[to_state] && backward[to_state];
      if (!keep_state || !keep_to) {
        return removeTransition(nfa, state, input, to_state);
      }
    });
    if (debug) {
      console.log(util.inspect(nfa, false, null));
    }
    return nfa;
  };

  module.exports = function(apat, bpat, options) {
    var anfa, bnfa, glob, nfa;
    if (options == null) {
      options = {};
    }
    if (options.debug) {
      debug = true;
    }
    try {
      anfa = new NFA(apat);
      bnfa = new NFA(bpat);
      nfa = intersect(anfa, bnfa);
      if (debug) {
        console.log("intersection", util.inspect(nfa, false, null));
      }
      if (nfa) {
        glob = toGlob(nfa);
      }
    } finally {
      debug = false;
    }
    if (glob != null) {
      return glob;
    } else {
      return false;
    }
  };

}).call(this);