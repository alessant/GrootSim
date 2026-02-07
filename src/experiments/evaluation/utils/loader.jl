# *
# * utils for evaluation_runner.jl
# * load data and results
# *
function _load_params(window; subreddits_to_include=nothing)
    # * reddit-related params
    scored_basepath = ENV["DATA_PATH"]
    data_to_include_path = ENV["DATA_TO_INCLUDE_PATH"]
    precomputed_params_path = ENV["PRECOMPUTED_PARAMS_PATH"]
    # * loading the data
    reddittors_to_include = Set(pickle.load(open(joinpath(data_to_include_path, "final_users_to_include.pkl"))))
    subs_to_include = (pickle.load(open(joinpath(data_to_include_path, "final_subs_to_include.pkl"))))
    subs_to_include = Set([sub_id[4:end] for sub_id in subs_to_include])

    subreddits_dir = isnothing(subreddits_to_include) ? 
        "all" : join(sort(collect(subreddits_to_include)), "_")

    # * loading the most active users,
    # * namely the users with at least two actions
    most_active_users = deserialize(joinpath(precomputed_params_path, window, subreddits_dir, "most_active_users.ser"))

    # * loading the simulation intervals
    sim_intervals = deserialize(joinpath(precomputed_params_path, window, subreddits_dir, "sim_intervals.ser"))

    # * loading active intervals per users
    active_intervals_per_user = deserialize(joinpath(precomputed_params_path, window, subreddits_dir, "active_intervals_per_user.ser"))

    # * loading user opinions from ground-truth
    gt_user_opinions = get_true_user_stance(
        scored_basepath,
        subs_to_include,
        reddittors_to_include;
        subreddits_to_include=subreddits_to_include
    )

    # * loading the user opinions per interval
    gt_user_opinions_per_interval = get_avg_user_opinion_per_interval(
        gt_user_opinions,
        sim_intervals
    )

    return most_active_users, sim_intervals, active_intervals_per_user, gt_user_opinions, gt_user_opinions_per_interval
end

# *
# * utils for evaluation_runner.jl
# * load simulation results in a generalized manner
# *
function _load_sim_results_generalized(time_window, net_model; subreddits_to_include=nothing)
    sim_res_path = ENV["SIMULATION_RESULTS_PATH"]
    subreddits_dir = isnothing(subreddits_to_include) ? 
        "all" : join(sort(collect(subreddits_to_include)), "_")
    datapath = joinpath(sim_res_path, time_window, subreddits_dir, net_model, "ser")

    # load all files within datapath
    files = readdir(datapath)
    hi, hi_iter, mi, mi_iter, li, li_iter = nothing, nothing, nothing, nothing, nothing, nothing
    
    for file in files
        # if the file name contains id1 -> hi
        if occursin("id1", file) 
            if occursin("opinion_history_all", file)
                hi = deserialize(joinpath(datapath, file))
            end
            if occursin("iters", file)
                hi_iter = deserialize(joinpath(datapath, file))
            end
        # if the file name contains id2 -> mi
        elseif occursin("id2", file)
            if occursin("opinion_history_all", file)
                mi = deserialize(joinpath(datapath, file))
            end
            if occursin("iters", file)
                mi_iter = deserialize(joinpath(datapath, file))
            end
        # if the file name contains id3 -> li
        elseif occursin("id3", file)
            if occursin("opinion_history_all", file)
                li = deserialize(joinpath(datapath, file))
            end
            if occursin("iters", file)
                li_iter = deserialize(joinpath(datapath, file))
            end
        end
    end


    return Dict{Symbol, Any}(
        :hi => hi,
        :mi => mi,
        :li => li,
        :hi_iter => hi_iter,
        :mi_iter => mi_iter,
        :li_iter => li_iter
    )
end


# *
# * utils for criteria analyzer
# *
function _loading_data(
    thr::Int, 
    subreddits_to_include::Vector{String}, 
    metric::AbstractString, 
    basepath::AbstractString
)

    data = OrderedDict{String, DataFrame}()

    for hnetwork in subreddits_to_include
        #println(hnetwork)

        df = nothing
        # println(basepath)

        if metric == "confusion_matrix" || metric == "metrics" ||  metric == "first_drift" || metric == "direction"
            df = CSV.read(joinpath(basepath, hnetwork, "first_drift_all_$(thr)_band_thrs.csv"), DataFrame)
        # elseif metric == "direction"
        #     df = CSV.read(joinpath(basepath, hnetwork, "data", "new_first_drift_all_$(thr)_band_thrs.csv"), DataFrame)
        elseif metric == "n_drifts"
            df = CSV.read(joinpath(basepath, hnetwork, "n_drifts_$(thr)_band_thrs.csv"), DataFrame)
        elseif metric == "last_stance"
            df = CSV.read(joinpath(basepath, hnetwork, "last_stance_$(thr)_band_thrs.csv"), DataFrame)
        elseif metric == "last_stance_ml"
            df = CSV.read(joinpath(basepath, hnetwork, "data", "last_stance_ML_$(thr)_band_thrs.csv"), DataFrame)
        elseif metric == "drifters"
            df = CSV.read(joinpath(basepath, hnetwork, "data", "count_users_$(thr)_band_thrs.csv"), DataFrame)
        end
        data[hnetwork] = df
    end

    return data
end