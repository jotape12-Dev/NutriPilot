# NutriPilot 🥗⚡

> Assistente pessoal de nutrição de alta precisão, rápido e sucinto. Foco em decisão imediata, estimativas calibradas e execução local-first.

---

## 📱 Visão e Filosofia

- **Menos Dashboard, Mais Decisão:** Informações curtas e acionáveis para o momento (ex: o que comer na próxima refeição para bater a meta diária).
- **Registro Ultrarrápido:**
  - Água em 1 toque (< 2s).
  - Alimentação por texto ou favoritos (< 10s).
- **Cálculo Determinístico e Calibração Pessoal:**
  - TMB via Mifflin-St Jeor + GET adaptativo.
  - Estimativa de gordura corporal por fotos sempre em faixas com grau de confiança, calibrável por bioimpedância (BIA) e DEXA.
- **Segurança de Dados e Segredos:**
  - Chaves de API e segredos isolados e protegidos fora do controle de versão.
  - Arquitetura limpa modular em Swift + SwiftUI.

---

## 🛠️ Estrutura do Projeto

```text
NutriPilot/
├── Package.swift               # SPM multi-target com suporte iOS 17+ e macOS 14+
├── docs/                       # Especificações canônicas
│   ├── PRODUCT.md              # Requisitos e personas
│   ├── ARCHITECTURE.md         # Padrões e diagrama de camadas
│   ├── DATA_MODEL.md           # Modelos de dados e contratos
│   └── BACKLOG.md              # Fases de entrega e critérios de aceite
├── Sources/
│   ├── NutriPilotCore/         # Modelos puros e Calculadora Nutricional matemática
│   └── NutriPilotApp/          # Telas em SwiftUI (Hoje, Comida, Água, Corpo, Plano)
└── Tests/
    └── NutriPilotTests/        # Suíte de testes unitários
```

---

## 🧪 Rodando os Testes Unitários

```bash
swift test
```
