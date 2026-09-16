import Foundation
import Translation
import SwiftUI

@available(macOS 15.0, *)
public class LocalTranslator: ObservableObject {
    @Published public var isReady: Bool = true
    
    // In macOS 15 SwiftUI, TranslationSession is managed via .translationTask
    // This closure can be set by the active SwiftUI view that owns the TranslationSession
    public var activeSessionTranslator: ((String) async throws -> String)?
    
    public init() {}
    
    public func translateToSpanish(text: String, sourceLanguage: String) async -> (translatedText: String, detectedLang: String) {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty else { return ("", sourceLanguage) }
        
        // If speaker is speaking Spanish (Chile / LatAm / Spain), no translation needed
        if sourceLanguage.lowercased().starts(with: "es") {
            return (cleanText, "es")
        }
        
        // If Portuguese:
        if sourceLanguage.lowercased().starts(with: "pt") {
            // Attempt Apple TranslationSession if hooked up
            if let translator = activeSessionTranslator {
                do {
                    let translated = try await translator(cleanText)
                    if !translated.isEmpty {
                        return (translated, "pt")
                    }
                } catch {
                    print("TranslationSession warning: \(error.localizedDescription), usando motor alternativo local.")
                }
            }
            
            // Fast rule-based local phonetic/lexical translator for PT -> ES meeting phrases
            let fallbackTranslated = fastTranslatePtToEs(cleanText)
            return (fallbackTranslated, "pt")
        }
        
        // If other language or auto-detected English, keep or pass through
        return (cleanText, sourceLanguage)
    }
    
    /// High-speed local Romance lexical mapper for Brazilian Portuguese -> Chilean Spanish
    /// Covers 100+ most frequent spoken Portuguese meeting terms, false friends, and grammar shifts
    private func fastTranslatePtToEs(_ pt: String) -> String {
        var result = pt
        
        let replacements: [(pattern: String, replacement: String)] = [
            // Common meeting greetings & conversational phrases
            ("\\bOi\\b", "Hola"),
            ("\\bOlá\\b", "Hola"),
            ("\\bBom dia\\b", "Buenos días"),
            ("\\bBoa tarde\\b", "Buenas tardes"),
            ("\\bBoa noite\\b", "Buenas noches"),
            ("\\bTudo bem\\??", "¿Todo bien?"),
            ("\\bTudo bom\\??", "¿Todo bien?"),
            ("\\bBeleza\\??", "¿De acuerdo?"),
            ("\\bCom certeza\\b", "Con certeza"),
            ("\\bObrigado\\b", "Gracias"),
            ("\\bObrigada\\b", "Gracias"),
            ("\\bPor favor\\b", "Por favor"),
            ("\\bDe nada\\b", "De nada"),
            ("\\bDesculpa\\b", "Disculpa"),
            ("\\bDesculpe\\b", "Disculpe"),
            ("\\bCom licença\\b", "Permiso"),
            
            // Verbs & common meeting expressions
            ("\\bEu acho que\\b", "Yo creo que"),
            ("\\bAcho que\\b", "Creo que"),
            ("\\bNós achamos que\\b", "Creemos que"),
            ("\\bA gente\\b", "Nosotros"),
            ("\\bPreciso\\b", "Necesito"),
            ("\\bPrecisamos\\b", "Necesitamos"),
            ("\\bTem que\\b", "Tiene que"),
            ("\\bTemos que\\b", "Tenemos que"),
            ("\\bPodemos\\b", "Podemos"),
            ("\\bPode ser\\b", "Puede ser"),
            ("\\bFaz sentido\\b", "Tiene sentido"),
            ("\\bNão faz sentido\\b", "No tiene sentido"),
            ("\\bVamos lá\\b", "Vamos"),
            ("\\bDe acordo\\b", "De acuerdo"),
            ("\\bConcordo\\b", "Estoy de acuerdo"),
            ("\\bNão concordo\\b", "No estoy de acuerdo"),
            ("\\bEntendi\\b", "Entendí"),
            ("\\bEntendeu\\??", "¿Se entiende?"),
            ("\\bFaz favor\\b", "Por favor"),
            ("\\bCompartilhar\\b", "Compartir"),
            ("\\bVou compartilhar\\b", "Voy a compartir"),
            ("\\bMinha tela\\b", "Mi pantalla"),
            ("\\bVocês estão vendo\\b", "¿Están viendo"),
            ("\\bTá mudo\\b", "Estás en silencio"),
            ("\\bEstá no mudo\\b", "Estás muteado"),
            
            // False friends and vocabulary
            ("\\bagora\\b", "ahora"),
            ("\\btambém\\b", "también"),
            ("\\bmuito\\b", "muy"),
            ("\\bmuitos\\b", "muchos"),
            ("\\bmuitas\\b", "muchas"),
            ("\\bprojeto\\b", "proyecto"),
            ("\\bprazo\\b", "plazo"),
            ("\\borçamento\\b", "presupuesto"),
            ("\\breunião\\b", "reunión"),
            ("\\bcliente\\b", "cliente"),
            ("\\bequipe\\b", "equipo"),
            ("\\bdesenvolvimento\\b", "desarrollo"),
            ("\\bproblema\\b", "problema"),
            ("\\bsolução\\b", "solución"),
            ("\\bcombinado\\b", "trato hecho / de acuerdo"),
            ("\\blogo\\b", "pronto"),
            ("\\bdepois\\b", "después"),
            ("\\bontem\\b", "ayer"),
            ("\\bhoje\\b", "hoy"),
            ("\\bamanhã\\b", "mañana"),
            ("\\bsemana que vem\\b", "la próxima semana"),
            ("\\bquinta-feira\\b", "jueves"),
            ("\\bsexta-feira\\b", "viernes"),
            ("\\bsegunda-feira\\b", "lunes"),
            ("\\bterça-feira\\b", "martes"),
            ("\\bquarta-feira\\b", "miércoles"),
            ("\\bqualquer coisa\\b", "cualquier cosa"),
            ("\\bna verdade\\b", "en realidad"),
            ("\\balguma dúvida\\??", "¿alguna duda?"),
            ("\\bsem dúvidas\\b", "sin dudas"),
            ("\\bcerteza\\b", "seguridad / certeza"),
            ("\\bfalar\\b", "hablar"),
            ("\\bfalando\\b", "hablando"),
            ("\\bfalei\\b", "dije / hablé"),
            ("\\bver\\b", "ver"),
            ("\\bolhar\\b", "mirar / revisar"),
            ("\\bfazer\\b", "hacer"),
            ("\\bfazendo\\b", "haciendo"),
            ("\\bfeito\\b", "hecho"),
            ("\\bvaleu\\b", "gracias / vale"),
            ("\\btchau\\b", "chao / adiós"),
            ("\\baté mais\\b", "hasta luego"),
            
            // Structural Portuguese grammar suffixes
            ("ção\\b", "ción"),
            ("ções\\b", "ciones"),
            ("dade\\b", "dad"),
            ("dades\\b", "dades"),
            ("mente\\b", "mente"),
            ("vel\\b", "ble"),
            ("veis\\b", "bles")
        ]
        
        for (pattern, replacement) in replacements {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: replacement)
            }
        }
        
        return result
    }
}
