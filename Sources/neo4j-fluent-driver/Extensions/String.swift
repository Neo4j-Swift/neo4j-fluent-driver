import Foundation

extension String {
    func capitalizingFirstLetter() -> String {
        let first = String(characters.prefix(1)).capitalized
        let rest = String(characters.dropFirst())
        return first + rest
    }
}
