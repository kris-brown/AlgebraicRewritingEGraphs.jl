module Visualize

using Catlab
import Catlab.Graphics: Graphviz
using ..EGraphs: to_signature, input, output

nclasses(X::ACSet) = nparts(X, :Class)

function Base.view(eg::ACSet)
  n(i::Int) = fill(nothing, i)
  wd = WiringDiagram([],[])
  s = to_signature(eg)
  for _ in parts(eg, :Class)
    add_box!(wd, Junction(nothing, n(1), n(1)))
  end
  for (k,(ni,no)) in s
    for term in parts(eg, k)
      b = add_box!(wd, Box(k, n(ni), n(no)))
      for i in 1:ni
        add_wire!(wd, (eg[term, input(k, i)], 1)=>(b, i))
      end
      for o in 1:no 
        add_wire!(wd, ((b, o)=>(eg[term, output(k, o)], 1)))
      end
    end
  end

  to_graphviz(wd; orientation=LeftToRight)
end


prepend(s::Graphviz.Node, p::String) = 
  Graphviz.Node(p*s.name, s.attrs)

prepend(s::Graphviz.NodeID, p::String) = 
  Graphviz.NodeID(p*s.name, s.port, s.anchor)

prepend(s::Graphviz.Edge, p::String) = 
  Graphviz.Edge(prepend.(s.path, p), s.attrs)

const VS = Vector{Graphviz.Statement}

""" Represent an ACSet Transformation """
Base.view(h::ACSetTransformation) =
  mk_grph(dom(h), codom(h), Dict(k=>collect(v) for (k,v) in pairs(components(h))))

function mk_grph(X, Y, comps)
  d1, d2 = view(X), view(Y)
  stmts = Graphviz.Statement[]
  push!(stmts, Graphviz.Subgraph("cluster_dom", VS(prepend.(d1.stmts,"dom"))))
  push!(stmts, Graphviz.Subgraph("cluster_cod", VS(prepend.(d2.stmts, "codom"))))
  for x in parts(X,:Class)
    y = comps[:Class][x]
    y >0 && push!(stmts, Graphviz.Edge(["domn$x", "codomn$(y)"], Dict(:color=>"blue")))
  end
  s = to_signature(X)
  nsX, nsY = map([X,Y]) do Z 
    ns = cumsum(nparts.(Ref(Z), keys(s)))
    [nclasses(Z).+(a:b) for (a,b) in zip([1;ns.+1], ns)]
  end
  for (k, kX, kY) in zip(keys(s), nsX, nsY)
    for x in parts(X, k)
      y = comps[k][x]
      y > 0 && push!(stmts, Graphviz.Edge(["domn$(kX[x])", "codomn$(kY[y])"], 
                                          Dict(:color=>"red")))
    end
  end
  Graphviz.Digraph("hom_graph", stmts; node_attrs=d1.node_attrs, 
                   edge_attrs=d1.edge_attrs, graph_attrs=d1.graph_attrs)
end

""" Represent a *partial* ACSet Transformation """
function Base.view(h::Span)
  l, r = h
  X, Z = codom(l), codom(r)
  mk_grph(X, Z, Dict(map(collect(pairs(components(l)))) do (k, lₖ) 
    k => map(parts(X, k)) do x 
      p = preimage(lₖ, x)
      isempty(p) ? 0 : r[k](only(p))
    end
  end))
end


end # module
