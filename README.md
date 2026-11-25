# Iberia

App iOS de búsqueda de canciones. Escribes y los resultados aparecen en una lista; al tocar una canción se abre su detalle.

## API elegida

[iTunes Search API](https://developer.apple.com/library/archive/documentation/AudioVideo/Conceptual/iTuneSearchAPI/): pública, sin clave ni registro.

```
https://itunes.apple.com/search?term={query}&entity=song&limit=25
```

El filtrado lo hace el servidor. No se envía `country`, así que los resultados y los precios son de la tienda de EE. UU. (USD).

## Cómo ejecutarla

Requisitos: Xcode 26 y un simulador o dispositivo con iOS 17.6 o superior. Swift 6, sin dependencias externas.

1. Abre `Iberia.xcodeproj`.
2. Elige el esquema **Iberia** y un simulador.
3. Ejecuta con ⌘R.

### Tests

⌘U en Xcode, o por línea de comandos:

```bash
xcodebuild test -project Iberia.xcodeproj -scheme Iberia \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -only-testing:IberiaTests
```

- **Unitarios** (`IberiaTests`, Swift Testing): Domain, Data, Presentation y localización. No usan red ni esperas reales.
- **UI** (`IberiaUITests`, XCTest): auditorías de accesibilidad de Apple, en inglés y en español. Corren sin red: la app arranca con `-UITestStubbedSearch` (solo en compilaciones Debug) y usa canciones fijas.
- `Iberia.xctestplan` fija el idioma de los tests a inglés y desactiva la ejecución en paralelo. Los tests unitarios comparan textos en inglés, así que dependen de ese plan.

## Arquitectura

Tres capas, como carpetas de un único target. Las dependencias apuntan hacia dentro: `Presentation → Domain ← Data`.

```
Iberia/
  App/            IberiaApp: único sitio que conoce las tres capas y ensambla el grafo
  Domain/         Song, SearchQuery, SearchError, SongRepository, SearchSongsUseCase
  Data/           Cliente HTTP, DTOs y mapper, data source de iTunes, caché, repositorios
  Presentation/   SearchViewModel, SearchView, SongDetailView y componentes
```

- **Domain** no importa SwiftUI ni nada de red. Define los protocolos que Data implementa.
- **Inyección de dependencias** por constructor, con protocolos. No hay singletons.
- **Concurrencia (Swift 6):** las entidades son `struct` inmutables y `Sendable`, así viajan entre actores sin data races. La caché y el repositorio con caché son `actor`. El ViewModel es `@MainActor @Observable`.
- Cadena real: `URLSessionHTTPClient → ITunesSongRemoteDataSource → RemoteSongRepository → CachedSongRepository(SongMemoryCache) → DefaultSearchSongsUseCase → SearchViewModel → SearchView`.

## Decisiones principales

### Cancelación

- Cada vez que cambia el texto, el ViewModel cancela la tarea anterior al instante.
- Si el texto queda vacío, vuelve al estado inicial sin lanzar tarea ni red.
- Si no, espera 300 ms (debounce) sobre un reloj inyectable y entonces consulta el caso de uso.
- Tras cada `await` se comprueba `Task.isCancelled`: un resultado de una búsqueda cancelada nunca llega a la pantalla, aunque el caso de uso conteste tarde. Una `CancellationError` nunca se muestra como error.
- En cuanto el texto cambia a una búsqueda válida, la pantalla pasa a "cargando" y se descartan los resultados anteriores (también un estado vacío o un error). Así, lo que se ve siempre corresponde al texto actual y nunca se muestran resultados de una búsqueda anterior.
- La cancelación se propaga hasta `URLSession` (`URLError(.cancelled)` se traduce a `CancellationError`).

### Caché

- En memoria, indexada por `SearchQuery`: texto con espacios recortados y colapsados y en minúsculas. No se pliegan los diacríticos, porque "cafe" y "café" pueden devolver resultados distintos.
- **TTL de 3 minutos**, configurable por constructor. Una entrada con vida igual al TTL ya está expirada.
- Entrada válida → se devuelve **sin llamada de red**. Ausente o expirada → red, y se actualiza la caché.
- Solo se cachean respuestas correctas, nunca errores ni resultados de peticiones canceladas.
- El tiempo viene de un reloj inyectable (`CacheClock`), así los tests comprueban la expiración en milisegundos.
- Extras no pedidos por el enunciado: máximo de 50 entradas con desalojo de la menos usada, y las peticiones idénticas simultáneas comparten una sola llamada de red.

### Errores

Los fallos de red, HTTP o decodificación se traducen a `SearchError` en la capa Data. La interfaz muestra un mensaje localizado y un botón para reintentar.

### Accesibilidad y localización

- Inglés y español (`Localizable.xcstrings`).
- Cada fila es un solo elemento de VoiceOver con etiqueta y pista, y el resultado de cada búsqueda se anuncia. Los layouts se adaptan a Dynamic Type grande, a iPhone en horizontal y a iPad.

## Limitaciones conocidas

- Sin paginación: máximo 25 resultados por búsqueda.
- Sin `country` en la petición: precios siempre en USD.
- `URLSessionHTTPClient` no tiene tests: es el único código que toca la red real.
- La carátula del detalle pide una versión más grande cambiando `100x100bb` por `600x600bb` en la URL, algo que depende del formato de la CDN de Apple.
- Las auditorías de accesibilidad solo se han pasado en modo claro, y las traducciones al español no las ha revisado una persona nativa.
- Las auditorías exentan dos controles del propio iOS (el botón de borrar de la barra de búsqueda y la barra de predicciones del teclado), que la app no puede modificar.
