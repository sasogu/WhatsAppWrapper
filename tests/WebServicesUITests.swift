import XCTest
import Network

final class WebServicesUITests: XCTestCase {
    private var app: XCUIApplication!
    private var fixture: WebFixture!

    override func setUpWithError() throws {
        continueAfterFailure = false
        fixture = try WebFixture()
        let ready = expectation(description: "Servidor de prueba preparado")
        fixture.start { ready.fulfill() }
        wait(for: [ready], timeout: 10)
        app = XCUIApplication()
        app.launchEnvironment["WEB_SERVICES_UI_TESTING"] = "1"
        app.launchEnvironment["WEB_SERVICES_UI_RESET"] = "1"
        app.launch()
    }

    override func tearDownWithError() throws {
        app?.terminate()
        fixture?.stop()
    }

    private func addWeb(named name: String) {
        app.buttons["start-add-web"].tap()
        let title = app.textFields["web-name"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText(name)
        let address = app.textFields["web-address"]
        address.tap()
        address.typeText(fixture.address)
        app.buttons["Guardar"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Contenido 1"].waitForExistence(timeout: 15))
    }

    func testAddEditAndRestoreWeb() {
        XCTAssertTrue(app.staticTexts["Tus webs, en un solo lugar"].exists)
        addWeb(named: "Prueba")
        app.buttons["Gestionar webs"].tap()
        app.buttons.containing(.staticText, identifier: "Prueba").firstMatch.tap()
        let title = app.textFields["web-name"]
        title.tap()
        // Seleccionar todo sin depender del idioma del menú de edición.
        title.press(forDuration: 1.2)
        if app.menuItems["Select All"].exists { app.menuItems["Select All"].tap() }
        else if app.menuItems["Seleccionar todo"].exists { app.menuItems["Seleccionar todo"].tap() }
        else { title.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 6)) }
        title.typeText("Mi web")
        app.buttons["Guardar"].tap()
        app.buttons["Hecho"].tap()
        app.terminate()
        app.launchEnvironment["WEB_SERVICES_UI_RESET"] = "0"
        app.launch()
        XCTAssertTrue(app.staticTexts["Mi web"].firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(app.webViews.staticTexts["Contenido 1"].waitForExistence(timeout: 15))
    }

    func testNativeConfirmationAndCacheResetPreserveSession() {
        addWeb(named: "Prueba")
        app.webViews.buttons["Confirmar"].tap()
        XCTAssertTrue(app.alerts["Prueba"].waitForExistence(timeout: 5))
        app.alerts.buttons["Cancelar"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Cancelado"].waitForExistence(timeout: 5))
        app.webViews.buttons["Confirmar"].tap()
        app.alerts.buttons["Aceptar"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Aceptado"].waitForExistence(timeout: 5))
        fixture.setVersion(2)
        app.buttons["Más opciones"].tap()
        app.buttons["Limpiar caché y recargar"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Contenido 2"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.webViews.staticTexts["Sesión conservada"].exists)
        app.buttons["Gestionar webs"].tap()
        XCTAssertTrue(app.staticTexts["EduWeb"].exists)
    }
}

// Servidor local con datos ficticios. No accede a correo ni a servicios del usuario.
private final class WebFixture {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "WebFixture")
    private let lock = NSLock()
    private var version = 1
    var address: String { "http://127.0.0.1:\(listener.port!.rawValue)/" }

    init() throws { listener = try NWListener(using: .tcp, on: .any) }
    func start(ready: @escaping () -> Void) {
        listener.stateUpdateHandler = { if case .ready = $0 { ready() } }
        listener.newConnectionHandler = { [weak self] connection in
            connection.start(queue: self?.queue ?? .global())
            connection.receive(minimumIncompleteLength: 1, maximumLength: 32768) { data, _, _, _ in
                guard let self, let data else { connection.cancel(); return }
                let asset = String(data: data, encoding: .utf8)?.hasPrefix("GET /asset.js") == true
                self.lock.lock()
                let version = self.version
                self.lock.unlock()
                let body = asset ? "document.getElementById('content').textContent = 'Contenido \(version)';" : """
                <!doctype html><html lang="es"><head><meta name="viewport" content="width=device-width"></head>
                <body><h1 id="content"></h1><p id="session"></p><button onclick="document.getElementById('result').textContent=confirm('Confirmación de prueba')?'Aceptado':'Cancelado'">Confirmar</button><p id="result"></p>
                <script>document.getElementById('session').textContent=document.cookie.includes('fixtureSession=kept')?'Sesión conservada':'Sesión nueva';document.cookie='fixtureSession=kept;path=/';</script>
                <script src="/asset.js"></script></body></html>
                """
                let type = asset ? "application/javascript" : "text/html"
                let cache = asset ? "max-age=3600" : "no-store"
                let bytes = Data(body.utf8)
                let headers = "HTTP/1.1 200 OK\r\nContent-Type: \(type); charset=utf-8\r\nCache-Control: \(cache)\r\nContent-Length: \(bytes.count)\r\nConnection: close\r\n\r\n"
                connection.send(content: Data(headers.utf8) + bytes, completion: .contentProcessed { _ in connection.cancel() })
            }
        }
        listener.start(queue: queue)
    }
    func setVersion(_ value: Int) { lock.lock(); version = value; lock.unlock() }
    func stop() { listener.cancel() }
}
