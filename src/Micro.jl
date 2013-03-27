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
       route_params,

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

# This produces a dictionary that maps each type of request (GET, POST, etc.)
# to a `RoutingTable`, which is an alias to the `Tree` datatype specified in
# `Trees.jl`.
routing_tables() = (HttpMethodBitmask => RoutingTable)[method => RoutingTable()
                                            for method in HttpMethodBitmasks]

# An 'App' is simply a dictionary linking each HTTP method to a `RoutingTable`.
# The detault constructor produces an empty `RoutingTable` for member of
# `HttpMethods`.
#
type App
    routes::Dict{HttpMethodBitmask, RoutingTable}
end
function app()
    App(routing_tables())
end

# This defines a route and adds it to the `app.routes` dictionary. As HTTP
# methods are bitmasked integers they can be combined using the bitwise or
# opperator, e.g. `GET | POST` refers to a `GET` method and a `POST` method.
#
# Example:
#
#   function hello_world(req, res)
#       "Hello, world!"
#   end
#   route(hello_world, GET | POST, "/hello/world")
#
# Or using do syntax:
#
#   route(app, GET | POST, "/hello/world") do req, res
#       "Hello, world"
#   end
#
function route(handler::Function, app::App, methods::Int, path::String)
    for method in HttpMethodBitmasks
        methods & method == method && register!(app.routes[method], path, handler)
    end
    app
end
route(a::App, m::Int, p::String, h::Function) = route(h, a, m, p)

import Base.get

# These are shortcut functions for common calls to `route`.
# e.g `get` calls `route` with a `GET` as the method parameter.
#
get(h::Function, a::App, p::String)    = route(h, a, GET, p)
post(h::Function, a::App, p::String)   = route(h, a, POST, p)
put(h::Function, a::App, p::String)    = route(h, a, PUT, p)
update(h::Function, a::App, p::String) = route(h, a, UPDATE, p)
delete(h::Function, a::App, p::String) = route(h, a, DELETE, p)

# Convenience methods for getting url parameters from req.state[:url_params]
#
url_params(req::Request)                       = req.state[:url_params]
url_params(req::Request, key::String, default) = get(req.state[:url_params], key, default)
url_params(req::Request, key::String)          = url_params(req, key, nothing)

# Convenience methods for getting route parameters from req.state[:route_params]
#
route_params(req::Request)                     = get(req.state, :route_params, nothing)
route_params(req::Request, key::Symbol)        = has(req.state, :route_params) ? get(req.state[:route_params], key, nothing) : nothing

# `prepare_response` simply sets the data field of the `Response` to the input
# string `s` and calls the middleware's `repsond` function.
#
function prepare_response(s::String, req::Request, res::Response)
    res.data = s
    respond(req, res)
end

# `start` uses to `Http.jl` and `Meddle.jl` libraries to launch a webserver
# running `app` on the desired `port`.
#
# This is a blocking function, anything that appears after it in the source
# file will not run.
#
function start(app::App, port::Int)

    MicroApp = Midware() do req::Request, res::Response
        path = vcat(["/"], split(rstrip(req.resource,"/"),"/")[2:end])
        routeTable = app.routes[HttpMethodNameToBitmask[req.method]]
        handler, req.state[:route_params] = match_route_handler(routeTable, path)
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
