import SwiftUI
import WebKit

struct HTMLPreviewView: View {
    let htmlContent: String
    
    var body: some View {
        #if os(macOS)
        NSHTMLWebView(htmlContent: htmlContent)
        #else
        UIHTMLWebView(htmlContent: htmlContent)
        #endif
    }
}

#if os(macOS)
struct NSHTMLWebView: NSViewRepresentable {
    let htmlContent: String
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String = ""
        
        // Delegado para interceptar clicks en enlaces y abrirlos en el sistema
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let scheme = url.scheme?.lowercased()
                if scheme == "mailto" || scheme == "http" || scheme == "https" {
                    // Abrir en Mail.app o Safari del Mac
                    NSWorkspace.shared.open(url)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        webView.navigationDelegate = context.coordinator
        // Asegurar que la vista web se redimensione con su contenedor SwiftUI
        webView.autoresizingMask = [.width, .height]
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        nsView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
#else
struct UIHTMLWebView: UIViewRepresentable {
    let htmlContent: String
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var lastLoadedHTML: String = ""
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if let url = navigationAction.request.url {
                let scheme = url.scheme?.lowercased()
                if scheme == "mailto" || scheme == "http" || scheme == "https" {
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        uiView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
#endif
