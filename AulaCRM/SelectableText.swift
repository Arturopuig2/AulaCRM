//ESTRUCTURA PARA SELECCIONAR Y COPIAR

import SwiftUI
#if os(macOS)
import AppKit

struct SelectableText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isSelectable = true
        lineBreak(label)
        return label
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        nsView.stringValue = text
        lineBreak(nsView)
    }
    
    private func lineBreak(_ label: NSTextField) {
        label.usesSingleLineMode = true
        label.lineBreakMode = .byTruncatingTail
    }
}
#else
struct SelectableText: View {
    let text: String
    
    var body: some View {
        Text(text)
            .textSelection(.enabled)
    }
}
#endif
