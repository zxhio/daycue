import SwiftUI

struct MainWindowView: View {
    @ObservedObject var state: ScheduleState
    @Environment(\.calendar) private var calendar
    @State var selectedDate: Date
    let selectDate: (Date) -> Void
    let add: () -> Void
    let edit: (TimeBlock) -> Void
    let delete: (TimeBlock) -> Void

    private var week: ScheduleWeek { ScheduleWeek(containing: selectedDate, calendar: calendar) }

    private var selectedBlocks: [TimeBlock] {
        state.blocks(on: selectedDate, calendar: calendar)
    }

    private var isPast: Bool { !state.canEdit(on: selectedDate) }

    private func select(_ date: Date) {
        selectedDate = calendar.startOfDay(for: date)
        selectDate(selectedDate)
    }

    private func moveWeek(by offset: Int) {
        if let date = week.moving(by: offset) { select(date) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Time Blocks").font(.largeTitle.weight(.semibold))
                Spacer()
                Button(action: add) { Label("Add Time Block", systemImage: "plus") }
                    .controlSize(.large)
                    .disabled(state.loadError != nil || isPast)
                    .accessibilityIdentifier("daycue.add-block")
            }
            .padding(24)

            Divider().padding(.horizontal, 24)
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    Text(week.rangeTitle).font(.callout).foregroundStyle(.secondary).lineLimit(1)
                        .accessibilityIdentifier("daycue.week-range")
                    Spacer()
                    Button { moveWeek(by: -1) } label: {
                        Image(systemName: "chevron.left").font(.system(size: 10, weight: .semibold))
                            .frame(width: 16, height: 18).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Previous Week")
                    .accessibilityIdentifier("daycue.previous-week")
                    Button("Today") { select(state.today) }
                        .disabled(calendar.isDate(selectedDate, inSameDayAs: state.today))
                        .accessibilityIdentifier("daycue.today")
                    Button { moveWeek(by: 1) } label: {
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                            .frame(width: 16, height: 18).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Next Week")
                    .accessibilityIdentifier("daycue.next-week")
                }
                .controlSize(.small)
                HStack(spacing: 6) {
                    ForEach(week.days) { day in
                        let selected = calendar.isDate(day.date, inSameDayAs: selectedDate)
                        Button { select(day.date) } label: {
                            VStack(spacing: 4) {
                                Text(day.weekday.shortName).font(.caption.weight(.medium))
                                Text("\(day.dayNumber)").font(.system(size: 18, weight: .semibold)).monospacedDigit()
                            }
                            .lineLimit(1)
                            .frame(minWidth: 0, maxWidth: .infinity)
                            .frame(height: 54)
                            .background(selected ? Color(nsColor: .systemBlue) : Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 9))
                            .foregroundStyle(selected ? Color.white : Color.primary)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(week.label(for: day.date))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("daycue.date.\(day.weekday.rawValue)")
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 14)
            .padding(.bottom, 14)
            Divider()
            HStack {
                Text(week.selectedTitle).font(.headline)
                    .accessibilityIdentifier("daycue.selected-date")
                if isPast {
                    Label("Read only", systemImage: "lock")
                        .font(.caption).foregroundStyle(.secondary)
                        .accessibilityIdentifier("daycue.read-only")
                }
                Spacer()
                Text("\(selectedBlocks.count) time \(selectedBlocks.count == 1 ? "block" : "blocks")")
                    .font(.callout).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            if let error = state.loadError {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Couldn’t read your schedule.", systemImage: "exclamationmark.triangle").font(.headline)
                    Text(error).font(.callout).textSelection(.enabled)
                    Button("Try Again") { state.reload() }
                }
                .padding(24)
            } else if selectedBlocks.isEmpty {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 12) {
                            Image(systemName: isPast ? "calendar" : "calendar.badge.plus")
                                .font(.system(size: 36, weight: .light)).foregroundStyle(.secondary)
                            Text(isPast ? "No time blocks on this date." : "No time blocks yet.").font(.title3.weight(.medium))
                            if !isPast {
                                Text(state.blocks.isEmpty ? "Add a time block to get started." : "Keep this day open, or add a time block.")
                                    .foregroundStyle(.secondary)
                                Button("Add Time Block", action: add).controlSize(.large).padding(.top, 4)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: max(0, geometry.size.height - 48))
                        .padding(.vertical, 24)
                    }
                }
            } else {
                ScrollViewReader { scroll in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(selectedBlocks) { block in
                                HStack(spacing: 0) {
                                    if isPast {
                                        blockContent(block)
                                    } else {
                                        Button { edit(block) } label: {
                                            blockContent(block)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Edit \(block.name), \(block.timeRange)")
                                        .accessibilityIdentifier("daycue.edit.\(block.id)")
                                    }

                                    if !isPast {
                                        Button(role: .destructive) { delete(block) } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.secondary)
                                                .frame(width: 32, height: 32)
                                                .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        .padding(.trailing, 14)
                                        .help("Delete Time Block")
                                        .accessibilityLabel("Delete \(block.name)")
                                        .accessibilityIdentifier("daycue.delete.\(block.id)")
                                    }
                                }
                                .background(block.color.background, in: RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.primary.opacity(0.07)))
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                        .id("schedule-top")
                    }
                    .onChange(of: selectedDate) { _, _ in scroll.scrollTo("schedule-top", anchor: .top) }
                }
            }
            Spacer(minLength: 0)
            Divider()
            HStack {
                Image(systemName: "repeat")
                Text("Repeats weekly · Local time")
                Spacer()
                Text(isPast ? "Past schedule · Read only" : "Changes apply from today")
            }
            .font(.caption).foregroundStyle(.secondary).padding(.horizontal, 24).padding(.vertical, 12)
        }
        .frame(minWidth: 680, minHeight: 460)
        .accessibilityIdentifier("daycue.schedule")
    }

    private func blockContent(_ block: TimeBlock) -> some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 2).fill(block.color.tint).frame(width: 4)
            Text(block.timeRange)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.primary.opacity(0.75))
                .frame(width: 140, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                Text(block.name).font(.headline).lineLimit(2)
                Text(block.days.sorted().map(\.shortName).joined(separator: " · "))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 65)
        .contentShape(Rectangle())
    }
}

struct BlockEditorView: View {
    @ObservedObject var draft: BlockDraft
    var width: CGFloat = 560
    var maximumHeight: CGFloat = 720
    let save: () -> Void
    let cancel: () -> Void
    let delete: () -> Void
    @FocusState private var focusedField: Field?

    private enum Field: String {
        case name
    }

    private let inset: CGFloat = 20

    var body: some View {
        BlockEditorLayout(maximumHeight: maximumHeight) {
            VStack(spacing: 0) {
                ViewThatFits(in: .vertical) {
                    form.fixedSize(horizontal: false, vertical: true)
                    ScrollView { form }
                        .scrollBounceBehavior(.basedOnSize)
                }
                actions
                    .padding(.horizontal, inset)
                    .frame(height: 48)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .overlay(alignment: .top) { Divider() }
            }
        }
        .frame(width: width)
        .disabled(draft.isSaving)
        .onAppear { focusedField = .name }
        .accessibilityIdentifier("daycue.block-editor")
    }

    private var form: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(draft.original == nil ? "Add Time Block" : "Edit Time Block")
                .font(.title3.weight(.semibold))
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Name").font(.callout.weight(.semibold))
                    input("Time block name", text: $draft.name, field: .name)
                }
                VStack(alignment: .leading, spacing: 6) {
                    TimeRangeInputView(text: $draft.timeRange)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("Repeat On").font(.callout.weight(.semibold))
                HStack(spacing: width < 440 ? 4 : 6) {
                    ForEach(Weekday.allCases) { day in
                        Toggle(isOn: Binding(
                            get: { draft.days.contains(day) },
                            set: { if $0 { draft.days.insert(day) } else { draft.days.remove(day) } }
                        )) {
                            Text(day.shortName)
                                .font(width < 440 ? .caption.weight(.medium) : .callout.weight(.medium))
                                .lineLimit(1).minimumScaleFactor(0.85)
                                .frame(maxWidth: .infinity, minHeight: 24)
                        }
                        .toggleStyle(.button)
                        .controlSize(.small)
                        .accessibilityLabel(day.name)
                    }
                }
                Text("Changes apply from today to all repeat days. Past dates stay unchanged.")
                    .font(.caption2).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("Color").font(.callout.weight(.semibold))
                    Text(draft.color.name).font(.caption2).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 36, maximum: 36), spacing: 4)], alignment: .leading, spacing: 6) {
                    ForEach(BlockColor.allCases) { color in
                        colorSwatch(color)
                    }
                }
            }
            if let error = draft.error {
                Label(error, systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.red).font(.callout).fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("daycue.editor-error")
            }
        }
        .padding(inset)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actions: some View {
        HStack(spacing: 10) {
            if draft.original != nil {
                Button("Delete", role: .destructive, action: delete)
            }
            Spacer(minLength: 0)
            Button("Cancel", action: cancel)
                .buttonStyle(.bordered)
                .keyboardShortcut(.cancelAction)
            Button(draft.isSaving ? "Saving…" : "Save", action: save)
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: .systemBlue))
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("daycue.save-block")
        }
        .controlSize(.regular)
    }

    private func input(_ placeholder: String, text: Binding<String>, field: Field) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.plain)
            .focused($focusedField, equals: field)
            .padding(.horizontal, 12)
            .frame(height: 36)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8).strokeBorder(
                    focusedField == field ? Color(nsColor: .systemBlue) : Color.primary.opacity(0.15),
                    lineWidth: focusedField == field ? 2 : 1
                )
            }
            .accessibilityIdentifier("daycue.block-\(field.rawValue)")
    }

    private func colorSwatch(_ color: BlockColor) -> some View {
        Button { draft.color = color } label: {
            Circle()
                .fill(color.tint)
                .frame(width: 20, height: 20)
                .overlay {
                    if draft.color == color {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(color.selectionMark)
                    }
                }
                .padding(3)
                .overlay(Circle().strokeBorder(draft.color == color ? color.tint : .clear, lineWidth: 1.5))
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(color.name)
        .accessibilityLabel(color.name)
        .accessibilityValue(draft.color == color ? "Selected" : "Not selected")
        .accessibilityAddTraits(draft.color == color ? .isSelected : [])
        .accessibilityIdentifier("daycue.color.\(color.rawValue)")
    }
}

private struct BlockEditorLayout: Layout {
    let maximumHeight: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let size = subviews[0].sizeThatFits(ProposedViewSize(width: proposal.width, height: nil))
        return CGSize(width: size.width, height: min(size.height, maximumHeight))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews[0].place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
    }
}
