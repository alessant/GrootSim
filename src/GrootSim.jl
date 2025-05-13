module GrootSim

using ArgParse
using CSV 
using DataFrames
using Dates
using SimpleHypergraphs
using Statistics

# *
# * model-related code
# *
export build_conv_hg!
include("models/hg_builder.jl")

export hg2clique
include("models/hg2clique_builder.jl")

export build_reply_based_hg!
include("models/g_builder.jl")

# * utils for generalize the creation of the networks from multiple threads
export create_subreddits_hg
include("models/helpers/hg_builder_helper.jl")

# * time-related code
export Intervals, ContinuousIntervals, DiscreteIntervals
export build_intervals
include("models/helpers/time_utils.jl")

# * vertex weight-related code
export VertexWeightBuilder, Exponential
export weight_event

# * he weight-related code
export HeWeightBuilder, Average
export weight_thread
export weight_relations
include("models/weight_builder.jl")

export eval_intervals_based_on_decay
include("models/helpers/weight_builder_helper.jl")

# *
# * diffusion-related code
# *
export DiffusionAlgorithm
export DiscreteNonLinearConsensus, ContinuousNonLinearConsensus
include("diffusion/diffusion_types.jl")

export simulate
include("diffusion/simulate.jl")
include("diffusion/simulate_continuous.jl")

export sᴵ, sᴵᴵ
include("diffusion/influence_functions.jl")

export OpinionAggregationMethod, Sum, Avg
export aggregate
include("diffusion/aggregation.jl")

# *
# * opinion-related code
# *
export init_opinions_from_data # first opinion of each user
export get_true_user_stance # true stance of each user over all period
export get_avg_user_opinion_per_interval # average opinion of each user in each interval
include("opinions/gt_opinions.jl")

export _get_first_score!, _get_score!
include("opinions/utils/gt_opinions_utils.jl")

export get_last_opinions, get_average_opinions
export extend_opinions
include("opinions/sample_opinions.jl")

# *
# * visualization-related code
# *
export degree_histogram, size_histogram
include("utils/viz_utils.jl")

# *
# * conversational statistics-related code
# *
export eval_response_delay_distribution, eval_response_delay_distribution_across_threads 
export populate_existence_intervals
export eval_users_density, eval_users_density_across_threads
export eval_threads_density, eval_threads_density_across_threads
export eval_comments_density, eval_comments_density_across_threads
include("utils/conv_stats_utils.jl")

# *
# * experiments-related code
# *
export parse_commandline, parse_config
include("experiments/utils/parse_command_line.jl")

end # module GrootSim
