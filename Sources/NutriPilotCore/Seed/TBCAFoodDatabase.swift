import Foundation

/// Banco de dados local em memória com sementes de alimentos baseadas na Tabela Brasileira de Composição de Alimentos (TBCA / TACO).
/// Fornece dados nutricionais por 100g e medidas caseiras comuns na rotina brasileira.
public enum TBCAFoodDatabase {
    public static let foods: [FoodItem] = [
        FoodItem(
            name: "Arroz branco cozido",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 128.0,
            proteinGrams: 2.5,
            carbsGrams: 28.1,
            fatGrams: 0.2,
            fiberGrams: 1.6,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 25.0, description: "1 colher de sopa (25g)"),
                FoodPortion(name: "Escumadeira cheia", gramWeight: 100.0, description: "1 escumadeira cheia (100g)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 150.0, description: "1 xícara de chá (150g)")
            ]
        ),
        FoodItem(
            name: "Arroz integral cozido",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 124.0,
            proteinGrams: 2.6,
            carbsGrams: 25.8,
            fatGrams: 1.0,
            fiberGrams: 2.7,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 25.0, description: "1 colher de sopa (25g)"),
                FoodPortion(name: "Escumadeira cheia", gramWeight: 100.0, description: "1 escumadeira cheia (100g)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 150.0, description: "1 xícara de chá (150g)")
            ]
        ),
        FoodItem(
            name: "Feijão carioca cozido (50% grão / 50% caldo)",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 76.0,
            proteinGrams: 4.8,
            carbsGrams: 13.6,
            fatGrams: 0.5,
            fiberGrams: 4.9,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Concha média", gramWeight: 130.0, description: "1 concha média (130g)"),
                FoodPortion(name: "Concha pequena", gramWeight: 80.0, description: "1 concha pequena (80g)"),
                FoodPortion(name: "Colher de sopa", gramWeight: 25.0, description: "1 colher de sopa (25g)")
            ]
        ),
        FoodItem(
            name: "Feijão preto cozido (50% grão / 50% caldo)",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 77.0,
            proteinGrams: 4.5,
            carbsGrams: 14.0,
            fatGrams: 0.5,
            fiberGrams: 4.6,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Concha média", gramWeight: 130.0, description: "1 concha média (130g)"),
                FoodPortion(name: "Concha pequena", gramWeight: 80.0, description: "1 concha pequena (80g)"),
                FoodPortion(name: "Colher de sopa", gramWeight: 25.0, description: "1 colher de sopa (25g)")
            ]
        ),
        FoodItem(
            name: "Peito de frango grelhado",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 163.0,
            proteinGrams: 31.5,
            carbsGrams: 0.0,
            fatGrams: 3.2,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Filé médio", gramWeight: 100.0, description: "1 filé médio (100g)"),
                FoodPortion(name: "Filé grande", gramWeight: 150.0, description: "1 filé grande (150g)"),
                FoodPortion(name: "Filé pequeno", gramWeight: 70.0, description: "1 filé pequeno (70g)"),
                FoodPortion(name: "Colher de sopa picado", gramWeight: 25.0, description: "1 colher de sopa picado (25g)")
            ]
        ),
        FoodItem(
            name: "Peito de frango cozido desfiado",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 159.0,
            proteinGrams: 30.2,
            carbsGrams: 0.0,
            fatGrams: 3.5,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 25.0, description: "1 colher de sopa cheia (25g)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 120.0, description: "1 xícara de chá (120g)")
            ]
        ),
        FoodItem(
            name: "Ovo de galinha cozido",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 146.0,
            proteinGrams: 13.3,
            carbsGrams: 0.6,
            fatGrams: 9.5,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 50.0, description: "1 ovo médio (50g)"),
                FoodPortion(name: "Unidade grande", gramWeight: 60.0, description: "1 ovo grande (60g)")
            ]
        ),
        FoodItem(
            name: "Ovo de galinha mexido",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 170.0,
            proteinGrams: 12.0,
            carbsGrams: 1.2,
            fatGrams: 12.5,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade mexida (1 ovo)", gramWeight: 50.0, description: "1 ovo mexido (50g)"),
                FoodPortion(name: "Porção com 2 ovos", gramWeight: 100.0, description: "2 ovos mexidos (100g)")
            ]
        ),
        FoodItem(
            name: "Clara de ovo cozida",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 52.0,
            proteinGrams: 11.0,
            carbsGrams: 0.7,
            fatGrams: 0.2,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Clara de 1 ovo médio", gramWeight: 33.0, description: "1 clara (33g)"),
                FoodPortion(name: "Clara de 2 ovos médios", gramWeight: 66.0, description: "2 claras (66g)")
            ]
        ),
        FoodItem(
            name: "Patinho bovino grelhado",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 219.0,
            proteinGrams: 35.9,
            carbsGrams: 0.0,
            fatGrams: 7.3,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Bife médio", gramWeight: 100.0, description: "1 bife médio (100g)"),
                FoodPortion(name: "Bife grande", gramWeight: 150.0, description: "1 bife grande (150g)"),
                FoodPortion(name: "Colher de sopa moído", gramWeight: 30.0, description: "1 colher de sopa moído (30g)")
            ]
        ),
        FoodItem(
            name: "Carne bovina moída refogada",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 225.0,
            proteinGrams: 28.5,
            carbsGrams: 1.5,
            fatGrams: 11.2,
            fiberGrams: 0.2,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 30.0, description: "1 colher de sopa cheia (30g)"),
                FoodPortion(name: "Escumadeira média", gramWeight: 100.0, description: "1 escumadeira (100g)")
            ]
        ),
        FoodItem(
            name: "Pão francês",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 300.0,
            proteinGrams: 8.0,
            carbsGrams: 58.7,
            fatGrams: 3.1,
            fiberGrams: 2.3,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade", gramWeight: 50.0, description: "1 pão francês inteiro (50g)"),
                FoodPortion(name: "Metade sem miolo", gramWeight: 20.0, description: "1 metade sem miolo (20g)")
            ]
        ),
        FoodItem(
            name: "Pão de forma integral",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 253.0,
            proteinGrams: 9.4,
            carbsGrams: 46.2,
            fatGrams: 3.7,
            fiberGrams: 6.9,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Fatia", gramWeight: 25.0, description: "1 fatia (25g)"),
                FoodPortion(name: "2 Fatias (Sanduíche)", gramWeight: 50.0, description: "2 fatias (50g)")
            ]
        ),
        FoodItem(
            name: "Aveia em flocos",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 394.0,
            proteinGrams: 13.9,
            carbsGrams: 66.6,
            fatGrams: 8.5,
            fiberGrams: 9.1,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 15.0, description: "1 colher de sopa cheia (15g)"),
                FoodPortion(name: "Colher de sobremesa", gramWeight: 8.0, description: "1 colher de sobremesa (8g)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 60.0, description: "1 xícara de chá (60g)")
            ]
        ),
        FoodItem(
            name: "Banana prata crua",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 98.0,
            proteinGrams: 1.3,
            carbsGrams: 26.0,
            fatGrams: 0.1,
            fiberGrams: 2.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 70.0, description: "1 banana média (70g)"),
                FoodPortion(name: "Unidade grande", gramWeight: 100.0, description: "1 banana grande (100g)")
            ]
        ),
        FoodItem(
            name: "Banana nanica crua",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 92.0,
            proteinGrams: 1.4,
            carbsGrams: 23.8,
            fatGrams: 0.1,
            fiberGrams: 1.9,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 85.0, description: "1 banana média (85g)"),
                FoodPortion(name: "Unidade grande", gramWeight: 120.0, description: "1 banana grande (120g)")
            ]
        ),
        FoodItem(
            name: "Maçã com casca",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 52.0,
            proteinGrams: 0.3,
            carbsGrams: 13.8,
            fatGrams: 0.2,
            fiberGrams: 2.4,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 130.0, description: "1 maçã média (130g)"),
                FoodPortion(name: "Unidade pequena", gramWeight: 90.0, description: "1 maçã pequena (90g)")
            ]
        ),
        FoodItem(
            name: "Mamão papaia",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 40.0,
            proteinGrams: 0.5,
            carbsGrams: 10.4,
            fatGrams: 0.1,
            fiberGrams: 1.8,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Metade média", gramWeight: 140.0, description: "1/2 mamão papaia (140g)"),
                FoodPortion(name: "Fatia", gramWeight: 100.0, description: "1 fatia média (100g)")
            ]
        ),
        FoodItem(
            name: "Tapioca (goma hidratada pronta)",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 242.0,
            proteinGrams: 0.0,
            carbsGrams: 60.0,
            fatGrams: 0.0,
            fiberGrams: 0.5,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 20.0, description: "1 colher de sopa (20g)"),
                FoodPortion(name: "Disco médio (3 colheres)", gramWeight: 60.0, description: "1 disco médio (60g)")
            ]
        ),
        FoodItem(
            name: "Batata doce cozida",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 77.0,
            proteinGrams: 0.6,
            carbsGrams: 18.4,
            fatGrams: 0.1,
            fiberGrams: 2.2,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 120.0, description: "1 batata média (120g)"),
                FoodPortion(name: "Fatia grossa", gramWeight: 50.0, description: "1 fatia grossa (50g)")
            ]
        ),
        FoodItem(
            name: "Batata inglesa cozida",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 52.0,
            proteinGrams: 1.2,
            carbsGrams: 11.9,
            fatGrams: 0.0,
            fiberGrams: 1.3,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 140.0, description: "1 batata média (140g)"),
                FoodPortion(name: "Colher de sopa cheia (purê)", gramWeight: 40.0, description: "1 colher de sopa (40g)")
            ]
        ),
        FoodItem(
            name: "Mandioca / Aipim cozido",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 125.0,
            proteinGrams: 0.6,
            carbsGrams: 30.1,
            fatGrams: 0.3,
            fiberGrams: 1.6,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Pedaço médio", gramWeight: 100.0, description: "1 pedaço médio (100g)"),
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 35.0, description: "1 colher de sopa (35g)")
            ]
        ),
        FoodItem(
            name: "Leite de vaca desnatado",
            servingSize: 100.0,
            servingUnit: "ml",
            calories: 35.0,
            proteinGrams: 3.4,
            carbsGrams: 5.0,
            fatGrams: 0.1,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Copo americano", gramWeight: 190.0, description: "1 copo americano (190ml)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 200.0, description: "1 xícara de chá (200ml)"),
                FoodPortion(name: "Caneca", gramWeight: 250.0, description: "1 caneca (250ml)")
            ]
        ),
        FoodItem(
            name: "Leite de vaca integral",
            servingSize: 100.0,
            servingUnit: "ml",
            calories: 60.0,
            proteinGrams: 3.2,
            carbsGrams: 4.8,
            fatGrams: 3.2,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Copo americano", gramWeight: 190.0, description: "1 copo americano (190ml)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 200.0, description: "1 xícara de chá (200ml)")
            ]
        ),
        FoodItem(
            name: "Iogurte natural desnatado",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 43.0,
            proteinGrams: 4.2,
            carbsGrams: 5.8,
            fatGrams: 0.3,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Pote individual", gramWeight: 160.0, description: "1 pote (160g)"),
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 30.0, description: "1 colher de sopa cheia (30g)")
            ]
        ),
        FoodItem(
            name: "Queijo minas frescal",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 227.0,
            proteinGrams: 17.4,
            carbsGrams: 3.2,
            fatGrams: 16.0,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Fatia média", gramWeight: 30.0, description: "1 fatia média (30g)"),
                FoodPortion(name: "Fatia grossa", gramWeight: 50.0, description: "1 fatia grossa (50g)")
            ]
        ),
        FoodItem(
            name: "Queijo muçarela",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 280.0,
            proteinGrams: 22.0,
            carbsGrams: 2.2,
            fatGrams: 20.8,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Fatia", gramWeight: 20.0, description: "1 fatia (20g)"),
                FoodPortion(name: "2 Fatias", gramWeight: 40.0, description: "2 fatias (40g)")
            ]
        ),
        FoodItem(
            name: "Queijo cottage",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 98.0,
            proteinGrams: 11.1,
            carbsGrams: 3.4,
            fatGrams: 4.3,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 30.0, description: "1 colher de sopa (30g)"),
                FoodPortion(name: "Pote individual", gramWeight: 150.0, description: "1 pote (150g)")
            ]
        ),
        FoodItem(
            name: "Azeite de oliva extra virgem",
            servingSize: 100.0,
            servingUnit: "ml",
            calories: 884.0,
            proteinGrams: 0.0,
            carbsGrams: 0.0,
            fatGrams: 100.0,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa", gramWeight: 13.0, description: "1 colher de sopa (13ml)"),
                FoodPortion(name: "Colher de sobremesa", gramWeight: 5.0, description: "1 colher de sobremesa (5ml)")
            ]
        ),
        FoodItem(
            name: "Filé de tilápia grelhado",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 128.0,
            proteinGrams: 26.2,
            carbsGrams: 0.0,
            fatGrams: 2.7,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Filé médio", gramWeight: 120.0, description: "1 filé médio (120g)"),
                FoodPortion(name: "Filé pequeno", gramWeight: 80.0, description: "1 filé pequeno (80g)")
            ]
        ),
        FoodItem(
            name: "Salmão grelhado",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 206.0,
            proteinGrams: 22.1,
            carbsGrams: 0.0,
            fatGrams: 12.4,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Posta média", gramWeight: 120.0, description: "1 posta média (120g)"),
                FoodPortion(name: "Posta grande", gramWeight: 180.0, description: "1 posta grande (180g)")
            ]
        ),
        FoodItem(
            name: "Atum em conserva em água (drenado)",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 116.0,
            proteinGrams: 26.0,
            carbsGrams: 0.0,
            fatGrams: 1.0,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Lata inteira escorrida", gramWeight: 120.0, description: "1 lata drenada (120g)"),
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 30.0, description: "1 colher de sopa (30g)")
            ]
        ),
        FoodItem(
            name: "Whey Protein Concentrado 80%",
            brand: "Geral",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 400.0,
            proteinGrams: 80.0,
            carbsGrams: 6.0,
            fatGrams: 6.0,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Scoop padrão (1 dosador)", gramWeight: 30.0, description: "1 scoop (30g)"),
                FoodPortion(name: "Meio scoop", gramWeight: 15.0, description: "1/2 scoop (15g)")
            ]
        ),
        FoodItem(
            name: "Pasta de amendoim integral",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 588.0,
            proteinGrams: 25.0,
            carbsGrams: 20.0,
            fatGrams: 50.0,
            fiberGrams: 8.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Colher de sopa cheia", gramWeight: 20.0, description: "1 colher de sopa cheia (20g)"),
                FoodPortion(name: "Colher de sobremesa", gramWeight: 10.0, description: "1 colher de sobremesa (10g)")
            ]
        ),
        FoodItem(
            name: "Castanha-do-Pará",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 656.0,
            proteinGrams: 14.3,
            carbsGrams: 12.3,
            fatGrams: 66.4,
            fiberGrams: 7.5,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade", gramWeight: 4.0, description: "1 castanha (4g)"),
                FoodPortion(name: "Porção (2 unidades)", gramWeight: 8.0, description: "2 castanhas (8g)")
            ]
        ),
        FoodItem(
            name: "Brócolis cozido",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 25.0,
            proteinGrams: 2.1,
            carbsGrams: 4.4,
            fatGrams: 0.5,
            fiberGrams: 3.4,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Ramo médio", gramWeight: 35.0, description: "1 ramo médio (35g)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 100.0, description: "1 xícara de chá (100g)")
            ]
        ),
        FoodItem(
            name: "Cenoura crua",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 34.0,
            proteinGrams: 1.3,
            carbsGrams: 7.7,
            fatGrams: 0.2,
            fiberGrams: 3.2,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 100.0, description: "1 cenoura média (100g)"),
                FoodPortion(name: "Colher de sopa ralada", gramWeight: 20.0, description: "1 colher de sopa ralada (20g)")
            ]
        ),
        FoodItem(
            name: "Tomate cru",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 15.0,
            proteinGrams: 1.1,
            carbsGrams: 3.1,
            fatGrams: 0.2,
            fiberGrams: 1.2,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Unidade média", gramWeight: 100.0, description: "1 tomate médio (100g)"),
                FoodPortion(name: "Fatia média", gramWeight: 20.0, description: "1 fatia média (20g)")
            ]
        ),
        FoodItem(
            name: "Alface crespa",
            servingSize: 100.0,
            servingUnit: "g",
            calories: 11.0,
            proteinGrams: 1.3,
            carbsGrams: 1.7,
            fatGrams: 0.2,
            fiberGrams: 1.8,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Folha média", gramWeight: 15.0, description: "1 folha média (15g)"),
                FoodPortion(name: "Prato de sobremesa cheio", gramWeight: 50.0, description: "Prato de sobremesa (50g)")
            ]
        ),
        FoodItem(
            name: "Café preto sem açúcar",
            servingSize: 100.0,
            servingUnit: "ml",
            calories: 2.0,
            proteinGrams: 0.1,
            carbsGrams: 0.3,
            fatGrams: 0.0,
            fiberGrams: 0.0,
            source: "TBCA",
            portions: [
                FoodPortion(name: "Xícara de café", gramWeight: 50.0, description: "1 xícara de café (50ml)"),
                FoodPortion(name: "Xícara de chá", gramWeight: 150.0, description: "1 xícara de chá (150ml)"),
                FoodPortion(name: "Caneca", gramWeight: 200.0, description: "1 caneca (200ml)")
            ]
        )
    ]
}
