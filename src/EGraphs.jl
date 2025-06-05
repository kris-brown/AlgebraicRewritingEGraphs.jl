module EGraphs 

export make_datatype, merge, add_expr, from_expr, eval_expr

using Catlab

# Making custom database schemas from a signature
#################################################

const Signature = Dict{Symbol, Pair{Int,Int}} # input/output arity

sup, sub = Dict(zip(1:9,"¹²³⁴⁵⁶⁷⁸⁹")), Dict(zip(1:9,"₁₂₃₄₅₆₇₈₉"))

sup⁻¹, sub⁻¹ = [Dict(Symbol(v)=>k for (k,v) in d) for d in [sup, sub]]

input(f::Symbol,i::Int) =  Symbol("$(f)$(sub[i])")

output(f::Symbol,i::Int) =  Symbol("$(f)$(sup[i])")

split(fi::Symbol) = let s = string(fi); (Symbol(s[1]), Symbol(s[2])) end

function make_datatype(s::Signature, consts::AbstractVector=[])
  s = merge(s, Dict(Symbol(string(c))=>(0,1) for c in consts))
  P = Presentation(FreeSchema)
  Class = add_generator!(P, Ob(FreeSchema,:Class))
  for (op, (inputs, outputs)) in s
    f = add_generator!(P, Ob(FreeSchema, op))
    for i in 1:inputs
      add_generator!(P, Hom(input(op,i), f, Class)) 
    end
    for o in 1:outputs
      add_generator!(P, Hom(output(op,o), f, Class)) 
    end
  end
  AnonACSetType(Schema(P))
end

# Working with databases produced from signatures
#################################################

""" Default assume all 1-in-1-out """
make_datatype(funs::Vector{Symbol}, consts::AbstractVector=[]) = 
  make_datatype(Signature([k=>(1=>1) for k in funs]...,
                [Symbol(string(k))=>(0=>1) for k in consts]...))

function to_signature(x::ACSet)
  S = acset_schema(x)
  hs = homs(S; just_names=true)

  Dict(map(first.(split.(hs))) do f
    f => Pair(map([sub⁻¹,sup⁻¹]) do invmap 
      maximum([get(invmap, i, 0) for (f′,i) in split.(hs) if f == f′])
    end...)
  end)
end

const VarDict = Dict{Symbol, Int} # A map from Symbol variables to e-classes

function ordered_homs(db::ACSet, f::Symbol)::Vector{Symbol}
  i, o = to_signature(db)[f]
  [input.(f, 1:i); output.(f, 1:o)]
end 

function add_expr(db::ACSet, args...; kw...) 
  db = deepcopy(db)
  add_expr!(db, args...; kw...)
  db
end

add_expr!(db::ACSet, e::Expr, vars::NamedTuple) = 
  add_expr!(db, e; vars=VarDict(pairs(vars)))
  
function add_expr!(db::ACSet, e::Expr; vars::VarDict=VarDict())::Vector{Int}
  e.head == :call || error("Bad expr")
  head, args... = e.args
  i, o = to_signature(db)[head]
  o == 1 || error("Expecting only terms with one output")
  arg_classes = only.(add_expr!.(Ref(db), args; vars)) # assume functions have one output
  length(arg_classes) == i || error("Wrong number of inputs")
  found = find_expr(db, head, arg_classes)
  isnothing(found) || return [found]
  out_classes = add_parts!(db, :Class, o)
  kw = Dict(zip(ordered_homs(db, head), [arg_classes; out_classes]))
  add_part!(db, head; kw...)
  out_classes
end

function add_expr!(db::ACSet, e::Symbol; vars::VarDict)::Vector{Int}
  haskey(vars, e) && return [vars[e]]
  vars[e] = add_part!(db, :Class)
  [vars[e]]
end

""" Data is modeled as nullary term constructor """
function add_expr!(db::ACSet, data; vars::VarDict)::Vector{Int}
  s = Symbol(string(data))
  n = nparts(db, s)
  n == 1 && return [db[s, 1]]
  n > 1 && error("Cannot have multiple copies of same constant")
  [add_part!(db, s; Dict(output(s, 1)=>add_part!(db, :Class))...)]
end

const Expr0 = Union{Expr, Symbol}

find_expr(db::ACSet, e::Expr0, vars::NamedTuple) = 
  find_expr(db, e; vars=VarDict(pairs(vars)))

""" 
Return `nothing` if term is not found. Error if congruence doesn't hold (i.e.
there is more than one e-term with the same head and args) 
"""
function find_expr(db::ACSet, e::Expr; vars=VarDict())
  e.head == :call || error("Bad expr")
  head, args... = e.args
  arg_classes = find_expr.(Ref(db), args; vars)
  any(isnothing, arg_classes) && return nothing
  find_expr(db, head, arg_classes)
end

function find_expr(db::ACSet, head::Symbol, arg_classes::Vector{Int})
  candidates = Set(parts(db, head))
  i, o = to_signature(db)[head]
  i == length(arg_classes) || error("Bad # of inputs ")
  o == 1 || error("Assuming expression have exactly one output")
  for (hom, val) in zip(ordered_homs(db, head), arg_classes)
    intersect!(candidates, Set(incident(db, val, hom)))
    isempty(candidates) && return nothing
  end

  db[only(candidates), output(head, 1)]
end

find_expr(::ACSet, e::Symbol; vars) = get(vars, e, nothing)

function from_expr(T::Type, e::Expr) 
  db = T()
  add_expr!(db, e)
  db 
end

""" merge two e-class ids """
function Base.merge(eg::ACS, x::Int, y::Int) where {ACS<:ACSet}
  Class = ACS(); add_part!(Class, :Class)
  ob(coequalizer([ACSetTransformation(Class, eg; Class=[z]) for z in [x,y]]...))
end

""" Merge the two e-class ids of expressions """
Base.merge(eg::ACSet, x::Expr0, y::Expr0, vars::NamedTuple=(;)) = 
  merge(eg, find_expr(eg, x, vars), find_expr(eg, y, vars))

""" Take an e-graph with variables (eclasses without e-terms) and plug in a constant for each one """
function eval_expr(eg::ACSet, vals::Vector)
  sig = to_signature(eg)
  outs = vcat(map(collect(pairs(sig))) do (k, (_, o))
    eg[output(k, o)]
  end...)
  unassigned = setdiff(parts(eg, :Class), outs)
  length(vals) == length(unassigned) || error("mismatch")
  for (v, class) in zip(Symbol.(vals), unassigned)
    add_part!(eg, v; Dict(output(v, 1) => class)...)
  end
  eg
end

end # module
