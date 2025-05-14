# *
# * helper functions
# *
# here we associate the author of the submission/comment with the score of the submission/comment
# if this is their first action and the score is != 'NI'
function _get_first_score!(user_first_op_dict, user_first_action_dict, event_data)
    # submitter_id
    submitter_id = ismissing(event_data[:author_id]) ? nothing : Symbol(event_data[:author_id])
    isnothing(submitter_id) && return

    # sub score
    sub_score = event_data[:predicted_stance_scores]
    sub_score == "NI" && return # this should never happen

    # check if sub_score is a Float64
    if !isa(sub_score, Float64)
        sub_score = parse(Float64, event_data[:predicted_stance_scores])
    end

    # sub creation date
    sub_created_at = event_data[:created_at]

    # if this is the first time we see this user
    # we just add them to the Dict
    if !haskey(user_first_op_dict, submitter_id)
        # user_first_op_dict[submitter_id] = sub_score
        #user_first_action_dict[submitter_id] = sub_created_at
        push!(user_first_op_dict, submitter_id => sub_score) 
        push!(user_first_action_dict, submitter_id => sub_created_at)
    else
        # if this is not the first time we see this user
        # we check if this is their first action
        # if it is, we update the Dict
        if sub_created_at < user_first_action_dict[submitter_id]
            user_first_op_dict[submitter_id] = sub_score
            user_first_action_dict[submitter_id] = sub_created_at
        end
    end
end


#
function _get_score!(user_opinions, event_data)
    # author_id
    author_id = ismissing(event_data[:author_id]) ? nothing : Symbol(event_data[:author_id])
    isnothing(author_id) && return

    # sub score
    sub_score = event_data[:predicted_stance_scores]
    sub_score == "NI" && return

    # check if sub_score is a Float64
    if !isa(sub_score, Float64)
        sub_score = parse(Float64, event_data[:predicted_stance_scores])
    end

    # sub creation date
    created_at = event_data[:created_at]

    push!(
        get!(user_opinions, author_id, Array{Pair{DateTime,Float64}, 1}()),
        Pair(created_at, sub_score)
    )
end


# *
# *
# *
function _binning_opinions(
    opinions::Union{Vector{Float64}, Vector{Union{Float64, Nothing}}}, 
    thrs::Vector{Float64}
)
    to_return = Vector{Union{Int, Nothing}}()

    for op in opinions
        # we ignore thrs opinions (we should not ignore them)
        if isnothing(op) # || op in thrs
            push!(to_return, nothing)
        else
            push!(to_return, findfirst(x -> x > op, thrs)-1)
        end
    end

    return to_return
end