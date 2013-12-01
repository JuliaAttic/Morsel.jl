# Morsel

Morsel is a Sintra-like micro framework for declaring routes and handling requests.
It is built on top of HttpServer.jl and Meddle.jl.

## Installation

    :::julia
    julia> Pkg.add("Morsel")

## Example

Here is a brief example that will return a few different messages for different routes.
The line `get(app, "/about") do ...` is shorthand for only serving GET requests through that route.

    :::julia
    using Morsel

    app = Morsel.app()

    route(app, GET | POST | PUT, "/") do req, res
        "This is the root"
    end

    get(app, "/about") do req, res
        "This app is running on Morsel"
    end

    start(app, 8000)

### Expected Behavior:

The server will run on `localhost:8000`.

For GET, POST, and PUT requests for `/`, you will get "This is the root" as a response.
For GET requests for `/about`, you will get "This app is running on Morsel".
