# Relatório de Engenharia Reversa (REA) — Nutrium

> **Alvo:** `co.healthium.nutrium` (v4.x - Android/iOS APK Oficial)  
> **Data:** 20/10/2026  
> **Método:** Descompilação JADX, análise de entidades Room/SQLite e mineração de strings  
> **Objetivo:** Mapear a modelagem de previsão de peso (Weight Prediction), adesão (Compliance) e notificações de água para o NutriPilot.

---

## 1. Arquitetura Geral

- **Plataforma:** Android Nativo puro (Kotlin/Java) com Android Architecture Components.
- **Persistência Local:** Banco relacional SQLite local mapeando histórico de peso, registros de hidratação e planos.
- **Modularização de Negócio:**
  - `WeightPrediction`: Motor preditivo de evolução de peso baseado no pace calórico.
  - `WaterIntake`: Gerenciador de hidratação com notificações inteligentes.
  - `MealPlanVersions`: Versionamento temporal de dietas e dias da semana.
  - `Compliance`: Rastreamento diário de adesão percentual.

---

## 2. Motor de Previsão de Peso (`WeightPrediction`)

O Nutrium implementa um algoritmo de estimativa futura de alcance de meta corporal:

```
[Peso Atual] + [Taxa de Perda Semanal (Pace)] ──> [WeightPredictionAchievementSummary]
                                               └──> [Data Prevista para a Meta]
```

- **Entidades Mapeadas:**
  - `WeightPredictionPaceSelection`: Ritmo escolhido pelo usuário (ex: -0.5 kg/sem ou -0.75 kg/sem).
  - `WeightPredictionWeightTarget`: Meta final de peso.
  - `WeightPredictionAchievementSummary`: Sumário comparativo entre o peso real registrado e a curva preditiva esperada.
- **Aplicação no NutriPilot:** No nosso módulo de evolução corporal, usaremos exatamente esse conceito: plotar a **média móvel semanal real** contra a **linha teórica de déficit** para identificar platôs precocemente.

---

## 3. Gestão e Lembretes de Hidratação (`WaterIntake`)

O Nutrium possui um dos melhores fluxos de água para evitar cansaço de notificações:

- **Faixa de Horário (`WATER_INTAKE_NOTIFICATIONS_RANGE`):** O usuário define o intervalo útil do dia (ex: 08:00 às 22:00) para receber avisos.
- **Verificação de Status (`WATER_INTAKE_NOTIFICATIONS_STATUS`):** O lembrete só dispara se o usuário estiver abaixo da meta esperada para aquele horário do dia (evita notificar quem já bebeu a água).
- **Log com Exclusão Lógica:** `WaterIntakeLog` possui `WaterIntakeLogIsDeleted`, permitindo desfazer registros acidentais facilmente.

---

## 4. Versionamento de Planos e Adesão (`Compliance`)

- **Planos Versionados (`MEAL_PLAN_VERSION`):** Em vez de sobrescrever o cardápio, cada alteração gera uma nova versão com data de vigência.
- **Cardápio por Dia da Semana (`MEAL_PLAN_VERSION_WEEKDAYS`):** Permite dias de treino (alta caloria/carboidrato) vs. dias de descanso.
- **Cálculo de Compliance (`complianceData`):** Rastreia se o usuário cumpriu as refeições recomendadas daquele dia específico.

---

## 5. Próximos Passos no NutriPilot

Com os dados do **Dietbox** e do **Nutrium** dissecados:
1. Adicionamos o cálculo de **Previsão de Meta e Linha de Tendência** no `BodyProgressView`.
2. Adicionamos a lógica de **faixa de horário inteligente** para lembretes de água.
