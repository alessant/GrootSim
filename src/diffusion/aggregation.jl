abstract type OpinionAggregationMethod end
struct Sum <: OpinionAggregationMethod end
struct Avg <: OpinionAggregationMethod end

#
# default aggregation function
#
function aggregate(values::Array{Float64,1}, type::Type{Sum})
    return sum(values)
end

function aggregate(values::Array{Float64,1}, type::Type{Avg})
    return mean(values)
end