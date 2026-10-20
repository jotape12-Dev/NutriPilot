# Relatório de Engenharia Reversa (REA) — Dietbox

> **Alvo:** `com.craftbox.dietbox` (v8.x - Android/iOS APK Oficial)  
> **Data:** 20/10/2026  
> **Método:** Extração de assets, análise de bytecode Hermes, JADX decompile e REA inspection  
> **Objetivo:** Mapear a arquitetura de dados, rotas de API, regras antropométricas e mecânica de refeições do Dietbox para implementação no NutriPilot.

---

## 1. Arquitetura e Engenharia do Dietbox

- **Engine Mobile:** React Native + Expo (New Architecture com Fabric e Reanimated Worklets).
- **Runtime JS:** Bytecode compilado AOT do Facebook Hermes Engine (`c61f bc03`).
- **Persistência Local Offline:** **Realm Database** (`@realm/react`), permitindo leitura e gravação offline de refeições, metas e histórico de água.
- **Cache de Mídia:** Coil3 para imagens em disco e memória.

---

## 2. Endpoints e Contratos de API Identificados

A API do Dietbox é estruturada sob rotas orientadas ao paciente:

| Funcionalidade | Rota Identificada | Descrição / Payload |
|---|---|---|
| **Plano Alimentar** | `/paciente/planoalimentar` | Retorna o cardápio estruturado por refeição, horários e itens |
| **Substituições** | `/paciente/listasubstituicao` | Tabela de alimentos equivalentes por grupo nutricional |
| **Diário do Paciente** | `/paciente/diario` | Registros diários com fotos, porções e horários de consumo |
| **Avaliação Laboratorial** | `/paciente/avaliacaolaboratorial/print` | Exames de sangue e biomarcadores |
| **Notificações & Lembretes** | `@dietbox/notifications/installations/` | Registro de agendamento de água e refeições |

---

## 3. Modelo Antropométrico e Composição Corporal (REA)

O Dietbox possui um dos módulos mais completos do mercado nacional para antropometria. Foram extraídas as seguintes entidades exatas:

### 3.1 Dobras Cutâneas (`screens.anthropometry.skinfold`)
- **Peitoral:** `chestFold`
- **Abdominal:** `abdominalFold`
- **Axilar Média:** `middleAxillaryFold`
- **Subescapular:** `subscapularFold`
- **Suprailíaca:** `suprailiacFold`
- **Coxa:** `thighFold`
- **Tríceps:** `tricepsFold`

### 3.2 Circunferências Corporais
- **Braço:** `leftArmRelaxed` / `rightArmRelaxed`, `leftArmContracted` / `rightArmContracted`
- **Antebraço:** `leftForearm` / `rightForearm`
- **Punho:** `leftWrist` / `rightWrist`
- **Tronco:** `shoulder` (Ombro), `chest` (Tórax), `waist` (Cintura), `abdomen` (Abdômen), `hip` (Quadril)
- **Membros Inferiores:** `leftThigh` / `rightThigh`, `leftProximalThigh` / `rightProximalThigh`, `leftCalf` / `rightCalf` (Panturrilha)

### 3.3 Composição Corporal Derivada
- **Gordura:** `fatMassKg` e `fatMassPc` (% de gordura corporal)
- **Massa Magra:** `leanMassKg` e `leanMassPc` (% de massa magra)
- **Fracionamento:** `muscularWeight` (massa muscular), `boneWeight` (ósseo), `residualWeight` (residual)
- **Bioimpedância:** Módulo dedicado `screens.anthropometry.bioimpedance` com leitura direta de % gordura, água corporal e massa magra.

---

## 4. Mecânica do Plano Alimentar e Substituições

1. **Refeições Recorrentes:**
   - O plano alimentar é composto por blocos de refeição com horários sugeridos (`mealHour`), itens obrigatórios e lista de equivalência.
2. **Algoritmo de Substituição (`/paciente/listasubstituicao`):**
   - Cada alimento do plano possui uma lista atrelada de substitutos com a quantidade proporcional calculada para manter calorias e macros equivalentes (ex.: 100g de arroz integral = 120g de batata doce).
3. **Lista de Compras Automatizada (`screens.meal.shoppingList.text`):**
   - Agrega todos os ingredientes do plano semanal por categorias de mercado (Proteínas, Hortifrúti, Grãos/Cereais).

---

## 5. Aplicação Direta no NutriPilot

Com base nas evidências extraídas:
1. **Banco Local:** Já adotamos SwiftData no NutriPilot, que oferece a mesma garantia offline-first que o Dietbox tem com o Realm.
2. **Schema de Antropometria:** Atualizaremos o `DATA_MODEL.md` e o modelo `BodyMeasurement` para cobrir os 7 pontos de dobras cutâneas e circunferências padronizadas do Dietbox.
3. **Motor de Substituições:** Implementaremos a mesma lógica de lista de equivalência de macronutrientes na Fase 5.
