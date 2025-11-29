//
//  AutoScrollOverlay.swift
//  Mos
//  自动滚动覆盖窗口 - 在初始点击位置显示固定图标
//  Created by Auto-Scroll Implementation on 2025/11/29.
//  Copyright © 2025年 Caldis. All rights reserved.
//

import Cocoa

class AutoScrollOverlay {

    private var overlayWindow: NSWindow?
    private var imageView: NSImageView?

    /// 在指定位置显示自动滚动图标
    func show(at point: CGPoint) {
        NSLog("[AutoScrollOverlay] show(at: \(point))")

        // 创建图标图像
        let iconSize: CGFloat = 48
        let image = createAutoScrollIcon(size: iconSize)

        // 创建图像视图
        imageView = NSImageView(frame: NSRect(x: 0, y: 0, width: iconSize, height: iconSize))
        imageView?.image = image
        imageView?.wantsLayer = true
        imageView?.layer?.backgroundColor = NSColor.red.withAlphaComponent(0.5).cgColor

        // 找到光标所在的屏幕
        var targetScreen: NSScreen?
        for screen in NSScreen.screens {
            if NSMouseInRect(point, screen.frame, false) {
                targetScreen = screen
                break
            }
        }

        if targetScreen == nil {
            targetScreen = NSScreen.main
        }

        NSLog("[AutoScrollOverlay] Mouse point: \(point)")
        NSLog("[AutoScrollOverlay] Target screen frame: \(targetScreen?.frame ?? .zero)")
        NSLog("[AutoScrollOverlay] All screens: \(NSScreen.screens.map { $0.frame })")

        // 窗口位置使用全局屏幕坐标（不需要转换）
        let windowRect = NSRect(
            x: point.x - iconSize / 2,
            y: point.y - iconSize / 2,
            width: iconSize,
            height: iconSize
        )

        NSLog("[AutoScrollOverlay] windowRect: \(windowRect)")

        overlayWindow = NSWindow(
            contentRect: windowRect,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        overlayWindow?.backgroundColor = .red
        overlayWindow?.isOpaque = true
        overlayWindow?.hasShadow = true
        overlayWindow?.level = .statusBar
        overlayWindow?.ignoresMouseEvents = true
        overlayWindow?.contentView = imageView
        overlayWindow?.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        overlayWindow?.alphaValue = 0.8

        overlayWindow?.orderFrontRegardless()
        NSLog("[AutoScrollOverlay] Window shown: \(overlayWindow?.isVisible ?? false), screen: \(overlayWindow?.screen?.frame ?? .zero)")
    }

    /// 隐藏覆盖窗口
    func hide() {
        overlayWindow?.orderOut(nil)
        overlayWindow = nil
        imageView = nil
    }

    /// 创建自动滚动图标（基于SVG参考）
    private func createAutoScrollIcon(size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))

        image.lockFocus()

        // 绘制白色背景
        NSColor.white.withAlphaComponent(0.95).set()
        let background = NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: size - 4, height: size - 4))
        background.fill()

        // 缩放和翻转Y轴（SVG坐标系与NSView坐标系相反）
        let scale = size / 16.0
        let transform = NSAffineTransform()
        transform.translateX(by: 0, yBy: size)
        transform.scaleX(by: scale, yBy: -scale)
        transform.concat()

        // 设置颜色 #b5b5b5
        let iconColor = NSColor(red: 0xb5/255.0, green: 0xb5/255.0, blue: 0xb5/255.0, alpha: 1.0)
        iconColor.setFill()

        // Path 1: 中心圆圈 (circle at center)
        let centerCircle = NSBezierPath()
        centerCircle.appendOval(in: NSRect(x: 6, y: 6, width: 4, height: 4))
        let innerCircle = NSBezierPath()
        innerCircle.appendOval(in: NSRect(x: 7, y: 7, width: 2, height: 2))
        centerCircle.append(innerCircle.reversed)
        centerCircle.fill()

        // Path 2: 下箭头
        let downArrow = NSBezierPath()
        downArrow.move(to: NSPoint(x: 8, y: 13.585))
        downArrow.line(to: NSPoint(x: 5.2, y: 10.79))
        downArrow.line(to: NSPoint(x: 4.5, y: 11.5))
        downArrow.line(to: NSPoint(x: 8, y: 15))
        downArrow.line(to: NSPoint(x: 11.5, y: 11.5))
        downArrow.line(to: NSPoint(x: 10.795, y: 10.795))
        downArrow.line(to: NSPoint(x: 8, y: 13.585))
        downArrow.close()
        downArrow.fill()

        // Path 3: 上箭头
        let upArrow = NSBezierPath()
        upArrow.move(to: NSPoint(x: 8, y: 2.415))
        upArrow.line(to: NSPoint(x: 10.79, y: 5.2))
        upArrow.line(to: NSPoint(x: 11.5, y: 4.5))
        upArrow.line(to: NSPoint(x: 8, y: 1))
        upArrow.line(to: NSPoint(x: 4.5, y: 4.5))
        upArrow.line(to: NSPoint(x: 5.205, y: 5.205))
        upArrow.line(to: NSPoint(x: 8, y: 2.415))
        upArrow.close()
        upArrow.fill()

        image.unlockFocus()

        return image
    }
}
