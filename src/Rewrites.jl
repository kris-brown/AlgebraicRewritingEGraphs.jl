module Rewrites 

export saturate, congruence, introduce

using Catlab

using ..EGraphs: to_signature, input, output

""" 
For every operation there is a rewrite rule which merges outputs which have
the same input. 
"""
function congruence(X::ACSet, f::Symbol)
  sig = to_signature(X)
  i, o = sig[f]
  A, B = [constructor(X)() for _ in 1:2]
  add_parts!(A, :Class, i + o + o)
  add_parts!(B, :Class, i + o)
  ins = Dict(input(f,i)=>i for i in 1:i)
  outs = Dict(output(f,i)=>j for (i,j) in enumerate(i.+(1:o)))
  outs2 = Dict(output(f,i)=>j for (i,j) in enumerate((i+o).+(1:o)))
  add_part!(A, f; ins..., outs...)
  add_part!(B, f; ins..., outs...)
  add_part!(A, f; ins..., outs2...)
  homomorphism(A, B)
end

function introduce(X::ACSet, f::Symbol)
  sig = to_signature(X)
  i, o = sig[f]
  A, B = [constructor(X)() for _ in 1:2]
  add_parts!(A, :Class, i)
  add_parts!(B, :Class, i + o)
  ins = Dict(input(f,i)=>i for i in 1:i)
  outs = Dict(output(f,i)=>j for (i,j) in enumerate(i.+(1:o)))
  add_part!(B, f; ins..., outs...)
  ACSetTransformation(A, B; Class=1:i)
end

"""
Apply congruence rules until saturation. This will always terminate.
"""
function apply_congruences(X::ACSet, cong_rules)
  res = id(X)
  while true 
    is_changed = false
    for rule in cong_rules
      matches = homomorphisms(dom(rule), codom(res))
      isempty(matches) && continue 
      T = typeof(matches[1])
      Δ, _ = pushout(copair(Vector{T}(matches)), oplus(fill(rule, length(matches))))
      if !is_monic(Δ)
        is_changed = true 
        res = compose(res, Δ)
      end
    end
    is_changed || break 
  end
  res
end

is_iso(x) = is_epic(x) && is_monic(x)

""" 
Run e-saturation via a sequence of rewrite rules

Do this by running the rules in a (possibly random) order

"""
function saturate(X::ACSet, rules::Vector{<:ACSetTransformation}; random=false, intro=false, max=100)
  sig = to_signature(X)
  intros = introduce.(Ref(X), keys(sig))
  congs = congruence.(Ref(X), keys(sig))
  all_rules = [rules; intro ? intros : []]
  res = Pair{Int, ACSetTransformation}[]
  curr = X
  while true 
    is_changed = false
    rules = random ? shuffle(all_rules) : all_rules
    for (iᵣ, rule) in enumerate(rules)
      @debug " $iᵣ"
      matches = homomorphisms(dom(rule), curr)
      isempty(matches) && isnothing(@debug ("No Matches $iᵣ")) && continue 
      T = typeof(matches[1])
      Δ, _ = pushout(copair(Vector{T}(matches)), oplus(fill(rule, length(matches))))
      q = apply_congruences(codom(Δ), congs)
      if !(is_iso(Δ⋅q)) 
        is_changed = true
        push!(res, iᵣ => Δ⋅q)
        curr = codom(q)
        @debug ("Added change $iᵣ")
      else 
        @debug ("No active matches $iᵣ")
      end
    end
    @debug ("Changed: $is_changed")
    is_changed || break 
  end
  res
end

end # module
