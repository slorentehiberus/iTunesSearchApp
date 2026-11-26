# iTunesSearchApp — Convenciones del proyecto

App iOS nativa de búsqueda de canciones sobre la iTunes Search API. Estas reglas son obligatorias en todo el código nuevo.

## Stack y objetivos
- **Swift 6** con Strict Concurrency en `complete`. Todo lo que cruce aislamientos es `Sendable`. `async/await` y `actor`; nada de GCD ni completion handlers.
- **iOS 17.0+** como mínimo (el proyecto usa 17.6). Necesario por `@Observable`, `ContentUnavailableView`, `.searchable` moderno y `Clock` genérico.
- **SwiftUI 100%**. ViewModels con `@Observable` + `@MainActor`. Prohibido `ObservableObject`/`@Published`/Combine.
- **Tests: solo Swift Testing** (`import Testing`, `@Test`, `#expect`, `#require`, `@Suite`). Prohibido `XCTest` (salvo el target UITests generado por Xcode).
- Sin dependencias de terceros.

## Ajustes de build (ya aplicados)
- `SWIFT_VERSION = 6.0` en los 3 targets (implica concurrencia estricta completa).
- `IPHONEOS_DEPLOYMENT_TARGET = 17.6` en todos los targets.
- `SWIFT_DEFAULT_ACTOR_ISOLATION = nonisolated` para que `Domain` y `Data` no queden aislados a `MainActor`. El aislamiento a `@MainActor` se declara explícitamente en `Presentation`.
- En el paquete esos ajustes se reproducen en `layerSettings` de `Package.swift` (modo Swift 6, `NonisolatedNonsendingByDefault`, `InferIsolatedConformances`, `MemberImportVisibility`) y se aplican a todos los módulos y targets de test. Un módulo nuevo debe usar `layerSettings`.

## Domain: decisiones de concurrencia
- Entidades y value objects: `struct` inmutables (`let`), `Sendable`, `Hashable`. Sin `@unchecked Sendable`.
- Protocolos `SongRepository` y `SearchSongsUseCase` son `Sendable` con métodos `async throws`.
- `CancellationError` se propaga tal cual (nunca se envuelve). Cualquier otro error que llegue al caso de uso se convierte en `SearchError`.
- `SearchError.unknown(String)` conserva la descripción del error original (`String(describing:)`) para depurar.
- `Song` incluye los campos opcionales útiles de iTunes (`album`, `genre`, `releaseDate`, `artworkURL`, `price`, `previewURL`, `durationMilliseconds`) para no tener que tocar Domain al construir Data.
- **Requisito para Data:** `URLError(.cancelled)` (lo que lanza `URLSession` al cancelar la `Task`) debe mapearse a `CancellationError` en la capa Data; si no, el caso de uso lo convertiría en `SearchError.unknown` y la UI mostraría un error falso. Debe tener test.
- Query inválida (vacía/espacios) → el caso de uso devuelve `[]` sin llamar al repositorio.
- Resultados deduplicados por `Song.id` conservando el orden del servidor.

## Arquitectura (Clean Architecture)
Dependencias solo hacia dentro: `Presentation → Domain ← Data`. `App` (composition root) es el único que conoce las tres.

**Las capas son módulos de un paquete local** (`Packages/SearchKit`, módulos `Domain`, `Data`, `Presentation`), así que el compilador impone la regla: `Presentation` y `Data` dependen solo de `Domain` (ver `Package.swift`). Lo que cruza módulos es `public` (tipos, inicializadores y miembros que usa el composition root); lo demás es `internal` y los tests lo alcanzan con `@testable import`. Los archivos de Data y Presentation necesitan `import Domain` explícito. El paquete solo compila para iOS (Presentation usa UIKit).

```
iTunesSearchApp/                      Target de la app: composición, assets, InfoPlist.xcstrings
  iTunesSearchAppApp                  composition root / DI
  App/StubbedSearchSongsUseCase       solo DEBUG, para UI tests
Packages/SearchKit/Sources/
  Domain/         Swift puro. Sin SwiftUI, sin URLSession, sin Foundation de red.
    Entities/       Song (struct Sendable, Identifiable, Equatable)
    Repositories/   Protocolos (SongRepository)
    UseCases/       SearchSongsUseCase (normaliza query, reglas de negocio)
  Data/           Implementaciones.
    Network/        HTTPClientProtocol + URLSessionHTTPClient, ITunesSearchEndpoint, DataErrorMapper
    DTOs/           Decodables de la API + mapeo a entidades de Domain
    DataSources/    SongRemoteDataSource (protocolo), ITunesSongRemoteDataSource (URL, HTTP, status, decode, mapeo de errores)
    Cache/          SongCache (protocolo), SongMemoryCache (actor, TTL), CacheClock (reloj inyectable)
    Repositories/   RemoteSongRepository (adapta el data source) y CachedSongRepository (struct sin estado, Decorator: solo política de caché)
  Presentation/   SwiftUI.
    Search/Views/ (SearchView, SongRowView), Search/ViewModels/ (SearchViewModel, SearchViewState, SearchError+UserMessage)
    SongDetail/ (SongDetailView, SongDetailFormatter), Components/ (ArtworkView, ScrollableStateView, Song+Artwork)
Packages/SearchKit/Tests/  DomainTests/, DataTests/, PresentationTests/ y TestSupport/ (spies, fixtures, reloj manual y `waitUntil` compartidos)
iTunesSearchAppUITests/    UI tests (XCTest)
```

Reglas:
- `Domain` no importa `SwiftUI` ni `Data`/`Presentation`. `Presentation` no conoce DTOs ni `URLSession`.
- Programar contra protocolos (`SongRepository`, `HTTPClientProtocol`, `SongCache`, `CacheClock`), implementaciones intercambiables (DIP, OCP). Una responsabilidad por tipo (SRP); protocolos pequeños (ISP).
- Errores tipados en Domain (`SearchError`); la UI nunca ve errores de red crudos.
- Un tipo por archivo.
- **Idioma (regla estricta):** todo el código y todos los comentarios (`//`, `///`, `// MARK:`), identificadores, nombres de tests y descripciones de `@Test`/`@Suite` se escriben **en inglés**. Los textos visibles de UI van en `iTunesSearchApp/Localizable.xcstrings` (inglés + español), no hardcodeados. Esta documentación (`CLAUDE.md`) puede seguir en español.

## Inyección de dependencias
- Por **constructor**, con protocolos. Sin singletons ni service locators globales.
- `iTunesSearchAppApp` (composition root) crea el grafo real una vez: `URLSessionHTTPClient → ITunesSongRemoteDataSource → RemoteSongRepository → CachedSongRepository(cache: SongMemoryCache(clock: SystemCacheClock())) → DefaultSearchSongsUseCase → SearchViewModel`.
- Los tests y previews construyen el grafo con fakes; nunca tocan la red real.

## Búsqueda (search-as-you-type)
- `SearchViewModel` (`@MainActor @Observable`) reacciona a cada cambio del texto.
- **Debounce de 300 ms** (configurable por inyección) usando el `Clock` inyectado, no `Task.sleep` directo.
- Mantiene `searchTask: Task<Void, Never>?`; en cada pulsación se **cancela explícitamente** la anterior antes de crear la nueva y se comprueba `Task.isCancelled` / `Task.checkCancellation()` antes de publicar estado. Un resultado de una query obsoleta jamás debe pisar el estado actual.
- Estados de vista modelados con un `enum` (idle, loading, results, empty, error). Vacío/error con `ContentUnavailableView`.
- Query vacía o solo espacios → estado idle, sin red.

## Caché
- `actor SongMemoryCache` en memoria, indexada por **`SearchQuery`** (value object de Domain, `Hashable`), cuyo texto está normalizado con **trim + minúsculas + espacios internos colapsados**. **No se pliegan diacríticos** ("cafe" y "café" son claves distintas): el servidor puede devolver resultados distintos y compartirían caché incorrectamente. El texto enviado a la API es ese mismo texto normalizado.
- **TTL por defecto 3 minutos**, configurable por constructor (`ttl: Duration`).
- Reloj inyectado vía `CacheClock` (`now: Duration` monótono; `SystemCacheClock` usa `ContinuousClock`). `any Clock<Duration>` no sirve para esto porque su `Instant` existencial no es comparable. Una entrada con edad >= TTL está expirada. El debounce del ViewModel sí usará `Clock` (`sleep`).
- **Regla estricta:** entrada válida (no expirada) → se devuelve sin NINGUNA llamada de red. Ausente o expirada → red, y se actualiza la caché. Las entradas expiradas se eliminan al leerlas.
- Solo se cachean respuestas correctas, nunca errores.

## API
`https://itunes.apple.com/search?term={query}&entity=song&limit=25`
- Construir la URL con `URLComponents`/`URLQueryItem` (nunca concatenar el término).
- Filtrado en servidor; no filtrar en cliente.

## Accesibilidad (desde el diseño inicial)
- Cada celda de canción es **un solo elemento** de VoiceOver: `.accessibilityElement(children: .combine)` o `.ignore` + `accessibilityLabel` compuesto ("Título, de Artista, álbum Álbum") y `accessibilityHint` cuando aplique.
- Imágenes decorativas (carátulas) con `.accessibilityHidden(true)`.
- **Dynamic Type**: fuentes semánticas (`.headline`, `.subheadline`…), sin `frame(height:)` fijos ni `lineLimit` que corte texto; `@ScaledMetric` para tamaños de imagen; `ViewThatFits`/`@Environment(\.dynamicTypeSize)` para pasar de `HStack` a `VStack` en tamaños accesibilidad.
- Estados de carga/vacío/error con textos claros; el campo de búsqueda con label e hint.
- Textos de accesibilidad localizables.

## Testing (Swift Testing)
- `@Suite` por tipo bajo prueba; `@Test` con nombres descriptivos; `#expect`/`#require`.
- Prohibido `sleep` real y esperas largas: usar un **reloj manual** (`ManualClock: Clock`) en `Support/` que avanza el tiempo de forma determinista; TTL y debounce se prueban en milisegundos.
- Los helpers de `TestSupport` son `nonisolated` por defecto; los que reciben cierres no `Sendable` desde un test `@MainActor` (`waitUntil`, `settle`) se declaran `nonisolated(nonsending)` para ejecutarse en el aislamiento de quien llama.
- Mocks/fakes escritos a mano (sin librerías): `HTTPClientSpy` que cuenta llamadas y reproduce pasos, `SongRepositoryStub`, etc.
- Casos obligatorios: caché hit sin red; caché expirada → red; normalización de query; cancelación de búsqueda previa; resultado obsoleto no pisa al nuevo; debounce colapsa pulsaciones rápidas.

## Flujo de trabajo
- Antes de codificar una capa, explicar brevemente el diseño. Implementar de dentro hacia fuera: Domain → Data → Presentation → App.
- Cada pieza nueva viene con sus tests.
- Las carpetas del target de la app usan *synchronized groups* de Xcode: los archivos creados en disco entran solos al target. Los archivos del paquete los gestiona SwiftPM. No editar `project.pbxproj` a mano salvo para los ajustes de build indicados arriba.
- **Abrir `iTunesSearchApp.xcworkspace`, no el `.xcodeproj`.** El workspace contiene el proyecto y el paquete; solo así Xcode ofrece los tests del paquete en el plan de pruebas. Los tests de las capas se añaden al plan desde Xcode (Choose Targets…), no a mano.

## Data: decisiones
- **Decorator:** `CachedSongRepository` (política de caché) envuelve cualquier `SongRepository`; `RemoteSongRepository` adapta un `SongRemoteDataSource`. La red (URL, HTTP, status, decode) vive solo en `ITunesSongRemoteDataSource`.
- `HTTPClientProtocol` devuelve `(Data, HTTPURLResponse)` y lanza errores crudos; el data source los traduce con `DataErrorMapper`: `URLError(.cancelled)` → `CancellationError`; conectividad → `networkUnavailable`; HTTP no 2xx → `serverError`; `DecodingError` → `invalidResponse`; resto → `unknown(String)`.
- **Cancelación:** `Task.checkCancellation()` justo antes y después de la llamada HTTP; nunca se cachea un error ni el resultado de una petición cancelada.
- **Sin coalescencia de peticiones idénticas (decisión consciente):** el ViewModel cancela la búsqueda anterior en cada cambio y el debounce evita el solape; con un único consumidor no aporta nada y complica la cancelación. `CachedSongRepository` espera directamente al repositorio base, de modo que la cancelación se propaga por concurrencia estructurada hasta `URLSession`. No reintroducirla salvo que aparezcan varios consumidores de la misma consulta.
- **Caché:** TTL 180 s, expiradas purgadas en cada `store`; leer no alarga el TTL. Sin límite de tamaño ni LRU (decisión consciente: el enunciado pide solo TTL y memoria).
- DTOs con todos los campos opcionales; el mapper descarta ítems sin `trackId`/`trackName`/`artistName`. `trackPrice < 0` (no disponible) → `price` y `currencyCode` nil. El precio se convierte vía `Decimal(string:)` para no arrastrar ruido de `Double`.
- La URL se construye con `URLComponents`; el `+` literal se escapa a `%2B`.

## Presentation: decisiones
- `SearchViewModel` es `@MainActor @Observable`. `searchText` tiene accessors manuales (`access`/`withMutation`) para poder lanzar la búsqueda al escribir y seguir siendo observable; el resto del estado interno va con `@ObservationIgnored`.
- Estado: `SearchViewState` (`idle`, `loading`, `loaded([Song])`, `empty`, `error(String)`), `Equatable` y `Sendable`. Los errores llegan a la UI como `SearchError.userMessage` localizado, nunca como valores crudos.
- Cada cambio de texto cancela `searchTask` al instante. Texto vacío o solo espacios (misma regla que `SearchQuery`) → `.idle` sin tarea ni red. Si no, `Task` con debounce de 300 ms sobre el `any Clock<Duration>` inyectado.
- Tras cada `await` se comprueba `Task.isCancelled`; `CancellationError` nunca produce `.error`. Un resultado obsoleto jamás pisa el estado.
- **Nunca se muestran resultados de una búsqueda anterior** (requisito del enunciado): en cuanto el texto cambia a una búsqueda válida (o se pulsa Search/Retry) el estado pasa a `.loading`, descartando lista, vacío o error previos. Durante pulsaciones seguidas el estado permanece en `.loading` (sin parpadeo entre ellas). Solo texto en blanco vuelve a `.idle`.
- `retry()` y `submit()` (tecla Search del teclado, `.onSubmit(of: .search)`) lanzan la búsqueda actual sin debounce.
- Layout adaptativo: `AnyLayout` conmutando `HStack`/`VStack` según `dynamicTypeSize.isAccessibilitySize` (filas) y `horizontalSizeClass == .regular || verticalSizeClass == .compact` (detalle). Nada de `frame(width:height:)` en contenedores de texto; solo en la carátula, con `@ScaledMetric`. Pantallas de estado dentro de `ScrollableStateView` (centradas si caben, desplazables si no).
- Accesibilidad: filas con `.accessibilityElement(children: .combine)`, label "título, by artista" y hint "Double tap to view song details"; carátula de lista oculta; carátula del detalle con label y trait imagen.
- Las URLs de carátula de iTunes terminan en `100x100bb`; el detalle pide `600x600bb` (`Song.artworkURL(pixelSize:)`).
- Formato (`SongDetailFormatter`) puro y con `Locale` inyectable: fechas en UTC, precio con `FormatStyle.currency`, "Free"/"Not available".
- Composition root: `iTunesSearchAppApp` ensambla `URLSessionHTTPClient → ITunesSongRemoteDataSource → RemoteSongRepository → CachedSongRepository(SongMemoryCache) → DefaultSearchSongsUseCase → SearchViewModel → SearchView`.
- El proyecto tiene `MemberImportVisibility`: los miembros de Foundation (`String(localized:)`, `Date`, `HTTPURLResponse.statusCode`…) exigen `import Foundation` explícito aunque se importe SwiftUI.
- Tests: el esquema usa `iTunesSearchApp.xctestplan` (inglés, sin paralelo). `ManualClock` (en `Support/`) implementa `Clock`; `SearchSongsUseCaseSpy` permite pausar, liberar y ignorar la cancelación de cada llamada. Prohibido esperar tiempo real: `waitUntil` espera estado, `settle()` para comprobar que algo NO ocurre.

## Accesibilidad: implementación y verificación
- Todos los textos de VoiceOver salen de `SongAccessibility` (label de fila "título, by artista", hint, label de carátula, hint de Retry), puro y con tests unitarios. Nunca se escriben a mano en las vistas.
- Título del detalle con trait `.isHeader`; título+artista agrupados; carátula de lista oculta, carátula del detalle con label y trait imagen; filas de metadatos agrupadas ("Album, X").
- Identificadores no localizados (`songRow`, `searchResultsList`, `songDetail`) para los UI tests.
- **UI tests** (`iTunesSearchAppUITests`, XCTest: único sitio donde se permite): corren offline con el argumento `-UITestStubbedSearch`, que sustituye el caso de uso por `StubbedSearchSongsUseCase` (solo `#if DEBUG`; "zzzz" → vacío, "error" → fallo, resto → 3 canciones, una con textos muy largos). Usan `performAccessibilityAudit()` en bienvenida, resultados, detalle, vacío, error y con Dynamic Type `AccessibilityXXXL`; además un test de navegación (buscar → detalle → volver).
- Los UI tests exigen un simulador funcionando; sin él solo se puede comprobar que compilan.

## Localización (inglés + español)
- `Packages/SearchKit/Sources/Presentation/Resources/Localizable.xcstrings` (idioma fuente `en`, traducción `es`). **Todo texto se busca en el bundle del módulo**: `String(localized: "...", bundle: .module)`, `Text("...", bundle: .module)`; los literales sueltos (`navigationTitle("…")`, `ContentUnavailableView("…")`, `Button("…")`) buscan en el bundle de la app y NO traducen, así que se usan sus variantes con `Text(…, bundle: .module)`. Si falla, no hay error: se ve el texto en inglés.
- **`iTunesSearchApp/InfoPlist.xcstrings` es imprescindible**: es lo que declara la app como localizada en `en` y `es`. Sin él la app no tiene recursos en español propios e iOS se queda en inglés aunque el dispositivo esté en español, y ningún test lo detecta (comprobado en el simulador). No borrarlo. Toda cadena nueva de UI, de VoiceOver o de mensajes de error debe añadirse al catálogo en **ambos** idiomas: si falta una, el test de completitud falla.
- Interpolaciones: la clave es el formato (`"%@, by %@"`, `"%lld songs found"`); el español debe conservar los mismos especificadores.
- Fechas y precios no van en el catálogo: salen de `FormatStyle` con el `Locale` del dispositivo.
- **Los tests unitarios corren siempre en inglés**: `iTunesSearchApp.xctestplan` fija `language = en, region = US` (y desactiva el paralelo); para ejecutar solo el paquete a mano hace falta `-testLanguage en -testRegion US`. Así las aserciones sobre texto son deterministas, y `LocalizationTests` comprueba que es así.
- `LocalizationTests` valida el catálogo compilado del módulo (`Bundle.presentation`, interno a Presentation): mismas claves en `en` y `es`, sin traducciones vacías y con los mismos especificadores de formato.
- Los UI tests se ejecutan solo en inglés (`AccessibilityUITests`, en `iTunesSearchAppUITests/iTunesSearchAppUITests.swift`).
- Si se cambia un texto que los UI tests buscan, actualizar las constantes al inicio de `AccessibilityUITests`.

## Accesibilidad: contraste y auditorías
- No usar `.foregroundStyle(.secondary)` para texto: no cumple el contraste de la auditoría con texto pequeño sobre fondo blanco. Usar `.mutedText` (`Components/MutedText.swift`).
- Los UI tests usan el helper `audit(_:for:)`, que ejecuta `performAccessibilityAudit` y solo exime dos controles del propio iOS que la app no puede cambiar: el botón "borrar texto" de la barra de búsqueda (`_UITextFieldClearButton`, área táctil pequeña) y la barra de predicciones del teclado (`TUIPredictionViewCell`). Se identifican por nombre de clase en `detailedDescription`; cualquier otro hallazgo sigue fallando. Si iOS renombra esas clases, habrá que actualizar el helper.
- Pendiente de auditar: modo oscuro.

## Notas posteriores
- **VoiceOver anuncia el resultado de cada búsqueda** ("N songs found" / "1 song found", "No songs found" y el mensaje de error), igual que las demás prácticas comparadas: el foco se queda en el campo de búsqueda y el cambio pasaría inadvertido. Lo hace `SearchViewModel` a través de un `AccessibilityAnnouncer` inyectable (`SystemAccessibilityAnnouncer` en producción, `RecordingAnnouncer` en tests), con los textos en `SongAccessibility`. Una búsqueda cancelada u obsoleta no anuncia nada. Antes solo se anunciaban los errores; se cambió a propósito.
- Las filas añaden `accessibilityInputLabels([title])` para Control por voz.
- `.searchable` usa `placement: .navigationBarDrawer(displayMode: .always)` **solo en iPad** (`SearchView.searchPlacement`): allí la colocación por defecto es una pastilla pequeña arriba a la derecha, separada del título. En iPhone se mantiene la colocación por defecto: con el drawer fijo la auditoría de accesibilidad marcaba el campo como recortado y cortaba el título de bienvenida con Dynamic Type máximo. Batería completa (unitarios + UI) pasada en iPhone 17 y en iPad (A16, iOS 26.4).
- Anchura en pantallas grandes: `readableContentWidth(_:)` (`Components/ReadableContentWidth.swift`) limita y centra el contenido (lista 700 pt, detalle 900 pt, escalados con Dynamic Type). Sin efecto en iPhone. Los tests pasan en iPad; la revisión visual en horizontal, Split View y Slide Over sigue pendiente.
