import Foundation

@objc protocol PrivilegedMetricsXPCProtocol {
    func fetchCPUMetrics(reply: @escaping (Data?, String?) -> Void)
}
