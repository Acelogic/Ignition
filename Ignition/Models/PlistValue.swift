import Foundation

indirect enum PlistValue: Identifiable, Equatable {
    case string(String)
    case int(Int)
    case real(Double)
    case bool(Bool)
    case date(Date)
    case data(Data)
    case array([PlistValue])
    case dict([(key: String, value: PlistValue)])

    var id: String { UUID().uuidString }

    var typeLabel: String {
        switch self {
        case .string: return "String"
        case .int: return "Number"
        case .real: return "Real"
        case .bool: return "Boolean"
        case .date: return "Date"
        case .data: return "Data"
        case .array: return "Array"
        case .dict: return "Dictionary"
        }
    }

    init(fromAny value: Any) {
        switch value {
        case let s as String:
            self = .string(s)
        case let b as Bool:
            self = .bool(b)
        case let n as NSNumber:
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                self = .bool(n.boolValue)
            } else if n.objCType.pointee == CChar(UnicodeScalar("d").value) ||
                      n.objCType.pointee == CChar(UnicodeScalar("f").value) {
                self = .real(n.doubleValue)
            } else {
                self = .int(n.intValue)
            }
        case let d as Date:
            self = .date(d)
        case let data as Data:
            self = .data(data)
        case let arr as [Any]:
            self = .array(arr.map { PlistValue(fromAny: $0) })
        case let dict as [String: Any]:
            let pairs = dict.sorted(by: { $0.key < $1.key }).map { (key: $0.key, value: PlistValue(fromAny: $0.value)) }
            self = .dict(pairs)
        default:
            self = .string(String(describing: value))
        }
    }

    func toAny() -> Any {
        switch self {
        case .string(let s): return s
        case .int(let n): return n
        case .real(let d): return d
        case .bool(let b): return b
        case .date(let d): return d
        case .data(let d): return d
        case .array(let arr): return arr.map { $0.toAny() }
        case .dict(let pairs):
            var dict: [String: Any] = [:]
            for pair in pairs { dict[pair.key] = pair.value.toAny() }
            return dict
        }
    }

    static func == (lhs: PlistValue, rhs: PlistValue) -> Bool {
        switch (lhs, rhs) {
        case (.string(let a), .string(let b)): return a == b
        case (.int(let a), .int(let b)): return a == b
        case (.real(let a), .real(let b)): return a == b
        case (.bool(let a), .bool(let b)): return a == b
        case (.date(let a), .date(let b)): return a == b
        case (.data(let a), .data(let b)): return a == b
        case (.array(let a), .array(let b)): return a == b
        case (.dict(let a), .dict(let b)):
            guard a.count == b.count else { return false }
            for (pairA, pairB) in zip(a, b) {
                if pairA.key != pairB.key || pairA.value != pairB.value { return false }
            }
            return true
        default: return false
        }
    }
}
