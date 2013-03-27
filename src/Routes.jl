include("Trees.jl")

abstract RouteNode

immutable StringNode <: RouteNode
    val::String
end
isequal(s1::StringNode, s2::String) = s1.val == s2
isequal(s1::StringNode, s2::StringNode) = s1.val == s2.val
ismatch(s1::StringNode, s2::String) = s1.val == s2

typealias Route (RouteNode,Union(Function,Nothing)) # ('/about', function()...)
isequal(r::Route, v) = isequal(r[1], v)
ismatch(r::Route, v) = ismatch(r[1], v)

isequal(node::RouteNode, route::Route) = isequal(node, route[1])

typealias RoutingTable Tree
RoutingTable() = RoutingTable((StringNode("/"), nothing))

ismatch(node::String, resource_chunk::String) = node == resource_chunk

function parse_part(part::String)
    StringNode(part != "" ? part : "/")
end

function path_to_handler(route::String, handler::Function)
    path = Route[(parse_part(part),nothing) for part in split(strip(route, "/"), "/")]
    path[end] = (path[end][1], handler)
    path
end

function register!(table::RoutingTable, resource::String, handler::Function)
    path = path_to_handler(resource, handler)
    # NOTE: a bit hack-ey, but fixes the root routing problem
    if resource == "/" 
        table.value = path[1]
    else
        insert!(table, path)
    end
end

# It is easiest to understand the behavior of `searchroute` by example.
# When passed an array of url/resource components, e.g. for "/hello/world" the
# array `["hello", "world"], `searchroute` returns a function, `searchpred` that
# takes a single argument.
#
# When passed matching components `searchpred` returns `false` until the final
# element of `paths` is matched, e.g.:
#
#   > searchpred = searchroute(["hello", "world"])
#   > searchpred("hello")
#   false
#   > searchpred("world")
#   true
#
# However if a non-matching component is passed to `search` it returns `PRUNE`:
#
#   > searchpred = searchroute(["hello", "world"])
#   > searchpred("goodbye")
#   PRUNE
#
# This is used to indicate that it is not neccessary to continue searching a
# given branch of the `RoutingTable`.
#
function searchroute(parts::Array)
    function searchpred(val)
        if ismatch(val, parts[1])
            if length(parts) == 1
                true
            else
                parts = parts[2:end]; false
            end
        else
            PRUNE
        end
    end
end

function match_route_handler(table::RoutingTable, parts::Array)
    result = search(table, searchroute(parts))
    result != nothing ? result[2] : nothing
end
