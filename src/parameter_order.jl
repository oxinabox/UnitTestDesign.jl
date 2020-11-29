"""
    ipog(arity, n_way)

The `arity` is an integer array of the number of possible values each
parameter can take. The `n_way` is whether each parameter must appear
once in the test suite, or whether each pair of parameters must appear
together, or whether each triple must appear together. The wayness
can be set as high as the length of the arity.

This uses the in-parameter-order-general algorithm. It will always return
the same set of values. It takes less time and memory than most other
approaches.

This function represents a test set as a two-dimensional array of
the same integer type as the input arity. Each value of the array
is either an integer number, from 1 to the arity of that parameter,
or it is 0 for what the paper calls a don't-care value.

Lei, Yu, Raghu Kacker, D. Richard Kuhn, Vadim Okun, and James Lawrence.
2008. “IPOG/IPOG-D: Efficient Test Generation for Multi-Way Combinatorial
Testing.” Software Testing, Verification & Reliability 18 (3): 125–48.
"""
function ipog(arity, n_way)
    nonincreasing = sortperm(arity, rev = true)
    original_arity = arity
    arity = arity[nonincreasing]
    original_order = sortperm(nonincreasing)

    param_cnt = length(arity)
    # Setup by taking first n_way parameters.
    # This is a 2D array.
    test_set = all_combinations(arity[1:n_way], n_way)

    for param_idx in (n_way + 1):param_cnt
        wider = zeros(eltype(arity), size(test_set, 1), param_idx)
        wider[:, 1:(param_idx - 1)] .= test_set

        # Seed test cases by adding them once params are covered and not double-covering.
        # Make mixed strength here, once all params at a strength are covered.
        allc = one_parameter_combinations_matrix(arity[1:param_idx], n_way)
        # Exclude unwanted by stripping them from the allc combinations.
        for set_row_idx in 1:size(wider, 1)
            # This needs to account for previous entries that aren't set.
            match_hist = matches_from_missing(allc, wider[set_row_idx, :], param_idx)
            if (any(match_hist .> 0))
                # The argmax tie-breaks in a consistent manner.
                wider[set_row_idx, param_idx] = argmax(match_hist)
                add_coverage!(allc, wider[set_row_idx, :])
            end  # else don't set this entry by leaving it zero.
        end

        for missing_row_idx in 1:size(wider, 1)
            nonzero = sum(wider[missing_row_idx, 1:(param_idx - 1)] .> 0)
            if nonzero < param_idx - 1
                # The found_values has what format?
                found_entry = fill_consistent_matches(allc, wider[missing_row_idx, :])
                remain_zero = sum(found_entry .> 0)
                if remain_zero < nonzero
                    wider[missing_row_idx, :] .= found_entry
                    add_coverage!(allc, found_entry)
                end  # else nothing found for this row.
            end
        end

        add_entries = Array{Array{eltype(allc),1},1}()
        while remaining_uncovered(allc) > 0
            # add a new row. Fill with necessary tuples.
            entry = first_match_for_parameter(allc, param_idx)
            filled = fill_consistent_matches(allc, entry)
            add_coverage!(allc, filled)
            push!(add_entries, filled)
        end

        test_set = zeros(eltype(arity), size(wider, 1) + length(add_entries), param_idx)
        test_set[1:size(wider, 1), :] .= wider
        for long_idx in 1:length(add_entries)
            test_set[size(wider, 1) + long_idx, :] .= add_entries[long_idx]
        end
    end

    # We could have zero values at the end, so fill them in with the
    # least-used values.
    hist = zeros(Int, param_cnt, maximum(arity))
    for hist_row in 1:size(test_set, 1)
        for hist_col in 1:size(test_set, 2)
            if test_set[hist_row, hist_col] > 0
                hist[hist_col, test_set[hist_row, hist_col]] += 1
            end
        end
    end
    for fill_row in 1:size(test_set, 1)
        for fill_col in 1:size(test_set, 2)
            if test_set[fill_row, fill_col] == 0
                fill_val = argmin(hist[fill_col, 1:arity[fill_col]])
                test_set[fill_row, fill_col] = fill_val
                hist[fill_col, fill_val] += 1
            end
        end
    end
    # reorder test columns with `original_order`.
    test_set[:, original_order]
end
