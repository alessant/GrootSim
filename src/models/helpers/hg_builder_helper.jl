# create a hypergraph from multiple subreddits 
# or from just multiple scored conversations, i.e., submissions' threads
# clearly, this code is functional to the current structure
# of the data we have
# - subreddit
#   - submissions
#   - threads
function create_subreddits_hg(
    basepath::String,
    subs_to_include::Set{String},
    reddittors_to_include::Set{String};
    mindate::Union{DateTime,Nothing}=nothing, 
    maxdate::Union{DateTime,Nothing}=nothing,
    subreddits_to_include::Union{Set{String},Nothing}=nothing, #subreddits' names
    ignore_NI::Bool=false,
    reply_graph::Bool=false,
    verbose::Bool=false
)
    # *
    # * path-related params
    # *
    submission_path = joinpath(basepath, "submissions")
    thread_basepath = joinpath(basepath, "threads")
    subreddit_dirs = readdir(thread_basepath)

    # *
    # * hg-related params
    # *
    hg = Hypergraph{Bool, Symbol, Symbol}(0, 0)
    v_to_id = Dict{Symbol, Int}()
    he_to_id = Dict{Symbol, Int}()
    
    # *
    # * let's build the conv hypergraph
    # * considering all data we have
    # *

    for subreddit_dir in subreddit_dirs
        subreddit_name = split(subreddit_dir, "_")[1]

        !isnothing(subreddits_to_include) && !(subreddit_name in subreddits_to_include) && continue

        verbose && println("subreddit_name: ", subreddit_name)
    
        # first, we load all submissions' metadata 
        # within the subreddit 
        submission_metadata_path = joinpath(submission_path, subreddit_dir, "$(subreddit_name)_scored.csv")
        subs_df = CSV.read(submission_metadata_path, DataFrame)
    
        # we filter out the submissions that are not in the subs_to_include set
        filter!(row -> row[:sub_id] in subs_to_include, subs_df)
    
        # for each submission, we load the corresponding thread
        for sub_data in eachrow(subs_df)
            sub_id = sub_data[:sub_id]
            submitter_id = ismissing(sub_data[:author_id]) ? "unknown" : sub_data[:author_id]

            ignore_submitter = false
            
            if ignore_NI
                submitter_score = sub_data[:predicted_stance_scores]
                ignore_submitter = submitter_score == "NI"
            end

            if ismissing(sub_data[:author_id])
                ignore_submitter = true
            end
    
            thread_path = joinpath(thread_basepath, subreddit_dir, "_scored", "$(sub_id)_scored.csv")

            # if the thread does not exist, we skip it
            isfile(thread_path) || continue

            thread_df = CSV.read(thread_path, DataFrame)
    
            # we filter out the redditors that are not in the reddittors_to_include set
            filter!(row -> row[:author_id] in reddittors_to_include, thread_df)

            if ignore_NI
                # we also filter out all comments with a not inferrable stance ('NI')
                filter!(row -> row[:predicted_stance_scores] != "NI", thread_df)
            end
    
            nrow(thread_df) == 0 && continue

            if reply_graph
                GrootSim.build_reply_based_hg!(
                    thread_df,
                    submitter_id; 
                    hg=hg,
                    v_to_id=v_to_id,
                    he_to_id=he_to_id,
                    mindate=mindate,
                    maxdate=maxdate,
                    ignore_submitter=ignore_submitter,
                    verbose=verbose
                )
            else
                GrootSim.build_conv_hg!(
                    thread_df,
                    submitter_id; 
                    hg=hg,
                    v_to_id=v_to_id,
                    he_to_id=he_to_id,
                    mindate=mindate,
                    maxdate=maxdate,
                    ignore_submitter=ignore_submitter,
                    verbose=verbose
                )
            end
        end
    end

    return hg, v_to_id, he_to_id
end