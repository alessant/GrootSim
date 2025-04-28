"""

"""
function degree_histogram(hg; normalized=false) 
    hist = Dict{Int,Union{Int,Float64}}()
    
    for v in 1:nhv(hg)      
        deg = length(gethyperedges(hg, v))
        hist[deg] = get(hist, deg, 0) + 1
    end

    if normalized
        for (deg, count) in hist
            hist[deg] = count / nhv(hg)
        end

        return hist
    end

    return hist
end


"""

"""
function size_histogram(hg; normalized=false) 
    hist = Dict{Int,Union{Int,Float64}}()

    for he in 1:nhe(hg)      
        s = length(getvertices(hg, he))
        hist[s] = get(hist, s, 0) + 1
    end

    if normalized
        for (s, count) in hist
            hist[s] = count / nhe(hg)
        end

        return hist
    end

    return hist
end