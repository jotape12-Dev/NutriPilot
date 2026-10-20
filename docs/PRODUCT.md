# NutriPilot — Documento de Produto (PRODUCT.md)

> **Versão:** 1.0  
> **Objetivo:** Assistente pessoal de nutrição de alta precisão, ultrarrápido e sucinto para uso diário do próprio usuário (João).  
> **Filosofia:** Menos dashboard, mais decisão imediata.

---

## 1. Visão Geral e Princípios

1. **Uso Pessoal e Direto:** Funciona localmente no dispositivo do usuário. Sem burocracias desnecessárias, onboarding comercial ou restrições multiusuário.
2. **Registro de Atrito Mínimo:**
   - Água: 1 toque via botões rápidos (< 2s).
   - Comida: texto rápido, voz ou favoritos recorrentes (< 10s).
3. **Decisão Acionável em Poucas Linhas:**
   - Respostas do assistente e resumos devem ter no máximo 4 linhas, sempre sugerindo a próxima ação concreta (ex.: calorias/proteínas restantes e o que comer no jantar).
4. **Estimativas Calibradas e Transparentes:**
   - Estimativas de TMB/GET iniciais são refinadas após 14 dias de tendência de peso.
   - Gordura corporal estimada por foto sempre em **faixa com grau de confiança**, calibrável com dados reais de bioimpedância e DEXA.
   - Sem diagnósticos clínicos ou promessas irreais de ganho muscular absoluto em kg por foto.
5. **Autônomo com Modo Profissional Opcional:**
   - Totalmente funcional sem depender de nutricionista, com possibilidade de exportar dados resumidos (PDF/JSON) para consulta.

---

## 2. Personas e Cenários de Uso

- **Usuário:** João, desenvolvedor/estudante, treina musculação e corrida, utiliza iPhone e Apple Watch.
- **Cenário Diário:**
  - Acordar: registra peso rápido e primeira dose de água (500 ml).
  - Almoço: digita ou fala *"200g frango, 150g arroz e salada"*. O app identifica macros e confirma com 1 toque.
  - Tarde: consulta *"Como está meu dia?"* -> App responde: *"70% das calorias, faltam 35g de proteína e 1L de água. Sugestão: lanche proteico agora."*
  - Noite: bate as metas com o jantar planejado.

---

## 3. Módulos do Produto (MVP)

| Módulo | Prioridade | Descrição Principal |
|---|:---:|---|
| **Perfil & Metas** | P0 | Cálculo de TMB (Mifflin-St Jeor), GET por atividade/treino, metas de macros, água e fibras |
| **Diário Alimentar** | P0 | Registro via texto rápido, voz, busca TBCA/alimentos brasileiros e refeições favoritas |
| **Hidratação** | P0 | Meta diária automática, botões rápidos (100ml, 250ml, 500ml, 1L) e histórico |
| **Resumo Inteligente** | P0 | Card principal com progresso diário e sugestão curta da próxima refeição |
| **Evolução Corporal** | P0 | Peso com média móvel semanal, circunferências e tendências |
| **Fotos & Bioimpedância** | P1 | Fotos padronizadas, importação de dados de bioimpedância e calibração de gordura |
| **Plano Alimentar & Compras**| P1 | Cardápio sugerido, substituições por macronutrientes equivalentes e lista de compras |
| **Assistente Nutricional** | P1 | Chat pontual para dúvidas da rotina diária e ajustes de porções |
