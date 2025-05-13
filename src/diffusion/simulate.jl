"""
    Reproduce the opinion change process from the paper 
    "Modelling non-linear consensus dynamics on hypergraphs"
    https://iopscience.iop.org/article/10.1088/2632-072X/abcea3/meta

    NB. Discrete time simulation
"""
function simulate(
    h::Hypergraph, 
    type::Type{DiscreteNonLinearConsensus};
    max_iter::Union{Int,Float64}=1000,
    step_size::Union{Int,Float64}=1, #not used here
    homophily_function::Function=sᴵ,
    homophily_function_params::Union{Dict,Nothing}=nothing,
    conformity_function::Function=sᴵᴵ,
    aggregation_method::DataType=Sum,
    initial_opinions::Union{Array{Float64,1},Nothing}=nothing,
    verbose::Bool=true
)
    
    # initiliaze opinion vector 
    isnothing(initial_opinions) ? initial_opinions = rand(Uniform(0.0,1.0), nhv(h)) : initial_opinions

    # initialize the memory of the simulation
    # it stores the initial opinion of each node
    opinion_history = Dict{Int, Array{Float64, 1}}()
    for v in 1:nhv(h)
        push!(
            get!(opinion_history, v, Array{Float64, 1}()),
            initial_opinions[v]
        )
    end

    # save the initial opinions
    curr_opinions = deepcopy(initial_opinions)
    next_opinions = zeros(Float64, nhv(h))

    _iter = nothing

    # simulate the diffusion process
    for iter in 1:max_iter
        println("iteration $iter/$max_iter")
        _iter = iter

        # iterate over all nodes
        for v in 1:nhv(h)
            # initialize the gain of the node v
            gains = Dict{Int, Float64}(collect(1:nhe(h)) .=> 0.0)

            # iterate over all hyperedges
            # that contain the node v
            for he in gethyperedges(h, v)
                avg_op = 0.0
                avg_neigh_op = 0.0

                neighbors = getvertices(h, he.first)

                # if the node v is the only node in the hyperedge
                # then the gain is 0
                if length(neighbors) == 1
                    gains[he.first] = 0.0
                    continue
                end

                # iterate over all neighbors of the node v
                # in the hyperedge he
                for u in neighbors
                    # sum up the nodes' opinions
                    avg_op += curr_opinions[u.first]

                    # we also store the avg opinion of the neighbors
                    # of the node v excluding v itself
                    if u.first != v
                        avg_neigh_op += curr_opinions[u.first]
                    end
                end

                # compute the average opinion of the he
                avg_op /= length(neighbors) #getvertices(h, he.first)
                # and how much the opinion of the node v
                # differs from the average opinion of the he
                avg_disᵢ = avg_op - curr_opinions[v]
                # evaluate the homophily value
                homophily = isnothing(homophily_function_params) ? 
                    homophily_function(abs(avg_disᵢ)) : 
                    homophily_function(abs(avg_disᵢ); homophily_function_params...)

                # now we evaluate the conformity value
                conformity = 0.0
                # compute the average opinion of the he, excluding v
                avg_neigh_op /= length(neighbors) - 1 # getvertices(h, he.first) - 1

                # here we evaluate how much a node u differs from the average opinion
                # of the hyperedge, without considering the opinion of the node v
                for u in neighbors #getvertices(h, he.first)
                    avg_dis = avg_neigh_op - curr_opinions[u.first]
                    conformityᵤ = conformity_function(abs(avg_dis)) * (curr_opinions[u.first] - curr_opinions[v])
                    conformity = conformity + conformityᵤ
                end

                # evaluate the gain from each he
                gain = homophily * conformity
                # store the value
                gains[he.first] = gain

                verbose && println("homophily: $homophily - conformity: $conformity - avg_op: $avg_op - avg_neigh_op: $avg_neigh_op - v: $v - e: $(he.first) - gain: $gain")
            end

            # aggregate the gains
            gain = aggregate(collect(values(gains)), aggregation_method)
            #next_opinions[v] = curr_opinions[v] + gain
            
            verbose && println("v: $v - curr_op: $(curr_opinions[v]) - gain: $gain - next_op: $(curr_opinions[v] + gain)")
            verbose && println("gains: $gains")
            verbose && println("curr_opinions: $curr_opinions")
            verbose && println("------------------------------------\n")

            next_opinions[v] = 
              (curr_opinions[v] + gain) < 0.0 ? 
              0.0 : (curr_opinions[v] + gain) > 1.0 ? 
              1.0 : curr_opinions[v] + gain 

            # store the current opinion vector
            #! iter == 1 && continue # we already stored the initial opinion
            #! push!(opinion_history[v], curr_opinions[v])  
            push!(opinion_history[v], next_opinions[v])  
        end # end node iteration

        if abs(std(next_opinions .- curr_opinions)) < 0.0005
            println("convergence reached at $iter/$max_iter iteration")
            break
        end

        # update the current opinion vector
        curr_opinions = deepcopy(next_opinions)   
    end # end diffusion process

    return opinion_history, _iter
end


