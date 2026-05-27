import SwiftUI
import UIKit
import AVFoundation
import MapKit

struct NFCKeyboardReader: UIViewRepresentable {
    
    @Binding var scannedText: String
    var onTag: ((String) -> Void)?
    
    func makeUIView(context: Context) -> UITextField {
        let field = UITextField(frame: .zero)
        
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.keyboardType = .asciiCapable
        field.textColor = .clear
        field.tintColor = .clear
        field.backgroundColor = .clear
        field.delegate = context.coordinator
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            field.becomeFirstResponder()
        }
        
        return field
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        DispatchQueue.main.async {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        
        let parent: NFCKeyboardReader
        
        init(_ parent: NFCKeyboardReader) {
            self.parent = parent
        }
        
        func textField(
            _ textField: UITextField,
            shouldChangeCharactersIn range: NSRange,
            replacementString string: String
        ) -> Bool {
            
            let current = textField.text ?? ""
            
            let newText = (current as NSString).replacingCharacters(
                in: range,
                with: string
            )
            
            if string == "\n" || string == "\r" || newText.count >= 6 {
                let clean = newText
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                
                if clean.count >= 4 {
                    DispatchQueue.main.async {
                        self.parent.scannedText = clean
                        self.parent.onTag?(clean)
                        textField.text = ""
                    }
                    return false
                }
            }
            
            return true
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    @ObservedObject var manager: CameraManager
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        
        let layer = AVCaptureVideoPreviewLayer(session: manager.session)
        layer.videoGravity = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspectFill")
        if let connection = layer.connection {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 0
            } else {
                connection.videoOrientation = .landscapeRight
            }
        }
        
        view.layer.addSublayer(layer)
        
        DispatchQueue.main.async {
            layer.frame = view.bounds
        }
        
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let layer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            layer.frame = uiView.bounds
            layer.videoGravity = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspectFill")
            if let connection = layer.connection {
                if #available(iOS 17.0, *) {
                    connection.videoRotationAngle = 0
                } else {
                    connection.videoOrientation = .landscapeRight
                }
            }
        }
    }
}

struct ProBox<Content: View>: View {
    let title: String
    let content: Content
    
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        AVOCommercialCard(title: title, accent: AVOCommercialTheme.neonCyan) {
            content
        }
    }
}

struct MiniText: View {
    let name: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Text(name)
                .foregroundColor(.white.opacity(0.72))
            
            Spacer()
            
            Text(value)
                .foregroundColor(color)
        }
        .font(.system(size: 12, weight: .bold, design: .monospaced))
    }
}

struct BottomButton: View {
    let title: String
    let color: Color
    
    init(_ title: String, _ color: Color) {
        self.title = title
        self.color = color
    }
    
    var body: some View {
        Text(title.uppercased())
            .foregroundColor(.black)
            .font(.system(size: 12, weight: .black, design: .monospaced))
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .background(color)
            .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner).stroke(color.opacity(0.45), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner))
            .shadow(color: color.opacity(0.18), radius: 8, x: 0, y: 0)
    }
}

struct SideMenuButton: View {
    let title: String
    let active: Bool
    
    var body: some View {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundColor(active ? .black : AVOCommercialTheme.neonGreen)
            .frame(width: 76, height: 34)
            .background(active ? AVOCommercialTheme.neonGreen : Color.black.opacity(0.55))
            .overlay(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner).stroke(AVOCommercialTheme.neonGreen.opacity(active ? 0.25 : 0.38), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: AVOCommercialTheme.smallCorner))
    }
}

struct HeartWave: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height
                
                let points: [CGFloat] = [
                    0.55, 0.50, 0.62, 0.48,
                    0.58, 0.52, 0.61, 0.30,
                    0.70, 0.42, 0.55, 0.60,
                    0.50
                ]
                
                path.move(to: CGPoint(x: 0, y: h * 0.55))
                
                for i in 0..<points.count {
                    path.addLine(
                        to: CGPoint(
                            x: CGFloat(i) / CGFloat(points.count - 1) * w,
                            y: h * points[i]
                        )
                    )
                }
            }
            .stroke(Color.green, lineWidth: 2)
            .shadow(color: .green, radius: 5)
        }
    }
}

struct CircularGauge: View {
    let title: String
    let value: Double
    let color: Color
    let text: String
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
            
            VStack(spacing: 3) {
                Text(title)
                    .foregroundColor(.white.opacity(0.85))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                
                ZStack {
                    Circle()
                        .trim(from: 0.18, to: 0.88)
                        .stroke(Color.white.opacity(0.16), lineWidth: 9)
                        .rotationEffect(.degrees(35))
                    
                    Circle()
                        .trim(from: 0.18, to: 0.18 + value * 0.70)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round)
                        )
                        .rotationEffect(.degrees(35))
                    
                    Text(text)
                        .foregroundColor(.white)
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .offset(y: 30)
                }
            }
            .padding(8)
        }
    }
}

struct HorseOverlay: View {
    let horseBox: CGRect
    let riderBox: CGRect
    let riderPosePoints: [CGPoint]
    let horseKeypoints: [CGPoint]
    let quality: Double
    let fatigue: Double
    let risk: Double
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let rect = CGRect(
                x: horseBox.minX * w,
                y: (1.0 - horseBox.maxY) * h,
                width: horseBox.width * w,
                height: horseBox.height * h
            )
            
            ZStack {
                Rectangle()
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                
                Text(horseKeypoints.isEmpty ? "POSE MODEL SEARCHING" : "AVOHORSEPOSE REAL LOCK")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.72))
                    .position(x: rect.midX, y: max(12, rect.minY - 12))
                
                ForEach(riderPosePoints, id: \.self) { point in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                        .position(x: point.x * w, y: (1 - point.y) * h)
                }
                
                ForEach(horseKeypoints, id: \.self) { point in
                    Circle()
                        .stroke(Color.cyan, lineWidth: 2)
                        .frame(width: 10, height: 10)
                        .position(x: point.x * w, y: (1 - point.y) * h)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct RealGPSMapView: View {
    @ObservedObject var location: LocationManager
    
    var body: some View {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        )
        
        let binding = Binding<MapCameraPosition>(
            get: { .region(region) },
            set: { _ in }
        )
        
        ZStack(alignment: .topLeading) {
            Map(position: binding) {
                if location.path.count > 1 {
                    MapPolyline(coordinates: location.path)
                        .stroke(.green, lineWidth: 5)
                }
                
                Marker("HORSE", coordinate: location.coordinate)
                    .tint(.red)
            }
            .mapStyle(.imagery(elevation: .realistic))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            
            HStack {
                Text(location.gpsText)
                    .foregroundColor(.green)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .padding(6)
                    .background(Color.black.opacity(0.70))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                
                Spacer()
                
                Text(location.zoneStatus)
                    .foregroundColor(location.zoneStatus.contains("INSIDE") ? .green : .orange)
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .padding(6)
                    .background(Color.black.opacity(0.70))
                    .clipShape(RoundedRectangle(cornerRadius: 5))
            }
            .padding(8)
        }
    }
}

struct AVOLogoView: View {
    var body: some View {
        VStack(alignment: .trailing, spacing: -2) {
            HStack(spacing: 0) {
                Text("A")
                    .foregroundColor(.red)
                    .font(.system(size: 46, weight: .black))
                    .italic()
                
                Text("VO")
                    .foregroundColor(.white)
                    .font(.system(size: 46, weight: .black))
                    .italic()
            }
            
            Text("PERFORMANCE")
                .foregroundColor(.white)
                .font(.system(size: 11, weight: .black))
                .tracking(1.5)
            
            Rectangle()
                .fill(Color.red)
                .frame(width: 130, height: 4)
        }
        .shadow(color: .red.opacity(0.45), radius: 8)
    }
}

struct RuggedTabletFrame<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Color(red: 0.006, green: 0.010, blue: 0.012)
                .ignoresSafeArea()

            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .padding(2)

            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.10), lineWidth: 1)
                .padding(6)

            content
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
    }
}
struct BottomStatusBox: View {
    let title: String
    let value: String
    let color: Color
    let width: CGFloat
    
    var body: some View {
        VStack(spacing: 3) {
            Text(title)
                .foregroundColor(.white.opacity(0.55))
                .font(.system(size: 9, weight: .bold, design: .monospaced))
            
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
        .frame(width: width, height: 58)
        .background(Color.black.opacity(0.35))
        .overlay(
            Rectangle()
                .fill(Color.green.opacity(0.12))
                .frame(width: 1),
            alignment: .trailing
        )
    }
}

struct BottomActionButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .foregroundColor(.black)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .frame(width: 58, height: 32)
                .background(color)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
    }
}

// MARK: - AVO Premium Dense UI Components V33

struct AVOPremiumPanel<Content: View>: View {
    let title: String
    let accent: Color
    let content: Content
    init(_ title: String, accent: Color = .green, @ViewBuilder content: () -> Content) {
        self.title = title
        self.accent = accent
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(title.uppercased())
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.92))
                Rectangle().fill(accent.opacity(0.45)).frame(height: 1)
            }
            content
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(colors: [Color(red: 0.025, green: 0.055, blue: 0.06).opacity(0.96), Color.black.opacity(0.92)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(accent.opacity(0.32), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AVODenseValue: View {
    let name: String
    let value: String
    let color: Color
    var body: some View {
        HStack(spacing: 6) {
            Text(name.uppercased())
                .foregroundColor(.white.opacity(0.64))
                .font(.system(size: 10, weight: .black, design: .monospaced))
            Spacer(minLength: 6)
            Text(value)
                .foregroundColor(color)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.55)
        }
    }
}

struct AVOKPIBox: View {
    let title: String
    let value: String
    let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.55))
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(color)
                .minimumScaleFactor(0.45)
                .lineLimit(1)
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black.opacity(0.42))
        .overlay(RoundedRectangle(cornerRadius: 7).stroke(color.opacity(0.34), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}

struct AVOTableHeader: View {
    let columns: [String]
    var body: some View {
        HStack {
            ForEach(columns, id: \.self) { c in
                Text(c.uppercased())
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.60))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color.white.opacity(0.05))
    }
}

struct AVOTableRow: View {
    let values: [String]
    let color: Color
    var body: some View {
        HStack {
            ForEach(Array(values.enumerated()), id: \.offset) { _, v in
                Text(v)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.55)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 8)
        .background(Color.black.opacity(0.22))
        .overlay(Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1), alignment: .bottom)
    }
}

struct AVOMiniHUD: View {
    let horse: String
    let gait: String
    let risk: String
    let fatigue: String
    let hr: String
    let speed: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            AVODenseValue(name: "MODE", value: "FULL BIOMECH", color: .green)
            AVODenseValue(name: "HORSE", value: horse, color: .cyan)
            AVODenseValue(name: "GAIT", value: gait, color: .green)
            HStack(spacing: 12) {
                Text("RISK \(risk)").foregroundColor(.red)
                Text("FAT \(fatigue)").foregroundColor(.orange)
                Text(hr).foregroundColor(.green)
                Text(speed).foregroundColor(.cyan)
            }
            .font(.system(size: 10, weight: .black, design: .monospaced))
        }
        .padding(9)
        .frame(width: 265, alignment: .leading)
        .background(Color.black.opacity(0.62))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.45), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AVOHorseWireframe: View {
    var body: some View {
        GeometryReader { geo in
            Path { p in
                let w = geo.size.width, h = geo.size.height
                p.move(to: CGPoint(x: w*0.18, y: h*0.52)); p.addCurve(to: CGPoint(x: w*0.65, y: h*0.45), control1: CGPoint(x: w*0.30,y:h*0.25), control2: CGPoint(x:w*0.55,y:h*0.30))
                p.addCurve(to: CGPoint(x: w*0.82, y: h*0.32), control1: CGPoint(x:w*0.72,y:h*0.36), control2: CGPoint(x:w*0.76,y:h*0.30))
                p.addLine(to: CGPoint(x: w*0.90, y: h*0.38)); p.addLine(to: CGPoint(x: w*0.82, y: h*0.47))
                p.addCurve(to: CGPoint(x: w*0.22, y: h*0.60), control1: CGPoint(x:w*0.62,y:h*0.65), control2: CGPoint(x:w*0.38,y:h*0.68))
                p.closeSubpath()
                p.move(to: CGPoint(x:w*0.35,y:h*0.59)); p.addLine(to: CGPoint(x:w*0.30,y:h*0.88))
                p.move(to: CGPoint(x:w*0.48,y:h*0.60)); p.addLine(to: CGPoint(x:w*0.45,y:h*0.88))
                p.move(to: CGPoint(x:w*0.62,y:h*0.57)); p.addLine(to: CGPoint(x:w*0.66,y:h*0.88))
                p.move(to: CGPoint(x:w*0.73,y:h*0.52)); p.addLine(to: CGPoint(x:w*0.78,y:h*0.88))
            }
            .stroke(Color.green, lineWidth: 2)
            ForEach(0..<14, id: \.self) { i in
                Circle().fill(i % 3 == 0 ? Color.cyan : Color.green)
                    .frame(width: 7, height: 7)
                    .position(x: geo.size.width * CGFloat([0.20,0.28,0.36,0.48,0.58,0.69,0.80,0.88,0.31,0.45,0.66,0.78,0.52,0.74][i]), y: geo.size.height * CGFloat([0.53,0.47,0.43,0.40,0.42,0.38,0.34,0.39,0.86,0.86,0.86,0.86,0.59,0.52][i]))
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.22))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.green.opacity(0.38), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
