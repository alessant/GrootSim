# *
# * Evaluate the first drift in the simulated data
# * Here we only consider users who have actually changed their opinion
# * (True positive)
# *
function eval_first_drift(
    most_active_users,
    gt_user_opinions_per_interval,
    active_intervals_per_user,
    sim_intervals,
    thrs,
    predicted_opinions,
    diffusion_iterations;
    verbose=false
)

    n_users = 0
    n_matched = 0

    results_dict = Dict{Symbol, Union{Float64,Int}}(
        :avg_anticipated_intervals => 0.0,
        :avg_postponed_intervals => 0.0,
        :avg_mismatched_intervals => 0.0,
        :perc_matched_users => 0.0,
        :n_users => 0,
        :n_matched => 0
    )

    for user in most_active_users
        verbose && println(user)

        # this constraint is necesary when we do not evaluate the overall dataset,
        # but only a subset
        !haskey(active_intervals_per_user, user) && continue

        # *
        # * retrieve user data
        # *
        # avg real user opinion per interval
        avg_gt_user_op_per_interval = gt_user_opinions_per_interval[user]
        verbose && println(avg_gt_user_op_per_interval)
        # get the indices of the sim intervals with not null opinions
        op_idxs = findall(x -> !isnothing(x), avg_gt_user_op_per_interval)

        if length(op_idxs) == 0
            verbose && println("$user not active in the considered sim intervals")
            continue
        end

        # * check whether the user has drifted
        drift, _, when_idx, _ = find_first_drift(gt_user_opinions_per_interval[user], sim_intervals, thrs)

        !drift && continue

        n_users += 1

        # active intervals
        active_user_intervals = active_intervals_per_user[user]

        # *
        # * model data
        # *
        # network model
        model_user_op = predicted_opinions[user] 
        
        # ^ network model: hypergraph | clique-graph | reply-based graph
        # sampled_user_op = sample_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(sampled_user_op)
        # # avg opinion in the interval
        # avg_user_op = average_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(avg_user_op)
        # extended opinions
        extended_user_op = extend_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        verbose && println(extended_user_op)

        # * eval first drift in the simulated data
        drift_sim, _, when_idx_sim, _ = find_first_drift(extended_user_op, sim_intervals, thrs)

        if drift_sim
            n_matched += 1
            before = 0
            after = 0

            if when_idx_sim[1] < when_idx[1]
                before = (when_idx[1] - when_idx_sim[1])^2
                results_dict[:avg_anticipated_intervals] += before
            end
            
            if when_idx_sim[2] > when_idx[2]
                after = (when_idx_sim[2] - when_idx[2])^2
                results_dict[:avg_postponed_intervals] += after
            end

            results_dict[:avg_mismatched_intervals] += (before + after) 
        end

    end # for over most active users
    
    println("Matched users: ", n_matched, "/", n_users)

    if n_matched == 0
        results_dict[:avg_anticipated_intervals] = -1
        results_dict[:avg_postponed_intervals] = -1
        results_dict[:avg_mismatched_intervals] = -1
    else
        results_dict[:avg_anticipated_intervals] = sqrt(results_dict[:avg_anticipated_intervals] / n_matched)
        results_dict[:avg_postponed_intervals] = sqrt(results_dict[:avg_postponed_intervals] / n_matched)
        results_dict[:avg_mismatched_intervals] = sqrt(results_dict[:avg_mismatched_intervals] / n_matched)
    end

    results_dict[:perc_matched_users] = n_matched / n_users * 100
    results_dict[:n_users] = n_users
    results_dict[:n_matched] = n_matched

    return results_dict

end # end function


# *
# * Evaluate the first drift in the simulated data
# * Here we consider all users, regardless they have changed their opinion or not
# * (ALL USERS)
# *
function eval_first_drift_all(
    most_active_users,
    gt_user_opinions_per_interval,
    active_intervals_per_user,
    sim_intervals,
    thrs,
    predicted_opinions,
    diffusion_iterations;
    verbose=false
)

    n_users = 0
    n_identified = 0

    n_drifters = 0
    n_matched = 0

    results_dict = Dict{Symbol, Union{Float64,Int}}(
        :avg_anticipated_intervals => 0.0,
        :avg_postponed_intervals => 0.0,
        :avg_mismatched_intervals => 0.0,
        :perc_matched_users => 0.0, # perc of users that have drifted and have been correctly identified
        :perc_correctly_identified => 0.0, # perc of users who have been correctly identified, regardless they have drifted or not
        :n_users => 0,
        :n_drifters => 0, # total number of users who changed their opinion
        :tp => 0,
        :fp => 0,
        :fn => 0,
        :tn => 0,
        :n_matched_direction => 0, # it stores how many times the direction of the drift has been correctly identified
        :avg_anticipated_intervals_direction => 0.0,
        :avg_postponed_intervals_direction => 0.0,
        :avg_mismatched_intervals_direction => 0.0,
    )

    for user in most_active_users
        verbose && println(user)
        n_users += 1

        # this constraint is necesary when we do not evaluate the overall dataset,
        # but only a subset
        !haskey(active_intervals_per_user, user) && continue

        # *
        # * retrieve user data
        # *
        # avg real user opinion per interval
        avg_gt_user_op_per_interval = gt_user_opinions_per_interval[user]
        verbose && println(avg_gt_user_op_per_interval)
        # get the indices of the sim intervals with not null opinions
        op_idxs = findall(x -> !isnothing(x), avg_gt_user_op_per_interval)

        if length(op_idxs) == 0
            verbose && println("$user not active in the considered sim intervals")
            continue
        end

        # * check whether the user has drifted
        drift, _, when_idx, _, direction = find_first_drift(gt_user_opinions_per_interval[user], sim_intervals, thrs)

        if drift
            n_drifters += 1
        end

        # we should evaluate all users
        # regardless whether they have drifted or not
        # !drift && continue

        # active intervals
        active_user_intervals = active_intervals_per_user[user]

        # *
        # * model data
        # *
        # network model
        model_user_op = predicted_opinions[user] 
        
        # ^ network model: hypergraph | clique-graph | reply-based graph
        # sampled_user_op = sample_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(sampled_user_op)
        # # avg opinion in the interval
        # avg_user_op = average_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(avg_user_op)
        # # extended opinions
        # println(model_user_op)
        # println(diffusion_iterations)
        # println(active_user_intervals)
        # println(sum(active_user_intervals))
        extended_user_op = extend_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        verbose && println(extended_user_op)

        # * eval first drift in the simulated data
        drift_sim, _, when_idx_sim, _, direction_sim = find_first_drift(extended_user_op, sim_intervals, thrs)

        # if the model correctly predicted that 
        # the user changed their opinion
        if drift_sim && drift
            n_matched += 1 # TP
            before = 0
            after = 0

            # we just focus on this case
            if direction_sim == direction
                results_dict[:n_matched_direction] += 1

                if when_idx_sim[1] < when_idx[1]
                    before = (when_idx[1] - when_idx_sim[1])^2
                    results_dict[:avg_anticipated_intervals_direction] += before
                end
                
                if when_idx_sim[2] > when_idx[2]
                    after = (when_idx_sim[2] - when_idx[2])^2
                    results_dict[:avg_postponed_intervals_direction] += after
                end
    
                results_dict[:avg_mismatched_intervals_direction] += (before + after) 
            end

            if when_idx_sim[1] < when_idx[1]
                before = (when_idx[1] - when_idx_sim[1])^2
                results_dict[:avg_anticipated_intervals] += before
            end
            
            if when_idx_sim[2] > when_idx[2]
                after = (when_idx_sim[2] - when_idx[2])^2
                results_dict[:avg_postponed_intervals] += after
            end

            results_dict[:avg_mismatched_intervals] += (before + after) 

        elseif drift_sim && !drift
            results_dict[:fp] += 1
        elseif !drift_sim && drift
            results_dict[:fn] += 1
        else
            results_dict[:tn] += 1
        end

    end # for over most active users
    
    println("Matched drifted users: ", n_matched, "/", n_drifters)

    if n_matched == 0
        results_dict[:avg_anticipated_intervals] = -1
        results_dict[:avg_postponed_intervals] = -1
        results_dict[:avg_mismatched_intervals] = -1
    else
        results_dict[:avg_anticipated_intervals] = sqrt(results_dict[:avg_anticipated_intervals] / n_matched)
        results_dict[:avg_postponed_intervals] = sqrt(results_dict[:avg_postponed_intervals] / n_matched)
        results_dict[:avg_mismatched_intervals] = sqrt(results_dict[:avg_mismatched_intervals] / n_matched)
    end

    results_dict[:perc_matched_users] = n_matched / n_drifters * 100
    results_dict[:perc_correctly_identified] = (n_matched + results_dict[:tn]) / n_users * 100
    results_dict[:n_users] = n_users
    results_dict[:n_drifters] = n_drifters
    results_dict[:tp] = n_matched

    return results_dict

end # end function


# *
# * Evaluate the number of drifts in the simulated data
# *
function eval_n_drifts(
    most_active_users,
    gt_user_opinions_per_interval,
    active_intervals_per_user,
    thrs,
    predicted_opinions,
    diffusion_iterations;
    verbose=false
)

    results_dict = Dict{Symbol, Float64}(
        :rmse => 0.0
    )

    n_users = 0

    for user in most_active_users
        verbose && println(user)

        !haskey(active_intervals_per_user, user) && continue

        # *
        # * retrieve user data
        # *
        # avg real user opinion per interval
        avg_gt_user_op_per_interval = gt_user_opinions_per_interval[user]
        verbose && println(avg_gt_user_op_per_interval)
        # get the indices of the sim intervals with not null opinions
        op_idxs = findall(x -> !isnothing(x), avg_gt_user_op_per_interval)

        if length(op_idxs) == 0
            verbose && println("$user not active in the considered sim intervals")
            continue
        end

        # * check how many times the user has drifted
        n_drifts = count_drifts(avg_gt_user_op_per_interval, thrs)

        if n_drifts > 0
            n_users += 1 #! should we count all users and not only those that have drifted?
        end

        # active intervals
        active_user_intervals = active_intervals_per_user[user]

        # *
        # * model data
        # *
        # network model
        model_user_op = predicted_opinions[user] 
        
        # ^ network model: hypergraph | clique-graph | reply-based graph
        # sampled_user_op = sample_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(sampled_user_op)
        # # avg opinion in the interval
        # avg_user_op = average_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(avg_user_op)
        # extended opinions
        extended_user_op = extend_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        verbose && println(extended_user_op)

        # * check how many times a user has drifted in the simulation
        n_drifts_sim = count_drifts(extended_user_op, thrs)

        results_dict[:rmse] += (n_drifts_sim - n_drifts)^2
    end # end for

    println(n_users, " users have changed their opinion at least once.")

    results_dict[:rmse] = sqrt(results_dict[:rmse] / n_users)
    return results_dict
end


# *
# * Evaluate the last stance in the simulated data
# *
function eval_final_stance(
    most_active_users,
    gt_user_opinions,
    gt_user_opinions_per_interval,
    active_intervals_per_user,
    thrs,
    predicted_opinions,
    diffusion_iterations;
    verbose=false
    #model_users
) 

    results_dict = Dict{Symbol, Union{Int,Float64}}(
        :final_stance_correct => 0,
        :final_stance_wrong => 0,
        :final_stance_nothing => 0,
        :final_stance_nothing_gt => 0, # it counts how many times the comparison is null because of the gt
        :final_stance_same_index_correct => 0,
        :final_stance_same_index_nothing => 0,
        :drifted_users => 0,
        :n_users => 0,
        :perc_matched_users => 0.0
    )

    n_users = 0
        
    for user in most_active_users
        verbose && println(user)
        has_drifted = false

        !haskey(active_intervals_per_user, user) && continue

        # *
        # * retrieve user data
        # *
        # real user opinions
        gt_user_op = sort(gt_user_opinions[user], by=x->x[1])
        verbose && println(gt_user_op)
        # avg real user opinion per interval
        avg_gt_user_op_per_interval = gt_user_opinions_per_interval[user]
        verbose && println(avg_gt_user_op_per_interval)
        # get the indices of the sim intervals with not null opinions
        op_idxs = findall(x -> !isnothing(x), avg_gt_user_op_per_interval)

        if length(op_idxs) == 0
            verbose && println("$user not active in the considered sim intervals")
            continue
        end

        # let's count how many users drifted from the first the their last op 
        verbose && println("first opinion: $(gt_user_op[1][2]), last opinion: $(gt_user_op[end][2]), last opinion sim: $(avg_gt_user_op_per_interval[op_idxs[end]])")
        same_stance = check_final_stance(gt_user_op[1][2], avg_gt_user_op_per_interval[op_idxs[end]], thrs)

        if !isnothing(same_stance)
            if !same_stance
                has_drifted = true
            end
        end
        
        verbose && println(op_idxs)

        # active intervals
        active_user_intervals = active_intervals_per_user[user]

        # *
        # * model data
        # *
        # network model
        model_user_op = predicted_opinions[user] #mi_hg[user]
        
        ## ^ network model: hypergraph | clique-graph | reply-based graph
        # sampled_user_op = sample_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(sampled_user_op)
        # # avg opinion in the interval
        # avg_user_op = average_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(avg_user_op)
        # # extended opinions
        extended_user_op = extend_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        verbose && println(extended_user_op)

        # * evaluate last opinion 
        verbose && println("last opinion, model: $(extended_user_op[end]), real: $(avg_gt_user_op_per_interval[op_idxs[end]])")
        #println("last opinion, model: $(extended_user_op[end]), real: $(avg_gt_user_op_per_interval[op_idxs[end]])")
        final_stance = check_final_stance(extended_user_op[end], avg_gt_user_op_per_interval[op_idxs[end]], thrs)
        final_stance_same_index = check_final_stance(extended_user_op[op_idxs[end]], avg_gt_user_op_per_interval[op_idxs[end]], thrs)

        verbose && println(final_stance)
        verbose && println(final_stance_same_index)

        if !isnothing(final_stance)
            if final_stance
                # true positive
                results_dict[:final_stance_correct] += 1
                if has_drifted
                    results_dict[:drifted_users] += 1
                    #push!(model_users, user)
                end
            else
                results_dict[:final_stance_wrong] += 1
            end
        else
            results_dict[:final_stance_nothing] += 1
            if avg_gt_user_op_per_interval[op_idxs[end]] in thrs
                results_dict[:final_stance_nothing_gt] += 1
            end
        end

        if !isnothing(final_stance_same_index)
            if final_stance_same_index
                results_dict[:final_stance_same_index_correct] += 1
            end
        else
            results_dict[:final_stance_same_index_nothing] += 1
        end

        n_users += 1

    end # end for over most active users

    results_dict[:n_users] = n_users
    results_dict[:perc_matched_users] = results_dict[:final_stance_correct] / n_users * 100

    #println(n_users, " users evaluated")

    return results_dict
end


# *
# * Count the number of users who changed their opinion from start to end
# *
function count_drifters(
    most_active_users,
    gt_user_opinions,
    gt_user_opinions_per_interval,
    active_intervals_per_user,
    thrs,
    predicted_opinions,
    diffusion_iterations;
    verbose=false
    #model_users
) 

    results_dict = Dict{Symbol, Union{Int,Float64}}(
        :n_drifters_gt => 0,
        :n_drifters_sim => 0,
        :n_no_drifters => 0,
        :n_no_drifters_sim => 0,
        :n_matched_drifters => 0, # number of users who have drifted and have been correctly identified
        :n_matched_users => 0,
        :n_users => 0,
    )

    n_users = 0
        
    for user in most_active_users
        verbose && println(user)
        has_drifted = false

        !haskey(active_intervals_per_user, user) && continue

        # *
        # * retrieve user data
        # *
        # real user opinions
        gt_user_op = sort(gt_user_opinions[user], by=x->x[1])
        verbose && println(gt_user_op)
        # avg real user opinion per interval
        avg_gt_user_op_per_interval = gt_user_opinions_per_interval[user]
        verbose && println(avg_gt_user_op_per_interval)
        # get the indices of the sim intervals with not null opinions
        op_idxs = findall(x -> !isnothing(x), avg_gt_user_op_per_interval)

        if length(op_idxs) == 0
            verbose && println("$user not active in the considered sim intervals")
            continue
        end

        # let's count how many users drifted from the first the their last op 
        verbose && println("first opinion: $(gt_user_op[1][2]), last opinion: $(gt_user_op[end][2]), last opinion sim: $(avg_gt_user_op_per_interval[op_idxs[end]])")
        same_stance = check_final_stance(gt_user_op[1][2], avg_gt_user_op_per_interval[op_idxs[end]], thrs)

        if !isnothing(same_stance)
            if !same_stance
                has_drifted = true
                results_dict[:n_drifters_gt] += 1
            else
                results_dict[:n_no_drifters] += 1
            end
        end
        
        verbose && println(op_idxs)

        # active intervals
        active_user_intervals = active_intervals_per_user[user]

        # *
        # * model data
        # *
        # network model
        model_user_op = predicted_opinions[user] #mi_hg[user]
        
        ## ^ network model: hypergraph | clique-graph | reply-based graph
        # sampled_user_op = sample_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(sampled_user_op)
        # # avg opinion in the interval
        # avg_user_op = average_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        # verbose && println(avg_user_op)
        # # extended opinions
        extended_user_op = extend_opinions(model_user_op, diffusion_iterations, active_user_intervals)
        verbose && println(extended_user_op)

        # * evaluate last opinion 
        verbose && println("last opinion, model: $(extended_user_op[end]), real: $(avg_gt_user_op_per_interval[op_idxs[end]])")
        #println("last opinion, model: $(extended_user_op[end]), real: $(avg_gt_user_op_per_interval[op_idxs[end]])")
        # final_stance = check_final_stance(extended_user_op[end], avg_gt_user_op_per_interval[op_idxs[end]], thrs)
        # final_stance_same_index = check_final_stance(extended_user_op[op_idxs[end]], avg_gt_user_op_per_interval[op_idxs[end]], thrs)

        same_stance_sim = check_final_stance(extended_user_op[1], extended_user_op[end], thrs)

        verbose && println(same_stance_sim)

        if !isnothing(same_stance_sim)
            if !same_stance_sim
                results_dict[:n_drifters_sim] += 1
            else
                results_dict[:n_no_drifters_sim] += 1
            end
        end

        # now we need to check how many users have been correctly identified
        final_stance = check_final_stance(extended_user_op[end], avg_gt_user_op_per_interval[op_idxs[end]], thrs)

        if !isnothing(final_stance)
            if final_stance
                # true positive
                results_dict[:n_matched_users] += 1

                if has_drifted
                    results_dict[:n_matched_drifters] += 1
                end
            end
        end

        n_users += 1

    end # end for over most active users

    results_dict[:n_users] = n_users
    # results_dict[:perc_matched_users] = results_dict[:final_stance_correct] / n_users * 100

    #println(n_users, " users evaluated")

    return results_dict
end

