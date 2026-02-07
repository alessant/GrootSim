# *
# * Helper functions for the analysis of evaluation results
# *

# *
# * 
# *
function get_metrics_data(
    df::DataFrame, 
    involvement::AbstractString, 
    net_model::AbstractString
)

    _df = filter(df -> (df.diffusion_params == involvement && df.net_model == net_model), df)

    tp = (_df[!, :tp] ./ _df[!, :n_users]) .* 100
    fp = (_df[!, :fp] ./ _df[!, :n_users]) .* 100
    fn = (_df[!, :fn] ./ _df[!, :n_users]) .* 100
    tn = (_df[!, :tn] ./ _df[!, :n_users]) .* 100

    # ratio of correctly predicted observations to all the observations
    accuracies = (tp .+ tn) ./ (tp .+ tn .+ fp .+ fn)
    # detected positive cases among all predicted positive case - false positive higher cost
    precisions = tp ./ (tp .+ fp)
    # detected positive cases among all positive instances - false negative higher cost
    recalls = tp ./ (tp .+ fn)
    # harmonic mean of precision and recall
    f1s = 2 .* (precisions .* recalls) ./ (precisions .+ recalls)

    return [accuracies, precisions, recalls, f1s]
end

# *
# * 
# *
# this function keeps into account the direction of the opinion change when evaluating true positives
function get_metrics_data_direction(
    df::DataFrame, 
    involvement::AbstractString, 
    net_model::AbstractString
)

    _df = filter(df -> (df.diffusion_params == involvement && df.net_model == net_model), df)

    # number of users correctly identified as changing opinion
    n_matched = _df[!, :n_matched_direction] #renamed matched_direction in the code 
    n_drifters = _df[!, :n_drifters]

    perc_matched_dir = (n_matched ./ n_drifters) .* 100

    return perc_matched_dir
end


# *
# * 
# *
function get_first_drit_data_direction(
    df::DataFrame, 
    involvement::AbstractString, 
    net_model::AbstractString
)
    _df = filter(df -> (df.diffusion_params == involvement && df.net_model == net_model), df)

    avg_anticipated_intervals = sqrt.(_df[!, :avg_anticipated_intervals_direction] ./ _df[!, :n_matched_direction])
    avg_postponed_intervals = sqrt.(_df[!, :avg_postponed_intervals_direction] ./ _df[!, :n_matched_direction])
    avg_mismatched_intervals = sqrt.(_df[!, :avg_mismatched_intervals_direction] ./ _df[!, :n_matched_direction])
    #perc_matched_users = _df[!, :perc_matched_users]

    return [avg_anticipated_intervals, avg_postponed_intervals, avg_mismatched_intervals]
end

# *
# * 
# *
function get_last_stance_data(
    df::DataFrame, 
    involvement::AbstractString, 
    net_model::AbstractString
)
    _df = filter(df -> (df.diffusion_params == involvement && df.net_model == net_model), df)

    perc_matched_users = _df[!, :perc_matched_users]
    perc_drifted_users = (_df[!, :drifted_users] ./ _df[!, :final_stance_correct]) .* 100

    return [perc_matched_users, perc_drifted_users]
end