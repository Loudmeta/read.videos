import SwiftUI

struct RichTextEditor: View {
    @Binding var text: AttributedString
    @State private var selectedRange: NSRange?
    
    var body: some View {
        TextEditor(text: Binding(
            get: { text.description },
            set: { text = AttributedString($0) }
        ))
        .font(.body)
        .onChange(of: text) { oldValue, newValue in
            // Update selectedRange when text changes
            if let range = selectedRange,
               let stringRange = Range(range, in: newValue.description) {
                selectedRange = NSRange(stringRange, in: newValue.description)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: { applyStyle(.bold) }) {
                    Image(systemName: "bold")
                }
                Button(action: { applyStyle(.italic) }) {
                    Image(systemName: "italic")
                }
                Button(action: { applyStyle(.underline) }) {
                    Image(systemName: "underline")
                }
                Spacer()
                Button(action: { applyColor(.red) }) {
                    Image(systemName: "circle.fill").foregroundColor(.red)
                }
                Button(action: { applyColor(.blue) }) {
                    Image(systemName: "circle.fill").foregroundColor(.blue)
                }
                Button(action: { applyColor(.green) }) {
                    Image(systemName: "circle.fill").foregroundColor(.green)
                }
            }
        }
    }
    
    private func applyStyle(_ style: TextStyle) {
        guard let range = selectedRange,
              let attributedRange = Range(range, in: text) else { return }
        var newText = text
        
        switch style {
        case .bold:
            newText[attributedRange].inlinePresentationIntent = .stronglyEmphasized
        case .italic:
            newText[attributedRange].inlinePresentationIntent = .emphasized
        case .underline:
            newText[attributedRange].underlineStyle = .single
        }
        
        text = newText
    }
    
    private func applyColor(_ color: Color) {
        guard let range = selectedRange,
              let attributedRange = Range(range, in: text) else { return }
        var newText = text
        
        newText[attributedRange].foregroundColor = color
        text = newText
    }
}

enum TextStyle {
    case bold, italic, underline
}

struct RichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        RichTextEditor(text: .constant(AttributedString("Sample text")))
    }
}