using Pkg
Pkg.activate(".")
using GrootSim

using DotEnv
DotEnv.load!()

using Distributions
using PyCall
pickle = pyimport("pickle")
using PyPlot
using Serialization
using SimpleHypergraphs


# *
# * reddit-related params
# *
data_to_include_path = ENV["DATA_TO_INCLUDE_PATH"]
datapath = ENV["DATA_PATH"]

# * loading the data
reddittors_to_include = Set(pickle.load(open(joinpath(data_to_include_path, "final_users_to_include.pkl"))))
subs_to_include = (pickle.load(open(joinpath(data_to_include_path, "final_subs_to_include.pkl"))))
subs_to_include = Set([sub_id[4:end] for sub_id in subs_to_include])

# * output path 
output_path = joinpath(ENV["RESULTS_BASEPATH"], "simulation", "static")
if !isdir(output_path)
    mkpath(output_path)
end

subreddits = nothing #Set{String}() 
# push!(subreddits, "bayarea")

# * get the hg 
hg, author_to_id, thread_to_id = create_subreddits_hg(
                            datapath,
                            subs_to_include,
                            reddittors_to_include;
                            subreddits_to_include=subreddits
                        )

nhv(hg), nhe(hg)

# * simulate                        
opinions = rand(Uniform(0.0,1.0), nhv(hg))

# 
# high involvment Φₐ=0.10, Φᵣ=0.15
#
homophily_function_params = Dict{Symbol, Float64}(:Φₐ => 0.10, :Φᵣ => 0.15)

opinion_history, timesteps = simulate(hg, ContinuousNonLinearConsensus; 
                        initial_opinions=opinions, 
                        homophily_function_params=homophily_function_params,
                        verbose=false
                    )

serialize(joinpath(output_path, "opinions_high_cont.ser"), opinion_history)
serialize(joinpath(output_path, "timesteps_high_cont.ser"), timesteps)

# opinion_history = deserialize(joinpath(output_path, "opinions_high_cont.ser"))
# timesteps = deserialize(joinpath(output_path, "timesteps_high_cont.ser"))

# length(opinion_history), length(timesteps)
# length(opinion_history) == nhv(hg)

# plot the opinion trend
clf()

for v in 1:nhv(hg)
    plot(timesteps, opinion_history[v], color="black", linewidth=.3)
end

ylim(top=1.05, bottom=-0.05)
gcf()

savefig(joinpath(output_path, "high_cont.png"))


#
# medium involvment Φₐ=0.15, Φᵣ=0.30
#
homophily_function_params = Dict{Symbol, Float64}(:Φₐ => 0.15, :Φᵣ => 0.30)

opinion_history, timesteps = simulate(hg, ContinuousNonLinearConsensus; 
                            initial_opinions=opinions, 
                            homophily_function_params=homophily_function_params,
                            verbose=false
                        )

serialize(joinpath(output_path, "opinions_medium_cont.ser"), opinion_history)
serialize(joinpath(output_path, "timesteps_medium_cont.ser"), timesteps)

clf()

for v in 1:nhv(hg)
    plot(timesteps, opinion_history[v], color="black", linewidth=.3)
end

ylim(top=1.05, bottom=-0.05)
gcf()

savefig(joinpath(output_path, "medium_cont.png"))


#
# - low involvment Φₐ=0.40, Φᵣ=0.80
#
homophily_function_params = Dict{Symbol, Float64}(:Φₐ => 0.40, :Φᵣ => 0.8)

opinion_history, timesteps = simulate(hg, ContinuousNonLinearConsensus; 
                    initial_opinions=opinions, 
                    homophily_function_params=homophily_function_params,
                    verbose=false
                )

serialize(joinpath(output_path, "opinions_low_cont.ser"), opinion_history)
serialize(joinpath(output_path, "timesteps_low_cont.ser"), timesteps)

# plot the opinion trend
clf()

for v in 1:nhv(hg)
    plot(timesteps, opinion_history[v], color="black", linewidth=.3)
end 

ylim(top=1.05, bottom=-0.05)
gcf()

savefig(joinpath(output_path, "medium_cont.png"))
