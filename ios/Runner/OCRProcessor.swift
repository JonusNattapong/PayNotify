import Foundation
import Vision
import UIKit

class OCRProcessor {
    static let shared = OCRProcessor()
    
    private let bankPatterns: [String: [String: String]] = [
        "SCB": [
            "namePattern": "(?:SCB|ไทยพาณิชย์|Siam Commercial Bank)",
            "transferPattern": "(?:transfer|โอนเงิน|รับเงิน|เงินเข้า)",
            "amountPattern": "(?:THB|฿|บาท)\\s*([0-9,.]+)|([0-9,.]+)\\s*(?:THB|฿|บาท)",
            "accountPattern": "(?:a/c|account|บัญชี)[^\\d]*(\\d{3}[-\\s]?\\d+[-\\s]?\\d+)",
            "senderPattern": "(?:จาก|from|โดย|By)[^\\d\\n]*([\\wก-๙\\s'\".]+)"
        ],
        "KBANK": [
            "namePattern": "(?:KBANK|กสิกร|KASIKORN)",
            "transferPattern": "(?:transfer|โอนเงิน|รับเงิน|เงินเข้า)",
            "amountPattern": "(?:THB|฿|บาท)\\s*([0-9,.]+)|([0-9,.]+)\\s*(?:THB|฿|บาท)",
            "accountPattern": "(?:a/c|account|บัญชี)[^\\d]*(\\d{3}[-\\s]?\\d+[-\\s]?\\d+)",
            "senderPattern": "(?:จาก|from|โดย|By)[^\\d\\n]*([\\wก-๙\\s'\".]+)"
        ],
        // Add more banks with their patterns
    ]
    
    private let logoRegions: [String: CGRect] = [
        "SCB": CGRect(x: 0.05, y: 0.05, width: 0.2, height: 0.1),
        "KBANK": CGRect(x: 0.05, y: 0.05, width: 0.2, height: 0.1),
        "KTB": CGRect(x: 0.05, y: 0.05, width: 0.2, height: 0.1),
        "BBL": CGRect(x: 0.05, y: 0.05, width: 0.2, height: 0.1),
        // Add more bank logo regions
    ]
    
    func processTransferImage(_ image: UIImage, completion: @escaping ([String: Any]?, Error?) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(nil, NSError(domain: "OCRProcessor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid image"]))
            return
        }
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                completion(nil, error)
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(nil, NSError(domain: "OCRProcessor", code: -2, userInfo: [NSLocalizedDescriptionKey: "No text found"]))
                return
            }
            
            let result = self.extractTransferInfo(from: observations, imageSize: image.size)
            completion(result, nil)
        }
        
        // Configure text recognition
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.minimumTextHeight = 0.01
        
        do {
            try requestHandler.perform([request])
        } catch {
            completion(nil, error)
        }
    }
    
    private func extractTransferInfo(from observations: [VNRecognizedTextObservation], imageSize: CGSize) -> [String: Any] {
        var result: [String: Any] = [:]
        var fullText = ""
        
        // Build full text and analyze text locations
        for observation in observations {
            if let topCandidate = observation.topCandidates(1).first {
                fullText += topCandidate.string + "\n"
                
                // Check for bank logo in expected regions
                let normalizedRect = observation.boundingBox
                let detectedBank = detectBankFromRegion(normalizedRect)
                if let bank = detectedBank {
                    result["bankName"] = bank
                }
            }
        }
        
        // If bank not detected from regions, try text-based detection
        if result["bankName"] == nil {
            result["bankName"] = detectBankFromText(fullText)
        }
        
        // Extract amount
        if let amount = extractAmount(from: fullText) {
            result["amount"] = amount
        }
        
        // Extract account number
        if let accountNumber = extractAccountNumber(from: fullText) {
            result["accountNumber"] = accountNumber
        }
        
        // Extract sender info
        if let sender = extractSenderInfo(from: fullText) {
            result["senderInfo"] = sender
        }
        
        result["rawText"] = fullText
        
        return result
    }
    
    private func detectBankFromRegion(_ rect: CGRect) -> String? {
        for (bank, region) in logoRegions {
            if region.intersects(rect) {
                return bank
            }
        }
        return nil
    }
    
    private func detectBankFromText(_ text: String) -> String {
        let lowercaseText = text.lowercased()
        if lowercaseText.contains("scb") || lowercaseText.contains("ไทยพาณิชย์") { return "SCB" }
        if lowercaseText.contains("kbank") || lowercaseText.contains("กสิกร") { return "KBANK" }
        if lowercaseText.contains("ktb") || lowercaseText.contains("กรุงไทย") { return "KTB" }
        if lowercaseText.contains("bbl") || lowercaseText.contains("กรุงเทพ") { return "BBL" }
        return "Unknown"
    }
    
    private func extractAmount(from text: String) -> Double? {
        let pattern = "(?:THB|฿|บาท)\\s*([0-9,.]+)|([0-9,.]+)\\s*(?:THB|฿|บาท)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange) else { return nil }
        
        // Get the matched group
        for i in 1...2 {
            let matchRange = match.range(at: i)
            if matchRange.location != NSNotFound,
               let range = Range(matchRange, in: text) {
                let amountStr = text[range].replacingOccurrences(of: ",", with: "")
                return Double(amountStr)
            }
        }
        
        return nil
    }
    
    private func extractAccountNumber(from text: String) -> String? {
        let pattern = "(?:a/c|account|บัญชี)[^\\d]*(\\d{3}[-\\s]?\\d+[-\\s]?\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        
        return String(text[range])
    }
    
    private func extractSenderInfo(from text: String) -> String? {
        let pattern = "(?:จาก|from|โดย|By)[^\\d\\n]*([\\wก-๙\\s'\".]+?)(?:\\s|$)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: nsRange),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}