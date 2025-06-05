module TestEGraphs 

using CSetEGraphs, Catlab, Test

# Define a signature: `f` a binary function, `g` a unary one 
fg = Dict(:f => (2=>1), :g => (1=>1))
FG = make_datatype(fg)

# Construct a term as a Julia expression
fgg = :(f(g(x),g(x)))
db = from_expr(FG, fgg)

# Try add the same term again to the e-graph
@test db == add_expr(db, fgg, (x=1,)) # adding again is no-op

# View the e-graph which has three e-classes: `x`, `g(x)`, `f(g(x),g(x))`
view(db)

# Identify `f(g(x),g(x))` with `g(x)`
db2 = merge(db, fgg, :(g(x)), (x=1,))

# View the modified e-graph, which now has only two e-classes
view(db2)

# View a morphism of e-graphs (in this case, the identity map on this one)
view(id(db2))

end # module
