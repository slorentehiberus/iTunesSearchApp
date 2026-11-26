import Domain
import Foundation

/// Turns `Song` fields into display text. Pure and locale-injectable so it can be tested.
struct SongDetailFormatter: Sendable {
    let locale: Locale

    init(locale: Locale = .current) {
        self.locale = locale
    }

    func album(of song: Song) -> String {
        song.album ?? String(localized: "Unknown album", bundle: .module)
    }

    func genre(of song: Song) -> String {
        song.genre ?? String(localized: "Unknown genre", bundle: .module)
    }

    /// Long date in UTC: iTunes release dates are UTC midday, so a local time zone could show the wrong day.
    func releaseDate(of song: Song) -> String {
        guard let date = song.releaseDate else { return String(localized: "Unknown", bundle: .module) }
        let style = Date.FormatStyle(
            date: .long,
            time: .omitted,
            locale: locale,
            calendar: Calendar(identifier: .gregorian),
            timeZone: .gmt
        )
        return date.formatted(style)
    }

    func price(of song: Song) -> String {
        guard let price = song.price else { return String(localized: "Not available", bundle: .module) }
        if price == 0 { return String(localized: "Free", bundle: .module) }
        if let code = song.currencyCode {
            return price.formatted(.currency(code: code).locale(locale))
        }
        return price.formatted(.number.locale(locale))
    }

    /// `nil` when the duration is unknown, so the row can be omitted.
    func duration(of song: Song) -> String? {
        guard let milliseconds = song.durationMilliseconds else { return nil }
        return Duration.milliseconds(milliseconds).formatted(.time(pattern: .minuteSecond))
    }
}
