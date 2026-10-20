import Foundation

/// Motor de assistente nutricional conversacional sucinto com garantia estrita de no máximo 4 linhas por resposta,
/// sem introduções vazias, fundamentado no estado metabólico real do usuário hoje.
public final class SuccinctAssistantEngine: Sendable {
    public static let shared = SuccinctAssistantEngine()

    public init() {}

    /// Processa a mensagem do usuário contextualizada com as stores ativas do aplicativo.
    public func respond(
        to query: String,
        profileStore: ProfileStore = .shared,
        mealStore: MealStore = .shared,
        waterStore: WaterStore = .shared,
        date: Date = Date()
    ) -> String {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let target = profileStore.currentTarget ?? NutritionTarget(
            calories: 2000,
            proteinGrams: 150,
            carbsGrams: 200,
            fatGrams: 55,
            waterMl: 2800
        )

        let totals = mealStore.dailyTotals(for: date)
        let waterConsumed = waterStore.totalWaterMl(for: date)

        let rawResponse: String

        // 1. Consulta de status do dia
        if isStatusQuery(cleanQuery) {
            rawResponse = buildDailyStatusResponse(target: target, totals: totals, waterConsumed: waterConsumed)
        }
        // 2. Dúvidas de compensação / excesso calórico planejado (pizza, doce, hambúrguer, etc.)
        else if isCompensationQuery(cleanQuery) {
            rawResponse = buildCompensationResponse(query: cleanQuery, target: target, totals: totals)
        }
        // 3. Sugestão da próxima refeição para bater macros restantes
        else if isNextMealQuery(cleanQuery) {
            rawResponse = buildNextMealSuggestion(target: target, totals: totals)
        }
        // 4. Dúvida geral / fallback sucinto
        else {
            rawResponse = buildGeneralNutritionalGuidance(query: cleanQuery, target: target, totals: totals)
        }

        return enforceMaxFourLines(rawResponse)
    }

    // MARK: - Respostas Especializadas (Máximo 4 Linhas)

    private func buildDailyStatusResponse(
        target: NutritionTarget,
        totals: DayNutritionTotals,
        waterConsumed: Double
    ) -> String {
        let remainingCal = max(0, target.calories - totals.calories)
        let waterProgress = target.waterMl > 0 ? Int((waterConsumed / target.waterMl) * 100.0) : 0

        let line1 = "Consumo: \(Int(totals.calories)) / \(Int(target.calories)) kcal (restam \(Int(remainingCal)) kcal)."
        let line2 = "Macros: P: \(Int(totals.proteinGrams))/\(Int(target.proteinGrams))g | C: \(Int(totals.carbsGrams))/\(Int(target.carbsGrams))g | G: \(Int(totals.fatGrams))/\(Int(target.fatGrams))g."
        let line3 = "Água: \(Int(waterConsumed)) / \(Int(target.waterMl)) ml (\(waterProgress)% da meta diária)."
        let line4 = remainingCal > 0
            ? "Mantenha o foco proteico na próxima refeição para fechar o dia em equilíbrio."
            : "Meta calórica do dia atingida; foque apenas em hidratação e repouso."

        return "\(line1)\n\(line2)\n\(line3)\n\(line4)"
    }

    private func buildNextMealSuggestion(
        target: NutritionTarget,
        totals: DayNutritionTotals
    ) -> String {
        let remCal = max(0, target.calories - totals.calories)
        let remProt = max(0, target.proteinGrams - totals.proteinGrams)
        let remCarbs = max(0, target.carbsGrams - totals.carbsGrams)
        let remFat = max(0, target.fatGrams - totals.fatGrams)

        let line1 = "Faltam \(Int(remCal)) kcal (\(Int(remProt))g proteína, \(Int(remCarbs))g carbo, \(Int(remFat))g gordura)."

        let line2: String
        let line3: String
        let line4: String

        if remProt >= 30.0 {
            line2 = "Sugestão: 160g de peito de frango grelhado ou filé de tilápia com 150g de batata doce."
            line3 = "Aporte: ~420 kcal, 48g de proteína e 28g de carboidrato de baixo índice glicêmico."
            line4 = "Adicione folhas verdes à vontade com 1 colher de sobremesa de azeite para saciedade."
        } else if remCarbs >= 40.0 {
            line2 = "Sugestão: 150g de arroz branco, 100g de feijão carioca e 100g de patinho moído."
            line3 = "Aporte: ~440 kcal, 38g de carboidrato, 35g de proteína e 9g de gordura."
            line4 = "Refeição balanceada perfeita para restaurar o glicogênio muscular."
        } else {
            line2 = "Sugestão: Omelete com 2 ovos inteiros, 30g de queijo minas e 1 maçã com casca."
            line3 = "Aporte: ~290 kcal, 20g de proteína, 15g de carbo e 16g de gorduras boas."
            line4 = "Opção leve e rápida para fechar os macros sem sobrecarregar a digestão."
        }

        return "\(line1)\n\(line2)\n\(line3)\n\(line4)"
    }

    private func buildCompensationResponse(
        query: String,
        target: NutritionTarget,
        totals: DayNutritionTotals
    ) -> String {
        let isPizza = query.contains("pizza")
        let isSweet = query.contains("doce") || query.contains("chocolate") || query.contains("sobremesa") || query.contains("acucar")

        let line1 = isPizza
            ? "2 fatias de pizza média somam aproximadamente 520 kcal (60g carbo e 20g gordura)."
            : (isSweet
                ? "Um doce tradicional adiciona entre 250 a 400 kcal puramente em carboidratos simples e gordura."
                : "A refeição livre adiciona em média 500 a 700 kcal concentradas em gorduras e carboidratos.")

        let line2 = "Estratégia: zere os carboidratos e gorduras do restante do dia, mantendo apenas proteínas magras."
        let line3 = "Consuma 200g de peito de frango grelhado ou tilápia com salada crua para preservar sua massa magra."
        let line4 = "Beba 500ml extras de água para acelerar a eliminação da retenção de sódio."

        return "\(line1)\n\(line2)\n\(line3)\n\(line4)"
    }

    private func buildGeneralNutritionalGuidance(
        query: String,
        target: NutritionTarget,
        totals: DayNutritionTotals
    ) -> String {
        let line1 = "Mantenha consistência calórica e priorize alimentos de alta densidade nutricional da TBCA."
        let line2 = "Distribua as proteínas em porções de 30-40g a cada 3 a 4 horas para síntese proteica máxima."
        let line3 = "Monitore sua hidratação diária com a meta de \(Int(target.waterMl)) ml registrada no app."
        let line4 = "Pequenos ajustes diários sustentáveis superam dietas radicais no longo prazo."

        return "\(line1)\n\(line2)\n\(line3)\n\(line4)"
    }

    // MARK: - Classificadores de Intenção

    private func isStatusQuery(_ q: String) -> Bool {
        q.contains("como esta") || q.contains("como está") || q.contains("meu dia") ||
        q.contains("status") || q.contains("resumo") || q.contains("hoje") || q.contains("como estou")
    }

    private func isCompensationQuery(_ q: String) -> Bool {
        q.contains("pizza") || q.contains("doce") || q.contains("chocolate") ||
        q.contains("cerveja") || q.contains("burger") || q.contains("hamburguer") ||
        q.contains("compensar") || q.contains("jacar") || q.contains("livre")
    }

    private func isNextMealQuery(_ q: String) -> Bool {
        q.contains("proxima") || q.contains("próxima") || q.contains("comer agora") ||
        q.contains("fechar macro") || q.contains("o que comer") || q.contains("sugestao") || q.contains("sugestão")
    }

    // MARK: - Garantia Estrita de Máximo 4 Linhas

    /// Assegura categoricamente que nenhuma resposta exceda 4 linhas.
    public func enforceMaxFourLines(_ text: String) -> String {
        let lines = text
            .components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        if lines.count <= 4 {
            return lines.joined(separator: "\n")
        } else {
            return lines.prefix(4).joined(separator: "\n")
        }
    }
}
