"""
    hg2clique(hg::Hypergraph)

Build a clique graph from the hypergraph `h`.
The returned object is still a hypergraph.
"""
function hg2clique(hg::Hypergraph)
    clique_hg = Hypergraph{Int, Symbol, Symbol}(nhv(hg), 0)

    for he in 1:nhe(hg)
        vertices = collect(keys(getvertices(hg, he)))

        edges_cnt = 0

        for (i, v) in enumerate(vertices)
            for j in i+1:length(vertices)
                u = vertices[j]
                heᵥ = Dict{Int, Int}(v => true, u => true)
                add_hyperedge!(clique_hg; vertices=heᵥ, he_meta=get_hyperedge_meta(hg, he))
                edges_cnt += 1
            end
        end

        if edges_cnt != length(vertices) * (length(vertices) - 1) / 2
            println("ERROR - $he")
            break
        end
    end

    # let's attach vertex metadata to the clique hypergraph
    for v in 1:nhv(hg)
        set_vertex_meta!(clique_hg, get_vertex_meta(hg, v),  v)
    end

    clique_hg
end