import SwiftUI

// MARK: - Raíz
struct RootView: View {
    @EnvironmentObject var s: Store
    @State private var recharge = false
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button { recharge = true } label: {
                    HStack { Text("💰 Saldo"); Text(eur(s.balance)).bold(); Spacer(); Image(systemName: "plus.circle.fill").foregroundColor(.green) }
                        .padding(10).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
                }.buttonStyle(.plain)
                HStack { Text("⭐ Puntos"); Spacer(); Text("\(s.points)").bold() }
                    .padding(10).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 12))
            }.padding(.horizontal).padding(.vertical, 6)
            TabView(selection: $s.tab) {
                ShopView().tabItem { Label("Tienda", systemImage: "house") }.tag(0)
                CartView().tabItem { Label("Carrito", systemImage: "cart") }.badge(s.count).tag(1)
                OrdersView().tabItem { Label("Pedidos", systemImage: "shippingbox") }.tag(2)
            }.tint(.green)
        }
        .sheet(isPresented: $recharge) { RechargeView() }
        .overlay { if s.showOffer { OfferModal() } }
        .overlay(alignment: .top) { if s.showBanner { OfferBanner() } }
        .overlay(alignment: .bottom) { if let o = s.delivered { DeliveredCard(order: o) } }
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: s.showOffer)
        .animation(.easeOut(duration: 0.4), value: s.showBanner)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: s.delivered?.id)
    }
}

// MARK: - Tienda
struct ShopView: View {
    @EnvironmentObject var s: Store
    @State private var cat = "Todo"
    @State private var q = ""
    var items: [Product] { catalog.filter { (cat == "Todo" || $0.cat == cat) && (q.isEmpty || $0.name.localizedCaseInsensitiveContains(q)) } }
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(["Todo"] + categories, id: \.self) { c in
                                Button(c) { cat = c }
                                    .padding(.horizontal, 14).padding(.vertical, 7)
                                    .background(cat == c ? Color.green : Color(.secondarySystemBackground))
                                    .foregroundColor(cat == c ? .white : .primary).clipShape(Capsule())
                            }
                        }
                    }
                    Text("🚚 Envío a domicilio 3,50 € · gratis desde 40 €").font(.footnote).foregroundColor(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(items) { p in ProductCard(p: p) }
                    }
                }.padding()
            }
            .navigationTitle("Super Atlántico")
            .searchable(text: $q, prompt: "Buscar productos")
        }
    }
}
struct ProductCard: View {
    @EnvironmentObject var s: Store
    let p: Product
    var body: some View {
        VStack(spacing: 4) {
            Text(p.emoji).font(.system(size: 44))
            Text(p.name).font(.subheadline).lineLimit(2).multilineTextAlignment(.center).frame(minHeight: 40)
            HStack {
                Text(eur(p.price)).bold()
                Spacer()
                if s.cart[p.id] != nil { QtyStepper(id: p.id) }
                else { Button { s.change(p.id, 1) } label: { Image(systemName: "plus.circle.fill").font(.title2) }.tint(.green) }
            }
        }
        .padding(12).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
struct QtyStepper: View {
    @EnvironmentObject var s: Store
    let id: Int
    var body: some View {
        HStack(spacing: 10) {
            Button { s.change(id, -1) } label: { Image(systemName: "minus.circle") }
            Text("\(s.units(id))").frame(minWidth: 24).monospacedDigit()
            Button { s.change(id, 1) } label: { Image(systemName: "plus.circle.fill") }
        }.buttonStyle(.borderless).font(.title3).tint(.green)
    }
}

// MARK: - Carrito
struct CartView: View {
    @EnvironmentObject var s: Store
    func row(_ a: String, _ b: String, bold: Bool = false) -> some View {
        HStack { Text(a); Spacer(); Text(b) }.fontWeight(bold ? .bold : .regular)
    }
    var body: some View {
        NavigationStack {
            if s.cart.isEmpty {
                Text("🛒 Tu carrito está vacío").foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity).navigationTitle("Carrito")
            } else {
                List {
                    ForEach(s.cart.keys.sorted(), id: \.self) { id in
                        let p = s.product(id)
                        HStack {
                            Text(p.emoji).font(.largeTitle)
                            VStack(alignment: .leading) {
                                Text(p.name)
                                Text(p.isOffer ? "5 uds por 2,00 € · antes 2,75 €" : eur(p.price)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            QtyStepper(id: id)
                        }
                    }
                    Section {
                        row("Subtotal", eur(s.subtotal))
                        row("Envío", s.shipping == 0 ? "Gratis" : eur(s.shipping))
                        row("Total", eur(s.total), bold: true)
                    }
                    Section { NavigationLink("Continuar") { CheckoutView() } }
                }.navigationTitle("Carrito")
            }
        }
    }
}

// MARK: - Finalizar pedido
struct CheckoutView: View {
    @EnvironmentObject var s: Store
    @Environment(\.dismiss) var dismiss
    @State private var name = "", phone = "", address = "", barrio = ""
    @State private var method = Method.saldo
    @State private var card = "", exp = "", cvc = ""
    @State private var error = ""
    @State private var recharge = false
    var label: String { (method == .saldo ? "Pagar con saldo · " : method == .tarjeta ? "Pagar con tarjeta · " : "Confirmar pedido · ") + eur(s.total) }
    var body: some View {
        Form {
            Section("Datos de entrega") {
                TextField("Nombre", text: $name)
                TextField("Teléfono", text: $phone).keyboardType(.phonePad)
                TextField("Dirección", text: $address)
                Picker("Barrio", selection: $barrio) {
                    Text("Elegir…").tag("")
                    ForEach(barrios, id: \.self) { Text($0).tag($0) }
                }
            }
            Section("Pago") {
                Picker("Método", selection: $method) { ForEach(Method.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                if method == .saldo {
                    HStack { Text("💰 Saldo disponible \(eur(s.balance))"); Spacer(); Button("Recargar") { recharge = true }.buttonStyle(.borderless) }
                }
                if method == .tarjeta {
                    TextField("Tarjeta 4242 4242 4242 4242", text: $card).keyboardType(.numberPad)
                    TextField("MM/AA", text: $exp)
                    TextField("CVC", text: $cvc).keyboardType(.numberPad)
                }
            }
            Section("Resumen") {
                ForEach(s.cart.keys.sorted(), id: \.self) { id in Text("\(s.units(id)) × \(s.product(id).name)") }
                HStack { Text("Total").bold(); Spacer(); Text(eur(s.total)).bold() }
            }
            if !error.isEmpty { Text(error).foregroundColor(.red) }
            Button { confirm() } label: { Text(label).bold().frame(maxWidth: .infinity) }.buttonStyle(.borderedProminent).tint(.green)
        }
        .navigationTitle("Finalizar pedido")
        .sheet(isPresented: $recharge) { RechargeView() }
    }
    func confirm() {
        if name.trimmingCharacters(in: .whitespaces).isEmpty || address.isEmpty || barrio.isEmpty || phone.filter(\.isNumber).count < 9 {
            error = "Completa nombre, teléfono (9 dígitos), dirección y barrio."; return
        }
        if method == .tarjeta {
            if card.filter(\.isNumber).count != 16 { error = "El número de tarjeta debe tener 16 dígitos."; return }
            if exp.range(of: #"^(0[1-9]|1[0-2])/\d\d$"#, options: .regularExpression) == nil { error = "La caducidad debe tener el formato MM/AA."; return }
            if !(3...4).contains(cvc.count) { error = "El CVC debe tener 3 o 4 dígitos."; return }
        }
        if let e = s.place(method: method) { error = e } else { error = ""; dismiss() }
    }
}

// MARK: - Pedidos
struct OrdersView: View {
    @EnvironmentObject var s: Store
    var body: some View {
        NavigationStack {
            List {
                if s.orders.isEmpty { Text("📦 Aún no has hecho ningún pedido").foregroundColor(.secondary) }
                ForEach(s.orders) { o in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack { Text("Pedido #\(o.id)").bold(); Spacer(); Text(eur(o.total)) }
                        Text(o.date.formatted(date: .abbreviated, time: .shortened) + " · " + o.method.paidLabel).font(.caption).foregroundColor(.secondary)
                        ForEach(o.lines, id: \.self) { Text($0).font(.subheadline) }
                        HStack(spacing: 6) {
                            ForEach(0..<3, id: \.self) { i in
                                VStack(spacing: 4) {
                                    Capsule().fill(i <= o.stage.rawValue ? Color.green : Color.gray.opacity(0.3)).frame(height: 5)
                                    Text(["🧑‍🍳 Preparando", "🛵 En camino", "✅ Entregado"][i]).font(.caption2)
                                }
                            }
                        }
                        if o.stage != .delivered {
                            Button("▶︎ Simular siguiente paso del repartidor") { s.advance(o.id) }.font(.footnote).buttonStyle(.borderless)
                        }
                    }.padding(.vertical, 4)
                }
                Section { Button("Reiniciar todo", role: .destructive) { s.resetAll() } }
            }.navigationTitle("Pedidos")
        }
    }
}

// MARK: - Recargar saldo
struct RechargeView: View {
    @EnvironmentObject var s: Store
    @Environment(\.dismiss) var dismiss
    enum Kind: String, CaseIterable { case tarjeta = "💳 Tarjeta", bizum = "📱 Bizum", paypal = "🅿️ PayPal", apple = "🍎 Apple Pay" }
    @State private var amount = ""
    @State private var kind = Kind.tarjeta
    @State private var name = "", card = "", exp = "", cvc = "", phone = "", mail = ""
    @State private var error = ""
    @State private var busy = false, done = false
    var value: Double { Double(amount.replacingOccurrences(of: ",", with: ".")) ?? 0 }
    var body: some View {
        NavigationStack {
            Form {
                if done {
                    Section {
                        Text("✅ Recarga completada: +\(eur(value)). Nuevo saldo: \(eur(s.balance))")
                        Button("Listo") { dismiss() }
                    }
                } else {
                    Section("Cantidad") {
                        HStack {
                            ForEach([10, 20, 50, 100], id: \.self) { n in
                                Button("\(n) €") { amount = "\(n)" }.buttonStyle(.bordered).tint(amount == "\(n)" ? .green : .gray)
                            }
                        }
                        TextField("Otra cantidad (1–500 €)", text: $amount).keyboardType(.decimalPad)
                    }
                    Section("Método de pago") {
                        Picker("Método", selection: $kind) { ForEach(Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                        switch kind {
                        case .tarjeta:
                            TextField("Titular", text: $name)
                            TextField("Tarjeta 4242 4242 4242 4242", text: $card).keyboardType(.numberPad)
                            TextField("MM/AA", text: $exp)
                            TextField("CVC", text: $cvc).keyboardType(.numberPad)
                        case .bizum: TextField("Teléfono", text: $phone).keyboardType(.numberPad)
                        case .paypal: TextField("Correo de PayPal", text: $mail).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                        case .apple: Text("Confirmarás con Face ID (simulado)").font(.footnote)
                        }
                    }
                    if !error.isEmpty { Text(error).foregroundColor(.red) }
                    Section {
                        Button { pay() } label: {
                            if busy { ProgressView().frame(maxWidth: .infinity) }
                            else { Text(value >= 1 ? "Recargar \(eur(value))" : "Recargar").bold().frame(maxWidth: .infinity) }
                        }.disabled(busy)
                        Text("Demo: no se cobra nada real.").font(.footnote).foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Recargar saldo")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } } }
        }
    }
    func pay() {
        guard value >= 1 && value <= 500 else { error = "Elige o escribe una cantidad entre 1 y 500 €."; return }
        switch kind {
        case .tarjeta:
            if name.count < 2 { error = "Escribe el nombre del titular."; return }
            if card.filter(\.isNumber).count != 16 { error = "El número de tarjeta debe tener 16 dígitos."; return }
            if exp.range(of: #"^(0[1-9]|1[0-2])/\d\d$"#, options: .regularExpression) == nil { error = "La caducidad debe tener el formato MM/AA."; return }
            if !(3...4).contains(cvc.count) { error = "El CVC debe tener 3 o 4 dígitos."; return }
        case .bizum: if phone.filter(\.isNumber).count != 9 { error = "Escribe un teléfono de 9 dígitos."; return }
        case .paypal: if !mail.contains("@") || !mail.contains(".") { error = "Escribe un correo válido."; return }
        case .apple: break
        }
        error = ""; busy = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { s.recharge(value); busy = false; done = true }
    }
}

// MARK: - Oferta 5x2€ (centro) y banner (arriba)
struct OfferModal: View {
    @EnvironmentObject var s: Store
    @State private var wob = false
    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(spacing: 8) {
                Text("⚡ OFERTA RELÁMPAGO").font(.caption.bold()).padding(.horizontal, 12).padding(.vertical, 4)
                    .background(Color.red).foregroundColor(.white).clipShape(Capsule())
                Text("🥖").font(.system(size: 56)).rotationEffect(.degrees(wob ? 8 : -8))
                Text("5x2€").font(.system(size: 54, weight: .black)).foregroundColor(.green).scaleEffect(wob ? 1.08 : 1)
                Text("5 barras de pan frescas por solo 2 €").multilineTextAlignment(.center)
                Text("Precio normal 2,75 €").font(.caption).strikethrough().foregroundColor(.secondary)
                HStack {
                    Button("Denegar") { s.denyOffer() }.buttonStyle(.plain)
                        .frame(maxWidth: .infinity).padding().background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 14))
                    Button("Aceptar") { s.acceptOffer() }.buttonStyle(.plain)
                        .frame(maxWidth: .infinity).padding().background(Color.green).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 14))
                }.font(.headline).padding(.top, 6)
                Text("Al aceptar se añade al carrito").font(.caption2).foregroundColor(.secondary)
            }
            .padding(20).frame(maxWidth: 320).background(Color(.systemBackground)).clipShape(RoundedRectangle(cornerRadius: 26)).padding(24)
        }
        .transition(.scale.combined(with: .opacity))
        .onAppear { withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) { wob = true } }
    }
}
struct OfferBanner: View {
    @EnvironmentObject var s: Store
    @State private var x = UIScreen.main.bounds.width
    @State private var spin = 0.0
    let words = ["🔥", "OFERTA", "5x2€", "·", "5", "barras", "de", "pan", "por", "solo", "2€", "🥖", "¡Toca", "para", "añadir!", "🔥"]
    var body: some View {
        ZStack(alignment: .leading) {
            LinearGradient(colors: [.red, .orange], startPoint: .leading, endPoint: .trailing)
            HStack(spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { i, w in
                    Text(w).font(.headline.weight(.heavy)).foregroundColor(.white).fixedSize()
                        .rotation3DEffect(.degrees(spin), axis: (x: 1, y: 0, z: 0))
                        .animation(.linear(duration: 1.6).repeatForever(autoreverses: false).delay(Double(i) * 0.14), value: spin)
                }
            }.fixedSize().offset(x: x)
        }
        .frame(height: 44).clipped().contentShape(Rectangle()).onTapGesture { s.acceptOffer() }
        .overlay(alignment: .trailing) {
            Button { s.showBanner = false } label: { Image(systemName: "xmark.circle.fill").foregroundColor(.white).padding(8) }
        }
        .transition(.move(edge: .top))
        .onAppear {
            x = UIScreen.main.bounds.width
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) { x = -620 }
            spin = 360
        }
    }
}

// MARK: - Pedido entregado
struct DeliveredCard: View {
    @EnvironmentObject var s: Store
    let order: Order
    var body: some View {
        VStack(spacing: 8) {
            Text("🎉").font(.system(size: 64))
            Text("¡Felicidades, tu pedido fue entregado!").font(.title2.bold()).multilineTextAlignment(.center)
            Text("Pedido #\(order.id) · Gracias por elegirnos 💚").foregroundColor(.secondary)
            Button { s.delivered = nil } label: {
                Text("¡Genial!").font(.headline).frame(maxWidth: .infinity).padding()
                    .background(Color.green).foregroundColor(.white).clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(24).frame(maxWidth: .infinity).background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 26)).shadow(radius: 20)
        .transition(.move(edge: .bottom))
    }
}
