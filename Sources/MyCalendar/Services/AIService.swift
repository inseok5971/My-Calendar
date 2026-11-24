import Foundation
import Combine

struct ParsedEventInfo: Sendable {
    var title: String
    var startDate: Date
    var endDate: Date
    var category: EventCategory
    var linkedFolderPath: String?
    var notes: String
}

@MainActor
final class AIService: ObservableObject {
    static let shared = AIService()

    @Published var isProcessing: Bool = false
    @Published var lastAIStatusMessage: String?

    private init() {}

    // MARK: - Natural Language Parsing (Hybrid: Local Rule + Gemini LLM)

    func parseNaturalLanguage(
        prompt: String,
        baseDate: Date = Date(),
        apiKey: String? = nil
    ) async throws -> ParsedEventInfo {
        isProcessing = true
        defer { isProcessing = false }

        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedKey.isEmpty {
            do {
                let parsed = try await parseWithGemini(prompt: prompt, baseDate: baseDate, apiKey: trimmedKey)
                lastAIStatusMessage = "✨ Gemini AI 파싱 완료"
                return parsed
            } catch {
                print("Gemini API error, falling back to local NLP: \(error)")
            }
        }

        // Local Smart NLP Fallback
        let parsed = parseWithLocalNLP(prompt: prompt, baseDate: baseDate)
        lastAIStatusMessage = "⚡ 스마트 로컬 AI 파싱 완료"
        return parsed
    }

    // MARK: - Gemini API Parsing

    private func parseWithGemini(
        prompt: String,
        baseDate: Date,
        apiKey: String
    ) async throws -> ParsedEventInfo {
        let formatter = ISO8601DateFormatter()
        let todayStr = formatter.string(from: baseDate)

        let systemInstruction = """
        You are a smart calendar assistant.
        Today's reference date-time is: \(todayStr).
        Analyze the user's natural language input in Korean and extract calendar event details.
        Output MUST be pure JSON with NO markdown code block, matching this schema:
        {
          "title": "Event title",
          "startISO": "YYYY-MM-DDTHH:mm:ss",
          "durationMinutes": 60,
          "category": "업무" | "개인" | "건강" | "학습" | "기타",
          "linkedFolderPath": null or "extracted path string",
          "notes": "additional notes or raw text"
        }
        """

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemInstruction)\n\nUser Input: \(prompt)"]
                    ]
                ]
            ],
            "generationConfig": [
                "response_mime_type": "application/json",
                "temperature": 0.1
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCand = candidates.first,
              let content = firstCand["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        guard let parsedData = text.data(using: .utf8),
              let dict = try JSONSerialization.jsonObject(with: parsedData) as? [String: Any] else {
            throw URLError(.cannotParseResponse)
        }

        let title = (dict["title"] as? String) ?? prompt
        let startISO = dict["startISO"] as? String
        let duration = (dict["durationMinutes"] as? Int) ?? 60
        let categoryStr = (dict["category"] as? String) ?? "업무"
        let folderPath = dict["linkedFolderPath"] as? String
        let notes = (dict["notes"] as? String) ?? ""

        let startDate: Date
        if let startISO, let d = formatter.date(from: startISO) {
            startDate = d
        } else {
            startDate = baseDate
        }
        let endDate = startDate.addingTimeInterval(TimeInterval(duration * 60))

        let category = EventCategory(rawValue: categoryStr) ?? .work

        return ParsedEventInfo(
            title: title,
            startDate: startDate,
            endDate: endDate,
            category: category,
            linkedFolderPath: folderPath,
            notes: notes
        )
    }

    // MARK: - Local Rule-based NLP Engine (Offline 100% Reliable)

    func parseWithLocalNLP(prompt: String, baseDate: Date) -> ParsedEventInfo {
        let calendar = Calendar.current
        var targetDate = baseDate
        var startHour = calendar.component(.hour, from: baseDate) + 1
        var startMinute = 0
        let durationMinutes = 60
        var detectedCategory: EventCategory = .work

        let lower = prompt.lowercased()

        // 1. Date offset detection
        if lower.contains("오늘") {
            targetDate = baseDate
        } else if lower.contains("내일") {
            targetDate = calendar.date(byAdding: .day, value: 1, to: baseDate) ?? baseDate
        } else if lower.contains("모레") {
            targetDate = calendar.date(byAdding: .day, value: 2, to: baseDate) ?? baseDate
        } else if lower.contains("글피") {
            targetDate = calendar.date(byAdding: .day, value: 3, to: baseDate) ?? baseDate
        }

        // Weekday detection (이번주 금요일 등)
        let weekdays = [
            ("일요일", 1), ("월요일", 2), ("화요일", 3), ("수요일", 4),
            ("목요일", 5), ("금요일", 6), ("토요일", 7)
        ]
        for (wName, targetWeekday) in weekdays {
            if lower.contains(wName) || lower.contains(String(wName.prefix(1)) + "욜") {
                let currentWeekday = calendar.component(.weekday, from: baseDate)
                var diff = targetWeekday - currentWeekday
                if diff <= 0 { diff += 7 }
                targetDate = calendar.date(byAdding: .day, value: diff, to: baseDate) ?? baseDate
                break
            }
        }

        // 2. Time detection (오후 3시, 저녁 7시, 15시, 오전 10시 30분 등)
        let timeRegex = try? NSRegularExpression(pattern: "(오전|오후|저녁|밤|아침|새벽)?\\s*(\\d{1,2})시(?:\\s*(\\d{1,2})분)?")
        let nsString = prompt as NSString
        if let match = timeRegex?.firstMatch(in: prompt, range: NSRange(location: 0, length: nsString.length)) {
            var isPM = false
            if match.range(at: 1).location != NSNotFound {
                let ampm = nsString.substring(with: match.range(at: 1))
                isPM = (ampm == "오후" || ampm == "저녁" || ampm == "밤")
            }

            if match.range(at: 2).location != NSNotFound {
                let hourVal = Int(nsString.substring(with: match.range(at: 2))) ?? 9
                if isPM && hourVal < 12 {
                    startHour = hourVal + 12
                } else if !isPM && hourVal == 12 && match.range(at: 1).location != NSNotFound {
                    startHour = 0
                } else {
                    startHour = hourVal
                }
            }

            if match.range(at: 3).location != NSNotFound {
                startMinute = Int(nsString.substring(with: match.range(at: 3))) ?? 0
            }
        } else {
            // Check direct hour format like 14:30
            let colonRegex = try? NSRegularExpression(pattern: "(\\d{1,2}):(\\d{2})")
            if let match = colonRegex?.firstMatch(in: prompt, range: NSRange(location: 0, length: nsString.length)) {
                startHour = Int(nsString.substring(with: match.range(at: 1))) ?? startHour
                startMinute = Int(nsString.substring(with: match.range(at: 2))) ?? 0
            }
        }

        // 3. Category detection
        if lower.contains("운동") || lower.contains("헬스") || lower.contains("병원") || lower.contains("치과") || lower.contains("약") {
            detectedCategory = .health
        } else if lower.contains("공부") || lower.contains("강의") || lower.contains("독서") || lower.contains("시험") || lower.contains("학습") {
            detectedCategory = .study
        } else if lower.contains("생일") || lower.contains("약속") || lower.contains("모임") || lower.contains("여행") || lower.contains("영화") || lower.contains("동창") {
            detectedCategory = .personal
        } else {
            detectedCategory = .work
        }

        // 4. Folder path detection (e.g., /Desktop/... or "폴더: ...")
        var folderPath: String? = nil
        let folderRegex = try? NSRegularExpression(pattern: "(/Users/[^\\s,]+|~/[^\\s,]+)")
        if let match = folderRegex?.firstMatch(in: prompt, range: NSRange(location: 0, length: nsString.length)) {
            let path = nsString.substring(with: match.range(at: 1))
            folderPath = (path as NSString).expandingTildeInPath
        }

        // 5. Clean Title extraction
        var cleanTitle = prompt
        cleanTitle = cleanTitle.replacingOccurrences(of: "(오늘|내일|모레|글피)", with: "", options: .regularExpression)
        cleanTitle = cleanTitle.replacingOccurrences(of: "(오전|오후|저녁|밤|아침|새벽)?\\s*\\d{1,2}시(\\s*\\d{1,2}분)?", with: "", options: .regularExpression)
        cleanTitle = cleanTitle.replacingOccurrences(of: "\\d{1,2}:\\d{2}", with: "", options: .regularExpression)
        cleanTitle = cleanTitle.replacingOccurrences(of: "(월요일|화요일|수요일|목요일|금요일|토요일|일요일)", with: "", options: .regularExpression)
        cleanTitle = cleanTitle.replacingOccurrences(of: "(/Users/[^\\s,]+|~/[^\\s,]+)", with: "", options: .regularExpression)
        cleanTitle = cleanTitle.replacingOccurrences(of: "폴더[는|에]?\\s*", with: "", options: .regularExpression)
        cleanTitle = cleanTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanTitle.isEmpty { cleanTitle = "새 일정" }

        let constructedStart = calendar.date(bySettingHour: startHour % 24, minute: startMinute % 60, second: 0, of: targetDate) ?? targetDate
        let constructedEnd = constructedStart.addingTimeInterval(TimeInterval(durationMinutes * 60))

        return ParsedEventInfo(
            title: cleanTitle,
            startDate: constructedStart,
            endDate: constructedEnd,
            category: detectedCategory,
            linkedFolderPath: folderPath,
            notes: "AI 스마트 생성 (\(Date().formatted(date: .abbreviated, time: .shortened)))"
        )
    }

    // MARK: - Folder Smart Insight AI (Document summarization)

    func summarizeFolder(folderPath: String, apiKey: String? = nil) async -> String {
        isProcessing = true
        defer { isProcessing = false }

        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folderPath) else {
            return "❌ 폴더 경로를 찾을 수 없습니다: \(folderPath)"
        }

        // Find recent text/md files
        var extractedContents: [String] = []
        let files = (try? fileManager.contentsOfDirectory(atPath: folderPath)) ?? []
        for file in files {
            if file.hasPrefix(".") || file.contains("node_modules") || file.contains(".build") { continue }
            let ext = (file as NSString).pathExtension.lowercased()
            if ["md", "txt", "json", "swift", "js", "html"].contains(ext) {
                let fullPath = (folderPath as NSString).appendingPathComponent(file)
                if let data = try? Data(contentsOf: URL(fileURLWithPath: fullPath)),
                   let text = String(data: data, encoding: .utf8) {
                    let preview = String(text.prefix(800))
                    extractedContents.append("[\(file)]\n\(preview)")
                    if extractedContents.count >= 3 { break }
                }
            }
        }

        if extractedContents.isEmpty {
            return "📁 폴더 내 텍스트 파일이 없습니다. (\((folderPath as NSString).lastPathComponent))"
        }

        let combined = extractedContents.joined(separator: "\n\n")

        let trimmedKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedKey.isEmpty {
            do {
                return try await summarizeWithGemini(content: combined, apiKey: trimmedKey)
            } catch {
                print("Gemini summary error: \(error)")
            }
        }

        // Local Fallback Summary
        let lines = combined.components(separatedBy: .newlines).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sample = lines.prefix(4).map { "• " + $0.trimmingCharacters(in: .whitespaces) }.joined(separator: "\n")
        return "⚡ [로컬 스마트 브리핑] 최근 작업 파일 요약:\n\(sample)"
    }

    private func summarizeWithGemini(content: String, apiKey: String) async throws -> String {
        let systemInstruction = """
        You are an executive AI assistant.
        Summarize the key takeaways and agendas from the following project folder files in 3 concise Korean bullet points.
        Format:
        ✨ [AI 안건 3줄 브리핑]
        1. ...
        2. ...
        3. ...
        """

        let urlStr = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: urlStr) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": "\(systemInstruction)\n\nFiles Content:\n\(content)"]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.2
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCand = candidates.first,
              let content = firstCand["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let text = parts.first?["text"] as? String else {
            throw URLError(.cannotParseResponse)
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
