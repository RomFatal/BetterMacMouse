//
//  AutoScrollCursor.swift
//  Mos
//  自动滚动自定义光标 - 带上下箭头指示器
//  Created by Auto-Scroll Implementation on 2025/11/29.
//  Copyright © 2025年 Caldis. All rights reserved.
//

import Cocoa

class AutoScrollCursor {

    /// 创建带有上下箭头的自定义光标
    static func create() -> NSCursor {
        let size = CGSize(width: 32, height: 32)
        let image = NSImage(size: size)

        image.lockFocus()

        // 清除背景
        NSColor.clear.set()
        NSRect(x: 0, y: 0, width: size.width, height: size.height).fill()

        // 绘制蓝色圆圈（中心指示器）
        NSColor.systemBlue.withAlphaComponent(0.6).setFill()
        let circleRect = NSRect(x: 8, y: 8, width: 16, height: 16)
        NSBezierPath(ovalIn: circleRect).fill()

        // 设置白色描边用于箭头
        NSColor.white.setStroke()

        // 绘制上箭头
        let upArrow = NSBezierPath()
        upArrow.move(to: NSPoint(x: 16, y: 4))
        upArrow.line(to: NSPoint(x: 16, y: 6))
        upArrow.move(to: NSPoint(x: 16, y: 4))
        upArrow.line(to: NSPoint(x: 13, y: 7))
        upArrow.move(to: NSPoint(x: 16, y: 4))
        upArrow.line(to: NSPoint(x: 19, y: 7))
        upArrow.lineWidth = 2
        upArrow.stroke()

        // 绘制下箭头
        let downArrow = NSBezierPath()
        downArrow.move(to: NSPoint(x: 16, y: 28))
        downArrow.line(to: NSPoint(x: 16, y: 26))
        downArrow.move(to: NSPoint(x: 16, y: 28))
        downArrow.line(to: NSPoint(x: 13, y: 25))
        downArrow.move(to: NSPoint(x: 16, y: 28))
        downArrow.line(to: NSPoint(x: 19, y: 25))
        downArrow.lineWidth = 2
        downArrow.stroke()

        image.unlockFocus()

        // 创建光标，热点在中心
        let hotSpot = NSPoint(x: 16, y: 16)
        return NSCursor(image: image, hotSpot: hotSpot)
    }

    /// 创建带动画效果的光标（可选，用于未来增强）
    static func createAnimated(frame: Int) -> NSCursor {
        // TODO: 实现动画光标
        return create()
    }
}
