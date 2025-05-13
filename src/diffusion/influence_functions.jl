#
# default homophily function
# potentially, each node can have different parameters
# - high involvment Φₐ=0.10, Φᵣ=0.15
# - medium involvment Φₐ=0.15, Φᵣ=0.30
# - low involvment Φₐ=0.40, Φᵣ=0.80
#
function sᴵ(avg_dis; λ=-1, Φₐ=0.15, Φᵣ=0.30)
    # avg_dis will be very low if the opinion of node x
    # is close to the average opinion of its neighbors 
    # in the same hyperedge
    if avg_dis <= Φₐ
        return exp(λ * avg_dis) #ℯ^(λ * avg_dis)
    # avg_dis will be very high if the opinion of node x
    # is far away to the average opinion of its neighbors 
    # in the same hyperedge
    elseif avg_dis >= Φᵣ
        return - exp(λ * avg_dis) #ℯ^(λ * avg_dis)
    else
        return 0.0
    end   
end

#
# default conformity function
# potentially, each node can have different parameters
#
function sᴵᴵ(avg_dis; δ=-5)
    return exp(δ * avg_dis) #ℯ^(δ * avg_dis)
end