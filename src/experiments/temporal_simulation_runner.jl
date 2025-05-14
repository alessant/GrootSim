using Pkg
Pkg.activate(".")
using GrootSim

using DotEnv
DotEnv.load!()

using DataFrames
using Dates
using Distributions
using PyCall
pickle = pyimport("pickle")
using PyPlot
using JSON
using JSONTables
using Serialization
using SimpleHypergraphs

# *
# * 0. Load all data
# *

#@show 
parsed_args = parse_config()

config_path = parsed_args["config"]
# decomment the following line to manually run the script
config_path = #"results/simulation/temporal/configs/day/bayarea/all_models.json" 
config_data = JSON.parse((open(config_path, "r")))

jtable = jsontable(read(open(config_path, "r")))
paramsdf = DataFrame(jtable)


# *
# * 1. Load the data for a single experiment
# *
for exp in eachrow(paramsdf)

    println("\n----------------EXP CONFIG-------------------------")
    for property in propertynames(exp)
        print("$(property) = $(exp[property])  |   ")
    end
    println("\n---------------------------------------------------\n")
    flush(stdout)

    # ^ data-related params
    data_to_include_path = exp[:data_to_include_path]
    scored_conv_path = exp[:datapath]

    reddittors_to_include = Set(pickle.load(open(joinpath(data_to_include_path, "final_users_to_include.pkl"))))
    subs_to_include = (pickle.load(open(joinpath(data_to_include_path, "final_subs_to_include.pkl"))))
    subs_to_include = Set([sub_id[4:end] for sub_id in subs_to_include])

    subreddits_to_include = "subreddits_to_include" in names(paramsdf) ?
        Set{String}(split(exp[:subreddits_to_include], "_")) : nothing 

    # ^ model-related params
    clique = "clique" in names(paramsdf) ? exp[:clique] : false
    reply_based_graph = "reply_based_graph" in names(paramsdf) ? exp[:reply_based_graph] : false

    if reply_based_graph
        println("Building reply-based graph")
        flush(stdout)
    end

    # ^ time-related params
    intervals = deserialize(joinpath(exp[:precomputedpath], "sim_intervals.ser"))

    # ^ weight-related params
    granularity = exp[:granularity]
    thr = exp["weight_thr"]
    
    # ^ diffusion-related params
    if exp[:random_opinions]
        init_opinions = deserialize(joinpath(exp[:precomputedpath], "random_opinions.ser"))
    else
        init_opinions = deserialize(joinpath(exp[:precomputedpath], "gt_opinions.ser"))
    end
    Φₐ = exp[:Φₐ]
    Φᵣ = exp[:Φᵣ]
    homophily_function_params = Dict{Symbol, Float64}(:Φₐ => Φₐ, :Φᵣ => Φᵣ)

    max_iter = exp[:max_iter]

    # ^ output-related params
    verbose = exp[:verbose]
    output_path = exp[:output_path]

    # *
    # * 2. Init the param to run the simulation
    # *
    users = deserialize(joinpath(exp[:precomputedpath], "users.ser"))
    s_date = DateTime(exp[:starting_date], "yyyy-mm-ddTHH:MM:SS")
    curr_opinions_all = init_opinions

    # initialize the memory of the simulation
    # it stores the initial opinion of each node
    opinion_history_all = Dict{Symbol, Array{Float64, 1}}()
    for u in users
        push!(
            get!(opinion_history_all, u, Array{Float64, 1}()),
            init_opinions[u]
        )
    end

    # we also want to know the last opinion of each node
    # at the end of each interval
    # we still init this structure with the initial opinions
    opinion_history_last = Dict{Symbol, Array{Float64, 1}}()
    for u in users
        push!(
            get!(opinion_history_last, u, Array{Float64, 1}()),
            init_opinions[u]
        )
    end

    # same for the average opinion
    opinion_history_avg = Dict{Symbol, Array{Float64, 1}}()
    for u in users
        push!(
            get!(opinion_history_avg, u, Array{Float64, 1}()),
            init_opinions[u]
        )
    end

    # we need to store when the simulation algorithm converges
    # since we may need different convergence criteria
    # for the three models (basically, graph-based models converge later than the hg-based)
    # so, what we do is to simply plot the opinion of each node at the end
    # of each simulation interval
    _iters = Array{Int64, 1}()

    # *
    # * 3. Run the simulation
    # *
    for (index, period) in enumerate(intervals)
        s_date = period.first
        obs_date = period.second

        verbose && println("*\nSimulating diffusion for interval $(index)/$(length(intervals)) : [$s_date - $obs_date]")
        flush(stdout)

        # 2.2 Create a temporal (hyper)graph for each interval
        hg, v_to_id, he_to_id = create_subreddits_hg(
            scored_conv_path,
            subs_to_include,
            reddittors_to_include;
            mindate=s_date,
            maxdate=obs_date,
            ignore_NI=true,
            subreddits_to_include=subreddits_to_include,
            reply_graph=reply_based_graph,
            verbose=false
        )  
    
        println("Number of vertices: $(nhv(hg)); number of hyperedges: $(nhe(hg))")

        # check whether we are simulating on a graph projection of the hg
        # clique
        if clique
            println("clique!")
            hg = hg2clique(hg)
        end

        # 2.3 Attach the he weights to the hypergraph
        # - not needed now
    
        # ^ create the opinion vector as required by the diffusion algo
        # - this is a vector of Float64
        # - the order of the opinions is the same as the order of the vertices in the hypergraph
        # We init the opinion vector of a user u with their last opinion from the previous interval
        _curr_opinions = [curr_opinions_all[get_vertex_meta(hg,v)] for v in 1:nhv(hg)]
    
        # 2.4 Run the diffusion process
        _opinion_history, timesteps = simulate(
                            hg, 
                            ContinuousNonLinearConsensus; 
                            max_iter=max_iter, 
                            initial_opinions=_curr_opinions, 
                            homophily_function_params=homophily_function_params,
                            verbose=false
                        )
    
        # ^ store the opinion history of each node
        for v in 1:nhv(hg)
            user = get_vertex_meta(hg, v)
            v_op = _opinion_history[v]
            append!(
                get!(opinion_history_all, user, Array{Float64, 1}()), 
                v_op[2:end]
            )
        end

        # ^ store the last opinion of each node
        for v in 1:nhv(hg)
            user = get_vertex_meta(hg, v)
            v_op = _opinion_history[v]
            append!(
                get!(opinion_history_last, user, Array{Float64, 1}()), 
                v_op[end]
            )
        end

        # ^ store the average opinion of each node
        for v in 1:nhv(hg)
            user = get_vertex_meta(hg, v)
            v_op = _opinion_history[v]
            append!(
                get!(opinion_history_avg, user, Array{Float64, 1}()), 
                mean(v_op)
            )
        end
    
        # ^ evaluate the new current opinion vector for all users
        # - this is a Dict{Symbol, Float64}
        curr_opinions_all = Dict{Symbol, Float64}(users .=> zeros(length(users)))
    
        for u in keys(opinion_history_all)
            u_last_op = opinion_history_all[u][end]
            curr_opinions_all[u] = u_last_op
        end
    
        # ^ save the iters required to converge
        push!(_iters, length(timesteps))

        verbose && println()
    end # end loop over intervals

    # fname
    filedetails = "$(Dates.format(now(), "Y-mm-ddTHH-MM"))_$(exp[:exp_id])_$(exp[:exp_name])"
    # create the dir if it not exists
    fpath = joinpath(output_path, "ser")
    isdir(fpath) || mkpath(fpath)

    serialize(joinpath(fpath, "$(filedetails)_opinion_history_all.ser"), opinion_history_all)
    serialize(joinpath(fpath, "$(filedetails)_iters.ser"), _iters)
    serialize(joinpath(fpath, "$(filedetails)_opinion_history_last.ser"), opinion_history_last)
    serialize(joinpath(fpath, "$(filedetails)_opinion_history_avg.ser"), opinion_history_avg)

    # *
    # * 5. Plot the results
    # *
    clf()

    # plot opinion_history_all
    for user in keys(opinion_history_all)
        plot(collect(1:length(opinion_history_all[user])), opinion_history_all[user], color="black", linewidth=.05)
    end

    title(exp[:exp_label])
    ylim(top=1.05, bottom=-0.05)

    # create the dir if it not exists
    fpath = joinpath(output_path, "plots")
    isdir(fpath) || mkpath(fpath)

    savefig(joinpath(fpath, "$(filedetails)_opinion_history_all.png"))
end # end loop over experiments
