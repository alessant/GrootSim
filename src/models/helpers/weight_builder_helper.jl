# This helper function evaluates the starting time of each time window
# based on the importance decay function.
# - the same workflow can be used to evaluate and store the weight of each event
# - as well as the weight of each subthread
function eval_intervals_based_on_decay(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String},
    intervals::Array{DateTime, 1},
    starting_date::DateTime,
    thr::Float64=0.1;
    subreddits_to_include::Union{Nothing,Set{String}}=nothing, #subreddits' names
    verbose::Bool=false
)

    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    # * output params
    _intervals = Array{Pair{DateTime, DateTime}, 1}()

    # * working params
    interval_s_date = starting_date
    min_s_date = nothing

    mindates = Set()

    for (index, obs_date) in enumerate(intervals)
        println("index: ", index, " observation date: ", obs_date)

        s_date = interval_s_date
        min_s_date = obs_date

        for subreddit_dir in subreddit_dirs
            subreddit_name = split(subreddit_dir, "_")[1]

            !isnothing(subreddits_to_include) && !(subreddit_name in subreddits_to_include) && continue
            
            verbose && println("subreddit_name: ", subreddit_name)
        
            # first, we load all submissions' metadata 
            # within the subreddit 
            submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_subs.csv")
            subs_df = CSV.read(submission_metadata_path, DataFrame)
        
            # we filter out the submissions that are not in the subs_to_include set
            filter!(row -> row[:sub_id] in subs_to_include, subs_df)

            # for each submission, we load the corresponding thread
            for sub_data in eachrow(subs_df)
                sub_id = sub_data[:sub_id]

                # println("sub_id: ", sub_id)

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
                # thread_df[!, :created_at] = DateTime.(thread_df[!, :created_at], "yyyy-mm-dd HH:MM:SS")

                # * eval the min valid date
                # 2.1 Evaluate the weights of the vertices and hyperedges
                # - events_df cols: parent_id, comm_id, created_at, author_id, vertex_weight
                push!(mindates, minimum(thread_df[!, :created_at]))

                events_df, thread_weights = weight_relations(
                    ;
                    df = thread_df,
                    mindate=s_date,
                    maxdate=obs_date,
                    granularity=:day,
                    thr=thr,
                    verbose=false
                )

                if isnothing(events_df)
                    continue
                end

                verbose && println("Number of events considered in the interval: $(nrow(events_df))")

                # evaluating the new starting date
                # - this is the date of the first event whose weight is >= thr
                # c_s_date = s_date
                s_date = minimum(events_df[events_df[!, :vertex_weight] .>= thr, :created_at]; init=obs_date)

                # if s_date == obs_date
                #     verbose && println("No events with weight >= $thr in the interval: $c_s_date - $obs_date. Skipping...\n")
                #     continue
                # end

                if s_date < min_s_date 
                    min_s_date = s_date
                end
            end # end submission loop
        end # end subreddit loop

        printing_s_date = interval_s_date
        interval_s_date = maximum([interval_s_date, min_s_date])

        if interval_s_date == obs_date
            verbose && println("No events with weight >= $thr in the interval: $printing_s_date - $obs_date. Skipping...\n")
            continue
        end

        verbose && println("Adding the interval: $interval_s_date - $obs_date\n")
        push!(_intervals, Pair(interval_s_date, obs_date))

        println("-----------------------------------\n")

    end # end interval loop

    return _intervals, mindates
end
