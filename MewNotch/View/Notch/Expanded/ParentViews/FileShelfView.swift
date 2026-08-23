//
//  FileShelfView.swift
//  MewNotch
//
//  Created by Monu Kumar on 03/07/25.
//

import SwiftUI
import AppKit

struct FileShelfView: View {
    @ObservedObject var notchViewModel: NotchViewModel
    @StateObject private var diskListViewModel = ActiveDiskListViewModel()

    @State private var idDiscoConPopoverColor: String?
    @State private var colorSeleccionadoArion: Color = .red
    @State private var colorAplicadoArion: Color = .red
    @State private var arionDisponible: Bool = false
    @State private var aplicandoColorArion: Bool = false
    @State private var mensajeEstadoArion: String?
    @State private var esMensajeErrorArion: Bool = false

    private var diskNameFont: NSFont {
        NSFont.systemFont(ofSize: 11, weight: .medium)
    }

    private var leftPanelWidth: CGFloat {
        let maxNameWidth = diskListViewModel.activeDisks
            .map { $0.name.width(using: diskNameFont) }
            .max() ?? 0

        let rowContentWidth: CGFloat = 14 + 8 + maxNameWidth
        let rowHorizontalPadding: CGFloat = 8
        let panelHorizontalPadding: CGFloat = 8

        let calculatedWidth = rowContentWidth + rowHorizontalPadding + panelHorizontalPadding
        let minimumWidth = notchViewModel.notchSize.height * 1.9

        return max(calculatedWidth, minimumWidth)
    }

    private var shelfWidth: CGFloat {
        // Keep this view narrower than previous expanded width while reserving
        // a bit of horizontal space on the right side for future content.
        max(leftPanelWidth + 24, notchViewModel.notchSize.width * 1.55)
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 8) {
                Spacer(minLength: 0)

                ForEach(diskListViewModel.activeDisks) { disk in
                    Button {
                        manejarTapEnDisco(disk)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: disk.iconSystemName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                                .frame(width: 16, alignment: .leading)

                            Text(disk.name)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.9))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)

                            Spacer(minLength: 0)

                            if disk.isArionCandidate {
                                Circle()
                                    .fill(colorAplicadoArion)
                                    .frame(width: 10, height: 10)
                                    .overlay {
                                        Circle()
                                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                                    }
                            }
                        }
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white.opacity(0.07))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                }
                        }
                    }
                    .buttonStyle(.plain)
                    .popover(
                        isPresented: bindingPopoverColor(para: disk),
                        attachmentAnchor: .rect(.bounds),
                        arrowEdge: .trailing
                    ) {
                        if disk.isArionCandidate {
                            contenidoPopoverArion(nombreDisco: disk.name)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)
            .frame(
                width: leftPanelWidth,
                height: notchViewModel.notchSize.height * 3
            )
            .onChange(of: diskListViewModel.activeDisks) { _, discosActivos in
                guard let idDiscoConPopoverColor else { return }
                let discoSigueVisible = discosActivos.contains { $0.id == idDiscoConPopoverColor }
                if !discoSigueVisible {
                    self.idDiscoConPopoverColor = nil
                    arionDisponible = false
                    mensajeEstadoArion = nil
                    esMensajeErrorArion = false
                    aplicandoColorArion = false
                }
            }

            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(
             width: shelfWidth,
             height: notchViewModel.notchSize.height * 3,
             alignment: .bottom
        )
    }

    private func manejarTapEnDisco(_ disk: ActiveDiskItem) {
        guard disk.isArionCandidate else {
            NSWorkspace.shared.open(disk.mountURL)
            return
        }

        switch ArionRGBService.shared.validarCanal() {
        case .success:
            arionDisponible = true
            mensajeEstadoArion = nil
            esMensajeErrorArion = false
        case .failure(let error):
            arionDisponible = false
            mensajeEstadoArion = error.localizedDescription
            esMensajeErrorArion = true
        }

        idDiscoConPopoverColor = disk.id
    }

    private func aplicarColorArion() {
        aplicandoColorArion = true
        mensajeEstadoArion = nil
        esMensajeErrorArion = false

        Task {
            let resultado = await ArionRGBService.shared.aplicarColor(color: colorSeleccionadoArion)

            await MainActor.run {
                aplicandoColorArion = false

                switch resultado {
                case .success:
                    colorAplicadoArion = colorSeleccionadoArion
                    mensajeEstadoArion = "Color aplicado correctamente."
                    esMensajeErrorArion = false
                case .failure(let error):
                    mensajeEstadoArion = error.localizedDescription
                    esMensajeErrorArion = true
                }
            }
        }
    }

    private func bindingPopoverColor(para disk: ActiveDiskItem) -> Binding<Bool> {
        Binding(
            get: { idDiscoConPopoverColor == disk.id && disk.isArionCandidate },
            set: { nuevoValor in
                if nuevoValor {
                    idDiscoConPopoverColor = disk.id
                    return
                }

                if idDiscoConPopoverColor == disk.id {
                    idDiscoConPopoverColor = nil
                    arionDisponible = false
                    mensajeEstadoArion = nil
                    esMensajeErrorArion = false
                }
            }
        )
    }

    @ViewBuilder
    private func contenidoPopoverArion(nombreDisco: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(nombreDisco)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))

                Text("ROG STRIX ARION · Color RGB fijo")
                    .font(.system(size: 10, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.58))
            }

            RuedaColorRGBView(colorSeleccionado: $colorSeleccionadoArion)
                .frame(width: 206, height: 232)

            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(colorSeleccionadoArion)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    }
                    .frame(width: 22, height: 22)

                Text(colorSeleccionadoArion.rgbHexString)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))

                Spacer(minLength: 0)
            }

            Button(action: aplicarColorArion) {
                HStack(spacing: 8) {
                    if aplicandoColorArion {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .controlSize(.small)
                    }
                    Text(aplicandoColorArion ? "Aplicando..." : "Aplicar color")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(aplicandoColorArion || !arionDisponible)

            if let mensajeEstadoArion {
                Text(mensajeEstadoArion)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(esMensajeErrorArion ? .red.opacity(0.92) : .green.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(width: 236)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.92))
        )
    }
}

private extension String {
    func width(using font: NSFont) -> CGFloat {
        (self as NSString).size(withAttributes: [.font: font]).width
    }
}

private struct RuedaColorRGBView: View {
    @Binding var colorSeleccionado: Color

    @State private var tono: Double = 0
    @State private var saturacion: Double = 1
    @State private var brillo: Double = 1
    @State private var actualizandoInternamente = false

    private var coloresRueda: [Color] {
        stride(from: 0.0, through: 1.0, by: 1.0 / 12.0).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            GeometryReader { geometry in
                let lado = min(geometry.size.width, geometry.size.height)
                let radio = lado / 2
                let posicionMarcador = posicionIndicador(radio: radio)

                ZStack {
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: coloresRueda,
                                center: .center
                            )
                        )

                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: radio
                            )
                        )

                    Circle()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Circle()
                                .stroke(Color.black.opacity(0.35), lineWidth: 1)
                        }
                        .position(posicionMarcador)
                }
                .frame(width: lado, height: lado)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                .contentShape(Circle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            actualizarDesdePunto(value.location, size: geometry.size)
                        }
                )
            }
            .aspectRatio(1, contentMode: .fit)

            HStack(spacing: 8) {
                Text("Brillo")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))

                Slider(value: $brillo, in: 0...1)
                    .onChange(of: brillo) { _, _ in
                        actualizarColorSeleccionado()
                    }
                    .tint(.white)
            }
        }
        .onAppear {
            sincronizarConColorActual()
        }
        .onChange(of: colorSeleccionado) { _, _ in
            guard !actualizandoInternamente else { return }
            sincronizarConColorActual()
        }
    }

    private func posicionIndicador(radio: CGFloat) -> CGPoint {
        let angulo = tono * .pi * 2
        let distancia = saturacion * Double(radio)
        let x = Double(radio) + cos(angulo) * distancia
        let y = Double(radio) + sin(angulo) * distancia
        return CGPoint(x: x, y: y)
    }

    private func actualizarDesdePunto(_ punto: CGPoint, size: CGSize) {
        let lado = min(size.width, size.height)
        let radio = lado / 2
        guard radio > 0 else { return }

        let centro = CGPoint(x: size.width / 2, y: size.height / 2)

        let deltaX = punto.x - centro.x
        let deltaY = punto.y - centro.y

        let distancia = min(sqrt((deltaX * deltaX) + (deltaY * deltaY)), radio)
        saturacion = Double(distancia / radio)

        var angulo = atan2(deltaY, deltaX)
        if angulo < 0 {
            angulo += (.pi * 2)
        }
        tono = Double(angulo / (.pi * 2))

        actualizarColorSeleccionado()
    }

    private func actualizarColorSeleccionado() {
        actualizandoInternamente = true
        colorSeleccionado = Color(hue: tono, saturation: saturacion, brightness: brillo)
        actualizandoInternamente = false
    }

    private func sincronizarConColorActual() {
        guard let color = NSColor(colorSeleccionado).usingColorSpace(.deviceRGB) else {
            return
        }

        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0

        color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

        tono = Double(hue)
        self.saturacion = Double(saturation)
        brillo = Double(brightness)
    }
}

private struct ActiveDiskItem: Identifiable, Equatable {
    let id: String
    let name: String
    let isBuiltIn: Bool
    let mountURL: URL

    var iconSystemName: String {
        isBuiltIn ? "applelogo" : "internaldrive.fill"
    }

    var isArionCandidate: Bool {
        !isBuiltIn && name.localizedCaseInsensitiveContains("ROG")
    }
}

private final class ActiveDiskListViewModel: ObservableObject {
    @Published private(set) var activeDisks: [ActiveDiskItem] = []

    private var notificationTokens: [NSObjectProtocol] = []
    private let workspaceNotificationCenter = NSWorkspace.shared.notificationCenter

    init() {
        startObservingVolumeChanges()
        refreshDisks()
    }

    deinit {
        notificationTokens.forEach(workspaceNotificationCenter.removeObserver)
    }

    private func startObservingVolumeChanges() {
        let notifications: [Notification.Name] = [
            NSWorkspace.didMountNotification,
            NSWorkspace.didUnmountNotification,
            NSWorkspace.didRenameVolumeNotification
        ]

        notifications.forEach { notification in
            let token = workspaceNotificationCenter.addObserver(
                forName: notification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.refreshDisks()
            }
            notificationTokens.append(token)
        }
    }

    private func refreshDisks() {
        let keys: Set<URLResourceKey> = [
            .volumeNameKey,
            .volumeIsInternalKey,
            .volumeIsBrowsableKey,
            .volumeIsLocalKey
        ]

        let mountedVolumes = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: Array(keys),
            options: [.skipHiddenVolumes]
        ) ?? []

        var builtInDisk: ActiveDiskItem?
        var externalDisks: [ActiveDiskItem] = []

        for volumeURL in mountedVolumes {
            guard
                let values = try? volumeURL.resourceValues(forKeys: keys),
                values.volumeIsBrowsable != false,
                values.volumeIsLocal != false
            else {
                continue
            }

            let diskName = values.volumeName ?? volumeURL.lastPathComponent
            let isBuiltIn = values.volumeIsInternal ?? false
            let item = ActiveDiskItem(
                id: volumeURL.path,
                name: diskName,
                isBuiltIn: isBuiltIn,
                mountURL: volumeURL
            )

            if isBuiltIn {
                if builtInDisk == nil || volumeURL.path == "/" {
                    builtInDisk = item
                }
            } else {
                externalDisks.append(item)
            }
        }

        if builtInDisk == nil {
            let rootURL = URL(fileURLWithPath: "/")
            let rootName = (try? rootURL.resourceValues(forKeys: [.volumeNameKey]))?.volumeName ?? "Macintosh HD"
            builtInDisk = ActiveDiskItem(
                id: rootURL.path,
                name: rootName,
                isBuiltIn: true,
                mountURL: rootURL
            )
        }

        externalDisks.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        var nextState: [ActiveDiskItem] = []
        if let builtInDisk {
            nextState.append(builtInDisk)
        }
        if let firstExternal = externalDisks.first {
            nextState.append(firstExternal)
        }

        if activeDisks != nextState {
            activeDisks = nextState
        }
    }
}

private extension Color {
    var rgbHexString: String {
        guard let color = NSColor(self).usingColorSpace(.deviceRGB) else {
            return "#FFFFFF"
        }

        let red = UInt8(clamping: Int(round(color.redComponent * 255)))
        let green = UInt8(clamping: Int(round(color.greenComponent * 255)))
        let blue = UInt8(clamping: Int(round(color.blueComponent * 255)))

        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}
