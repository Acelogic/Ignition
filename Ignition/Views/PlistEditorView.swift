import SwiftUI

struct PlistEditorView: View {
    @Binding var plistValue: PlistValue
    let isReadOnly: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch plistValue {
            case .dict(let pairs):
                ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                    PlistDictRow(
                        key: pair.key,
                        value: pair.value,
                        isReadOnly: isReadOnly,
                        onUpdate: { newKey, newValue in
                            updateDictPair(at: index, key: newKey, value: newValue)
                        },
                        onDelete: {
                            deleteDictPair(at: index)
                        }
                    )
                }

                if !isReadOnly {
                    Button {
                        addDictPair()
                    } label: {
                        Label("Add Key", systemImage: "plus.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.accentColor)
                    .padding(.top, 4)
                }

            default:
                PlistValueEditor(value: $plistValue, isReadOnly: isReadOnly)
            }
        }
    }

    private func updateDictPair(at index: Int, key: String, value: PlistValue) {
        guard case .dict(var pairs) = plistValue else { return }
        guard index < pairs.count else { return }
        pairs[index] = (key: key, value: value)
        plistValue = .dict(pairs)
    }

    private func deleteDictPair(at index: Int) {
        guard case .dict(var pairs) = plistValue else { return }
        guard index < pairs.count else { return }
        pairs.remove(at: index)
        plistValue = .dict(pairs)
    }

    private func addDictPair() {
        guard case .dict(var pairs) = plistValue else { return }
        pairs.append((key: "NewKey", value: .string("")))
        plistValue = .dict(pairs)
    }
}

// MARK: - Dict Row

struct PlistDictRow: View {
    let key: String
    let value: PlistValue
    let isReadOnly: Bool
    let onUpdate: (String, PlistValue) -> Void
    let onDelete: () -> Void

    @State private var editedKey: String
    @State private var editedValue: PlistValue
    @State private var isExpanded = false

    init(key: String, value: PlistValue, isReadOnly: Bool,
         onUpdate: @escaping (String, PlistValue) -> Void,
         onDelete: @escaping () -> Void) {
        self.key = key
        self.value = value
        self.isReadOnly = isReadOnly
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self._editedKey = State(initialValue: key)
        self._editedValue = State(initialValue: value)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                if isContainer {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer().frame(width: 12)
                }

                // Key
                if isReadOnly {
                    Text(key)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .frame(minWidth: 120, alignment: .leading)
                } else {
                    TextField("Key", text: $editedKey)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .textFieldStyle(.plain)
                        .frame(minWidth: 120, alignment: .leading)
                        .onChange(of: editedKey) {
                            onUpdate(editedKey, editedValue)
                        }
                }

                // Type badge
                Text(value.typeLabel)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 3))

                if !isContainer {
                    PlistValueEditor(value: $editedValue, isReadOnly: isReadOnly)
                        .onChange(of: editedValue) {
                            onUpdate(editedKey, editedValue)
                        }
                } else {
                    Spacer()
                    Text(containerSummary)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if !isReadOnly {
                    Button { onDelete() } label: {
                        Image(systemName: "minus.circle")
                            .font(.caption)
                            .foregroundStyle(.red.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)

            if isExpanded {
                PlistEditorView(plistValue: $editedValue, isReadOnly: isReadOnly)
                    .padding(.leading, 24)
                    .onChange(of: editedValue) {
                        onUpdate(editedKey, editedValue)
                    }
            }
        }
    }

    // Use a computed binding so PlistEditorView can bind to editedValue
    private var valueBinding: Binding<PlistValue> {
        $editedValue
    }

    private var isContainer: Bool {
        switch value {
        case .dict, .array: return true
        default: return false
        }
    }

    private var containerSummary: String {
        switch value {
        case .dict(let pairs): return "(\(pairs.count) items)"
        case .array(let items): return "(\(items.count) items)"
        default: return ""
        }
    }
}

// MARK: - Value Editor

struct PlistValueEditor: View {
    @Binding var value: PlistValue
    let isReadOnly: Bool

    var body: some View {
        Group {
            switch value {
            case .string(let s):
                if isReadOnly {
                    Text(s)
                        .font(.system(.caption, design: .monospaced))
                        .lineLimit(1)
                } else {
                    TextField("Value", text: Binding(
                        get: { s },
                        set: { value = .string($0) }
                    ))
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                }

            case .int(let n):
                if isReadOnly {
                    Text("\(n)")
                        .font(.system(.caption, design: .monospaced))
                } else {
                    TextField("Value", value: Binding(
                        get: { n },
                        set: { value = .int($0) }
                    ), format: .number)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(maxWidth: 120)
                }

            case .real(let d):
                if isReadOnly {
                    Text(String(format: "%.4f", d))
                        .font(.system(.caption, design: .monospaced))
                } else {
                    TextField("Value", value: Binding(
                        get: { d },
                        set: { value = .real($0) }
                    ), format: .number)
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .frame(maxWidth: 120)
                }

            case .bool(let b):
                Toggle("", isOn: Binding(
                    get: { b },
                    set: { value = .bool($0) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(isReadOnly)

            case .date(let d):
                if isReadOnly {
                    Text(d.formatted())
                        .font(.system(.caption, design: .monospaced))
                } else {
                    DatePicker("", selection: Binding(
                        get: { d },
                        set: { value = .date($0) }
                    ))
                    .labelsHidden()
                    .controlSize(.small)
                }

            case .data(let d):
                Text("\(d.count) bytes")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)

            case .array, .dict:
                EmptyView()
            }
        }
    }
}
