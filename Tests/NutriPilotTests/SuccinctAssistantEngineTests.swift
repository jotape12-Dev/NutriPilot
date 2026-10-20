import XCTest
@testable import NutriPilotCore

final class SuccinctAssistantEngineTests: XCTestCase {

    let assistant = SuccinctAssistantEngine.shared

    func testStrictMaxFourLinesRuleAcrossQueries() {
        let testQueries = [
            "Como está meu dia?",
            "O que comer agora para bater macros?",
            "Quero comer pizza hoje à noite",
            "Comi um chocolate depois do almoço",
            "Qual o melhor horário para tomar creatina?",
            "Resumo do meu dia hoje",
            "Como compensar um hambúrguer com fritas?"
        ]

        for query in testQueries {
            let response = assistant.respond(to: query)
            let lines = response.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

            // Regra inegociável de concisão: máximo de 4 linhas
            XCTAssertLessThanOrEqual(lines.count, 4, "A resposta para '\(query)' excedeu 4 linhas: \(lines.count) linhas geradas.")
            XCTAssertGreaterThanOrEqual(lines.count, 1, "A resposta para '\(query)' veio vazia.")

            // Regra: Sem saudações vazias ou introduções prolixas
            let firstLine = lines.first?.lowercased() ?? ""
            XCTAssertFalse(firstLine.hasPrefix("olá"), "Resposta iniciou com saudação genérica: \(firstLine)")
            XCTAssertFalse(firstLine.hasPrefix("oi"), "Resposta iniciou com saudação genérica: \(firstLine)")
            XCTAssertFalse(firstLine.hasPrefix("com certeza"), "Resposta iniciou com introdução vazia: \(firstLine)")
            XCTAssertFalse(firstLine.hasPrefix("vamos lá"), "Resposta iniciou com introdução vazia: \(firstLine)")
        }
    }

    func testEnforceMaxFourLinesUtility() {
        let multiLineText = """
        Linha 1
        Linha 2
        Linha 3
        Linha 4
        Linha 5 excedente
        Linha 6 excedente
        """

        let enforced = assistant.enforceMaxFourLines(multiLineText)
        let lines = enforced.components(separatedBy: "\n")
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0], "Linha 1")
        XCTAssertEqual(lines[3], "Linha 4")
    }
}
