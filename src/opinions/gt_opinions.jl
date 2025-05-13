# * get the first opinion of each user
function init_opinions_from_data(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String};
    subreddits_to_include::Union{Set{String},Nothing}=nothing #subreddits' names
)

    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    user_first_op_dict = Dict{Symbol, Float64}()
    user_first_action_dict = Dict{Symbol, DateTime}()

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]

        !isnothing(subreddits_to_include) && !(subreddit_name in subreddits_to_include) && continue
        
        println("subreddit_name: ", subreddit_name)

        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_scored.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        # these should already be filtered out
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)

        # transform the created_at column to a DateTime
        subs_df[!, :created_at] = DateTime.(subs_df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

        # for each submission, 
        # we get the associated score
        # and the scores of the comments
        for sub_data in eachrow(subs_df)
            # first, we get the score of the sub, if any
            GrootSim._get_first_score!(user_first_op_dict, user_first_action_dict, sub_data)

            sub_id = sub_data[:sub_id]

            # then, we get the scores of the comments
            thread_path = joinpath(thread_basepath, subreddit_dir, "_scored", "$(sub_id)_scored.csv")

            # if the thread does not exist, we skip it
            isfile(thread_path) || continue

            thread_df = CSV.read(thread_path, DataFrame)
    
            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)
            # we also filter out all comments with a not inferrable stance ('NI')
            filter!(row -> row[:predicted_stance_scores] != "NI", thread_df)

            nrow(thread_df) == 0 && continue

            # transform the created_at column to a DateTime
            thread_df[!, :created_at] = DateTime.(thread_df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

            # for each comment, we get the associated score
            for comment_data in eachrow(thread_df)
                GrootSim._get_first_score!(user_first_op_dict, user_first_action_dict, comment_data)
            end
        end
    end

    return user_first_op_dict, user_first_action_dict
end


# creation of the users' stance vector from labeled data

# * get all true user stance
# * over all desired period
# *
# * Dict{Symbol, Array{Pair{DateTime, Float64}}} 
# * where the key is the user id
# * and the value is an array of pairs (date, score)
function get_true_user_stance(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String};
    mindate::Union{DateTime,Nothing}=nothing, 
    maxdate::Union{DateTime,Nothing}=nothing,
    subreddits_to_include::Union{Nothing,Set{String}}=nothing, #subreddits' names
    verbose::Bool=true
)

    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    user_opinions_dict = Dict{Symbol, Array{Pair{DateTime,Float64}}}()

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]
        
        !isnothing(subreddits_to_include) && !(subreddit_name in subreddits_to_include) && continue

        println("subreddit_name: ", subreddit_name)
    
        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_scored.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)

        # transform the created_at column to a DateTime
        subs_df[!, :created_at] = DateTime.(subs_df[!, :created_at], "yyyy-mm-dd HH:MM:SS")
    
        # for each submission, 
        # we get the associated score
        # and the scores of the comments
        for sub_data in eachrow(subs_df)
            GrootSim._get_score!(user_opinions_dict, sub_data)
            sub_id = sub_data[:sub_id]
            
            # then, we get the scores of the comments
            thread_path = joinpath(thread_basepath, subreddit_dir, "_scored", "$(sub_id)_scored.csv")

            # if the thread does not exist, we skip it
            isfile(thread_path) || continue

            thread_df = CSV.read(thread_path, DataFrame)

            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)
            # we also filter out all comments with a not inferrable stance ('NI')
            filter!(row -> row[:predicted_stance_scores] != "NI", thread_df)

            nrow(thread_df) == 0 && continue

            # transform the created_at column to a DateTime
            thread_df[!, :created_at] = DateTime.(thread_df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

            if !isnothing(mindate) && !isnothing(maxdate)
                filter!(row -> mindate <= row[:created_at] <= maxdate, thread_df)
            end

            nrow(thread_df) == 0 && continue

            # for each comment, we get the associated score
            for comment_data in eachrow(thread_df)
                GrootSim._get_score!(user_opinions_dict, comment_data)
            end

        end # end loop over submissions
    end # end loop over subreddits

    return user_opinions_dict
end


# * get the average opinion of each user in each interval
# * Dict{Symbol, Vector{Union{Nothing, Float64}}}
# * where the key is the user id
# * and the value is an array of the average opinion of the user in each interval
function get_avg_user_opinion_per_interval(
    user_opinions,
    intervals
)
    user_opinions_per_interval = Dict{Symbol, Array{Union{Float64,Nothing}, 1}}()

    for (_, window) in enumerate(intervals)
        s_date = window.first
        e_date = window.second

        for (user, opinions) in user_opinions
            #_sorted_opinions = sort(opinions, by=x->x.first)
            _opinions = [x.second for x in opinions if s_date <= x.first < e_date]

            if length(_opinions) == 0
                push!(
                    get!(user_opinions_per_interval, user, Array{Union{Float64,Nothing}, 1}()),
                    nothing
                )
            else
                push!(
                    get!(user_opinions_per_interval, user, Array{Union{Float64,Nothing}, 1}()),
                    mean(_opinions)
                )
            end
        end # end loop over users
    end # end loop over intervals

    return user_opinions_per_interval
end