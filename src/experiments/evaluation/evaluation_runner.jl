using Pkg
Pkg.activate(".")

using GrootSim

using CSV
using DataFrames
using Dates
using DotEnv
DotEnv.load!()
using Distributions
using PyPlot
# using Serialization

########################################################################################
# DATA
########################################################################################
subreddits_to_eval = [
    "all",
    # "AskReddit",
    # "bayarea", DONE
    # "California", DONE
    # "collapse", 
    # "news",
    # "politics",
    # "AskReddit_collapse",
    # "AskReddit_news",
    # "AskReddit_politics",
    # "bayarea_news", DONE
    # "collapse_news",
    # "collapse_politics",
    # "AskReddit_news_politics",
    # "collapse_news_politics"
]

# *
# * eval params
# *
my_step = 0.1

one_thr = []
for thr in 0.1:my_step:0.99
    push!(one_thr, [-1.1, thr, 1.1])
end

two_thrs = []
for thr1 in 0.1:my_step:0.99
    for thr2 in 0.9:-my_step:0.1
        thr2 <= thr1 && continue
        push!(two_thrs, [-1.1, thr1, thr2, 1.1])
    end
end

three_thrs = []
for thr1 in 0.1:my_step:0.99
    for thr2 in 0.1:my_step:0.99
        thr2 <= thr1 && continue
        for thr3 in 0.1:my_step:0.99
            thr3 <= thr2 && continue
            push!(three_thrs, [-1.1, thr1, thr2, thr3, 1.1])
        end  
    end
end

net_models = [:hg, :clique, :graph]
thrs_vector = [one_thr, two_thrs, three_thrs]
time_window = "day" #"sixhours"
thrs_vector = [one_thr, two_thrs, three_thrs]

# *
# * evaluation
# *
for subreddit in subreddits_to_eval
    # *
    # * input data
    # *
    if subreddit == "all"
        subreddits_to_include = nothing
    else
        subreddits_to_include = Set{String}()
        push!(subreddits_to_include, split(subreddit, "_")...)
    end

    println(subreddits_to_include)

    most_active_users, sim_intervals, active_intervals_per_user, gt_user_opinions, gt_user_opinions_per_interval = GrootSim._load_params(time_window; subreddits_to_include=subreddits_to_include)

    hg_sim_data = GrootSim._load_sim_results_generalized(time_window, "hg"; subreddits_to_include=subreddits_to_include)
    clique_sim_data = GrootSim._load_sim_results_generalized(time_window, "clique"; subreddits_to_include=subreddits_to_include)
    graph_sim_data = GrootSim._load_sim_results_generalized(time_window, "graph"; subreddits_to_include=subreddits_to_include)

    # *
    # * output data
    # *
    datapath = joinpath(ENV["EVALUATION_RESULTS_PATH"], "$(time_window)", "$(subreddit)")
    # datapath = joinpath(basepath, "data")
    # plotpath = joinpath(basepath, "plots")

    # if basepath is not a directory, create it
    !isdir(datapath) && mkdir(datapath)
    # if datapath is not a directory, create it
    # let's simplify the path
    # !isdir(datapath) && mkdir(datapath)
    # if plotpath is not a directory, create it
    # we don't use those now
    # !isdir(plotpath) && mkdir(plotpath)

    # * for each thr vector
    for (idx_thr, thr_vector) in enumerate(thrs_vector)
        n_bands = length(thr_vector[1]) - 1
        println("n_bands: $n_bands")

        # * output files
        first_drift_fp = joinpath(datapath, "first_drift_all_$(n_bands)_band_thrs.csv")
        n_drifts_fp = joinpath(datapath, "n_drifts_$(n_bands)_band_thrs.csv")
        last_stance_fp = joinpath(datapath, "last_stance_$(n_bands)_band_thrs.csv")
        count_users_fp = joinpath(datapath, "count_users_$(n_bands)_band_thrs.csv")

        for diffusion_params in [:hi, :mi, :li]
            println(diffusion_params)

            for (idx, net_model_data) in enumerate([hg_sim_data, clique_sim_data, graph_sim_data])
                println(net_models[idx])

                predicted_opinions = net_model_data[diffusion_params]
                diffusion_iterations = net_model_data[Symbol(string(diffusion_params, "_iter"))]

                for thrs in thr_vector
                    # * EVALUATION

                    # * first drift
                    first_drift_results = GrootSim.eval_first_drift_all(
                        most_active_users,
                        gt_user_opinions_per_interval,
                        active_intervals_per_user,
                        sim_intervals,
                        thrs,
                        predicted_opinions,
                        diffusion_iterations
                    )

                    # * n drifts 
                    n_drifts_results = GrootSim.eval_n_drifts(
                        most_active_users,
                        gt_user_opinions_per_interval,
                        active_intervals_per_user,
                        thrs,
                        predicted_opinions,
                        diffusion_iterations
                    )

                    # * last stance
                    last_stance_results = GrootSim.eval_final_stance(
                        most_active_users,
                        gt_user_opinions,
                        gt_user_opinions_per_interval,
                        active_intervals_per_user,
                        thrs,
                        predicted_opinions,
                        diffusion_iterations,
                        #verbose=true
                    )

                    # * count users
                    count_users_results = GrootSim.count_drifters(
                        most_active_users,
                        gt_user_opinions,
                        gt_user_opinions_per_interval,
                        active_intervals_per_user,
                        thrs,
                        predicted_opinions,
                        diffusion_iterations
                    ) 

                    _thr = nothing
                    rotation = 0

                    if n_bands == 2
                        _thr = thrs[2]
                    elseif n_bands == 3
                        thr1, thr2 = thrs[2], thrs[3]
                        _thr = "($thr1-$thr2)"
                        rotation = 90
                    elseif n_bands == 4
                        thr1, thr2, thr3 = thrs[2], thrs[3], thrs[4]
                        _thr = "($thr1-$thr2-$thr3)"
                        rotation = 90
                    end

                    println(_thr)

                    # * WRITE RESULTS
                    GrootSim.write_first_drift_results_all(first_drift_results, first_drift_fp, diffusion_params, net_models[idx], _thr)
                    GrootSim.write_n_drifts_results(n_drifts_results, n_drifts_fp, diffusion_params, net_models[idx], _thr)
                    GrootSim.write_last_stance_results(last_stance_results, last_stance_fp, diffusion_params, net_models[idx], _thr)
                    GrootSim.write_count_users_results(count_users_results, count_users_fp, diffusion_params, net_models[idx], _thr)
                    # * PLOT RESULTS
                    # plot_first_drift_res(first_drift_fp, plotpath, n_bands; rotation=rotation)
                    # plot_n_drifts(n_drifts_fp, plotpath, n_bands; rotation=rotation)
                    # plot_last_stance(last_stance_fp, plotpath, n_bands; rotation=rotation)
                end # end for thrs

                println("###")
            end # end for over net models
            println("------------------------------")
        end # end for over diffusion params
    end # end for over thr vectors
    
    println("----------------\n----------------\n----------------\n")
end