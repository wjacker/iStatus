import Foundation
import IOKit

final class CPUSampler {
    private var previousInfo: processor_info_array_t?
    private var previousInfoCount: mach_msg_type_number_t = 0

    func sampleDetailed() -> CPUDetail? {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount)
        guard result == KERN_SUCCESS, let info else { return nil }
        defer {
            if let previousInfo {
                let size = vm_size_t(previousInfoCount) * vm_size_t(MemoryLayout<integer_t>.stride)
                vm_deallocate(mach_task_self_, vm_address_t(bitPattern: previousInfo), size)
            }
            previousInfo = info
            previousInfoCount = infoCount
        }

        guard let previousInfo else {
            return nil
        }

        var totalTicks: UInt64 = 0
        var idleTicks: UInt64 = 0
        var userTicks: UInt64 = 0
        var systemTicks: UInt64 = 0
        let cpuInfo = Int(CPU_STATE_MAX)
        var perCoreUsage: [Double] = []

        for cpu in 0..<Int(cpuCount) {
            let base = cpu * cpuInfo
            let user = UInt64(info[base + Int(CPU_STATE_USER)]) - UInt64(previousInfo[base + Int(CPU_STATE_USER)])
            let system = UInt64(info[base + Int(CPU_STATE_SYSTEM)]) - UInt64(previousInfo[base + Int(CPU_STATE_SYSTEM)])
            let nice = UInt64(info[base + Int(CPU_STATE_NICE)]) - UInt64(previousInfo[base + Int(CPU_STATE_NICE)])
            let idle = UInt64(info[base + Int(CPU_STATE_IDLE)]) - UInt64(previousInfo[base + Int(CPU_STATE_IDLE)])

            let total = user + system + nice + idle
            totalTicks += total
            idleTicks += idle
            userTicks += user
            systemTicks += system

            let usage = total > 0 ? (Double(total - idle) / Double(total)) * 100 : 0
            perCoreUsage.append(usage)
        }

        guard totalTicks > 0 else { return nil }
        let overall = (Double(totalTicks - idleTicks) / Double(totalTicks)) * 100
        let userPercent = (Double(userTicks) / Double(totalTicks)) * 100
        let systemPercent = (Double(systemTicks) / Double(totalTicks)) * 100

        return CPUDetail(overall: overall, user: userPercent, system: systemPercent, perCore: perCoreUsage)
    }

    func sample() -> Double? {
        sampleDetailed()?.overall
    }
}
