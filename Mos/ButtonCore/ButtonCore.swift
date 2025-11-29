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
    let mouseMoved = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
    let keyDown = CGEventMask(1 << CGEventType.keyDown.rawValue)
    let flagsChanged = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    var eventMask: CGEventMask {
        return leftDown | rightDown | otherDown | otherUp | mouseMoved | keyDown
    }

    // MARK: - 按钮事件处理
    let buttonEventCallBack: CGEventTapCallBack = { (proxy, type, event, refcon) in
        let buttonNumber = event.getIntegerValueField(.mouseEventButtonNumber)
        let location = event.location

        // 处理自动滚动相关事件
        if buttonNumber == Options.shared.autoScroll.activationButton {
            switch type {
            case .otherMouseDown:
                AutoScrollCore.shared.handleMiddleButtonDown(at: location)
                // 如果自动滚动已激活，消费事件以防止触发其他操作
                if AutoScrollCore.shared.isActive {
                    return nil
                }
            case .otherMouseUp:
                AutoScrollCore.shared.handleMiddleButtonUp(at: location)
                // 如果自动滚动已激活或刚激活，消费事件
                if AutoScrollCore.shared.isActive {
                    return nil
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
            do {
                eventInterceptor = try Interceptor(
                    event: eventMask,
                    handleBy: buttonEventCallBack,
                    listenOn: .cgAnnotatedSessionEventTap,
                    placeAt: .tailAppendEventTap,
                    for: .defaultTap
                )
                isActive = true
            } catch {
                NSLog("ButtonCore: Failed to create interceptor: \(error)")
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
