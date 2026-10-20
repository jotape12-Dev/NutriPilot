# NutriPilot — Arquitetura de Software (ARCHITECTURE.md)

> **Plataforma:** iOS 17+ (Swift 6.x + SwiftUI)  
> **Padrão Arquitetural:** Clean Architecture Modular + Local-First Persistence

---

## 1. Visão Arquitetural

```
┌────────────────────────────────────────────────────────┐
│                   Apresentação (UI)                    │
│      SwiftUI Views • ViewModels (@Observable)          │
│   (Dashboard, FoodLogging, Water, BodyProgress, Plan)  │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                     Domínio (Core)                     │
│    Modelos de Negócio • Protocolos de Repositório      │
│  Calculadoras Nutricionais (Mifflin-St Jeor, GET, TMB) │
└──────────────────────────┬─────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────┐
│                    Dados & Serviços                    │
│   Persistência Local (SwiftData / SQLite)              │
│   Seed Data (Tabela TBCA de Alimentos Brasileiros)     │
│   Serviços de IA (Parsing de Texto, Visão, Assistente) │
└────────────────────────────────────────────────────────┘
```

---

## 2. Divisão de Módulos e Pastas

```text
NutriPilot/
├── App/                     # Ponto de entrada, ciclo de vida e Router
│   ├── NutriPilotApp.swift
│   ├── RootView.swift
│   └── AppRouter.swift
├── Core/                    # Entidades puras e regras matemáticas independentes
│   ├── Models/              # Profile, Target, Food, MealLog, WaterLog, Measurement
│   ├── Nutrition/           # NutritionCalculator (TMB, GET, macros, água)
│   └── Config/              # AppConfig e gestão segura de chaves
├── Data/                    # Implementação de persistência e fontes de dados
│   ├── Local/               # SwiftData Context e Schema
│   ├── Repositories/        # Implementações dos repositórios
│   └── Seed/                # Banco inicial de alimentos brasileiros (TBCA)
├── Services/                # Serviços de parsing, IA e relatórios
│   ├── MealParsing/         # Parser de texto/voz para itens alimentares
│   ├── BodyEstimation/      # Calibração e estimativas corporais
│   └── AIAssistant/         # Geração de resumos e respostas sucintas
├── Features/                # Módulos de telas do SwiftUI
│   ├── Dashboard/           # Tela inicial: resumo do dia + próxima ação
│   ├── FoodLogging/         # Registro rápido de alimentos
│   ├── Water/               # Registro de água em 1 toque
│   ├── BodyProgress/        # Gráficos de peso, circunferências e fotos
│   ├── MealPlan/            # Plano de refeições e lista de compras
│   └── Onboarding/          # Definição inicial do perfil e metas
└── Tests/                   # Testes unitários para cálculos e regras
```

---

## 3. Gestão de Segurança e Segredos

- **Zero Credenciais no Git:** Nenhuma chave de API (OpenAI, Gemini, etc.) deve ser commitada.
- Arquivos `.env`, `Secrets.swift` e `Config.xcconfig` ficam explicitamente no `.gitignore`.
- O app consome configurações através do protocolo `ConfigProvider`, que busca primeiro em variáveis de ambiente / Keychain local, caindo em mock para testes offline.
