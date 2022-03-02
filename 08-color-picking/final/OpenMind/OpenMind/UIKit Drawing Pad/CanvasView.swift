/// Copyright (c) 2022 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// This project and source code may use libraries or frameworks that are
/// released under various Open-Source licenses. Use of those libraries and
/// frameworks are governed by their own individual licenses.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import UIKit

class CanvasView: UIControl {
  var drawingImage: UIImage?
  var color: UIColor = .black {
    didSet {
      shadingColor = color
    }
  }

  var shadingColor: UIColor = .black {
    didSet {
      let image = UIImage(named: "pencilTexture")!
      let tintedImage = UIGraphicsImageRenderer(size: image.size).image { _ in
        color.set()
        image.draw(at: .zero)
      }
      shadingColor = UIColor(patternImage: tintedImage)
    }
  }

  private let defaultLineWidth: CGFloat = 6
  private let minLineWidth: CGFloat = 5
  private let forceSensitivity: CGFloat = 4
  private let tiltThreshold: CGFloat = .pi / 6
  private let drawingColorView = DrawingColorView()

  init(color: UIColor, drawingImage: UIImage?) {
    self.drawingImage = drawingImage
    self.color = color
    super.init(frame: .zero)

    addSubview(drawingColorView)
    let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress))
    addGestureRecognizer(longPress)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func draw(_ rect: CGRect) {
    drawingImage?.draw(in: rect)
  }

  @objc func handleLongPress(gesture: UILongPressGestureRecognizer) {
    guard let drawingImage = drawingImage else { return }
    let location = gesture.location(in: self)
    guard let color = drawingImage.getColor(at: location) else { return }

    switch gesture.state {
    case .began:
      drawingColorView.show(color: color, location: location)
    case .ended:
      drawingColorView.hide()
      self.color = color
    default: break
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    sendActions(for: .valueChanged)
  }

  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }

    drawingImage = UIGraphicsImageRenderer(size: bounds.size).image { context in
      UIColor.white.setFill()
      context.fill(bounds)
      drawingImage?.draw(in: bounds)

      var touches: [UITouch] = []
      if let coalescedTouches = event?.coalescedTouches(for: touch) {
        touches = coalescedTouches
      } else {
        touches.append(touch)
      }
      print("Touch count: ", touches.count)

      for touch in touches {
        drawStroke(context: context.cgContext, touch: touch)
      }
    }
    setNeedsDisplay()
  }

  private func drawStroke(context: CGContext, touch: UITouch) {
    let previousLocation = touch.previousLocation(in: self)
    let location = touch.location(in: self)

    var lineWidth: CGFloat
    if touch.altitudeAngle < tiltThreshold {
      lineWidth = lineWidthForShading(touch: touch)
      shadingColor.setStroke()

      let minForce: CGFloat = 0
      let maxForce: CGFloat = 4
      let normalizedAlpha = (touch.force - minForce) / (maxForce - minForce)
      context.setAlpha(normalizedAlpha)
    } else {
      lineWidth = defaultLineWidth
      if touch.force > 0 {
        lineWidth = touch.force * forceSensitivity
      }
      color.setStroke()
    }

    context.setLineWidth(lineWidth)
    context.setLineCap(.round)

    context.move(to: previousLocation)
    context.addLine(to: location)
    context.strokePath()
  }

  private func lineWidthForShading(touch: UITouch) -> CGFloat {
    let maxLineWidth: CGFloat = 60
    let minAltitudeAngle: CGFloat = 0.25
    let maxAltitudeAngle = tiltThreshold
    let altitudeAngle = max(minAltitudeAngle, touch.altitudeAngle)

    let normalizedAltitude = (altitudeAngle - minAltitudeAngle) / (maxAltitudeAngle - minAltitudeAngle)
    return max(maxLineWidth * (1 - normalizedAltitude), minLineWidth)
  }
}

