using Morsel
using FactCheck
import Requests
req = Requests

app = Morsel.app()

get(app, "/") do req, res
    "root_get"
end

@async start(app, 8000)

# make sure the app has run
response = req.get("http://localhost:8000/")
while (response.status != 200)
    response = req.get("http://localhost:8000/")
end

facts("route") do
    facts("get, post, post, put, delete, request") do
        # patch doesn't support...
        route(app, POST | PUT | DELETE , "/") do req, res
            "root"
        end

        context("get") do
            response = req.get("http://localhost:8000/")
            @fact response.status => 200
            @fact response.data => "root_get"
        end

        context("post, put, delete") do
            @fact req.post("http://localhost:8000/").data => "root"
            @fact req.put("http://localhost:8000/").data => "root"
            @fact req.delete("http://localhost:8000/").data => "root"
        end
    end

    facts("Add route when the app is running") do
        get(app, "/running") do req, res
            "running"
        end
        @fact req.get("http://localhost:8000/running").status => 200
    end

    facts("dynamic route") do
        context("the request will succes if the type is right") do
            route(app, GET, "/users/<id::Int>" ) do req, res
                string("User id is:", req.params[:id])
            end

            @fact req.get("http://localhost:8000/users/10").status => 200
            @fact req.get("http://localhost:8000/users/abc").status => 404 # wrong type
        end
        context("can get the value by req.params[:id]") do
            @fact req.get("http://localhost:8000/users/10").data => "User id is:10"
        end
        context("regex route") do
            route(app, GET, "/name/<name::%[a-z]{3}[0-9]{2}>") do req, res
                req.params[:name]
            end

            @fact req.get("http://localhost:8000/name/abc33").data => "abc33"
            @fact req.get("http://localhost:8000/name/abc333").status => 404 # not match the regex
        end
    end

    facts("namespace") do
        namespace(app, "/namespace") do app
            get(app, "/hello/") do req, res
                "hello namespace"
            end
        end

        @fact req.get("http://localhost:8000/namespace/hello").data => "hello namespace"
    end
end
