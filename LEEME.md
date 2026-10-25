# Super Atlántico — app cliente (iOS nativa, SwiftUI)

Necesitas un Mac con Xcode 15 o superior. iPhone con iOS 16+.

## Opción A: con XcodeGen (un comando)
1. `brew install xcodegen`
2. En esta carpeta: `xcodegen`  → crea `SuperAtlantico.xcodeproj`
3. Ábrelo, elige tu iPhone, en *Signing & Capabilities* selecciona tu Team (vale un Apple ID gratuito) y pulsa ▶︎.

## Opción B: a mano
1. Xcode → File → New → Project → iOS → App (Interface: SwiftUI, Language: Swift), nombre `SuperAtlantico`.
2. Borra `ContentView.swift` y el archivo @main que crea Xcode.
3. Arrastra a la carpeta del proyecto los 3 archivos de `SuperAtlantico/`: `SuperAtlanticoApp.swift`, `Store.swift`, `Views.swift`.
4. Selecciona tu iPhone, tu Team, y ▶︎.

## Notas
- Con Apple ID gratuito la app caduca a los 7 días (se reinstala desde Xcode). Para TestFlight/App Store hace falta Apple Developer Program (99 €/año).
- Acepta el permiso de notificaciones al abrir la app.
- No está conectada a la app del repartidor: en *Pedidos*, el botón «Simular siguiente paso del repartidor» hace de repartidor. La conexión real necesita un servidor.
