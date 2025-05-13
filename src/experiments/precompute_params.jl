using Pkg
Pkg.activate(".")
using GrootSim

using DotEnv
DotEnv.load!()

using Dates
using Serialization

using PyCall
pickle = pyimport("pickle");


# *
# * reddit-related params
# *
datapath = ENV["DATA_PATH"]
data_to_include_path = ENV["DATA_TO_INCLUDE_PATH"]

granularity = "day"
subreddit = "bayarea" #"AskReddit_news_politics" #"collapse_news_politics" #nothing
subreddits_to_include = Set{String}(split(subreddit, "_")) #nothing

output_path = joinpath(ENV["RESULTS_BASEPATH"], "simulation", "temporal", "precomputed_params", granularity, subreddit)
if !isdir(output_path)
    mkpath(output_path)
end

 
# *
# * Create the simulation windows
# *

Δ = convert(Dates.Millisecond, Dates.Hour(24)) #24*7, week
mindate = Dates.DateTime(2020, 07, 1, 0, 0, 0)
maxdate = Dates.DateTime(2022, 12, 31, 0, 0, 0)

# evaluating intervals
# - since we are evaluating ContinuousIntervals
# - this array only contains the upper bound of each interval
# - the lower bound (i.e., the start of the interval) is evaluated based on the 
#   date of the first event whose weight is >= thr
intervals = build_intervals(ContinuousIntervals; mindate=mindate, maxdate=maxdate, stride=Δ)

serialize(joinpath(output_path, "intervals.ser"), intervals)

# *
# * Init the opinion vector
# *

# * loading the data
# subreddit_dirs = readdir(thread_basepath)
reddittors_to_include = Set(pickle.load(open(joinpath(data_to_include_path, "final_users_to_include.pkl"))))
subs_to_include = (pickle.load(open(joinpath(data_to_include_path, "final_subs_to_include.pkl"))))
subs_to_include = Set([sub_id[4:end] for sub_id in subs_to_include]);

# * building the hg to get allfinal users
hg, author_to_id, thread_to_id = create_subreddits_hg(
                                    datapath,
                                    subs_to_include,
                                    reddittors_to_include;
                                    subreddits_to_include=subreddits_to_include,
                                    ignore_NI=true,
                                )

# * here, we initialize the op vector from a random number using a uniform distribution
users = keys(author_to_id)
# random_opinions = Dict{Symbol, Float64}(users .=> rand(Uniform(0.0,1.0), length(users)))

# * here, we initialize the op vector from ground-truth data
# ! the number of these users may not correspond to 
# ! the number of nodes in the hypergraph
# ! because sub authors whose threads has only NI answers are not included in the hg
user_first_op, user_first_action = init_opinions_from_data(
    datapath,
    subs_to_include,
    reddittors_to_include;
    subreddits_to_include=subreddits_to_include
)

users_op = keys(user_first_op)

for u in users_op
    if !haskey(author_to_id, u)
        delete!(user_first_op, u)
    end
end

length(user_first_op)

serialize(joinpath(output_path, "users.ser"), users)
serialize(joinpath(output_path, "gt_opinions.ser"), user_first_op)
# serialize(joinpath(output_path, "random_opinions.ser"), random_opinions)

# check
setdiff(keys(author_to_id), keys(user_first_op))


# *
# * Evaluate the simulation intervals
# * the following code also compute the weight of the events in each interval
# * as well as the weight of each subthread
# *
sim_intervals, mindates = eval_intervals_based_on_decay(
    datapath,
    subs_to_include,
    reddittors_to_include,
    intervals,
    mindate;
    subreddits_to_include=subreddits_to_include,
    verbose=true
)

serialize(joinpath(output_path, "sim_intervals.ser"), sim_intervals)
# sim_intervals = deserialize(joinpath(output_path, "sim_intervals.ser"))

length(sim_intervals)


# *
# * Evaluate when each user is active in which interval
# *

active_intervals_per_user = Dict{Symbol, Vector{Bool}}(
        #collect(keys(author_to_id)) .=> copy([false for _ in 1:length(sim_intervals)])
    )

for user in users
    active_intervals_per_user[user] = [false for _ in 1:length(sim_intervals)]
end

active_intervals_per_user

for (i, period) in enumerate(sim_intervals)
    println("evaluating period $i/$(length(sim_intervals))")
    s_date = period.first
    obs_date = period.second

    hg, v_to_id, he_to_id = create_subreddits_hg(
        datapath,
        subs_to_include,
        reddittors_to_include;
        mindate=s_date,
        maxdate=obs_date,
        subreddits_to_include=subreddits_to_include,
        ignore_NI=true,
        verbose=false
    )

    for user in keys(v_to_id)
        active_intervals_per_user[user][i] = true
    end
end

serialize(joinpath(output_path, "active_intervals_per_user.ser"), active_intervals_per_user)