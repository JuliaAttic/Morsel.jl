module Micro

using Http
using Meddle

export GET, POST, PUT, UPDATE, DELETE, OPTIONS, HEAD, get, post, put, update, delete, options, head, App, app

# HTTP method bitmask, allows fancy GET | POST | UPDATE style API.
typealias HttpMethod Int
const GET     = 2^0
const POST    = 2^1
const PUT     = 2^2
const UPDATE  = 2^3
const DELETE  = 2^4
const OPTIONS = 2^5
const HEAD    = 2^6

HttpMethods = HttpMethod[GET, POST, PUT, UPDATE, DELETE, OPTIONS, HEAD]

typealias Route (String,Function)     # ('/about', function()...)
typealias RoutingTable Array{Route,1} # [Route, Route]

function init_method_routing_tables()
	{method => RoutingTable[] for method in HttpMethods}
end

type App
    routes::Dict{HttpMethod, RoutingTable}
end
function app()
	App(init_method_routing_tables())
end

function route(app::App, methods::Int, path::String, handler::Function)

end

end # module Micro
