module TestRewrites

using CSetEGraphs, Catlab, Test

# A signature where `f` and `g` are unary functions and 7,8,9 are constants
S = make_datatype([:f, :g], [7,8,9])

##################
# Defining rules #
##################

# Define a rule: f(f(x)) => f(x)
ffx = from_expr(S, :(f(f(x))))
fx_ffx = merge(ffx, :(f(x)), :(f(f(x))), (x=1,))

# The rule is a merging rule (i.e. an epimorphism)
rule₁ = homomorphism(ffx, fx_ffx; monic=[:f])
view(rule₁)

# Define a rule: g(f(x)) => g(x)
gfx = from_expr(S, :(g(f(x))))
gx_gfx = merge(add_expr(gfx, :(g(x)), (x=1,)), :(g(f(x))), :(g(x)), (x=1,))
rule₂ = homomorphism(gfx, gx_gfx)
view(rule₂)


##################
# Applying rules #
##################

X₁ = from_expr(S,:(g(f(f(7)))))
view(X₁) # start state for applying a rewrite 

r = Rule(id(ffx), rule₁)
@test length(get_matches(r, X₁)) == 1 # there is only one way to apply this match
X₂ = rewrite(r, X₁)
view(X₂) # result of applying the rule

r = Rule(id(gfx), rule₂)
m, = filter(is_monic, get_matches(r, X₂)) # only one monic match
X₃ = rewrite_match(r, m)
view(X₃) # result of applying the rule

# we now have witnessed that g(7) == g(f(f(7)))

# With a binary operation too
#-----------------------------

S′ = make_datatype(Dict(:f=>(1=>1), :g=>(1=>1), :h=>(2=>1)), [7,8,9])

# rules 1 and 2 the same as before
ffx = from_expr(S′, :(f(f(x))))
fx_ffx = merge(ffx, :(f(x)), :(f(f(x))), (x=1,))
rule₁ = homomorphism(ffx, fx_ffx; monic=[:f])

gfx = from_expr(S′, :(g(f(x))))
gx_gfx = merge(add_expr(gfx, :(g(x)), (x=1,)), :(g(f(x))), :(g(x)), (x=1,))
rule₂ = homomorphism(gfx, gx_gfx)

# now add a rule: h(x, g(x)) => x
hexpr = :(h(x,g(x)))
hxgx = from_expr(S′, hexpr)
hxgxx = merge(hxgx, hexpr, :x, (x=1,))
rule₃ = homomorphism(hxgx, hxgxx)
view(rule₃)

####################
# Saturating rules #
####################

view(introduce(S′(), :h))

view(congruence(S′(), :h))

expr = from_expr(S′, :(g(h(h(x,y),g(f(f(f(h(x,y)))))))))
expr = eval_expr(expr, [8,9])
r = saturate(expr, [rule₂,rule₁,rule₃])

end # module
