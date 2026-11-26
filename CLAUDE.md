# iTunesSearchApp — Convenciones del proyecto

App iOS de búsqueda de canciones sobre la iTunes Search API (`https://itunes.apple.com/search?term={query}&entity=song&limit=25`). Prueba técnica: se valoran claridad, separación de capas y cancelación; no añadir features que nadie ha pedido. Estas reglas son obligatorias.

## Stack
- **Swift 6**, concurrencia estricta, iOS 17.6+, **SwiftUI 100%**, sin dependencias de terceros. `async/await` y `actor`; nada de GCD ni completion handlers.
- ViewModels `@MainActor @Observable`. Prohibido `ObservableObject`, `@Published` y Combine.
- Tests con **Swift Testing**; `XCTest` solo en el target de UI tests.
- Código, comentarios, identificadores y nombres de tests **en inglés**. Esta documentación, en español.

## Arquitectura
`Presentation → Domain ← Data`, cada capa un **módulo del paquete local `Packages/SearchKit`**, así que el compilador impone la regla (`Presentation` y `Data` dependen solo de `Domain`). La app (`iTunesSearchApp/`) es el único composition root y conoce las tres.
- Lo que cruza módulos es `public`; lo demás, `internal` y los tests lo alcanzan con `@testable import`. Data y Presentation necesitan `import Domain` explícito (y `import Foundation` donde se use: `MemberImportVisibility`).
- Módulos nuevos usan `layerSettings` de `Package.swift`. El paquete solo compila para iOS (Presentation usa UIKit).
- Programar contra protocolos (`SongRepository`, `HTTPClientProtocol`, `SongCache`, `CacheClock`). Inyección por constructor, sin singletons. Un tipo por archivo.
- Grafo real: `URLSessionHTTPClient → ITunesSongRemoteDataSource → RemoteSongRepository → CachedSongRepository(SongMemoryCache) → DefaultSearchSongsUseCase → SearchViewModel → SearchView`.

## Domain y Data
- Entidades y value objects: `struct` inmutables, `Sendable`, `Hashable`. Sin `@unchecked Sendable`. Domain es Swift puro (sin SwiftUI ni red).
- `SearchQuery` normaliza: trim, espacios internos colapsados, minúsculas; **no pliega diacríticos**. Ese texto es la clave de caché y lo que se envía a la API. Query vacía → `[]` sin llamar al repositorio. Resultados deduplicados por `Song.id`, conservando el orden.
- `CancellationError` se propaga tal cual; cualquier otro error se convierte en `SearchError` (`unknown(String)` conserva `String(describing:)`). **`URLError(.cancelled)` → `CancellationError`** en Data (`DataErrorMapper`); no hacerlo mostraría un error falso.
- La URL se construye con `URLComponents`; el `+` literal se escapa a `%2B`. Filtrado en servidor.
- **Caché:** `actor SongMemoryCache`, TTL 180 s (`ttl` configurable), reloj inyectado vía `CacheClock` (`any Clock` no sirve: su `Instant` no es comparable). Entrada con edad >= TTL expirada; las expiradas se purgan en cada `store`. Válida → sin red; ausente o expirada → red y se actualiza. Solo se cachean respuestas correctas, nunca errores ni resultados de peticiones canceladas.
- `CachedSongRepository` es un decorador sin estado: solo decide caché o red, y espera directamente al repositorio base para que la cancelación llegue hasta `URLSession`.
- **Decisiones conscientes, no reintroducir:** sin coalescencia de peticiones idénticas (un solo consumidor, el debounce evita el solape y complicaría la cancelación), sin LRU ni límite de tamaño, sin segunda llamada `/lookup` para el detalle (la búsqueda ya trae todo lo que muestra), sin paginación.

## Presentation
- `SearchViewModel`: `searchText` con accessors manuales (`access`/`withMutation`) para lanzar la búsqueda al escribir y seguir observable. Cada cambio **cancela `searchTask` al instante**; texto en blanco → `.idle` sin tarea ni red; si no, `.loading` **de inmediato** (nunca se ven resultados, vacío o error de un texto anterior) y un `Task` con debounce de 300 ms sobre el `Clock` inyectado.
- Tras cada `await` se comprueba `Task.isCancelled`; un resultado obsoleto jamás pisa el estado y `CancellationError` nunca produce `.error`. `retry()` y `submit()` buscan sin debounce.
- Estado: `SearchViewState` (`idle`, `loading`, `loaded`, `empty`, `error(String)`). La UI recibe `SearchError.userMessage` localizado, nunca errores crudos.
- **VoiceOver anuncia el resultado de cada búsqueda** (número de canciones, vacío, error) vía `AccessibilityAnnouncer` inyectable; una búsqueda cancelada u obsoleta no anuncia nada.
- Layout adaptativo: `AnyLayout` según `dynamicTypeSize.isAccessibilitySize` y size classes; tamaños con `@ScaledMetric`, sin `frame` fijos en texto. En iPad el campo de búsqueda va bajo el título (`.navigationBarDrawer`); en iPhone, colocación por defecto (con el drawer fijo la auditoría lo marca recortado).
- Fuentes semánticas. **No usar `.foregroundStyle(.secondary)` para texto** (contraste): usar `.mutedText`.

## Accesibilidad
- Cada fila es un solo elemento de VoiceOver con label y hint; carátula de lista oculta; título del detalle con trait `.isHeader`. Todos los textos de VoiceOver salen de `SongAccessibility`, nunca a mano en las vistas.
- Identificadores no localizados (`songRow`, `searchResultsList`, `songDetail`) para los UI tests.

## Localización (inglés + español)
- Catálogo: `Packages/SearchKit/Sources/Presentation/Resources/Localizable.xcstrings`. **Todo texto se busca en el bundle del módulo**: `String(localized:…, bundle: .module)` y `Text(…, bundle: .module)`. Los literales sueltos (`navigationTitle("…")`, `Button("…")`, `ContentUnavailableView("…")`) buscan en el bundle de la app y NO traducen; si falla se ve inglés, sin error.
- **`iTunesSearchApp/InfoPlist.xcstrings` es imprescindible**: declara la app como localizada en `en` y `es`. Sin él iOS se queda en inglés aunque el dispositivo esté en español. No borrarlo. Lo vigila un UI test que lanza la app en español.
- Toda cadena nueva (UI, VoiceOver, errores) va al catálogo en **ambos** idiomas, con los mismos especificadores; `LocalizationTests` lo comprueba. Fechas y precios salen de `FormatStyle` con el `Locale` del dispositivo.

## Tests
- Estructura: `iTunesSearchAppTests/{Domain,Data,Presentation,Support}` (un target del proyecto que importa los módulos con `@testable`) e `iTunesSearchAppUITests`. **⌘U desde `iTunesSearchApp.xcodeproj` ejecuta todo**; no hay workspace.
- `iTunesSearchApp.xctestplan` fija inglés (`en/US`) y desactiva el paralelo: los tests unitarios comparan textos en inglés. Los UI tests también van en inglés, salvo `testAppIsLocalizedInSpanish`.
- Prohibido `sleep` real: `ManualClock` y `ManualCacheClock` avanzan el tiempo a mano; `waitUntil` espera estado y `settle()` comprueba que algo NO ocurre (ambos `nonisolated(nonsending)`). Fakes escritos a mano (`SongRepositorySpy`, `SearchSongsUseCaseSpy`, `HTTPClientSpy`, `RecordingAnnouncer`, `StubURLProtocol`), sin librerías.
- Casos obligatorios: caché hit sin red; caché expirada → red; normalización de query; cancelación de la búsqueda previa (también contra una `URLSession` real); resultado obsoleto no pisa al nuevo; debounce colapsa pulsaciones rápidas. No añadir tests que solo repitan una constante o la cobertura de otro.
- UI tests offline con `-UITestStubbedSearch` (`StubbedSearchSongsUseCase`, solo `#if DEBUG`: "zzzz" → vacío, "error" → fallo, resto → 3 canciones). Usan `performAccessibilityAudit` vía el helper `audit(_:for:)`, que solo exime dos controles de iOS (`_UITextFieldClearButton`, `TUIPredictionViewCell`).

## Flujo de trabajo
- Explicar brevemente el diseño antes de codificar; de dentro hacia fuera: Domain → Data → Presentation → App. Cada pieza nueva viene con sus tests.
- Las carpetas del target de la app y de los tests usan *synchronized groups*: los archivos entran solos. No editar `project.pbxproj` a mano salvo para ajustes de build.
- Un solo simulador a la vez; no compilar Release salvo que se pida.
- **Commits sin ninguna atribución a Claude** (sin `Co-Authored-By` ni "Generated with"); solo se commitea cuando se pide.
- Sin verificar todavía: VoiceOver real, modo oscuro, Release, iPad en horizontal y Split View.
