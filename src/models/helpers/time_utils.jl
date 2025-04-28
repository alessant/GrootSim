abstract type Intervals end
struct ContinuousIntervals end
struct DiscreteIntervals end

"""
    here we only consider the ending time of the interval since,
    potentially, the starting date can always match mindate
    The cut off will be done only after the weights of each event have been computed
"""
function build_intervals(type::Type{ContinuousIntervals}; mindate::DateTime, maxdate::DateTime, stride::Dates.Millisecond)
    # this structure will contain the right intervals
    # mindate + i * stride 
    intervals = Array{DateTime, 1}()

    # Evaluating the total number of time slots
    # within the observation period (maxtime - mintime)
    # using the stride as discretization param
    nintervals = ceil(Int,(maxdate - mindate)/stride)

    for i = 1:nintervals
        offset = mindate + i * stride 
        lastdate = offset > maxdate ? maxdate + Dates.Millisecond(1) :  offset
        push!(intervals, lastdate)
    end

    return intervals
end


"""
    eval_intervals(mindate::DateTime, maxdate::DateTime, Δₘ::Dates.Millisecond)

Evaluate the total amount of intervals to analyze together with their
starting and ending date from `mindate` to `maxdate`.

The number of intervals is given by the following formula:
(maxdate - mindate)/Δ

Return a dict where each entry is in the form
    interval_id -> (start_date, end_date)
"""
function build_intervals(type::Type{DiscreteIntervals}; mindate::DateTime, maxdate::DateTime, stride::Dates.Millisecond)
    # interval_id -> (start_date, end_date)
    intervals = Dict{Int, Pair{DateTime, DateTime}}()

    Δ = stride

    # Evaluating the total number of time slots
    # within the observation period (maxdate - mindate)
    # using Δₘ as discretization param
    nintervals = ceil(Int,(maxdate - mindate)/Δ)

    for i=1:nintervals
        offset = mindate + Δ > maxdate ?  maxdate + Dates.Millisecond(1) :  mindate + Δ

        push!(
            intervals,
            i => Pair(convert(Dates.DateTime, (mindate)), convert(Dates.DateTime, (offset)))
        )

        mindate = offset
    end

    intervals
end