# *
# * helper functions to evaluate the proper discretization param delta
# *

"""
    Evaluate the delay between the creation date of the parent comment and the creation date of each one of its replies.
"""
function eval_response_delay_distribution_across_threads(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String},
    verbose::Bool=false
)

    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    # * we could also have a dict per subreddit
    response_time_per_subthread = Dict{Symbol, Vector{DateTime}}()
    delays_per_subthread =  Dict{Symbol, Vector{Millisecond}}()

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]
        println("subreddit_name: ", subreddit_name)
    
        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_subs.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)
    
        # for each submission, we load the corresponding thread
        for sub_data in eachrow(subs_df)
            sub_id = sub_data[:sub_id]
            sub_creation_date = DateTime(sub_data[:created_at], "yyyy-mm-dd HH:MM:SS")
            # submitter_id = String(ismissing(sub_data[:author_id]) ? "unknown" : sub_data[:author_id])
    
            thread_path = joinpath(thread_basepath, subreddit_dir, "$(sub_id).csv")
            thread_df = CSV.read(thread_path, DataFrame)
    
            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)
    
            nrow(thread_df) == 0 && continue

            partial_response_time_per_subthread, partial_delays_per_subthread = 
                eval_response_delay_distribution(thread_df, sub_creation_date, verbose) 

            # update the global dict
            push!(response_time_per_subthread, partial_response_time_per_subthread...)
            push!(delays_per_subthread, partial_delays_per_subthread...)
        end
    end

    return response_time_per_subthread, delays_per_subthread
    
end


"""
    Evaluate the delay between the creation date of the parent comment and the creation date of each one of its replies.
"""
function eval_response_delay_distribution(
    df::DataFrame, 
    sub_creation_date::DateTime,
    verbose::Bool=false
)

    #sort comments_df by created_at
    DataFrames.sort!(df, :created_at)

    # transform the created_at column to a DateTime
    df[!, :created_at] = DateTime.(df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

    # subthread -> response time
    response_time_per_subthread = Dict{Symbol, Vector{DateTime}}()

    # The ID of the parent comment (prefixed with t1_). 
    # If it is a top-level comment, this returns the submission ID instead (prefixed with t3_)
    for comment in eachrow(df)
        parent_id = comment[:parent_id]
        created_at = comment[:created_at]

        # add the comment's creation date 
        # to the set of comments' data replying to the parent comment
        push!(
            get!(response_time_per_subthread, Symbol(parent_id), Vector{DateTime}[]),
            created_at
        )
    end

    # we also need to add the creation date of the parent comment
    # to the vector of comments replying to it 
    # (in this way, we won't have any hyperedge of size 1)
    # ps we could continue having hyperedges of size 1
    # if the parent comment has been deleted
    for parent_id in keys(response_time_per_subthread)
        # id of the parent comment
        p_id = String(parent_id)
        # creation date of the parent comment
        p_creation_date = nothing

        # if the parent comment is a top-level comment
        if startswith(p_id, "t3")
            p_creation_date = sub_creation_date
        else # p_id.startswith("t1")
            p_comm_id = p_id[4:length(p_id)]
            p_df = df[df[!, :comm_id] .== p_comm_id, :created_at]

            if length(p_df) > 0
                p_creation_date = p_df[1]
            else
                verbose && println("Comment deleted - Parent author not added, $(p_id)")
                continue
            end
        end

        # add the parent author to the set of authors replying to the parent comment
        push!(
                get!(response_time_per_subthread, Symbol(p_id), Vector{DateTime}[]),
                p_creation_date
        )
    end

    delays_per_subthread = Dict{Symbol, Vector{Millisecond}}()

    for subthread in keys(response_time_per_subthread)
        # just to be sure
        sorted_creation_dates = sort(response_time_per_subthread[subthread])
        
        # evaluate the delay between two consecutive comments
        # i.e., considering the time elapsed between 
        # the creation date of the parent comment and the creation date of each one of its replies
        delays = [sorted_creation_dates[i] - sorted_creation_dates[1] for i in 2:length(sorted_creation_dates)]
        
        # store the result
        push!(delays_per_subthread, subthread => delays)
    end

    return response_time_per_subthread, delays_per_subthread
end


# *
# * Helper functions to evaluate how big will be the hg at each time interval
# * - this is only an estimation since we are considering fixed-width windows
# *   and not the sliding windows of the simulation
# *

"""
    Compute in which intervals each user has been active.
"""
function populate_existence_intervals(
    df::DataFrame,
    intervals::Dict
)

    # output
    # user_id => intervals in which they have posted a comment 
    user_intervals = Dict{Symbol, Set{Int}}()
    # parent_id => intervals in which they have been updated 
    subthread_intervals = Dict{Symbol, Set{Int}}()

    # for each interval
    for i in intervals
        mindate = i.second.first
        maxdate = i.second.second

        curr_df = filter(
            row -> row[:created_at] >= mindate && row[:created_at] < maxdate,
            df
        )

        # we store which 
        # user has posted a replies
        # as answer to which comment
        users = unique(curr_df[!, :author_id])

        for u in users
            push!(
                get!(user_intervals, Symbol(u), Set{Int}()),
                i.first
            )
        end

        # here, we store the intervals within which
        # a subthread has been answered
        subthreads = unique(curr_df[!, :parent_id])

        for s in subthreads
            push!(
                get!(subthread_intervals, Symbol(s), Set{Int}()),
                i.first
            )
        end  
    end
    
    return user_intervals, subthread_intervals

end


#
# ^ USER-RELATED FUNCTIONS ^
#

"""
    Evaluate the number of users per each interval of time across multiple conversations.
"""
function eval_users_density_across_threads(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String},
    mindate::DateTime,
    maxdate::DateTime,
    Δ::Dates.Millisecond;
    normalized::Bool=false,
    verbose::Bool=false
)

    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    # *
    # * analysis-related params
    # *
    # we consider the same intervals for each thread
    intervals = build_intervals(DiscreteIntervals; mindate=mindate, maxdate=maxdate, stride=Δ)

    k_int = collect(range(1, length=length(intervals)+1))
    users_per_intervals = Dict{Int,Union{Int,Float64}}(k_int .=> 0)

    authors = Set()

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]
        println("subreddit_name: ", subreddit_name)
    
        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_subs.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)
    
        # for each submission, we load the corresponding thread
        for sub_data in eachrow(subs_df)
            sub_id = sub_data[:sub_id]
            sub_creation_date = DateTime(sub_data[:created_at], "yyyy-mm-dd HH:MM:SS")
    
            thread_path = joinpath(thread_basepath, subreddit_dir, "$(sub_id).csv")
            thread_df = CSV.read(thread_path, DataFrame)
    
            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)
    
            nrow(thread_df) == 0 && continue

            authors = union(authors, thread_df[!, :author_id])

            # we evaluate the number of users per each interval of time
            partial_users_per_interval = eval_users_density(thread_df, intervals)

            # we update the global users_per_intervals dictionary
            for (k, v) in partial_users_per_interval
                users_per_intervals[k] += v
            end
        end
    end

    if normalized
        for (interval, n_users) in users_per_intervals
            users_per_intervals[interval] = n_users /= length(authors)
        end
    end

    users_per_intervals
end


"""
    Evaluate the number of users per each interval of time.
"""
function eval_users_density(
    df::DataFrame,
    intervals::Dict; 
    normalized=false
)

    # transform the created_at column to a DateTime
    df[!, :created_at] = DateTime.(df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

    # discretize the observation period
    #intervals = eval_intervals(DiscreteIntervals; minimum(df[!, :created_at]), maximum(df[!, :created_at]), Δ)
    
    # knowledge about which user
    # has contributed in which interval
    # so kinda want to create the inverse
    user_intervals, _ = populate_existence_intervals(df, intervals)

    #k_int = union(collect(Iterators.flatten(values(user_intervals))))
    k_int = collect(range(1, length=length(intervals)+1))
    users_per_intervals = Dict{Int,Union{Int,Float64}}(k_int .=> 0)

    for user in keys(user_intervals)
        for i in user_intervals[user]
            users_per_intervals[i] += 1
        end
    end

    if normalized
        for (interval, n_users) in users_per_intervals
            users_per_intervals[interval] = n_users /= length(user_intervals)
        end
    end

    users_per_intervals
end


#
# ^ SUBTHREAD-RELATED FUNCTIONS ^
#

"""
    Evaluate the number of subthreads per each interval of time across multiple conversations.
"""
function eval_threads_density_across_threads(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String},
    mindate::DateTime,
    maxdate::DateTime,
    Δ::Dates.Millisecond;
    normalized::Bool=false,
    verbose::Bool=false
)
    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    # *
    # * analysis-related params
    # *
    # we consider the same intervals for each thread
    intervals = build_intervals(DiscreteIntervals; mindate=mindate, maxdate=maxdate, stride=Δ)

    k_int = collect(range(1, length=length(intervals)+1))
    subthread_per_intervals = Dict{Int,Union{Int,Float64}}(k_int .=> 0)

    subthreads = Set()

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]
        println("subreddit_name: ", subreddit_name)
    
        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_subs.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)
    
        # for each submission, we load the corresponding thread
        for sub_data in eachrow(subs_df)
            sub_id = sub_data[:sub_id]
    
            thread_path = joinpath(thread_basepath, subreddit_dir, "$(sub_id).csv")
            thread_df = CSV.read(thread_path, DataFrame)
    
            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)
    
            nrow(thread_df) == 0 && continue

            union!(subthreads, thread_df[!, :parent_id])

            # we evaluate the number of users per each interval of time
            partial_subthread_per_intervals = eval_threads_density(thread_df, intervals)

            # we update the global users_per_intervals dictionary
            for (k, v) in partial_subthread_per_intervals
                subthread_per_intervals[k] += v
            end
        end
    end

    if normalized
        for (interval, n_users) in subthread_per_intervals
            subthread_per_intervals[interval] = n_users /= length(subthreads)
        end
    end

    subthread_per_intervals
end


"""
    Evaluate the number of subthreads per each interval of time.
"""
function eval_threads_density(
    df::DataFrame,
    intervals::Dict; 
    normalized=false
)
    # transform the created_at column to a DateTime
    df[!, :created_at] = DateTime.(df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

    # knowledge about which user
    # has contributed in which interval
    # so kinda want to create the inverse
    _, subthread_intervals = populate_existence_intervals(df, intervals)

    k_int = collect(range(1, length=length(intervals)+1))
    subthread_per_intervals = Dict{Int,Union{Int,Float64}}(k_int .=> 0)

    for subthread in keys(subthread_intervals)
        for i in subthread_intervals[subthread]
            subthread_per_intervals[i] += 1
        end
    end

    if normalized
        for (interval, n_threads) in subthread_per_intervals
            subthread_per_intervals[interval] = n_threads /= length(subthread_intervals)
        end
    end

    subthread_per_intervals
end


#
# ^ COMMENT-RELATED FUNCTIONS ^
#
    
"""
    Evaluate the number of comments per each interval of time across multiple conversations.
"""
function eval_comments_density_across_threads(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String},
    mindate::DateTime,
    maxdate::DateTime,
    Δ::Dates.Millisecond;
    normalized::Bool=false,
    verbose::Bool=false
)
    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    # *
    # * analysis-related params
    # *
    # we consider the same intervals for each thread
    intervals = build_intervals(DiscreteIntervals; mindate=mindate, maxdate=maxdate, stride=Δ)

    k_int = collect(range(1, length=length(intervals)+1))
    comments_per_intervals = Dict{Int,Union{Int,Float64}}(k_int .=> 0)

    n_comms = 0

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]
        println("subreddit_name: ", subreddit_name)
    
        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_subs.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)
    
        # for each submission, we load the corresponding thread
        for sub_data in eachrow(subs_df)
            sub_id = sub_data[:sub_id]
    
            thread_path = joinpath(thread_basepath, subreddit_dir, "$(sub_id).csv")
            thread_df = CSV.read(thread_path, DataFrame)
    
            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)
    
            nrow(thread_df) == 0 && continue

            n_comms += nrow(thread_df)

            # we evaluate the number of users per each interval of time
            partial_comments_per_intervals = eval_comments_density(thread_df, intervals)

            # we update the global users_per_intervals dictionary
            for (k, v) in partial_comments_per_intervals
                comments_per_intervals[k] += v
            end
        end
    end

    if normalized
        for (interval, n_users) in comments_per_intervals
            comments_per_intervals[interval] = n_users /= n_comms
        end
    end

    comments_per_intervals
end


"""
    Evaluate the number of comments per each interval.
"""
function eval_comments_density(
    df::DataFrame,
    intervals::Dict; 
    normalized=false
)

    # transform the created_at column to a DateTime
    df[!, :created_at] = DateTime.(df[!, :created_at], "yyyy-mm-dd HH:MM:SS")
    
    comments_per_interval = Dict{Int, Int}()

    # for each interval
    for i in intervals
        mindate = i.second.first
        maxdate = i.second.second

        curr_df = filter(
            row -> row[:created_at] >= mindate && row[:created_at] < maxdate,
            df
        )

        #println(nrow(curr_df))

        push!(
            comments_per_interval,
            i.first => nrow(curr_df)
        ) 
    end

    comments_per_interval
end

