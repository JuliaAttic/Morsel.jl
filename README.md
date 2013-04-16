Micro is a Sintra-like micro framework for declaring routes and handling requests.  It is built on top of `Http.jl` and `Meddle.jl`.

Here is a brief example that will return a few different messages for different routes, if you run this and open `localhost:8000` you will see "This is the root" for GET, POST or PUT requests.  The line `get(app, "/about") do ...` is shorthand for only serving GET requests through that route.

```.jl
using Micro

app = Micro.app()

route(app, GET | POST | PUT, "/") do req, res
    "This is the root"
end

get(app, "/about") do req, res
    "This app is running on Micro"
end

start(app, 8000)
```
