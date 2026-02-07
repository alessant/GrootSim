function find_first_drift(
    opinions, #::Vector{Union{Float64, Nothing}} 
    intervals,
    thrs::Vector{Float64}
)

    binned_ops = _binning_opinions(opinions, thrs)
    _intervals = deepcopy(intervals)

    # find nothing values in bins
    n_idxs = findall(x -> isnothing(x), binned_ops)
    # remove nothing values
    deleteat!(binned_ops, n_idxs)
    deleteat!(_intervals, n_idxs)
   
    drift = false
    when = nothing
    when_idx = nothing
    idx = nothing
    change = nothing # positive or negative

    for index in 1:lastindex(binned_ops)-1
        curr_op = binned_ops[index]
        next_op = binned_ops[index+1]

        # the opinions cannot be nothing
        # since we removed them
        if !isnothing(curr_op) && !isnothing(next_op) && curr_op != next_op
            drift = true
            idx = index
            when = (_intervals[index], _intervals[index+1])
            when_idx = (findfirst(x -> x == when[1], intervals), findfirst(x -> x == when[2], intervals))
            change = curr_op < next_op ? :positive : :negative
            break
        end
    end

    return drift, when, when_idx, idx, change
end

# *
# *
# *
function count_drifts(
    opinions, #::Vector{Union{Float64, Nothing}} 
    thrs::Vector{Float64}
)
    binned_ops = _binning_opinions(opinions, thrs)

    # find nothing values in bins
    n_idxs = findall(x -> isnothing(x), binned_ops)
    # remove nothing values
    deleteat!(binned_ops, n_idxs)

    drifts = 0

    for index in 1:lastindex(binned_ops)-1
        curr_op = binned_ops[index]
        next_op = binned_ops[index+1]

        # the opinions cannot be nothing
        # since we removed them
        if !isnothing(curr_op) && !isnothing(next_op) && curr_op != next_op
            drifts += 1
        end
    end

    return drifts
end


# *
# *
# *
function check_final_stance(true_stance, predicted_stance, thrs)
    true_binned_stance = GrootSim._binning_opinions([true_stance], thrs)
    predicted_binned_stance = GrootSim._binning_opinions([predicted_stance], thrs)

    # if a binned stance is equal to a thrs
    # we cannot compare them
    if isnothing(true_binned_stance[1]) || isnothing(predicted_binned_stance[1])
        return nothing
    end

    return true_binned_stance[1] == predicted_binned_stance[1]
end


# # *
# # *
# # *
# function _binning_opinions(
#     opinions::Union{Vector{Float64}, Vector{Union{Float64, Nothing}}}, 
#     thrs::Vector{Float64}
# )
#     to_return = Vector{Union{Int, Nothing}}()

#     for op in opinions
#         # we ignore thrs opinions (we should not ignore them)
#         if isnothing(op) # || op in thrs
#             push!(to_return, nothing)
#         else
#             push!(to_return, findfirst(x -> x > op, thrs)-1)
#         end
#     end

#     return to_return
# end