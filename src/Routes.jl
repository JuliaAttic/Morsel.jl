module Routes

require("Micro/src/Trees.jl")
using Trees

export RoutingTable, 
       register!,
       match_route_handler

abstract RouteNode

immutable StringNode <: RouteNode
    val::String
end
isequal(s1::StringNode, s2::String) = s1.val == s2
ismatch(s1::StringNode, s2::String) = s1.val == s2

typealias Route (RouteNode,Union(Function,Nothing)) # ('/about', function()...)
isequal(r::Route, v) = isequal(r[1], v)
ismatch(r::Route, v) = ismatch(r[1], v)

typealias RoutingTable Tree
RoutingTable() = RoutingTable((StringNode("/"), nothing))

ismatch(node::String, resource_chunk::String) = node == resource_chunk

function parse_part(part::String)
    StringNode(part)
end

function path_to_handler(route::String, handler::Function)
    # TODO: handle "/" root route
    path = Route[(parse_part(part),nothing) for part in split(strip(route, "/"), "/")]
    path[end] = (path[end][1], handler)
    path
end

function register!(table::RoutingTable, resource::String, handler::Function)
    insert!(table, path_to_handler(resource, handler))
end

function searchroute(route)
    function searchpred(val)
        if ismatch(val, route[1])
            if length(route) == 1
                true
            else
                route = route[2:end]; false
            end
        else
            Trees.PRUNE
        end
    end
end

function match_route_handler(table::RoutingTable, parts::Array) 
    result = search(table, searchroute(parts))
    result != nothing ? result[2] : nothing
end

end # module Routes
