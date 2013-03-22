using Micro

app = Micro.app()

# Route with HTTP verbs
get(app, "/") do req, res
    "hello"
end

post(app, "/") do req, res
    # ...
end

# Route with URL vars
route(app, "/hello/<id::Int>/<name::%[a-z]{3}[0-9]{2}>") do req, res
    req.resources[:id] == 99 ? string("Go to hell ", req.resources[:name]) : string("Hello ", req.resources[:name])
end

route(app, GET, "/") do req, res
    # ...
end

route(app, GET | POST, "/") do req, res
    # ...
end

route(app, ALL, "/") do req, res
    # ...
end

function handleImageUpload(req, res)
    "Nice pix."
end

route(app, POST, "/upload", handleImageUpload)

# Route middleware
auth = Micro.Midware() do req, res
    if !get(session(req), :authenticated, false)
        return req, redirect("/login")
    end
    req, res
end

with(auth) do
    get(app, "/private") do req, res
        # ...   
    end  
end

namespace(app, "/admin", auth) do
    get(app, "/pages/<page_id::Int>") do req, res
        page = get_page(req.resources[:page_id])
        render("viewName.ejl", page)
    end

    put(app, "/pages/<page_id::Int>") do req, res
        update_page(get_page(req.resources[:page_id]), req.params)
        redirect("/pages/", req.resources[:page_id])
    end
end

route(app, "/*") do req, res
    res.headers["Status"] = 404
    render("404.ejl")
end

start(app, 8000)
