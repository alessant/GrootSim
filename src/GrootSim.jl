module GrootSim

using CSV 
using DataFrames
using Dates
using SimpleHypergraphs

# *
# * model-related stuff
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
# * visualization-related stuff
# *
export degree_histogram, size_histogram
include("utils/viz_utils.jl")

# *
# * conversational statistics-related stuff
# *
export eval_response_delay_distribution, eval_response_delay_distribution_across_threads 
export populate_existence_intervals
export eval_users_density, eval_users_density_across_threads
export eval_threads_density, eval_threads_density_across_threads
export eval_comments_density, eval_comments_density_across_threads
include("utils/conv_stats_utils.jl")

end # module GrootSim
