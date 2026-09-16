import Cocoa
import SwiftUI

@available(macOS 15.0, *)
public class FloatingSubtitlesPanel: NSPanel {
    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .resizable, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        // Window behaviors for video call overlay
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = true
        self.isMovableByWindowBackground = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        
        // Position at bottom center of main screen by default
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - (contentRect.width / 2)
            let y = screenFrame.minY + 60 // 60px above dock
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }
    
    public func setClickThrough(_ enabled: Bool) {
        self.ignoresMouseEvents = enabled
    }
}
