//ESTRUCTURA PARA SELECCIONAR Y COPIAR

import SwiftUI
import AppKit   // importante para NSTextField

struct SelectableText: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> NSTextField {
        // label con comportamiento de solo lectura
        let label = NSTextField(labelWithString: text)
        label.isEditable = false
        label.isBezeled = false
        label.drawsBackground = false
        label.isSelectable = true   // <-- CLAVE: se puede seleccionar y copiar
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
