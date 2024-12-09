#include "Comparator.hh"
#include <iostream>
#include <iomanip>
#include <cmath>

namespace hip_intercept {

Comparator::Comparator(float epsilon) : epsilon_(epsilon) {}

bool Comparator::compareFloats(float a, float b) const {
    if (std::isnan(a) && std::isnan(b)) return true;
    if (std::isinf(a) && std::isinf(b)) return a == b;
    return std::abs(a - b) <= epsilon_;
}

ValueDifference Comparator::compareMemoryChanges(
    const std::vector<MemoryChange>& changes1,
    const std::vector<MemoryChange>& changes2) {
    
    std::cout << "  Comparing memory changes: " 
              << changes1.size() << " vs " << changes2.size() << " changes" << std::endl;
    
    ValueDifference diff;
    diff.matches = true;
    
    std::set<size_t> indices1, indices2;
    for (const auto& change : changes1) indices1.insert(change.element_index);
    for (const auto& change : changes2) indices2.insert(change.element_index);
    
    // Find missing indices
    std::cout << "  Finding missing indices..." << std::endl;
    std::set_difference(indices1.begin(), indices1.end(),
                       indices2.begin(), indices2.end(),
                       std::back_inserter(diff.missing_indices));
    
    // Compare values for common indices
    std::cout << "  Comparing values for common indices..." << std::endl;
    size_t progress = 0;
    const size_t total = changes1.size();
    
    for (const auto& change1 : changes1) {
        if (progress % 10000 == 0) { // Print progress every 10000 elements
            std::cout << "    Progress: " << progress << "/" << total << "\r" << std::flush;
        }
        progress++;
        
        // Use a more efficient way to find matching elements
        auto it = std::lower_bound(changes2.begin(), changes2.end(), change1,
            [](const MemoryChange& a, const MemoryChange& b) {
                return a.element_index < b.element_index;
            });
        
        if (it != changes2.end() && it->element_index == change1.element_index) {
            if (!compareFloats(change1.pre_value, it->pre_value)) {
                diff.matches = false;
                diff.pre_value_mismatches.push_back({
                    change1.element_index,
                    change1.pre_value,
                    it->pre_value
                });
            }
            if (!compareFloats(change1.post_value, it->post_value)) {
                diff.matches = false;
                diff.post_value_mismatches.push_back({
                    change1.element_index,
                    change1.post_value,
                    it->post_value
                });
            }
        }
    }
    std::cout << std::endl;
    
    return diff;
}

KernelComparisonResult Comparator::compareKernelExecutions(
    const KernelExecution& exec1,
    const KernelExecution& exec2) {
    
    std::cout << "Comparing kernel: " << exec1.kernel_name << std::endl;
    
    KernelComparisonResult result;
    result.matches = true;
    result.kernel_name = exec1.kernel_name;
    
    // Compare basic kernel properties
    if (exec1.kernel_name != exec2.kernel_name) {
        result.matches = false;
        result.differences.push_back("Kernel names differ: " + 
            exec1.kernel_name + " vs " + exec2.kernel_name);
    }
    
    if (exec1.grid_dim.x != exec2.grid_dim.x ||
        exec1.grid_dim.y != exec2.grid_dim.y ||
        exec1.grid_dim.z != exec2.grid_dim.z) {
        result.matches = false;
        result.differences.push_back("Grid dimensions differ");
    }
    
    if (exec1.block_dim.x != exec2.block_dim.x ||
        exec1.block_dim.y != exec2.block_dim.y ||
        exec1.block_dim.z != exec2.block_dim.z) {
        result.matches = false;
        result.differences.push_back("Block dimensions differ");
    }
    
    if (exec1.shared_mem != exec2.shared_mem) {
        result.matches = false;
        result.differences.push_back("Shared memory size differs");
    }
    
    // Compare memory changes for each argument
    for (const auto& [arg_idx, changes1] : exec1.changes_by_arg) {
        auto it = exec2.changes_by_arg.find(arg_idx);
        if (it == exec2.changes_by_arg.end()) {
            result.matches = false;
            result.differences.push_back("Missing changes for argument " + 
                std::to_string(arg_idx) + " in second trace");
            continue;
        }
        
        std::vector<MemoryChange> changes1_vec, changes2_vec;
        for (const auto& [idx, vals] : changes1) {
            changes1_vec.push_back({idx, vals.first, vals.second});
        }
        for (const auto& [idx, vals] : it->second) {
            changes2_vec.push_back({idx, vals.first, vals.second});
        }
        
        auto diff = compareMemoryChanges(changes1_vec, changes2_vec);
        if (!diff.matches) {
            result.matches = false;
            result.value_differences[arg_idx] = diff;
        }
    }
    
    return result;
}

ComparisonResult Comparator::compare(const Trace& trace1, const Trace& trace2) {
    std::cout << "\nStarting trace comparison..." << std::endl;
    
    ComparisonResult result;
    result.traces_match = true;
    result.first_divergence_point = SIZE_MAX;

    // Create a merged timeline of events
    struct TimelineEvent {
        enum Type { KERNEL, MEMORY } type;
        size_t index;  // Index in original vector
        uint64_t execution_order;
        
        TimelineEvent(Type t, size_t i, uint64_t order) 
            : type(t), index(i), execution_order(order) {}
    };

    std::vector<TimelineEvent> timeline1, timeline2;

    // Build timelines for both traces
    for (size_t i = 0; i < trace1.kernel_executions.size(); i++) {
        timeline1.emplace_back(TimelineEvent::KERNEL, i, 
                             trace1.kernel_executions[i].execution_order);
    }
    for (size_t i = 0; i < trace1.memory_operations.size(); i++) {
        timeline1.emplace_back(TimelineEvent::MEMORY, i, 
                             trace1.memory_operations[i].execution_order);
    }

    for (size_t i = 0; i < trace2.kernel_executions.size(); i++) {
        timeline2.emplace_back(TimelineEvent::KERNEL, i, 
                             trace2.kernel_executions[i].execution_order);
    }
    for (size_t i = 0; i < trace2.memory_operations.size(); i++) {
        timeline2.emplace_back(TimelineEvent::MEMORY, i, 
                             trace2.memory_operations[i].execution_order);
    }

    // Sort timelines by execution order
    auto sort_by_order = [](const TimelineEvent& a, const TimelineEvent& b) {
        return a.execution_order < b.execution_order;
    };
    std::sort(timeline1.begin(), timeline1.end(), sort_by_order);
    std::sort(timeline2.begin(), timeline2.end(), sort_by_order);

    // Compare events in chronological order
    size_t kernel_count = 0;
    size_t i1 = 0, i2 = 0;
    
    while (i1 < timeline1.size() && i2 < timeline2.size()) {
        const auto& event1 = timeline1[i1];
        const auto& event2 = timeline2[i2];

        if (event1.type != event2.type) {
            result.traces_match = false;
            result.error_message += "Event type mismatch at execution order " + 
                std::to_string(event1.execution_order) + "\n";
            break;
        }

        if (event1.type == TimelineEvent::KERNEL) {
            auto kernel_result = compareKernelExecutions(
                trace1.kernel_executions[event1.index],
                trace2.kernel_executions[event2.index]
            );
            
            result.kernel_results.push_back(kernel_result);
            
            if (!kernel_result.matches && result.first_divergence_point == SIZE_MAX) {
                result.first_divergence_point = kernel_count;
            }
            kernel_count++;
        } else {
            // Compare memory operations
            const auto& op1 = trace1.memory_operations[event1.index];
            const auto& op2 = trace2.memory_operations[event2.index];
            
            if (op1.type != op2.type || op1.size != op2.size || op1.kind != op2.kind) {
                result.traces_match = false;
                result.error_message += "Memory operation differs in type, size, or kind\n";
            }
            
            // Compare memory states
            if ((op1.pre_state && !op2.pre_state) || (!op1.pre_state && op2.pre_state)) {
                result.traces_match = false;
                result.error_message += "Memory operation differs in pre-state availability\n";
            }
            
            if (op1.pre_state && op2.pre_state &&
                (op1.pre_state->size != op2.pre_state->size ||
                 memcmp(op1.pre_state->data.get(), op2.pre_state->data.get(),
                        op1.pre_state->size) != 0)) {
                result.traces_match = false;
                result.error_message += "Memory operation differs in pre-state\n";
            }
            
            // Similar checks for post-state...
        }

        i1++;
        i2++;
    }

    // Check for remaining events
    if (i1 < timeline1.size() || i2 < timeline2.size()) {
        result.traces_match = false;
        result.error_message += "Different number of events in traces\n";
    }

    return result;
}

void Comparator::printComparisonResult(const ComparisonResult& result) {
    std::cout << "\nComparison Results:\n"
              << "==================\n";
    
    if (result.traces_match) {
        std::cout << "Traces match exactly!\n";
        return;
    }
    
    std::cout << "Traces differ.\n";
    
    // Print memory operation differences first
    if (!result.error_message.empty()) {
        std::cout << "\nMemory Operation Differences:\n"
                  << "----------------------------\n"
                  << result.error_message;
    }
    
    // Print kernel execution differences
    if (result.first_divergence_point != SIZE_MAX) {
        std::cout << "\nKernel Execution Differences:\n"
                  << "---------------------------\n"
                  << "First divergence at kernel execution "
                  << result.first_divergence_point << "\n";
    }
    
    for (size_t i = 0; i < result.kernel_results.size(); ++i) {
        const auto& kr = result.kernel_results[i];
        if (!kr.matches) {
            std::cout << "\nKernel " << i << " (" << kr.kernel_name << "):\n";
            
            // Print kernel configuration differences
            if (!kr.differences.empty()) {
                std::cout << "  Configuration differences:\n";
                for (const auto& diff : kr.differences) {
                    std::cout << "    - " << diff << "\n";
                }
            }
            
            // Print argument differences
            for (const auto& [arg_idx, diff] : kr.value_differences) {
                std::cout << "\n  Argument " << arg_idx << ":\n";
                
                // Pre-execution state
                std::cout << "    Pre-execution state:\n";
                if (!diff.pre_value_mismatches.empty()) {
                    std::cout << "      " << diff.pre_value_mismatches.size() 
                             << " values differ\n";
                    std::cout << "      First 3 differences:\n";
                    for (size_t j = 0; j < std::min(size_t(3), diff.pre_value_mismatches.size()); j++) {
                        const auto& m = diff.pre_value_mismatches[j];
                        std::cout << "        Index " << m.index << ": "
                                 << m.value1 << " vs " << m.value2 << "\n";
                    }
                } else {
                    std::cout << "      Matches\n";
                }
                
                // Post-execution state
                std::cout << "    Post-execution state:\n";
                if (!diff.post_value_mismatches.empty()) {
                    std::cout << "      " << diff.post_value_mismatches.size() 
                             << " values differ\n";
                    std::cout << "      First 3 differences:\n";
                    for (size_t j = 0; j < std::min(size_t(3), diff.post_value_mismatches.size()); j++) {
                        const auto& m = diff.post_value_mismatches[j];
                        std::cout << "        Index " << m.index << ": "
                                 << m.value1 << " vs " << m.value2 << "\n";
                    }
                } else {
                    std::cout << "      Matches\n";
                }
                
                if (!diff.missing_indices.empty()) {
                    std::cout << "    Missing " << diff.missing_indices.size() 
                             << " indices in second trace\n";
                }
            }
        }
    }
}

ComparisonResult Comparator::compare(const std::string& trace_path1, const std::string& trace_path2) {
    try {
        Trace trace1 = Tracer::loadTrace(trace_path1);
        Trace trace2 = Tracer::loadTrace(trace_path2);
        return compare(trace1, trace2);
    } catch (const std::exception& e) {
        ComparisonResult result;
        result.traces_match = false;
        result.error_message = std::string("Failed to load traces: ") + e.what();
        return result;
    }
}

} // namespace hip_intercept


int main(int argc, char* argv[]) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0] << " <trace1> <trace2>\n";
        return 1;
    }

    hip_intercept::Comparator comparator;
    hip_intercept::ComparisonResult result = comparator.compare(argv[1], argv[2]);
    comparator.printComparisonResult(result);
    return 0;
}