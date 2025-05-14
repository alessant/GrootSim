# this function samples users' last opinions  
# in every simulation interval (if active)
function get_last_opinions(
                user_opinions, 
                sampling_intervals, 
                active_intervals;
                store_gt_opinion=false # whether retrieve the (first) GT opinion
)
    
    sampled_ops = store_gt_opinion ? [user_opinions[1]] : []

    index = 1

    for (i, conv_iter) in enumerate(sampling_intervals)
        !active_intervals[i] && continue
        #println("index: $i - conv_iter: $(conv_iter-1)")

        index = index + (conv_iter-1)
        push!(sampled_ops, user_opinions[index])
    end

    sampled_ops
end


# this function get the average opinion of each user 
# during every simulation interval the user was active
function get_average_opinions(
                user_opinions, 
                sampling_intervals, 
                active_intervals;
                store_gt_opinion=false # whether retrieve the (first) GT opinion
)
    sampled_ops = store_gt_opinion ? [user_opinions[1]] : []

    s_index = 1

    for (i, conv_iter) in enumerate(sampling_intervals)
        !active_intervals[i] && continue

        e_index = s_index + (conv_iter-1)

        avg_op = mean(user_opinions[s_index:e_index])
        push!(sampled_ops, avg_op)

        s_index = e_index
        
    end

    sampled_ops
end

# this function just extends the opinions of inactive users
# to the next active interval
# this is done to avoid having a lot of NaN values
# in the sampled opinions
function extend_opinions(user_opinions, sampling_intervals, active_intervals)
    extended_opinions = Array{Float64, 1}()

    index = 1

    for (i, conv_iter) in enumerate(sampling_intervals)

        if !active_intervals[i]
            if i == 1
                push!(extended_opinions, user_opinions[1])
            else
                push!(extended_opinions, extended_opinions[i-1])
            end
        else
            index = index + (conv_iter-1)
            push!(extended_opinions, user_opinions[index])
        end
    end

    extended_opinions
end