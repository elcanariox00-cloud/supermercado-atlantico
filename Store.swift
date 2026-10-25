import SwiftUI
import UserNotifications

// MARK: - Modelos
struct Product: Identifiable, Hashable {
    let id: Int, cat: String, emoji: String, name: String, price: Double
    static let offerID = 999
    static let offer = Product(id: 999, cat: "Oferta", emoji: "🥖", name: "Barra de pan (oferta 5x2€)", price: 2)
    var isOffer: Bool { id == Product.offerID }
}
enum Method: String, Codable, CaseIterable {
    case saldo = "Con saldo", tarjeta = "Tarjeta", recibir = "Al recibir"
    var paidLabel: String { self == .saldo ? "Pagado con saldo" : self == .tarjeta ? "Pagado con tarjeta" : "Pago al recibir" }
}
enum Stage: Int, Codable { case preparing, onTheWay, delivered }
enum OfferState: String, Codable { case fresh, accepted, denied }
struct Order: Identifiable, Codable {
    let id: Int; let date: Date; let total: Double; let method: Method; var stage: Stage; let lines: [String]
}

let barrios = ["Barrial", "Caideros", "Fagajesto", "Gáldar Centro", "Juncalillo", "La Montaña", "Los Quintana", "Marmolejos", "Piso Firme", "San Isidro", "Sardina del Norte"]
let categories = ["Frutas y verduras", "Carne y pescado", "Lácteos y huevos", "Panadería", "Despensa", "Bebidas", "Congelados", "Limpieza", "Higiene", "Hogar y mascotas"]
// Mismo formato que la demo web: emoji|nombre|precio;...  (añade aquí más productos)
private let rawCatalog = [
    "🍌|Plátano de Canarias kg|2.20;🍎|Manzana golden kg|1.99;🍅|Tomate rama kg|2.35;🥔|Papas arrugadas 2kg|2.90",
    "🍗|Pechuga de pollo 500g|4.50;🐟|Sardinas frescas 500g|3.80;🥩|Carne picada mixta 500g|3.95;🦐|Gambas peladas 250g|5.90",
    "🥛|Leche entera 1L|0.95;🧀|Queso de flor de Guía 300g|6.50;🥚|Huevos camperos 12 uds|3.25;🍦|Yogur natural 4 uds|1.45",
    "🍞|Pan de molde 600g|1.65;🥖|Barra de pan|0.55;🥐|Croissants 6 uds|2.10;🍪|Galletas María 800g|1.95",
    "🍚|Arroz largo 1kg|1.65;🌾|Gofio de trigo 1kg|2.70;🌶️|Mojo picón 250ml|2.45;🫒|Aceite de oliva virgen extra 1L|8.95",
    "💧|Agua mineral 6x1,5L|2.40;🍺|Cerveza Tropical pack 6|5.40;☕|Café molido 250g|3.20;🧃|Zumo de piña 1L|1.40",
    "🍕|Pizza margarita|2.95;🍟|Patatas fritas congeladas 1kg|2.20;🧆|Croquetas de jamón 500g|3.10;🍦|Helado de vainilla 1L|3.45",
    "🧴|Detergente líquido 40 lavados|8.95;🧼|Lavavajillas 750ml|1.75;🧻|Papel higiénico 12 rollos|4.60;🧽|Estropajos 3 uds|1.25",
    "🚿|Gel de ducha 750ml|2.20;🧴|Champú 400ml|2.95;🪥|Cepillo de dientes 2 uds|2.40;☀️|Protector solar SPF50 200ml|9.50",
    "🐕|Pienso para perro 3kg|6.95;🐈|Comida para gato 12 sobres|4.80;🔋|Pilas AA 8 uds|4.20;💡|Bombilla LED|2.50"
]
let catalog: [Product] = {
    var out: [Product] = []
    for (ci, s) in rawCatalog.enumerated() {
        for item in s.split(separator: ";") {
            let a = item.split(separator: "|")
            out.append(Product(id: out.count, cat: categories[ci], emoji: String(a[0]), name: String(a[1]), price: Double(a[2]) ?? 0))
        }
    }
    return out
}()
func eur(_ v: Double) -> String { String(format: "%.2f €", v).replacingOccurrences(of: ".", with: ",") }

// MARK: - Notificaciones (locales, con sonido)
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()
    func userNotificationCenter(_ c: UNUserNotificationCenter, willPresent n: UNNotification, withCompletionHandler h: @escaping (UNNotificationPresentationOptions) -> Void) { h([.banner, .sound]) }
    func send(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: c, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)))
    }
}

// MARK: - Estado de la app
final class Store: ObservableObject {
    @Published var balance = 0.0 { didSet { save() } }
    @Published var points = 0 { didSet { save() } }
    @Published var orders: [Order] = [] { didSet { save() } }
    @Published var offer = OfferState.fresh { didSet { save() } }
    @Published var cart: [Int: Int] = [:]
    @Published var tab = 0
    @Published var showOffer = false
    @Published var showBanner = false
    @Published var delivered: Order?

    private struct Saved: Codable { var balance: Double; var points: Int; var orders: [Order]; var offer: OfferState }
    private func save() {
        if let d = try? JSONEncoder().encode(Saved(balance: balance, points: points, orders: orders, offer: offer)) { UserDefaults.standard.set(d, forKey: "sa") }
    }
    private var timer: Timer?

    init() {
        if let d = UserDefaults.standard.data(forKey: "sa"), let s = try? JSONDecoder().decode(Saved.self, from: d) {
            balance = s.balance; points = s.points; orders = s.orders; offer = s.offer
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        // Oferta: a los 6 s y luego cada 5 min
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.tick()
            self.timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in self.tick() }
        }
    }

    // Carrito
    func product(_ id: Int) -> Product { id == Product.offerID ? Product.offer : catalog[id] }
    func units(_ id: Int) -> Int { (cart[id] ?? 0) * (id == Product.offerID ? 5 : 1) }
    var count: Int { cart.keys.reduce(0) { $0 + units($1) } }
    var subtotal: Double { cart.reduce(0) { $0 + product($1.key).price * Double($1.value) } }
    var shipping: Double { cart.isEmpty || subtotal >= 40 ? 0 : 3.5 }
    var total: Double { subtotal + shipping }
    func change(_ id: Int, _ d: Int) {
        let n = (cart[id] ?? 0) + d
        if n <= 0 { cart[id] = nil } else { cart[id] = n }
    }
    func recharge(_ v: Double) { balance = ((balance + v) * 100).rounded() / 100 }

    // Pedidos
    func place(method: Method) -> String? {
        let t = total
        if method == .saldo && t > balance { return "Saldo insuficiente: te faltan \(eur(t - balance))." }
        let lines = cart.keys.sorted().map { "\(units($0)) × \(product($0).name)" }
        if method == .saldo { balance = ((balance - t) * 100).rounded() / 100 }
        points += 10
        let o = Order(id: Int.random(in: 10000...99999), date: Date(), total: t, method: method, stage: .preparing, lines: lines)
        orders.insert(o, at: 0); cart = [:]; tab = 2
        Notifier.shared.send("🧑‍🍳 Pedido #\(o.id) recibido", "Se está preparando. Te avisaremos cuando salga.")
        return nil
    }
    func advance(_ id: Int) {
        guard let i = orders.firstIndex(where: { $0.id == id }), orders[i].stage != .delivered,
              let n = Stage(rawValue: orders[i].stage.rawValue + 1) else { return }
        orders[i].stage = n
        let go = n == .onTheWay
        Notifier.shared.send(go ? "🛵 Tu pedido va en camino" : "✅ Pedido entregado",
                             "Pedido #\(id) · " + (go ? "El repartidor ha salido hacia tu dirección." : "¡Que lo disfrutes! Gracias por elegirnos."))
        if n == .delivered {
            delivered = orders[i]
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { self.delivered = nil }
        }
    }
    func resetAll() { balance = 0; points = 0; orders = []; cart = [:]; offer = .fresh; showBanner = false; showOffer = false }

    // Oferta 5x2€
    func tick() {
        guard offer != .accepted, !showOffer else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        if offer == .denied {
            showBanner = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 20) { self.showBanner = false }
        } else { showOffer = true }
    }
    func acceptOffer() {
        cart[Product.offerID] = max(1, cart[Product.offerID] ?? 0)
        offer = .accepted; showOffer = false; showBanner = false
        Notifier.shared.send("🛒 Oferta añadida", "5 barras de pan por 2,00 € ya están en tu carrito.")
    }
    func denyOffer() { showOffer = false; offer = .denied }
}
