module Micro

using Http,
      Meddle

export GET,
       POST,
       PUT,
       UPDATE,
       DELETE,
       OPTIONS,
       HEAD,
       App,
       app,
       route,
       get,
       post,
       put,
       update,
       delete,
       start,

       # from Routes
       match_route_handler

include("Routes.jl")

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

routing_tables() = (HttpMethod => RoutingTable)[method => RoutingTable() for method in HttpMethods]

type App
    routes::Dict{HttpMethod, RoutingTable}
end
function app()
    App(routing_tables())
end

# define new routes
function route(handler::Function, app::App, methods::Int, path::String)
    for method in HttpMethods
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

function prepare_response(s::String, req::Request, res::Response)
    res.data = s
    respond(req, res)
end

function start(app::App, port::Int)

    MicroApp = Midware() do req::Request, res::Response
        path = vcat(["/"], split(rstrip(req.resource,"/"),"/")[2:end])
        handler = match_route_handler(app.routes[GET], path)
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
