module Routes

using Trees

function ismatch(v1::StringNode, v2::String)
    v1.value == v2
end
ismatch(v1::String, v2::String) = v1 == v2

function searchroute(route)
    function searchpred(val)
        if ismatch(val, route[1])
            if length(route) == 1
                true
            else
                route = route[2:end]; false
            end
        else
            Trees.PRUNE
        end
    end
end

end # module Routes
