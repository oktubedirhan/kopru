// Köprü uygulama simgesini çizer: gün batımında suyun üstünde tek kemerli taş köprü.
// Kullanım: swift tools/app-icon/make-icon.swift <çıktı.png>   (1024×1024)
// .icns'e çevirmek için: tools/app-icon/build.sh
//
// Koordinatlar: CoreGraphics'te (0,0) sol alt köşe, y yukarı doğru artar.
// Apple'ın macOS simge ızgarası: 1024'lük tuvalde 824×824 gövde, köşe yarıçapı ~185.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let size = 1024
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

func linear(_ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: space, colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let shape = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)
let horizon: CGFloat = 400  // su çizgisi

// Gövdenin altındaki yumuşak gölge
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgb(0x000000, 0.35))
ctx.addPath(shape)
ctx.setFillColor(rgb(0x1E1F4B))
ctx.fillPath()
ctx.restoreGState()

ctx.addPath(shape)
ctx.clip()

// Gökyüzü: yukarıda gece laciverti, ufka doğru turuncu
linear([rgb(0x1E1F4B), rgb(0x5B3A7A), rgb(0xE0744A), rgb(0xF6B26B)],
       from: CGPoint(x: 0, y: 924), to: CGPoint(x: 0, y: horizon))

// Birkaç yıldız
for (x, y, r) in [(250.0, 850.0, 5.0), (380, 800, 3.5), (690, 870, 4.5), (800, 780, 3), (560, 830, 3)] {
    ctx.setFillColor(rgb(0xFFF4E0, 0.85))
    ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
}

// Güneş: kemerin içinden görünecek; etrafında ışıma
let sun = CGPoint(x: 512, y: 470)
let glow = CGGradient(colorsSpace: space, colors: [rgb(0xFFD58A, 0.9), rgb(0xFFB066, 0)] as CFArray, locations: nil)!
ctx.drawRadialGradient(glow, startCenter: sun, startRadius: 0, endCenter: sun, endRadius: 300, options: [])
ctx.setFillColor(rgb(0xFFE3A3))
ctx.fillEllipse(in: CGRect(x: sun.x - 120, y: sun.y - 120, width: 240, height: 240))

// Su
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: 0, width: 1024, height: horizon))
linear([rgb(0x3A4E8C), rgb(0x16224A)], from: CGPoint(x: 0, y: horizon), to: CGPoint(x: 0, y: 100))
// Güneşin sudaki parıltısı: daralan yatay çizgiler
for i in 0..<6 {
    let y = horizon - 30 - CGFloat(i) * 42
    let w = 220 - CGFloat(i) * 30
    ctx.setFillColor(rgb(0xFFDB8E, 0.85 - CGFloat(i) * 0.12))
    ctx.fill(CGRect(x: 512 - w / 2, y: y, width: w, height: 9))
}
ctx.restoreGState()

// Köprü: kambur bir yol, altında hafif sivri (Mostar tarzı) kemer. Çift-tek kuralıyla kemer boşluğu oyuluyor.
// Yolun üst çizgisi: tepe ≈ y 700 (kübik eğride t=0.5 noktası).
func addDeck(_ p: CGMutablePath) {
    p.addCurve(to: CGPoint(x: 884, y: 470), control1: CGPoint(x: 340, y: 777), control2: CGPoint(x: 684, y: 777))
}

// Kemer: iki kübik eğri tepede açılı buluşuyor, böylece hafif sivri oluyor.
func addArch(_ p: CGMutablePath) {
    p.move(to: CGPoint(x: 250, y: horizon))
    p.addCurve(to: CGPoint(x: 512, y: 642), control1: CGPoint(x: 250, y: 560), control2: CGPoint(x: 395, y: 622))
    p.addCurve(to: CGPoint(x: 774, y: horizon), control1: CGPoint(x: 629, y: 622), control2: CGPoint(x: 774, y: 560))
}

func bridgePath() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 140, y: horizon))
    p.addLine(to: CGPoint(x: 140, y: 470))
    addDeck(p)
    p.addLine(to: CGPoint(x: 884, y: horizon))
    p.closeSubpath()
    addArch(p)
    p.closeSubpath()
    return p
}

// Kıyılar: iki yanda koyu tepeler; köprünün uçları bunların üstüne oturuyor
func banks() -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: 0, y: horizon))
    p.addLine(to: CGPoint(x: 0, y: 486))
    p.addLine(to: CGPoint(x: 150, y: 480))
    p.addQuadCurve(to: CGPoint(x: 330, y: horizon), control: CGPoint(x: 260, y: 476))
    p.closeSubpath()
    p.move(to: CGPoint(x: 1024, y: horizon))
    p.addLine(to: CGPoint(x: 1024, y: 486))
    p.addLine(to: CGPoint(x: 874, y: 480))
    p.addQuadCurve(to: CGPoint(x: 694, y: horizon), control: CGPoint(x: 764, y: 476))
    p.closeSubpath()
    return p
}

// Yansıma: su çizgisine göre ters çevrilmiş, soluk
ctx.saveGState()
ctx.clip(to: CGRect(x: 0, y: 0, width: 1024, height: horizon))
ctx.translateBy(x: 0, y: 2 * horizon)
ctx.scaleBy(x: 1, y: -1)
ctx.setAlpha(0.2)
ctx.addPath(banks()); ctx.setFillColor(rgb(0x120F2A)); ctx.fillPath()
ctx.addPath(bridgePath()); ctx.setFillColor(rgb(0xF3E2C7)); ctx.fillPath(using: .evenOdd)
ctx.restoreGState()

ctx.addPath(banks())
ctx.setFillColor(rgb(0x1A1533))
ctx.fillPath()

// Köprü taşları: üstte açık, altta hafif koyu krem
ctx.saveGState()
ctx.addPath(bridgePath())
ctx.clip(using: .evenOdd)
linear([rgb(0xFBF0DC), rgb(0xD9C2A0)], from: CGPoint(x: 0, y: 700), to: CGPoint(x: 0, y: horizon))
// Kemerin çevresinde ince taş bordür
ctx.setStrokeColor(rgb(0xB89B76, 0.85))
ctx.setLineWidth(12)
let arch = CGMutablePath()
addArch(arch)
ctx.addPath(arch)
ctx.strokePath()
ctx.restoreGState()

// Korkuluk: yolun üst çizgisinin biraz altında ince koyu çizgi
ctx.saveGState()
ctx.translateBy(x: 0, y: -22)
let rail = CGMutablePath()
rail.move(to: CGPoint(x: 140, y: 470))
addDeck(rail)
ctx.addPath(rail)
ctx.setStrokeColor(rgb(0xB89B76, 0.9))
ctx.setLineWidth(7)
ctx.setLineCap(.round)
ctx.strokePath()
ctx.restoreGState()

// Kaydet
let image = ctx.makeImage()!
let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png")
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
guard CGImageDestinationFinalize(dest) else { fatalError("PNG yazılamadı") }
print("Yazıldı: \(out.path)")
