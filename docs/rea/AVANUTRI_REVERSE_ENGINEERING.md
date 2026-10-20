# Engenharia Reversa Avanutri (Avanutri Mobile & Avanutri Balança)

> **Origem dos Artefatos Dissecados:**
> 1. `com.avanutri.mobile.xapk` (Avanutri para Pacientes v4.x — React Native / Expo Hermes v96)
> 2. `com.avanutri.balanca.xapk` (Avanutri Balança Bioimpedância — .NET MAUI / Android AOT)

---

## 1. Visão Geral da Arquitetura do Avanutri

A plataforma Avanutri divide seu ecossistema em três pontas:
1. **Avanutri Online (Web / SaaS Clínico):** `https://beta.avanutrionline.com/api` — Onde o nutricionista insere dobras cutâneas (Pollock 3 e 7 dobras, Faulkner, Petroski, Guedes), bioimpedância e prescreve o plano.
2. **Avanutri Mobile Paciente (`com.avanutri.mobile`):** App React Native com engine Hermes (Bytecode v96) e Expo. Responsável pela visualização da avaliação antropométrica, diário alimentar e plano de substituição.
3. **Avanutri Balança (`com.avanutri.balanca`):** App .NET MAUI (`libaot-Avanutri.Balanca.Mobile.dll.so`) com integração BLE direta para pareamento com balanças de bioimpedância de múltiplos sensores.

---

## 2. Endpoints e Contratos de Dados Extraídos

A partir da dissecação do bundle Hermes (`assets/index.android.bundle`), foram mapeados os principais contratos REST:

### A. Antropometria e Medições
- `GET /AntropometriaPaciente/MaisRecente`: Retorna o snapshot da última avaliação antropométrica consolidada pelo nutricionista.
  - Campos: Peso atual, Estatura, IMC, % Gordura Corporal, Massa Gorda (kg), Massa Magra (kg), Massa Muscular Esquelética, Gordura Visceral, Taxa Metabólica Basal (TMB) calculada e Idade Metabólica.
- `GET /RecomendacaoNutricionalPaciente`: Metas prescritas de calorias, água (ml) e distribuição de macronutrientes.

### B. Diário Alimentar e Substituição
- `GET /diarioalimentar/alimentos`: Catálogo de alimentos com medidas caseiras (`/UnidadesMedida`) e gramaturas padrão.
- `GET /AlimentosPorNumSubstitutiva`: Sistema de agrupamento de substituição direta. Alimentos compartilham um `NumSubstitutiva` e têm quantidades equivalentes calculadas para manter o mesmo aporte calórico e proteico da refeição planejada.

---

## 3. Dissecação da Balança de Bioimpedância (`com.avanutri.balanca`)

O app da balança utiliza arquitetura .NET MAUI compilada Ahead-Of-Time (AOT):
- **Pareamento BLE:** Detecta periféricos BLE de bioimpedância e conduz o fluxo em 3 etapas visuais guiadas por vídeo (`pre_impedancia.mp4`, `instrucoesbalanca.mp4`, `bioimpedancia.mp4`).
- **Validação de Estabilidade de Peso:** Exige estabilização de impedância por 3 segundos antes de registrar a leitura de resistência elétrica corporal ($\Omega$).
- **Parâmetros Biomédicos Utilizados:**
  - $R$ (Resistência) e $Xc$ (Reatância) para dedução de Água Corporal Total (ACT).
  - Massa Livre de Gordura (MLG) calculada a partir de ACT ($MLG = ACT / 0.732$).
  - Massa Gorda obtida por diferença ($Peso - MLG$).

---

## 4. Diretrizes para o NutriPilot (Fase 4 — Evolução Corporal)

1. **Protocolo de Dobras:** O NutriPilot já implementou o modelo completo de 7 dobras (`BodyMeasurement.swift`). Integrar as fórmulas de Jackson & Pollock (3 e 7 dobras) diretamente no Core offline.
2. **Registro de Bioimpedância:** Permitir entrada direta dos campos padrão do Avanutri: Peso, % Gordura, % Água, Massa Muscular e Gordura Visceral.
3. **Substituição de Alimentos:** O modelo `/AlimentosPorNumSubstitutiva` do Avanutri reforça a decisão de usar grupos de equivalência nutricional para o motor da Fase 5 do NutriPilot.
