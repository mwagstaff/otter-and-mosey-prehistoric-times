import Foundation

/// The pre-recorded narrator clips: each clip key and the words spoken in it (see narration.json).
public enum Narration {
    public static let clips: [String: String] = {
        guard let url = Bundle.module.url(forResource: "narration", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let lines = try? JSONDecoder().decode([String: String].self, from: data)
        else { return [:] }
        return lines
    }()
}
