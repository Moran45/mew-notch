//
//  ArionRGBService.swift
//  MewNotch
//
//  Created by Codex on 25/02/26.
//

import AppKit
import SwiftUI

enum ArionRGBServiceError: LocalizedError {
    case mensaje(String)

    var errorDescription: String? {
        switch self {
        case .mensaje(let texto):
            return texto
        }
    }
}

final class ArionRGBService {

    static let shared = ArionRGBService()

    private let controlador = ArionRGBController.sharedInstance()

    private init() {}

    func validarCanal() -> Result<Void, ArionRGBServiceError> {
        do {
            try controlador.canOpenChannel()
            return .success(())
        } catch {
            return .failure(.mensaje(Self.mensajeLegible(para: error as NSError)))
        }
    }

    func dispositivoDisponible() -> Bool {
        if case .success = validarCanal() {
            return true
        }

        return false
    }

    func aplicarColor(color: Color) async -> Result<Void, ArionRGBServiceError> {
        guard let colorRGB = color.componentesRGB8 else {
            return .failure(.mensaje("No se pudo convertir el color seleccionado a formato RGB."))
        }

        return await aplicarColor(
            rojo: colorRGB.rojo,
            verde: colorRGB.verde,
            azul: colorRGB.azul
        )
    }

    func aplicarColor(rojo: UInt8, verde: UInt8, azul: UInt8) async -> Result<Void, ArionRGBServiceError> {
        do {
            try controlador.applyStaticColor(withRed: rojo, green: verde, blue: azul)
            return .success(())
        } catch {
            return .failure(.mensaje(Self.mensajeLegible(para: error as NSError)))
        }
    }

    private static func mensajeLegible(para error: NSError?) -> String {
        guard let error else {
            return "Falló la escritura del color en el ROG STRIX ARION."
        }

        if error.domain == ArionRGBErrorDomain {
            switch error.code {
            case 1:
                return "No se detectó el ROG STRIX ARION conectado."
            case 2:
                return "Limitación de macOS: este Arion no expone un user-client SCSI utilizable (IOCFPlugInTypes), por lo que la app no puede aplicar RGB desde user-space."
            case 3:
                return error.localizedDescription
            default:
                return error.localizedDescription
            }
        }

        return error.localizedDescription
    }
}

struct ColorRGB8 {
    let rojo: UInt8
    let verde: UInt8
    let azul: UInt8
}

private extension Color {
    var componentesRGB8: ColorRGB8? {
        guard
            let colorNS = NSColor(self).usingColorSpace(.deviceRGB)
        else {
            return nil
        }

        let rojo = UInt8(clamping: Int(round(colorNS.redComponent * 255)))
        let verde = UInt8(clamping: Int(round(colorNS.greenComponent * 255)))
        let azul = UInt8(clamping: Int(round(colorNS.blueComponent * 255)))

        return ColorRGB8(rojo: rojo, verde: verde, azul: azul)
    }
}
