import Foundation

// Configuración vacía para instalaciones nuevas. Las webs se añaden en la app.
// El build admite Services.local.swift como importación de configuraciones antiguas;
// está en .gitignore para no publicar URLs privadas.
extension WebService {
    static let local: [WebService] = [
        // WebService(
        //     id: "correo",
        //     name: "Correo",
        //     systemImage: "envelope",
        //     url: URL(string: "https://mail.example.org/")!,
        //     allowedHostSuffixes: ["mail.example.org"]
        // )
    ]
}
