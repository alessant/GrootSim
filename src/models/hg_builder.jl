"""
 Build a hypergraph from a csv file containing the comments of a subreddit, where:
 - each vertex represents a user
 - each hyperedge represents a thread
    - each hyperedge contains the users that replied to the thread
"""
function build_conv_hg!(
        df::DataFrame,
        submitter_id::AbstractString; # the id of the user who submitted the post may be only stored in the submission file and not in the comments file (that's why we need to pass it as an argument)
        hg::Union{Hypergraph,Nothing}=nothing,
        v_to_id::Union{Dict,Nothing}=nothing,
        he_to_id::Union{Dict,Nothing}=nothing,
        mindate::Union{DateTime,Nothing}=nothing, 
        maxdate::Union{DateTime,Nothing}=nothing,
        ignore_submitter::Bool=false,
        verbose::Bool=false
)

    if !isnothing(mindate) && !isnothing(maxdate)
        # transform the created_at column to a DateTime
        df[!, :created_at] = DateTime.(df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

        filter!(
            row -> row[:created_at] >= mindate && row[:created_at] < maxdate,
            df
        )
    end

    # hg data
    # he => node set
    # parent_id => authors replying to this comment 
    hg_mapping = Dict{Symbol, Set{Symbol}}()

    # The ID of the parent comment (prefixed with t1_). 
    # If it is a top-level comment, this returns the submission ID instead (prefixed with t3_)
    for comment in eachrow(df)
        #comment_id = comment[:comm_id]
        author_id = comment[:author_id]

        parent_id = comment[:parent_id]
        #top_level = startswith(parent_id, "t3_")

        # add the comment's author 
        # to the set of authors replying to the parent comment
        push!(
            get!(hg_mapping, Symbol(parent_id), Set{Symbol}()),
            Symbol(author_id)
        )
    end

    # we also need to add the author of the parent comment
    # to the set of authors replying to it 
    # (if we didn't already included them as an author of a comment)
    # (in this way, we won't have any hyperedge of size 1)
    # ps we could continue having hyperedges of size 1
    # if the parent comment has been deleted
    #
    for parent_id in keys(hg_mapping)
        # id of the parent comment
        p_id = String(parent_id)
        # author of the parent comment
        p_author_id = nothing

        # if the parent comment is a top-level comment
        if startswith(p_id, "t3")
            if (!ignore_submitter) #|| (submitter_id == ("unknown"))
                p_author_id = Symbol(submitter_id)
            end
        else # p_id.startswith("t1")
            p_comm_id = p_id[4:length(p_id)]
            p_df = df[df[!, :comm_id] .== p_comm_id, :author_id]

            if length(p_df) > 0
                p_author_id = Symbol(p_df[1])
            else
                verbose && println("Comment deleted - Parent author not added, $(p_id)")
                continue
            end
        end

        # add the parent author to the set of authors replying to the parent comment
        if !isnothing(p_author_id)
            push!(
                get!(hg_mapping, parent_id, Set{Symbol}()),
                p_author_id
            )
        end
    end

    # now let's actually build the hg
    hg = isnothing(hg) ? Hypergraph{Bool, Symbol, Symbol}(0, 0) : hg
    v_to_id = isnothing(v_to_id) ? Dict{Symbol, Int}() : v_to_id
    he_to_id = isnothing(he_to_id) ? Dict{Symbol, Int}() : he_to_id

    # for each hyperedge (basically)
    for (parent_id, authors) in hg_mapping
        
        # collect the ids of the authors
        vertices_per_he = Dict{Int, Bool}()

        # check whether we have already 
        # added the node author
        for author_id in authors
            if !haskey(v_to_id, author_id)
                v_id = SimpleHypergraphs.add_vertex!(hg; v_meta=author_id)
                v_to_id[author_id] = v_id
            end

            # add this vertex to the list of incident vertices
            # namely, when we add the hyperedge SUBTHREAD, we say that it contains
            # all these vertices AUTHORS
            push!(
                vertices_per_he,
                get!(v_to_id, author_id, nothing) => true 
            )
        end

        # now we can add the hyperedge SUBTHREAD to the hypergraph
        he_id = add_hyperedge!(hg; vertices=vertices_per_he, he_meta=Symbol(parent_id))
        push!(he_to_id, Symbol(parent_id) => he_id)
    end

    return hg, v_to_id, he_to_id
end
