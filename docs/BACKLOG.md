# NutriPilot — Backlog de Execução (BACKLOG.md)

---

## Fase 0 — Fundação e Arquitetura [CONCLUÍDO]
- [x] **T-000:** Setup do repositório Git, `.gitignore` seguro para versionamento e template de segredos.
- [x] **T-001:** Documentação base (`PRODUCT.md`, `ARCHITECTURE.md`, `DATA_MODEL.md`, `BACKLOG.md`).
- [x] **T-002:** Estrutura base de módulos Swift e SPM/Xcode Project compilando.
- [x] **T-003:** Design System básico (Cores, Tipografia, Componentes reutilizáveis de Card e Barra de Progresso).
- [x] **T-004:** Shell de Navegação principal (`TabView` com abas: Hoje, Alimentação, Corpo, Planos, Ajustes).

---

## Fase 1 — Perfil, Metas e Motor Nutricional [CONCLUÍDO]
- [x] **T-005:** Modelagem e persistência local de Perfil e Metas (`UserProfile`, `NutritionTarget`).
- [x] **T-006:** `NutritionCalculator`: Implementar fórmulas TMB (Mifflin-St Jeor), GET por fator de atividade e metas por objetivo.
- [x] **T-007:** Suíte de testes unitários para `NutritionCalculator` (cobertura de idades, pesos, sexos e metas).
- [x] **T-008:** Fluxo de Onboarding rápido para inserção do perfil inicial e geração das metas.
- [x] **T-009:** Tela de exibição das metas calculadas com aviso explícito de estimativa inicial.

---

## Fase 2 — Registro Rápido (Comida & Água) [CONCLUÍDO]
- [x] **T-010:** Seed inicial de alimentos brasileiros comuns (base TBCA offline).
- [x] **T-011:** Registro de água em 1 toque com botões rápidos (+100ml, +250ml, +500ml) e meta visual.
- [x] **T-012:** Busca rápida e registro manual de refeições com cálculo automático de calorias e macros.
- [x] **T-013:** Sistema de refeições favoritas/recorrentes para logging instantâneo.
- [x] **T-014:** Tela "Hoje" (Dashboard) exibindo totais consumidos, restantes e próxima ação sugerida.

---

## Fase 3 — Parsing Inteligente de Refeições [CONCLUÍDO]
- [x] **T-015:** Contrato e parser de linguagem natural para refeições (texto/áudio) (`MealParserEngine`).
- [x] **T-016:** Tela de confirmação em 1 toque antes de persistir o alimento parseado (`MealParserConfirmationSheet`).
- [x] **T-017:** Suíte de testes de parsing com frases típicas brasileiras (`MealParserEngineTests`).

---

## Fase 4 — Evolução Corporal e Calibração [CONCLUÍDO]
- [x] **T-018:** Registro de peso com gráfico de tendência EWMA (7, 30 e 90 dias) e predição Nutrium (`WeightTrendCalculator`).
- [x] **T-019:** Registro de medidas corporais (cintura, quadril, braço, tórax, coxa) (`BodyMeasurementStore`).
- [x] **T-020:** Registro de entrada de bioimpedância e persistência em disco JSON.
- [x] **T-021:** Motor de avaliação antropométrica com Jackson & Pollock 3 e 7 dobras e Equação de Siri (`BodyCompositionCalculator`).

---

## Fase 5 — Planos Alimentares e Assistente Sucinto
- [ ] **T-022:** Gerador de plano alimentar diário baseado nas metas.
- [ ] **T-023:** Motor de substituição de alimentos equivalentes por macronutriente.
- [ ] **T-024:** Lista de compras consolidada gerada a partir do plano.
- [ ] **T-025:** Assistente conversacional sucinto com respostas em até 4 linhas.

---

## Fase 6 — Refinamento e Validação
- [ ] **T-026:** Exportação de relatório em PDF/JSON para nutricionista.
- [ ] **T-027:** Testes end-to-end e validação dos critérios de performance (< 2s água, < 10s comida).
