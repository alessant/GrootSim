abstract type VertexWeightBuilder end
struct Exponential <: VertexWeightBuilder end

abstract type HeWeightBuilder end
struct Average <: HeWeightBuilder end

"""
    Assign weights to subthreads (i.e., hyperedges) based on the 
    weights of the events within the given subthread.

* `granularity`: the granularity of the time intervals used to compute the weights (i.e., the stride)
* `weight_event_method`: the method used to assign weights to events (Expotential as default)
* `aggregation_method`: the method used to aggregate the weights of the events within a subthread (Average as default)
* `thr`: the threshold used to filter out events with a weight below the given threshold
"""
function weight_relations(
        ;
        filepath::AbstractString="",
        df::DataFrame=nothing,
        mindate::Union{DateTime,Nothing}=nothing, 
        maxdate::Union{DateTime,Nothing}=nothing,
        granularity::Symbol=:day,
        weight_event_method::Type{<:VertexWeightBuilder}=Exponential,
        aggregation_method::Type{<:HeWeightBuilder}=Average,
        thr::Float64=0.0,
        verbose::Bool=false
    )

    # file containing all comments
    if !isnothing(df)
        _df = copy(df)
    else
        _df = CSV.read(filepath, DataFrame)
    end
    
    if !isnothing(mindate) && !isnothing(maxdate)
        # transform the created_at column to a DateTime
        _df[!, :created_at] = DateTime.(_df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

        filter!(
            row -> row[:created_at] >= mindate && row[:created_at] < maxdate,
            _df
        )

        if nrow(_df) == 0
            # println("No events in the given time interval: ", mindate, " - ", maxdate)
            # println("Mindate and maxdate of the thread: ", minimum(df[!, :created_at]), " - ", maximum(df[!, :created_at]))
            # println()
            return nothing, nothing
        end
        
        verbose && println("Number of events in the given time interval: ", nrow(_df))
    end

    # * vertex (i.e., event) weights evaluation
    events = _df[!, [:parent_id, :comm_id, :created_at, :author_id]]

    vertex_weights = map(
        row -> weight_event(
                row[:created_at], 
                weight_event_method; 
                maxdate=maxdate, 
                granularity=granularity, 
                verbose=false
            ),
        eachrow(events)
    )

    events[!, :vertex_weight] = vertex_weights

    # * hyperedge (i.e., subthread) weights evaluation
    # subthread (he) => [event weights]
    # parent_id => authors replying to this comment 
    subt_events = Dict{Symbol, Array{Float64}}()

    # The ID of the parent comment (prefixed with t1_). 
    # If it is a top-level comment, this returns the submission ID instead (prefixed with t3_)
    for comment in eachrow(events)
        parent_id = comment[:parent_id]
        event_weight = comment[:vertex_weight]

        # add the comment's weight
        # to the subthread
        push!(
            get!(subt_events, Symbol(parent_id), Array{Float64, 1}()),
            event_weight
        )
    end

    # we also need to add the author of the parent comment
    # to the set of authors replying to it (in this case, its creation date and weight)
    # (in this way, we won't have any hyperedge of size 1)
    # ps we could continue having hyperedges of size 1
    # if the parent comment has been deleted
    for parent_id in keys(subt_events)
        s_parent_id = String(parent_id)
        # get the author of the parent comment
        try
            parent_weight = events[events[!, :comm_id] .== s_parent_id[4:length(s_parent_id)], :vertex_weight][1]
            push!(
                get!(subt_events, parent_id, Array{Float64, 1}()),
                parent_weight
            )
        catch BoundsError
            #verbose && println("Comment deleted")
            continue
        end
    end

    # * now that we have all the subthreads,
    # * we can evaluate their weight within the
    # * given time window
    thread_weights = Dict{Symbol, Union{Float64,Nothing}}()

    for (parent_id, event_weights) in subt_events
        thread_weights[parent_id] = weight_thread(event_weights, aggregation_method; thr=thr)
    end

    return events, thread_weights
end


"""
    Assign weights to subthreads (i.e., hyperedges) based on the 
    weights of the events within the given subthread 
    (if the event weight is highr than a thr).
"""
function weight_thread(event_weights::T, type::Type{Average}; thr::Float64=0.0) where T <: AbstractArray{<:Real}
    # filter out all events whose weight is below the threshold
    _event_weights = [w for w in event_weights if w >= thr]

    # if all the events have been filtered out
    # this means that the relation no longer exists
    if length(_event_weights) == 0
        return nothing
    end

    return mean(_event_weights)
end


"""
    Assign weights to events based on the time elapsed 
    between the event and the event horizon.
"""
function weight_event(
        event_time::DateTime, 
        type::Type{Exponential}; 
        maxdate::DateTime, 
        granularity=:hour,
        verbose::Bool=true
    ) 

    t = _evaluate_elapsed_time(event_time, maxdate, granularity=granularity)
    k = 1.0 # β / T₀

    verbose && println(t)

    return exp(-k*t)    
end

"""
    Helper function to evaluate the time elapsed between the event and the event horizon.
"""
function _evaluate_elapsed_time(event_time::DateTime, maxdate::DateTime;granularity=:hour)
    # evaluating the time elapsed beween the last event and the event horizon
    Δₜ = Dates.value(maxdate - event_time)
    # convert to minutes 
    Δₜ = round(Δₜ/60000)

    # convert to minutes
    granularity == :minute && return Δₜ

    # convert to hours
    granularity == :hour && return Δₜ/60

    # convert to 6-hours
    granularity == :sixhours && return Δₜ/60/6

    # convert to half-days
    granularity == :halfday && return Δₜ/60/12

    # convert to days
    granularity == :day && return Δₜ/60/24

    # converto to weeks 
    granularity == :week && return Δₜ/60/24/7

    #convert to months
    granularity == :month && return Δₜ/60/24/30
end