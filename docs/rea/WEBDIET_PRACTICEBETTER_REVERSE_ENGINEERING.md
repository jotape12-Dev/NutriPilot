# Relatório de Engenharia Reversa (REA) — WebDiet & Practice Better

> **Alvos:** `br.com.webdiet.webdiet` (WebDiet) & `io.practicebetter.mobile` (Practice Better)  
> **Data:** 20/10/2026  
> **Método:** Descompilação JADX, inspeção de pacotes web Cordova/WebView, análise de endpoints de HealthKit e Wearables  
> **Objetivo:** Mapear a arquitetura de anamnese/planos (WebDiet) e os protocolos de adesão, hábitos e integrações de saúde (Practice Better) para o NutriPilot.

---

## 1. WebDiet (`br.com.webdiet.webdiet`)

### 1.1 Arquitetura do Client
- **App Shell Nativo:** Construído em Kotlin com `android.webkit.WebView` e `WebChromeClient`.
- **Portal de Pacientes:** O aplicativo carrega a interface diretamente de `https://hubdiet.com/aplicativo/app_v2.php`.
- **Bridge Nativa:**
  - `gravarToken(token)`: Persistência de sessão de autenticação.
  - `fecharFloat(); removerBalaoParcial(); swal.close(); fecharCard();`: Controle de modais e alertas rápidos.
  - `sendPDF(...)`: Compartilhamento e impressão de dietas e exames laboratoriais.

### 1.2 Lições Práticas para o NutriPilot
- O WebDiet foca na simplicidade de entrega do cardápio sem cálculos pesados no dispositivo do paciente.
- No NutriPilot, como somos **100% nativos Swift/SwiftUI e offline-first**, superamos o modelo do WebDiet em velocidade de carregamento, responsividade e funcionamento sem conexão.

---

## 2. Practice Better (`io.practicebetter.mobile`)

### 2.1 Arquitetura do Client
- **Framework:** Apache Cordova / Capacitor empacotando SPA moderna (Angular/RxJS).
- **Módulos Centrais:**
  - `homeDashboardModule`: Visão do dia focada no paciente.
  - `planSummaryModule`: Resumo do plano e metas de macronutrientes.
  - `aiFormBuilderModule` & `cdn-ai.practicebetter.io`: Motor de IA para síntese de registros alimentares e sumários.

### 2.2 Integrações com Dispositivos e Wearables
O Practice Better possui o conjunto mais maduro de integrações de saúde do mercado, com endpoints mapeados:
- **Apple HealthKit:** `/hooks/apple/healthkit` (sincronização de passos, peso, treinos e frequência cardíaca).
- **Garmin Connect:** `/garmin/authorized.html` (dados de corrida e gasto energético).
- **Oura Ring:** `/ouraring/authorized.html` (recuperação e sono).
- **Cronometer:** `/cronometer/authorized.html` (banco aprofundado de micronutrientes).

### 2.3 Rastreamento de Hábitos e Protocolos
- **Protocolos por Fases:** Metas alimentares associadas a períodos de 14 a 30 dias (ex: fase de recomposição vs. manutenção).
- **Diário com Foco em Adesão:** O paciente não precisa registrar cada grama se seguir o plano prescrito — o app oferece a opção de *"Marcar refeição do plano como consumida"* com 1 toque.

---

## 3. Síntese Comparativa dos 4 Softwares Analisados

| Software | Maior Ponto Forte a Incorporar | O Que Evitar |
|---|---|---|
| **Dietbox** | As 7 dobras cutâneas e circunferências corporais completas; listas de substituição proporcional de alimentos | Complexidade excessiva de navegação e telas de nutricionista desnecessárias |
| **Nutrium** | Motor preditivo de peso (`WeightPrediction`) e notificações de água com faixa horária inteligente | Ofuscação pesada e lentidão em transições de tela |
| **WebDiet** | Cardápio limpo e direto ao ponto | Dependência de WebView online que quebra sem internet |
| **Practice Better** | Integração com Apple HealthKit e registro de refeição com 1 toque por cumprimento de plano | Burocracia de prontuários clínicos corporativos |

---

## 4. Próxima Ação no NutriPilot

Com as 4 dissecações concluídas, temos a especificação perfeita de mercado para:
1. Finalizar a Fase 1 (Perfil e Metas).
2. Avançar para a **Fase 2 (Registro Rápido em 1 Toque com Substituições e Água Inteligente)**.
