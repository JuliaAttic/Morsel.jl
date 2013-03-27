module Micro

using Http,
      Httplib,
      Meddle

export App,
       app,
       route,
       get,
       post,
       put,
       update,
       delete,
       start,
       url_params,

       # from Httplib
       GET,
       POST,
       PUT,
       UPDATE,
       DELETE,
       OPTIONS,
       HEAD,

       # from Routes
       match_route_handler

include("Routes.jl")

# The produces a dictionary that maps each type of request (GET, POST, etc.) to
# a RoutingTable, which is an alias to the Tree datatype specified in Trees.jl.
routing_tables() = (HttpMethodBitmask => RoutingTable)[method => RoutingTable() for method in HttpMethodBitmasks]

type App
    routes::Dict{HttpMethodBitmask, RoutingTable}
end
function app()
    App(routing_tables())
end

# This defines a route and adds it to the routes dictionary. As HTTP methods
# are bitmasked integers they can be combined using the bitwise or opperator,
# e.g. "GET | POST" will add a GET method and a POST method.
#
# Example:
#   function hello_world(req, res)
#       "Hello, world!"
#   end
#   route(hello_world, GET | POST, "/hello/world")
#
# Or using do syntax:
#   route(app, GET | POST, "/hello/world") do req, res
#       "Hello, world"
#   end
function route(handler::Function, app::App, methods::Int, path::String)
    for method in HttpMethodBitmasks
        methods & method == method && register!(app.routes[method], path, handler)
    end
    app
end
route(a::App, m::Int, p::String, h::Function) = route(h, a, m, p)

get(h::Function, a::App, p::String)    = route(h, a, GET, p)
post(h::Function, a::App, p::String)   = route(h, a, POST, p)
put(h::Function, a::App, p::String)    = route(h, a, PUT, p)
update(h::Function, a::App, p::String) = route(h, a, UPDATE, p)
delete(h::Function, a::App, p::String) = route(h, a, DELETE, p)

url_params(req::Request)                       = req.state[:url_params]
url_params(req::Request, key::String, default) = get(req.state[:url_params], key, default)
url_params(req::Request, key::String)          = url_params(req, key, nothing)

function prepare_response(s::String, req::Request, res::Response)
    res.data = s
    respond(req, res)
end

function start(app::App, port::Int)

    MicroApp = Midware() do req::Request, res::Response
        path = vcat(["/"], split(rstrip(req.resource,"/"),"/")[2:end])
        handler = match_route_handler(app.routes[HttpMethodNameToBitmask[req.method]], path)
        if handler != nothing
           return prepare_response(handler(req, res), req, res)
        end
        respond(req, Response(404))
    end

    stack = middleware(DefaultHeaders, CookieDecoder, MicroApp)
    http = HttpHandler((req, res) -> Meddle.handle(stack, req, res))
    http.events["listen"] = (port) -> println("Micro is listening on $port...")

    server = Server(http)
    run(server, port)
end

end # module Micro
