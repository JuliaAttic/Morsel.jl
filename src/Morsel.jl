module Morsel

using HttpServer,
      HttpCommon,
      Meddle

export App,
       app,
       route,
       namespace,
       with,
       get,
       post,
       put,
       update,
       delete,
       start,
       urlparam,
       routeparam,
       param,
       unsafestring,

       # from HttpCommon
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
    state::Dict{Any,Any}
end
function app()
    App(routing_tables(), Dict{Any,Any}())
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
    prefix    = get(app.state, :routeprefix, "")
    withstack = get(app.state, :withstack, Midware[])
    handle    = handler
    if length(withstack) > 0
        stack  = middleware(withstack..., Midware( (req::MeddleRequest, res::Response) -> prepare_response(handler(req, res), req, res) ))
        handle = (req::MeddleRequest, res::Response) -> Meddle.handle(stack, req, res)
    end
    for method in HttpMethodBitmasks
        methods & method == method && register!(app.routes[method], prefix * path, handle)
    end
    app
end
route(a::App, m::Int, p::String, h::Function) = route(h, a, m, p)

function namespace(thunk::Function, app::App, prefix::String)
    beforeprefix = get(app.state, :routeprefix, "")
    app.state[:routeprefix] = beforeprefix * prefix
    thunk(app)
    app.state[:routeprefix] = beforeprefix
    app
end

namespace(thunk::Function, app::App, prefix::String, mid::Union(Midware,MidwareStack)...) = with((app) -> namespace(thunk, app, prefix), app, mid...)

function with(thunk::Function, app::App, stack::MidwareStack)
    withstack = get(app.state, :withstack, Midware[])
    beforelen = length(withstack)
    for mid in stack
      push!(withstack, mid)
    end
    app.state[:withstack] = withstack
    thunk(app)
    app.state[:withstack] = withstack[1:beforelen]
    app
end

with(thunk::Function, app::App, mid::Midware...) = with(thunk, app, middleware(mid...))

import Base.get

# These are shortcut functions for common calls to `route`.
# e.g `get` calls `route` with a `GET` as the method parameter.
#
get(h::Function, a::App, p::String)    = route(h, a, GET, p)
post(h::Function, a::App, p::String)   = route(h, a, POST, p)
put(h::Function, a::App, p::String)    = route(h, a, PUT, p)
update(h::Function, a::App, p::String) = route(h, a, UPDATE, p)
delete(h::Function, a::App, p::String) = route(h, a, DELETE, p)

function sanitize(input::String)
    replace(input,r"</?[^>]*>|</?|>","")
end

function validatedvalue(value::Any, validator::Function)
    value == nothing && return nothing
    if validator == string
        value = sanitize(value)
    end
    validator(value)
end

function safelyaccess(req::MeddleRequest, stateKey::Symbol, valKey::Any, validator::Function)
   haskey(req.state, stateKey) ? validatedvalue(get(req.state[stateKey], valKey, nothing), validator) : nothing
end

# validator for getting unsafe ( raw ) input
#
unsafestring(input::String) = input

# Safe accessors for URL parameters, route parameters and POST data
#
function urlparam(req::MeddleRequest, key::String, validator::Function=string)
    safelyaccess(req, :url_params, key, validator)
end
function routeparam(req::MeddleRequest, key::String, validator::Function=string)
    safelyaccess(req, :route_params, key, validator)
end
function param(req::MeddleRequest, key::String, validator::Function=string)
    safelyaccess(req, :data, key, validator)
end
# support symbols...
function urlparam(req::MeddleRequest, key::Symbol, validator::Function=string)
    urlparam(req, string(key), validator)
end
function routeparam(req::MeddleRequest, key::Symbol, validator::Function=string)
    routeparam(req, string(key), validator)
end
function param(req::MeddleRequest, key::Symbol, validator::Function=string)
    param(req, string(key), validator)
end

# `prepare_response` simply sets the data field of the `Response` to the input
# string `s` and calls the middleware's `repsond` function.
#
function prepare_response(s::String, req::MeddleRequest, res::Response)
    res.data = s
    respond(req, res)
end
prepare_response(r::Response, req::MeddleRequest, res::Response) = respond(req, r)

# `start` uses to `Http.jl` and `Meddle.jl` libraries to launch a webserver
# running `app` on the desired `port`.
#
# This is a blocking function, anything that appears after it in the source
# file will not run.
#
function start(app::App, port::Int)

    MorselApp = Midware() do req::MeddleRequest, res::Response
        path = vcat(["/"], split(rstrip(req.http_req.resource,'/'),'/')[2:end])
        methodizedRouteTable = app.routes[HttpMethodNameToBitmask[req.http_req.method]]
        handler, req.state[:route_params] = match_route_handler(methodizedRouteTable, path)
        if handler != nothing
           return prepare_response(handler(req, res), req, res)
        end
        respond(req, Response(404))
    end

    stack = middleware(DefaultHeaders, URLDecoder, CookieDecoder, BodyDecoder, MorselApp)
    http = HttpHandler((req, res) -> Meddle.handle(stack, MeddleRequest(req,Dict{Symbol,Any}()), res))
    http.events["listen"] = (port) -> println("Morsel is listening on $port...")

    server = Server(http)
    run(server, port)
end

end # module Morsel
