function _get_diffusion_param_label(param::Symbol)
    label_mapping = Dict{Symbol, String}(
        :hi => "high_involvement",
        :mi => "medium_involvement",
        :li => "low_involvement",
        :hg => "hypergraph",
        :clique => "clique",
        :graph => "graph"
    )

    return get(label_mapping, param, string(param))
end

# *
# *
# *
function write_first_drift_results(
    first_drift_results,
    first_drift_fp,
    diffusion_params, 
    net_model,
    thr
)
    if !isfile(first_drift_fp)
        open(first_drift_fp, "w") do f
            write(
                f, 
                "diffusion_params,net_model,thr,",
                "avg_anticipated_intervals,avg_postponed_intervals,avg_mismatched_intervals,",
                "perc_matched_users,n_users,n_matched\n"     
            )
        end
    end

    _diffusion_params = _get_diffusion_param_label(diffusion_params)
    _net_model = _get_diffusion_param_label(net_model)
    avg_anticipated_intervals = round(first_drift_results[:avg_anticipated_intervals]; digits=2)
    avg_postponed_intervals = round(first_drift_results[:avg_postponed_intervals]; digits=2)
    avg_mismatched_intervals = round(first_drift_results[:avg_mismatched_intervals]; digits=2)
    perc_matched_users = round(first_drift_results[:perc_matched_users]; digits=2)
    n_users = first_drift_results[:n_users]
    n_matched = first_drift_results[:n_matched]

    open(first_drift_fp, "a") do f
        write(
            f, 
            "$_diffusion_params,$_net_model,$thr,",
            "$avg_anticipated_intervals,$avg_postponed_intervals,$avg_mismatched_intervals,",
            "$perc_matched_users,$n_users,$n_matched\n"     
        )
    end
end


# *
# *
# *
function write_first_drift_results_all(
    first_drift_results,
    first_drift_fp,
    diffusion_params, 
    net_model,
    thr
)
    if !isfile(first_drift_fp)
        open(first_drift_fp, "w") do f
            write(
                f, 
                "diffusion_params,net_model,thr,",
                "avg_anticipated_intervals,avg_postponed_intervals,avg_mismatched_intervals,",
                "perc_matched_users,n_drifters,perc_correctly_identified,n_users,",
                "tp,fp,fn,tn,",
                "n_matched_direction,",
                "avg_anticipated_intervals_direction,avg_postponed_intervals_direction,avg_mismatched_intervals_direction\n"     
            )
        end
    end

    _diffusion_params = _get_diffusion_param_label(diffusion_params)
    _net_model = _get_diffusion_param_label(net_model)
    avg_anticipated_intervals = round(first_drift_results[:avg_anticipated_intervals]; digits=2)
    avg_postponed_intervals = round(first_drift_results[:avg_postponed_intervals]; digits=2)
    avg_mismatched_intervals = round(first_drift_results[:avg_mismatched_intervals]; digits=2)
    perc_matched_users = round(first_drift_results[:perc_matched_users]; digits=2)
    n_drifters = first_drift_results[:n_drifters]
    perc_correctly_identified = round(first_drift_results[:perc_correctly_identified]; digits=2)
    n_users = first_drift_results[:n_users]
    tp = first_drift_results[:tp]
    fp = first_drift_results[:fp]
    fn = first_drift_results[:fn]
    tn = first_drift_results[:tn]

    n_matched_direction = first_drift_results[:n_matched_direction]
    avg_anticipated_intervals_direction = first_drift_results[:avg_anticipated_intervals_direction]
    avg_postponed_intervals_direction = first_drift_results[:avg_postponed_intervals_direction]
    avg_mismatched_intervals_direction = first_drift_results[:avg_mismatched_intervals_direction]

    open(first_drift_fp, "a") do f
        write(
            f, 
            "$_diffusion_params,$_net_model,$thr,",
            "$avg_anticipated_intervals,$avg_postponed_intervals,$avg_mismatched_intervals,",
            "$perc_matched_users,$n_drifters,$perc_correctly_identified,$n_users,",
            "$tp,$fp,$fn,$tn,",
            "$n_matched_direction,",
            "$avg_anticipated_intervals_direction,$avg_postponed_intervals_direction,$avg_mismatched_intervals_direction\n"     
        )
    end
end


# *
# *
# *
function write_n_drifts_results(
    n_drift_results,
    n_drifts_fp,
    diffusion_params,
    net_model,
    thr
)
    if !isfile(n_drifts_fp)
        open(n_drifts_fp, "w") do f
            write(
                f, 
                "diffusion_params,net_model,thr,",
                "rmse\n"     
            )
        end
    end

    _diffusion_params = _get_diffusion_param_label(diffusion_params)
    _net_model = _get_diffusion_param_label(net_model)
    rmse = round(n_drift_results[:rmse]; digits=2)

    open(n_drifts_fp, "a") do f
        write(
            f, 
            "$_diffusion_params,$_net_model,$thr,",
            "$rmse\n"     
        )
    end
end

# *
# *
# *
function write_last_stance_results(
    last_stance_results,
    last_stance_fp,
    diffusion_params,
    net_model,
    thr
)

    if !isfile(last_stance_fp)
        open(last_stance_fp, "w") do f
            write(
                f, 
                "diffusion_params,net_model,thr,",
                "final_stance_correct,final_stance_wrong,final_stance_nothing,",   
                "final_stance_nothing_gt,final_stance_same_index_correct,final_stance_same_index_nothing,",
                "drifted_users,n_users,perc_matched_users\n"  
            )
        end
    end

    _diffusion_params = _get_diffusion_param_label(diffusion_params)
    _net_model = _get_diffusion_param_label(net_model)
    final_stance_correct = last_stance_results[:final_stance_correct]
    final_stance_wrong = last_stance_results[:final_stance_wrong]
    final_stance_nothing = last_stance_results[:final_stance_nothing]
    final_stance_nothing_gt = last_stance_results[:final_stance_nothing_gt]
    final_stance_same_index_correct = last_stance_results[:final_stance_same_index_correct]
    final_stance_same_index_nothing = last_stance_results[:final_stance_same_index_nothing]
    drifted_users = last_stance_results[:drifted_users]
    n_users = last_stance_results[:n_users]
    perc_matched_users = round(last_stance_results[:perc_matched_users]; digits=2)

    open(last_stance_fp, "a") do f
        write(
            f, 
            "$_diffusion_params,$_net_model,$thr,",
            "$final_stance_correct,$final_stance_wrong,$final_stance_nothing,",   
            "$final_stance_nothing_gt,$final_stance_same_index_correct,$final_stance_same_index_nothing,",
            "$drifted_users,$n_users,$perc_matched_users\n"  
        )
    end
end


# *
# *
# *
function write_count_users_results(
    count_users_results,
    count_users_fp,
    diffusion_params,
    net_model,
    thr
)

    if !isfile(count_users_fp)
        open(count_users_fp, "w") do f
            write(
                f, 
                "diffusion_params,net_model,thr,",
                "n_drifters_gt,n_drifters_sim,n_no_drifters,n_no_drifters_sim,",
                "n_matched_drifters,n_matched_users,n_users\n"
            )
        end
    end

    _diffusion_params = _get_diffusion_param_label(diffusion_params)
    _net_model = _get_diffusion_param_label(net_model)
    n_drifters_gt = count_users_results[:n_drifters_gt]
    n_drifters_sim = count_users_results[:n_drifters_sim]
    n_no_drifters = count_users_results[:n_no_drifters]
    n_no_drifters_sim = count_users_results[:n_no_drifters_sim]
    n_matched_drifters = count_users_results[:n_matched_drifters]
    n_matched_users = count_users_results[:n_matched_users]
    n_users = count_users_results[:n_users]

    open(count_users_fp, "a") do f
        write(
            f, 
            "$_diffusion_params,$_net_model,$thr,",
            "$n_drifters_gt,$n_drifters_sim,$n_no_drifters,$n_no_drifters_sim,",
            "$n_matched_drifters,$n_matched_users,$n_users\n"
        )
    end
   
end



