function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--datapath"
            required = true
            arg_type = String
            help = "path to the data"
        "--precomputedpath"
            required = true
            arg_type = String
            help = "path to the precomputed data"
        "--thr"
            default = 0.1
            arg_type = Float64
            help = "threshold for the vertex weight"
        "--granularity"
            default = :day
            arg_type = Symbol
            help = "granularity of the time intervals"
        "--Φₐ"
            default = 0.10
            arg_type = Float64
            help = "homophily parameter for acceptance"
        "--Φᵣ"
            default = 0.15
            arg_type = Float64
            help = "homophily parameter for rejection"
        "--max_iter"
            default = 8
            arg_type = Int
            help = "maximum number of iterations of the diffusion algorithm"
        "--verbose"
            default = false
            arg_type = Bool
            help = "print verbose output"
    end

    return parse_args(s)
end

function parse_config()
    s = ArgParseSettings()

    @add_arg_table! s begin
        "--config"
            required = true
            arg_type = String
            help = "path to the config file"
    end

    return parse_args(s)
end