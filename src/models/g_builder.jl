"""
Build a hypergraph from a csv file containing the comments of a subreddit, where:
- each vertex represents a user
- each hyperedge represents a direct interaction between two redditors
"""
function build_reply_based_hg!(
    df::DataFrame,
    submitter_id::AbstractString; # the id of the user who submitted the post may be only stored in the submission file and not in the comments file (that's why we need to pass it as an argument)
    hg::Union{Hypergraph,Nothing}=nothing,
    v_to_id::Union{Dict,Nothing}=nothing,
    he_to_id::Union{Dict,Nothing}=nothing,
    mindate::Union{DateTime,Nothing}=nothing, 
    maxdate::Union{DateTime,Nothing}=nothing,
    ignore_submitter::Bool=false,
    verbose::Bool=true
)

    if !isnothing(mindate) && !isnothing(maxdate)
        # transform the created_at column to a DateTime
        df[!, :created_at] = DateTime.(df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

        filter!(
            row -> row[:created_at] >= mindate && row[:created_at] < maxdate,
            df
        )
    end

    # compute the direct interaction
    # to be added to the hg
    edges = Dict{Pair{Symbol, Symbol}, Int}()
    # edge -> comment within which the interaction happened
    edges_parent = Dict{Pair{Symbol, Symbol}, Symbol}()

    # let's store all user ids we found
    vertices = Set{Symbol}()

    for comment in eachrow(df)
        # get the author of the comment
        author_id = Symbol(comment[:author_id])
        # add the author to the set of vertices
        push!(vertices, author_id)

        # get the id of the parent comment
        p_id = comment[:parent_id]
        parent_id = p_id[4:length(p_id)]
        # author of the parent comment
        p_author_id = nothing

        # if the parent comment is a top-level comment
        if startswith(p_id, "t3")
            if (!ignore_submitter) #|| (submitter_id == ("unknown"))
                p_author_id = Symbol(submitter_id)
            end
        else # p_id.startswith("t1")
            # get the author of the parent comment
            parent_df = df[df[!, :comm_id] .== parent_id, :author_id]

            if length(parent_df) > 0
                p_author_id = Symbol(parent_df[1])
            else
                verbose && println("Comment deleted - Edge not added since parent $(parent_id) not found $(p_id)")
                continue
            end
        end

        # if the parent author has to be included in the graph
        if !isnothing(p_author_id)
            # direct interaction between u and v
            e = author_id < p_author_id ? author_id => p_author_id : p_author_id => author_id
            
            # add the edge to the set of edges
            # and increment the edge occurence
            edges[e] = get(edges, e, 0) + 1  
            
            if !haskey(edges_parent, e)
                edges_parent[e] = Symbol(p_id)
            end
        end
    end

    # now let's actually build the (h)g
    hg = isnothing(hg) ? Hypergraph{Bool, Symbol, Symbol}(0, 0) : hg
    v_to_id = isnothing(v_to_id) ? Dict{Symbol, Int}() : v_to_id
    he_to_id = isnothing(he_to_id) ? Dict{Symbol, Int}() : he_to_id

    for edge in keys(edges)
        u = edge.first
        v = edge.second

        # add the vertices to the hg
        if !haskey(v_to_id, u)
            u_id = add_vertex!(hg; v_meta=u)
            v_to_id[u] = u_id
        end

        if !haskey(v_to_id, v)
            v_id = add_vertex!(hg; v_meta=v)
            v_to_id[v] = v_id
        end

        vertices_per_he = Dict{Int, Bool}()
        vertices_per_he[v_to_id[u]] = true
        vertices_per_he[v_to_id[v]] = true
        
        he_id = add_hyperedge!(hg, vertices=vertices_per_he; he_meta=edges_parent[edge])
        push!(he_to_id, Symbol(edges_parent[edge]) => he_id)
    end

    # add the vertices to the hg
    # in this way, we add all isolated vertices
    for v in vertices
        if !haskey(v_to_id, v)
            v_id = add_vertex!(hg; v_meta=v)
            v_to_id[v] = v_id
        end
    end

    hg, v_to_id, he_to_id 
end