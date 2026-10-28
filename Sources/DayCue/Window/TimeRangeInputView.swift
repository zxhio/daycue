import AppKit
import SwiftUI

struct TimeRangeInputView: View {
    @Binding var text: String
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time").font(.callout.weight(.semibold))
            Button {
                showingPicker = true
            } label: {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8).strokeBorder(
                            showingPicker ? Color(nsColor: .systemBlue) : Color.primary.opacity(0.15),
                            lineWidth: showingPicker ? 2 : 1
                        )
                    }
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit start and end times")
            .accessibilityLabel("Edit time range, \(text)")
            .accessibilityIdentifier("daycue.block-time")
        }
        .popover(isPresented: $showingPicker, arrowEdge: .bottom) {
            TimeRangePicker(text: $text) { showingPicker = false }
                .onExitCommand { showingPicker = false }
        }
    }
}

private struct TimeRangePicker: View {
    @Binding var text: String
    let done: () -> Void
    @State private var startHour: Int
    @State private var startMinute: Int
    @State private var endHour: Int
    @State private var endMinute: Int

    init(text: Binding<String>, done: @escaping () -> Void) {
        _text = text
        self.done = done
        let range = MinuteRange.parse(text.wrappedValue) ?? MinuteRange(start: 540, end: 600)
        _startHour = State(initialValue: range.start / 60)
        _startMinute = State(initialValue: range.start % 60)
        _endHour = State(initialValue: range.end / 60)
        _endMinute = State(initialValue: range.end % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Time").font(.headline)
            HStack(alignment: .top, spacing: 24) {
                VStack(spacing: 8) {
                    Text("Start Time").font(.callout.weight(.medium))
                    HStack(spacing: 2) {
                        TimeWheel(value: $startHour, values: Array(0...23), title: "Start hour")
                        Text(":").font(.system(size: 24, weight: .medium))
                        TimeWheel(value: $startMinute, values: Array(0...59), title: "Start minute")
                    }
                }
                VStack(spacing: 8) {
                    Text("End Time").font(.callout.weight(.medium))
                    HStack(spacing: 2) {
                        TimeWheel(value: $endHour, values: Array(0...24), title: "End hour")
                        Text(":").font(.system(size: 24, weight: .medium))
                        TimeWheel(value: $endMinute, values: endHour == 24 ? [0] : Array(0...59), title: "End minute")
                    }
                }
            }
            if endHour == 24 {
                Text("24:00 is the end of the day.").font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button("Done") {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    DispatchQueue.main.async { done() }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .onChange(of: startHour) { _, _ in updateRange() }
        .onChange(of: startMinute) { _, _ in updateRange() }
        .onChange(of: endHour) { _, _ in
            if endHour == 24 { endMinute = 0 }
            updateRange()
        }
        .onChange(of: endMinute) { _, _ in updateRange() }
    }

    private func updateRange() {
        text = MinuteRange(start: startHour * 60 + startMinute, end: endHour * 60 + (endHour == 24 ? 0 : endMinute)).text
    }
}

private struct TimeWheel: NSViewRepresentable {
    @Binding var value: Int
    let values: [Int]
    let title: String

    func makeNSView(context: Context) -> TimeWheelView {
        let view = TimeWheelView()
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.incrementor)
        return view
    }

    func updateNSView(_ view: TimeWheelView, context: Context) {
        view.configure(value: value, values: values)
        view.select = { value = $0 }
        view.setAccessibilityLabel(title)
        view.setInputLabel(title)
        view.setAccessibilityValue(String(format: "%02d", value))
        view.needsDisplay = true
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: TimeWheelView, context: Context) -> CGSize? {
        CGSize(width: 56, height: 120)
    }
}

private final class TimeWheelView: NSView, NSTextFieldDelegate {
    var value = 0
    var values: [Int] = []
    var select: ((Int) -> Void)?
    private let input = TimeWheelField()
    private var editing = false
    private var accumulatedScroll: CGFloat = 0
    private var dragY: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        input.isBordered = false
        input.drawsBackground = false
        input.focusRingType = .none
        input.alignment = .center
        input.font = NSFont.monospacedDigitSystemFont(ofSize: 26, weight: .semibold)
        input.delegate = self
        input.target = self
        input.action = #selector(finishInput)
        addSubview(input)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        input.frame = NSRect(x: 0, y: bounds.midY - 17, width: bounds.width, height: 34)
    }

    func configure(value: Int, values: [Int]) {
        let changed = self.value != value || self.values != values
        self.value = value
        self.values = values
        input.isEditable = values.count > 1
        if !editing || changed {
            input.stringValue = String(format: "%02d", value)
            input.textColor = .labelColor
        }
    }

    func setInputLabel(_ title: String) { input.setAccessibilityLabel(title) }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 56, height: 120) }

    override func draw(_ dirtyRect: NSRect) {
        guard let index = values.firstIndex(of: value) else { return }
        for offset in [-1, 1] {
            let row = index + offset
            guard values.indices.contains(row) else { continue }
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 20, weight: .regular),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let text = NSAttributedString(string: String(format: "%02d", values[row]), attributes: attributes)
            let size = text.size()
            text.draw(at: NSPoint(x: (bounds.width - size.width) / 2, y: bounds.midY + CGFloat(offset) * 40 - size.height / 2))
        }
        if window?.firstResponder === self || editing {
            NSColor.keyboardFocusIndicatorColor.setStroke()
            let ring = NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 40), xRadius: 6, yRadius: 6)
            ring.lineWidth = 2
            ring.stroke()
        }
    }

    override func scrollWheel(with event: NSEvent) {
        if editing { window?.makeFirstResponder(self) }
        if event.phase == .began { accumulatedScroll = 0 }
        accumulatedScroll += event.scrollingDeltaY * (event.hasPreciseScrollingDeltas ? 1 : 12)
        let steps = Int(accumulatedScroll / 24)
        if steps != 0 {
            accumulatedScroll -= CGFloat(steps) * 24
            move(by: -steps)
        }
        if event.phase == .ended || event.phase == .cancelled { accumulatedScroll = 0 }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragY = convert(event.locationInWindow, from: nil).y
        if abs(dragY - bounds.midY) <= 20 {
            beginInput()
        } else if dragY < bounds.midY - 20 { move(by: -1) }
        else if dragY > bounds.midY + 20 { move(by: 1) }
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        let y = convert(event.locationInWindow, from: nil).y
        let steps = Int((dragY - y) / 24)
        if steps != 0 {
            dragY -= CGFloat(steps) * 24
            move(by: steps)
        }
    }

    override func keyDown(with event: NSEvent) {
        switch event.keyCode {
        case 126: move(by: -1)
        case 125: move(by: 1)
        case 36, 76: beginInput()
        default: super.keyDown(with: event)
        }
    }

    override func becomeFirstResponder() -> Bool { needsDisplay = true; return true }
    override func resignFirstResponder() -> Bool { needsDisplay = true; return true }

    func controlTextDidBeginEditing(_ notification: Notification) {
        editing = true
        needsDisplay = true
    }

    func controlTextDidChange(_ notification: Notification) {
        let text = input.stringValue
        let valid = (1...2).contains(text.count) && text.allSatisfy { $0.isASCII && $0.isNumber }
            && Int(text).map { values.contains($0) } == true
        input.textColor = valid ? .labelColor : .systemRed
        if text.count == 2, commitInput() {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.editing else { return }
                self.advanceInput()
            }
        }
    }

    func controlTextDidEndEditing(_ notification: Notification) {
        _ = commitInput()
        editing = false
        input.stringValue = String(format: "%02d", value)
        input.textColor = .labelColor
        needsDisplay = true
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        if commandSelector == #selector(NSResponder.insertNewline(_:)) {
            finishInput()
            return true
        }
        if commandSelector == #selector(NSResponder.moveUp(_:)) || commandSelector == #selector(NSResponder.moveDown(_:)) {
            _ = commitInput()
            move(by: commandSelector == #selector(NSResponder.moveUp(_:)) ? -1 : 1)
            input.selectText(nil)
            return true
        }
        return false
    }

    private func beginInput() {
        guard input.isEditable else { return }
        window?.makeFirstResponder(input)
        input.selectText(nil)
    }

    @objc private func finishInput() {
        if commitInput() { advanceInput() }
        else { input.selectText(nil) }
    }

    private func commitInput() -> Bool {
        let text = input.stringValue
        guard (1...2).contains(text.count), text.allSatisfy({ $0.isASCII && $0.isNumber }),
              let number = Int(text), values.contains(number) else { return false }
        value = number
        input.textColor = .labelColor
        setAccessibilityValue(String(format: "%02d", number))
        select?(number)
        needsDisplay = true
        return true
    }

    private func advanceInput() {
        guard let content = window?.contentView else { return }
        func wheels(in view: NSView) -> [TimeWheelView] {
            if let wheel = view as? TimeWheelView { return [wheel] }
            return view.subviews.flatMap { wheels(in: $0) }
        }
        let columns = wheels(in: content)
        guard let index = columns.firstIndex(where: { $0 === self }) else { return }
        if let next = columns.dropFirst(index + 1).first(where: { $0.input.isEditable }) {
            next.beginInput()
        } else {
            window?.makeFirstResponder(self)
        }
    }

    override func accessibilityPerformIncrement() -> Bool { move(by: 1); return true }
    override func accessibilityPerformDecrement() -> Bool { move(by: -1); return true }

    private func move(by steps: Int) {
        guard let index = values.firstIndex(of: value) else { return }
        let updated = values[max(0, min(index + steps, values.count - 1))]
        guard updated != value else { return }
        value = updated
        input.stringValue = String(format: "%02d", updated)
        setAccessibilityValue(String(format: "%02d", updated))
        select?(updated)
        needsDisplay = true
    }
}

private final class TimeWheelField: NSTextField {
    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        selectText(nil)
    }

    override func scrollWheel(with event: NSEvent) {
        superview?.scrollWheel(with: event)
    }
}
