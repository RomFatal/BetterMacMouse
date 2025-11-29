//
//  ButtonCore.swift
//  Mos
//  鼠标按钮事件截取与处理核心类
//  Created by Claude on 2025/8/10.
//  Copyright © 2025年 Caldis. All rights reserved.
//

import Cocoa

class ButtonCore {

    // 单例
    static let shared = ButtonCore()
    init() { NSLog("Module initialized: ButtonCore") }

    // 执行状态
    var isActive = false

    // 拦截层
    var eventInterceptor: Interceptor?

    // 组合的按钮事件掩码
    let leftDown = CGEventMask(1 << CGEventType.leftMouseDown.rawValue)
    let rightDown = CGEventMask(1 << CGEventType.rightMouseDown.rawValue)
    let otherDown = CGEventMask(1 << CGEventType.otherMouseDown.rawValue)
    let otherUp = CGEventMask(1 << CGEventType.otherMouseUp.rawValue)
    let otherDragged = CGEventMask(1 << CGEventType.otherMouseDragged.rawValue)
    let mouseMoved = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
    let keyDown = CGEventMask(1 << CGEventType.keyDown.rawValue)
    let flagsChanged = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    var eventMask: CGEventMask {
        return leftDown | rightDown | otherDown | otherUp | otherDragged | mouseMoved | keyDown
    }

    // MARK: - 按钮事件处理
    let buttonEventCallBack: CGEventTapCallBack = { (proxy, type, event, refcon) in
        NSLog("[ButtonCore] ⚡️ EVENT: type=\(type.rawValue)")

        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let cgLocation = event.location

        // 转换CGEvent坐标到NSScreen坐标
        // CGEvent: Y=0在屏幕顶部，向下递增
        // NSScreen: Y=0在主屏幕底部，向上递增
        func convertToScreenCoordinates(_ cgPoint: CGPoint) -> CGPoint {
            // CGEvent uses Quartz coordinates: Y=0 at TOP of primary screen, Y increases DOWNWARD
            // NSEvent uses Cocoa coordinates: Y=0 at BOTTOM of primary screen, Y increases UPWARD
            // NSScreen.screens also uses Cocoa coordinates

            // The global coordinate space origin (0,0) is at the top-left of the primary display in Quartz
            // In Cocoa, (0,0) is at the bottom-left of the primary display

            // Strategy: Find which screen contains this point in Quartz coords,
            // then convert to Cocoa coords accounting for that screen's position

            // CRITICAL: Use screens.first (primary display) not .main (focused screen)
            // .main changes based on which screen has focus, causing wrong height
            guard let primaryScreen = NSScreen.screens.first else { return cgPoint }
            let primaryScreenHeight = primaryScreen.frame.height

            // Find the screen that contains this point
            // We need to convert each screen's Cocoa frame to Quartz for comparison
            var targetScreen: NSScreen?
            for screen in NSScreen.screens {
                // Convert screen's Cocoa frame to Quartz coordinates
                let cocoaFrame = screen.frame
                // In Quartz: Y = primaryScreenHeight - (cocoaY + height)
                let quartzY = primaryScreenHeight - (cocoaFrame.origin.y + cocoaFrame.height)
                let quartzFrame = CGRect(
                    x: cocoaFrame.origin.x,
                    y: quartzY,
                    width: cocoaFrame.width,
                    height: cocoaFrame.height
                )

                if quartzFrame.contains(cgPoint) {
                    targetScreen = screen
                    break
                }
            }

            // Use primary screen as fallback
            let screen = targetScreen ?? primaryScreen
            let screenFrame = screen.frame

            // Convert point from Quartz to Cocoa relative to the target screen
            // The screen's top edge in Quartz is: primaryScreenHeight - (screenFrame.origin.y + screenFrame.height)
            // The point's offset from the screen's top in Quartz is: cgPoint.y - quartzTopEdge
            // In Cocoa, this becomes: (screenFrame.origin.y + screenFrame.height) - offsetFromTop
            let quartzTopEdge = primaryScreenHeight - (screenFrame.origin.y + screenFrame.height)
            let offsetFromTop = cgPoint.y - quartzTopEdge
            let cocoaY = (screenFrame.origin.y + screenFrame.height) - offsetFromTop

            return CGPoint(x: cgPoint.x, y: cocoaY)
        }

        let location = convertToScreenCoordinates(cgLocation)

        // DEBUG: Log every middle button event to file
        if buttonNumber == 2 {
            let mainScreenHeight = NSScreen.main?.frame.height ?? 0
            var log = "[\(Date())] Middle button: type=\(type.rawValue), btn=\(buttonNumber), activationBtn=\(Options.shared.autoScroll.activationButton), isEnabled=\(AutoScrollCore.shared.isEnabled)\n"
            log += "  Main screen height: \(mainScreenHeight)\n"
            log += "  CGEvent location (Quartz): (\(cgLocation.x), \(cgLocation.y))\n"
            log += "  Converted location (Cocoa): (\(location.x), \(location.y))\n"
            log += "  NSEvent.mouseLocation NOW: \(NSEvent.mouseLocation)\n"

            if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                fileHandle.seekToEndOfFile()
                if let data = log.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            } else {
                try? log.write(toFile: "/tmp/mos_button_debug.txt", atomically: false, encoding: .utf8)
            }

            NSLog("[ButtonCore] Middle button event: type=\(type.rawValue), btn=\(buttonNumber), location=\(location)")
        }

        // 处理自动滚动相关事件
        if buttonNumber == Options.shared.autoScroll.activationButton {
            let matchLog = "Button matches activationButton (\(Options.shared.autoScroll.activationButton))\n"
            if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                fileHandle.seekToEndOfFile()
                if let data = matchLog.data(using: .utf8) {
                    fileHandle.write(data)
                }
                fileHandle.closeFile()
            }

            switch type {
            case .otherMouseDown:
                let downLog = "  -> otherMouseDown - checking browserInfo...\n"
                if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                    fileHandle.seekToEndOfFile()
                    if let data = downLog.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }

                // CRITICAL: Check IMMEDIATELY if in blocked area BEFORE any other processing
                // This ensures we can consume the event before Chrome sees it
                let browserInfo = AutoScrollCore.shared.getBrowserWindowInfo(at: location)

                let infoLog = "  -> browserInfo: isUI=\(browserInfo.isInUIArea), name=\(browserInfo.name ?? "nil")\n"
                if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                    fileHandle.seekToEndOfFile()
                    if let data = infoLog.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }

                if browserInfo.isInUIArea {
                    // In blocked area - consume event immediately WITHOUT calling handleMiddleButtonDown
                    NSLog("[ButtonCore] DOWN in blocked area - consuming immediately")
                    let blockLog = "  -> BLOCKED - returning nil\n\n"
                    if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                        fileHandle.seekToEndOfFile()
                        if let data = blockLog.data(using: .utf8) {
                            fileHandle.write(data)
                        }
                        fileHandle.closeFile()
                    }
                    return nil
                }

                let proceedLog = "  -> NOT blocked - calling handleMiddleButtonDown\n"
                if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                    fileHandle.seekToEndOfFile()
                    if let data = proceedLog.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }

                // Not in blocked area - proceed normally
                let shouldConsume = AutoScrollCore.shared.handleMiddleButtonDown(at: location)

                let consumeLog = "  -> shouldConsume=\(shouldConsume), isActive=\(AutoScrollCore.shared.isActive)\n\n"
                if let fileHandle = FileHandle(forWritingAtPath: "/tmp/mos_button_debug.txt") {
                    fileHandle.seekToEndOfFile()
                    if let data = consumeLog.data(using: .utf8) {
                        fileHandle.write(data)
                    }
                    fileHandle.closeFile()
                }

                if shouldConsume || AutoScrollCore.shared.isActive {
                    return nil  // Consume event to prevent Chrome's auto-scroll
                }
            case .otherMouseUp:
                // If auto-scroll handled the event (activated OR blocked), consume it
                let wasHandled = AutoScrollCore.shared.handleMiddleButtonUp(at: location)
                if wasHandled || AutoScrollCore.shared.isActive {
                    return nil  // Consume event
                }
            default:
                break
            }
        }

        // 处理鼠标移动（用于拖动检测）
        if type == .mouseMoved {
            AutoScrollCore.shared.handleMouseMove(to: location)
            return Unmanaged.passUnretained(event)
        }

        // 任何鼠标点击都会停止自动滚动
        if AutoScrollCore.shared.isActive {
            if type == .leftMouseDown || type == .rightMouseDown {
                AutoScrollCore.shared.stopAutoScroll()
            }
        }

        // 获取当前应用的按钮绑定配置
        let bindings = ButtonUtils.shared.getButtonBindings()

        // 查找匹配的绑定
        guard let binding = bindings.first(where: {
            $0.triggerEvent.matches(event) && $0.isEnabled
        }) else {
            return Unmanaged.passUnretained(event)
        }

        // 执行绑定的系统快捷键
        ShortcutExecutor.shared.execute(named: binding.systemShortcutName)

        // 消费事件(不再传递给系统)
        return nil
    }

    // MARK: - 启用和禁用

    // 启用按钮监控
    func enable() {
        if !isActive {
            NSLog("ButtonCore enabled")
            try? "ButtonCore enabled at \(Date())\n".write(toFile: "/tmp/mos_buttoncore_enabled.txt", atomically: false, encoding: .utf8)
            do {
                eventInterceptor = try Interceptor(
                    event: eventMask,
                    handleBy: buttonEventCallBack,
                    listenOn: .cgAnnotatedSessionEventTap,
                    placeAt: .headInsertEventTap,  // Changed to HEAD to intercept BEFORE apps see events
                    for: .defaultTap
                )
                isActive = true
                try? "Interceptor created successfully\n".write(toFile: "/tmp/mos_buttoncore_enabled.txt", atomically: true, encoding: .utf8)

                // Check if interceptor is actually running
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    let isRunning = ButtonCore.shared.eventInterceptor?.isRunning() ?? false
                    NSLog("[ButtonCore] Interceptor running status: \(isRunning)")
                    try? "Interceptor running: \(isRunning)\n".write(toFile: "/tmp/mos_buttoncore_status.txt", atomically: false, encoding: .utf8)
                }
            } catch {
                NSLog("ButtonCore: Failed to create interceptor: \(error)")
                try? "ERROR: Failed to create interceptor: \(error)\n".write(toFile: "/tmp/mos_buttoncore_error.txt", atomically: false, encoding: .utf8)
            }
        }
    }

    // 禁用按钮监控
    func disable() {
        if isActive {
            NSLog("ButtonCore disabled")
            eventInterceptor?.stop()
            eventInterceptor = nil
            isActive = false
        }
    }

    // 切换状态
    func toggle() {
        isActive ? disable() : enable()
    }
}
