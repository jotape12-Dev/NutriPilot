# NutriPilot — Documento de Transição e Estado (HANDOFF.md)

> **Data de Parada:** 20/10/2026  
> **Diretório Físico do Projeto:** `/Users/jotape/Documents/NutriPilot`  
> **Status do Repositório Git:** Branch `main`, working tree limpo, 5 commits atômicos realizados.

---

## 📍 Como abrir o Workspace correto no Maestri

Para abrir o workspace no local certo:
1. Abra o Maestri e crie ou aponte o workspace para o diretório raiz:  
   👉 **`/Users/jotape/Documents/NutriPilot`**
2. Inicie o agente Maestro/Rainha diretamente dentro dessa pasta.

---

## 🚀 O que foi 100% Concluído e Entregue

### 1. Fase 0 — Fundação e Arquitetura Limpa
- Repositório Git inicializado e blindado com `.gitignore` contra vazamento de `.env`, segredos, chaves e arquivos pesados de build.
- `Package.swift` configurado para multi-target (Core, App SwiftUI e Testes) com compatibilidade iOS 17+ e macOS 14+.
- Documentação canônica em `docs/`:
  - `docs/PRODUCT.md`
  - `docs/ARCHITECTURE.md`
  - `docs/DATA_MODEL.md`
  - `docs/BACKLOG.md`

### 2. Dissecação por Engenharia Reversa (REA) dos 4 Softwares
Todos os pacotes oficiais foram descompilados e analisados, gerando relatórios técnicos canônicos:
- **Dietbox (`docs/rea/DIETBOX_REVERSE_ENGINEERING.md`):** Arquitetura React Native + Expo + Realm Database; extração das 7 dobras cutâneas clínicas e algoritmo de substituição proporcional de macronutrientes.
- **Nutrium (`docs/rea/NUTRIUM_REVERSE_ENGINEERING.md`):** Código Kotlin nativo; motor de previsão de peso (`WeightPrediction`) e notificações de água com faixa de horário inteligente (`WATER_INTAKE_NOTIFICATIONS_RANGE`).
- **WebDiet (`docs/rea/WEBDIET_PRACTICEBETTER_REVERSE_ENGINEERING.md`):** App Shell em WebView consumindo `hubdiet.com`.
- **Practice Better (`docs/rea/WEBDIET_PRACTICEBETTER_REVERSE_ENGINEERING.md`):** Integrações mapeadas com Apple HealthKit, Garmin e Oura Ring, além de fluxo de adesão a planos em 1 toque.

### 3. Fase 1 — Perfil, Metas e Onboarding
- `Sources/NutriPilotCore/Nutrition/NutritionCalculator.swift`: Motor matemático determinístico de Mifflin-St Jeor (TMB), cálculo de GET por atividade, divisão de macros por objetivo e meta de hidratação.
- `Sources/NutriPilotCore/Models/BodyMeasurement.swift`: Modelo antropométrico completo com as 7 dobras cutâneas e circunferências bilaterais.
- `Sources/NutriPilotCore/Storage/ProfileStore.swift`: Armazenamento reativo e persistente em disco do perfil do usuário e das metas calculadas.
- `Sources/NutriPilotApp/OnboardingView.swift`: Interface SwiftUI interativa para cadastro e recálculo dinâmico de metas.
- `Sources/NutriPilotApp/RootView.swift`: Navegação reativa alternando entre Onboarding e as abas principais (Dashboard com a Próxima Ação, Comida, Água em 1 toque, Corpo e Plano).
- `Tests/NutriPilotTests`: Suíte de testes unitários com **100% de aprovação** (`swift test` executando 6/6 testes sem falhas).

---

## 🎯 Ponto Exato de Retomada (Próxima Tarefa)

Quando o novo workspace for aberto, a próxima etapa já está definida no backlog:
- **Fase 2 — Registro Rápido (Comida & Água):**
  1. Inserir a base offline de alimentos brasileiros comuns (TBCA) com medidas caseiras em `Sources/NutriPilotCore/Seed/`.
  2. Implementar a busca e registro de refeições com cálculo automático de macros.
  3. Integrar a regra de notificação inteligente de hidratação aprendida no Nutrium.

---

## 🧪 Comando para Validar a Saúde do Projeto

Dentro de `/Users/jotape/Documents/NutriPilot`:
```bash
swift test
```
*(Deve compilar em ~1s e passar todos os 6 testes).*
