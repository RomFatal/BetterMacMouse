//
//  AutoScrollCore.swift
//  Mos
//  自动滚动核心类 - 中键点击激活自动滚动
//  Created by Auto-Scroll Implementation on 2025/11/29.
//  Copyright © 2025年 Caldis. All rights reserved.
//

import Cocoa

class AutoScrollCore {

    // 单例
    static let shared = AutoScrollCore()
    init() { NSLog("Module initialized: AutoScrollCore") }

    // MARK: - 状态管理

    // 自动滚动激活状态
    var isActive = false

    // 中键按下检测状态
    var middleButtonPressed = false
    var pressLocation: CGPoint?
    var pressTime: Date?

    // 滚动原点和当前点
    var originPoint: CGPoint?
    var currentPoint: CGPoint?

    // 计时器
    var scrollTimer: Timer?

    // 覆盖窗口（显示固定图标）
    var overlay: AutoScrollOverlay?

    // MARK: - 设置（独立于常规滚动设置）

    // 灵敏度（0.2x - 3.0x）
    var sensitivity: Double {
        get { Options.shared.autoScroll.sensitivity }
        set { Options.shared.autoScroll.sensitivity = newValue }
    }

    // 死区大小（像素）- 在此范围内不滚动
    var deadZone: CGFloat {
        get { Options.shared.autoScroll.deadZone }
    }

    // 拖动阈值（像素）- 超过此距离视为拖动而非点击
    var dragThreshold: CGFloat {
        get { Options.shared.autoScroll.dragThreshold }
    }

    // 最大滚动速度
    var maxSpeed: CGFloat {
        get { Options.shared.autoScroll.maxSpeed }
    }

    // 是否启用
    var isEnabled: Bool {
        get { Options.shared.autoScroll.enabled }
    }

    // MARK: - 事件处理

    /// 处理中键按下事件
    func handleMiddleButtonDown(at point: CGPoint) {
        guard isEnabled else { return }

        middleButtonPressed = true
        pressLocation = point
        pressTime = Date()

        NSLog("[AutoScroll] Middle button pressed at (\(point.x), \(point.y))")
    }

    /// 处理鼠标移动事件（用于拖动检测）
    func handleMouseMove(to point: CGPoint) {
        guard middleButtonPressed, let pressLoc = pressLocation else { return }

        // 计算移动距离
        let dx = point.x - pressLoc.x
        let dy = point.y - pressLoc.y
        let distance = sqrt(dx * dx + dy * dy)

        // 如果移动距离超过阈值，则标记为拖动操作
        if distance > dragThreshold {
            NSLog("[AutoScroll] Drag detected (distance: \(distance)px), canceling auto-scroll")
            middleButtonPressed = false
            pressLocation = nil
        }
    }

    /// 处理中键释放事件
    func handleMiddleButtonUp(at point: CGPoint) {
        guard isEnabled else { return }
        guard middleButtonPressed, let pressLoc = pressLocation else { return }

        // 计算点击期间的移动距离
        let dx = point.x - pressLoc.x
        let dy = point.y - pressLoc.y
        let distance = sqrt(dx * dx + dy * dy)

        if distance <= dragThreshold {
            // 是点击而非拖动 - 切换自动滚动状态
            if isActive {
                NSLog("[AutoScroll] Stopping auto-scroll")
                stopAutoScroll()
            } else {
                NSLog("[AutoScroll] ========== MIDDLE BUTTON CLICK at (\(point.x), \(point.y)) ==========")
                
                // 检查是否应该激活自动滚动
                if shouldActivateAutoScroll(at: point) {
                    NSLog("[AutoScroll] ✅ Starting auto-scroll")
                    startAutoScroll(at: point)
                } else {
                    NSLog("[AutoScroll] ❌ Auto-scroll blocked - not in scrollable area or in browser UI")
                }
            }
        } else {
            NSLog("[AutoScroll] Button release after drag (distance: \(distance)px), no action")
        }

        middleButtonPressed = false
        pressLocation = nil
        pressTime = nil
    }
    
    // MARK: - Scrollable Area Detection
    
    /// 检查是否应该在给定位置激活自动滚动
    func shouldActivateAutoScroll(at point: CGPoint) -> Bool {
        // 检查是否在浏览器UI区域（书签栏、标签栏等）
        if isInBrowserUIArea(at: point) {
            return false
        }
        
        // 检查是否有可滚动内容
        return hasScrollableContent(at: point)
    }
    
    /// 检查点击位置是否在浏览器UI区域（书签栏、标签栏、地址栏）
    func isInBrowserUIArea(at point: CGPoint) -> Bool {
        let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]]
        
        guard let windows = windowList else { return false }
        
        // 找到点击位置的窗口
        for window in windows {
            guard let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"],
                  let width = bounds["Width"], let height = bounds["Height"],
                  point.x >= x && point.x <= x + width &&
                  point.y >= y && point.y <= y + height else {
                continue
            }
            
            // 检查是否是浏览器窗口
            if let ownerName = window[kCGWindowOwnerName as String] as? String,
               (ownerName.contains("Chrome") || ownerName.contains("Chromium") || 
                ownerName.contains("Safari") || ownerName.contains("Firefox") || 
                ownerName.contains("Edge") || ownerName.contains("Brave") || 
                ownerName.contains("Opera") || ownerName.contains("Arc")) {
                
                let relativeY = point.y - y
                
                NSLog("[AutoScroll] Browser: \(ownerName), Relative Y: \(relativeY)px")
                
                // 浏览器UI区域：
                // - 标签栏: 0-40px
                // - 地址栏: 40-90px
                // - 书签栏（如果显示）: 90-125px
                // - 扩展图标区域: 可能延伸到140px
                // 使用动态计算：顶部300px或窗口高度的25%（取较小值）
                let uiHeight = min(300.0, height * 0.25)
                
                if relativeY < uiHeight {
                    NSLog("[AutoScroll] ❌ In browser UI area (top \(relativeY)px < \(uiHeight)px)")
                    return true
                }
                
                // 也检查底部区域（状态栏、下载栏）
                if relativeY > height - 50 {
                    NSLog("[AutoScroll] ❌ In browser bottom UI area")
                    return true
                }
            }
            
            break
        }
        
        return false
    }
    
    /// 检查点击位置是否有可滚动内容
    func hasScrollableContent(at point: CGPoint) -> Bool {
        // 转换为macOS坐标系（Y轴从下往上）
        guard let screen = NSScreen.main else {
            NSLog("[AutoScroll] ⚠️ Cannot get main screen")
            return false
        }
        
        let screenHeight = screen.frame.height
        let axPoint = CGPoint(x: point.x, y: screenHeight - point.y)
        
        // 获取点击位置的可访问性元素
        guard let element = getElementAtPoint(axPoint) else {
            NSLog("[AutoScroll] ⚠️ No accessibility element at point")
            return false
        }
        
        // 检查元素及其父元素链
        var current: AXUIElement? = element
        var depth = 0
        let maxDepth = 15
        
        while let elem = current, depth < maxDepth {
            let role = getRole(of: elem)
            let hasScrollBars = hasScrollBars(elem)
            
            NSLog("[AutoScroll] Level \(depth): Role=\(role ?? "nil"), HasScrollBars=\(hasScrollBars)")
            
            // 检查是否是可滚动的元素类型
            if let r = role {
                // Web内容区域
                if r == kAXScrollAreaRole as String || 
                   r == "AXWebArea" || 
                   r == kAXTextAreaRole as String ||
                   r == "AXGroup" && hasScrollBars {
                    NSLog("[AutoScroll] ✅ Found scrollable element: \(r)")
                    return true
                }
                
                // 明确的非滚动UI元素
                if r == kAXButtonRole as String ||
                   r == kAXToolbarRole as String ||
                   r == "AXTabGroup" ||
                   r == kAXRadioButtonRole as String ||
                   r == "AXLink" ||
                   r == kAXImageRole as String ||
                   r == kAXMenuRole as String ||
                   r == "AXTextField" {
                    NSLog("[AutoScroll] ❌ Found UI element (non-scrollable): \(r)")
                    return false
                }
            }
            
            // 尝试获取父元素
            current = getParentElement(of: elem)
            depth += 1
        }
        
        NSLog("[AutoScroll] ⚠️ No scrollable content found after checking \(depth) levels")
        return false
    }
    
    // MARK: - Accessibility Helpers
    
    /// 获取指定点的可访问性元素
    func getElementAtPoint(_ point: CGPoint) -> AXUIElement? {
        let systemWideElement = AXUIElementCreateSystemWide()
        var element: AXUIElement?
        
        let result = AXUIElementCopyElementAtPosition(systemWideElement, Float(point.x), Float(point.y), &element)
        
        if result == .success {
            return element
        }
        return nil
    }
    
    /// 获取元素的角色
    func getRole(of element: AXUIElement) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value)
        
        if result == .success, let role = value as? String {
            return role
        }
        return nil
    }
    
    /// 获取父元素
    func getParentElement(of element: AXUIElement) -> AXUIElement? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXParentAttribute as CFString, &value)
        
        if result == .success {
            return (value as! AXUIElement)
        }
        return nil
    }
    
    /// 检查元素是否有滚动条
    func hasScrollBars(_ element: AXUIElement) -> Bool {
        // 检查垂直滚动条
        var verticalScrollBar: AnyObject?
        let vResult = AXUIElementCopyAttributeValue(element, "AXVerticalScrollBar" as CFString, &verticalScrollBar)
        
        // 检查水平滚动条
        var horizontalScrollBar: AnyObject?
        let hResult = AXUIElementCopyAttributeValue(element, "AXHorizontalScrollBar" as CFString, &horizontalScrollBar)
        
        return vResult == .success || hResult == .success
    }

    // MARK: - 自动滚动控制

    /// 启动自动滚动
    func startAutoScroll(at point: CGPoint) {
        // 停止任何现有的滚动
        stopAutoScroll()

        // 设置原点
        originPoint = point
        isActive = true

        // 创建并显示固定图标覆盖层
        if overlay == nil {
            overlay = AutoScrollOverlay()
        }
        overlay?.show(at: point)

        // 启动滚动计时器（每10ms触发一次）
        scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            self?.performScroll()
        }

        // 添加到主运行循环
        if let timer = scrollTimer {
            RunLoop.current.add(timer, forMode: .common)
        }

        NSLog("[AutoScroll] Auto-scroll started")
    }

    /// 停止自动滚动
    func stopAutoScroll() {
        // 停止计时器
        scrollTimer?.invalidate()
        scrollTimer = nil

        // 隐藏覆盖层
        overlay?.hide()

        // 重置状态
        isActive = false
        originPoint = nil
        currentPoint = nil

        NSLog("[AutoScroll] Auto-scroll stopped")
    }

    /// 执行滚动（由计时器调用）
    func performScroll() {
        guard let origin = originPoint else { return }

        // 获取当前鼠标位置
        let current = NSEvent.mouseLocation

        // 计算与原点的垂直距离
        let deltaY = current.y - origin.y
        let deltaX = current.x - origin.x

        // 计算总距离（使用勾股定理）
        let totalDistance = sqrt(deltaX * deltaX + deltaY * deltaY)

        // 必须至少移动10像素才开始滚动
        if totalDistance < 10.0 {
            return // 鼠标还在原点附近，不滚动
        }

        // 死区处理
        let effectiveDistance = abs(deltaY) - deadZone
        if effectiveDistance <= 0 {
            return // 在死区内，不滚动
        }

        // 计算滚动方向（1 = 向下，-1 = 向上）- 反转以匹配自然滚动
        let direction: CGFloat = deltaY > 0 ? 1.0 : -1.0

        // 二次加速：滚动速度随距离增加而加速
        // 使用 maxSpeed 作为基准，距离越大速度越快
        let normalizedDistance = effectiveDistance / 100.0  // 标准化距离
        let acceleration = pow(normalizedDistance, 1.8)  // 非线性加速
        let scrollSpeed = min(acceleration * maxSpeed * 0.5, maxSpeed)

        // 应用灵敏度
        // 对于低速（<1.0），使用指数缩放使其更慢
        let adjustedSensitivity: CGFloat
        if sensitivity < 1.0 {
            adjustedSensitivity = CGFloat(pow(sensitivity, 1.5))
        } else {
            adjustedSensitivity = CGFloat(sensitivity)
        }

        let finalAmount = direction * scrollSpeed * adjustedSensitivity

        // 阈值检查 - 避免无意义的滚动
        let threshold = min(0.1, adjustedSensitivity * 0.5)
        if abs(finalAmount) < threshold {
            return
        }

        // 创建并发送滚动事件
        // 使用特殊标志来标记这是自动滚动事件，避免被 ScrollCore 处理
        if let scrollEvent = CGEvent(
            scrollWheelEvent2Source: nil,
            units: .pixel,
            wheelCount: 1,
            wheel1: Int32(finalAmount),
            wheel2: 0,
            wheel3: 0
        ) {
            // 使用 maskAlternate 标志来标记自动滚动事件
            // ScrollCore 会检测到这个标志并直接放行，不做平滑处理
            scrollEvent.flags = [.maskAlternate, .maskNonCoalesced]
            scrollEvent.post(tap: .cgSessionEventTap)
        }
    }

    // MARK: - 应用例外处理

    /// 检查当前应用是否应该禁用自动滚动
    func shouldEnableForCurrentApp() -> Bool {
        // TODO: 实现应用例外列表检查
        return isEnabled
    }

    /// 获取当前应用的拖动阈值
    func getDragThresholdForCurrentApp() -> CGFloat {
        // TODO: 实现应用特定的拖动阈值
        return dragThreshold
    }
}
