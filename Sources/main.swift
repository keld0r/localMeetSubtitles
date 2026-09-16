import Cocoa
import SwiftUI

@available(macOS 15.0, *)
class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: FloatingSubtitlesPanel?
    var statusItem: NSStatusItem?
    var coordinator: SubtitleCoordinator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // App policy: accessory app (shows in menu bar & overlay, does not take over dock unless needed)
        NSApp.setActivationPolicy(.accessory)
        
        let coordinator = SubtitleCoordinator()
        self.coordinator = coordinator
        
        let initialRect = NSRect(x: 0, y: 0, width: 680, height: 130)
        let panel = FloatingSubtitlesPanel(contentRect: initialRect)
        self.panel = panel
        
        let contentView = ContentView(coordinator: coordinator) { [weak panel] isClickThrough in
            panel?.setClickThrough(isClickThrough)
        }
        
        panel.contentView = NSHostingView(rootView: contentView)
        panel.makeKeyAndOrderFront(nil)
        
        setupStatusMenu()
        setupGlobalShortcut()
        
        print("✓ LocalMeetSubtitles iniciado exitosamente.")
        print("  - Overlay flotante activo en pantalla.")
        print("  - Ícono en la barra de menús activo.")
        print("  - Atajo Cmd+Shift+K para alternar modo Click-Through.")
    }
    
    private func setupStatusMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = "💬"
            button.toolTip = "Subtítulos en Tiempo Real (100% Local)"
        }
        
        let menu = NSMenu()
        
        menu.addItem(NSMenuItem(title: "Alternar Escucha (Pausar/Reanudar)", action: #selector(toggleListening), keyEquivalent: "p"))
        menu.addItem(NSMenuItem(title: "Alternar Modo Click-Through (Cmd+Shift+K)", action: #selector(toggleClickThrough), keyEquivalent: "k"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Fuente: Audio de Google Meet", action: #selector(setSourceSystem), keyEquivalent: "1"))
        menu.addItem(NSMenuItem(title: "Fuente: Micrófono", action: #selector(setSourceMic), keyEquivalent: "2"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Mostrar/Ocultar Ventana", action: #selector(toggleWindow), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Limpiar Subtítulos", action: #selector(clearSubtitles), keyEquivalent: "c"))
        menu.addItem(NSMenuItem.separator())
        
        menu.addItem(NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem?.menu = menu
    }
    
    private func setupGlobalShortcut() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            // Check for Cmd + Shift + K
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 40 { // 'k'
                self?.toggleClickThrough()
                return nil
            }
            return event
        }
    }
    
    @objc func toggleListening() {
        coordinator?.toggleListening()
    }
    
    @objc func toggleClickThrough() {
        guard let coordinator = coordinator, let panel = panel else { return }
        coordinator.isClickThrough.toggle()
        panel.setClickThrough(coordinator.isClickThrough)
    }
    
    @objc func setSourceSystem() {
        coordinator?.setAudioSource(.systemAudio)
    }
    
    @objc func setSourceMic() {
        coordinator?.setAudioSource(.microphone)
    }
    
    @objc func toggleWindow() {
        guard let panel = panel else { return }
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            panel.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc func clearSubtitles() {
        coordinator?.clearSubtitles()
    }
}

// Entry Point
if #available(macOS 15.0, *) {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.run()
} else {
    print("Error: Requiere macOS 15 o superior para el soporte nativo de Translation.")
    exit(1)
}
