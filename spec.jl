using Morsel

app = Morsel.app()

# Route with HTTP verbs
get(app, "/") do req, res
    "hello"
end

post(app, "/") do req, res
    # ...
end

# Route with URL vars
route(app, GET, "/hello/<id::Int>/<name::%[a-z]{3}[0-9]{2}>") do req, res
    req.params[:id] == 99 ? string("Go to hell ", req.params[:name]) : string("Hello ", req.params[:name])
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
auth = Morsel.Midware() do req, res
    if !get(session(req), :authenticated, false)
        return req, redirect(res, "/login")
    end
    req, res
end

with(app, auth) do app
    get(app, "/private") do req, res
        # ...
    end
end

namespace(app, "/admin", auth) do app
    get(app, "/pages/<page_id::Int>") do req, res
        page = get_page(req.params[:page_id])
        render("viewName.ejl", page)
    end

    put(app, "/pages/<page_id::Int>") do req, res
        update_page(get_page(req.params[:page_id]), req.params)
        redirect(res, "/pages/", req.params[:page_id])
    end
end

route(app, GET, "/*") do req, res
    res.headers["Status"] = 404
    render("404.ejl")
end

start(app, 8000)
