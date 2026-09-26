# Rogue Fish: design e pesquisa

Este documento resume a pesquisa feita para a versão 1.1 e mostra onde cada
ideia foi aplicada no jogo.

## 1. Por que Vampire Survivors prende o jogador

| Princípio | Como aparece no Rogue Fish |
|---|---|
| **Um único verbo, sem fricção**: só mover; os ataques são automáticos | Armas automáticas. A mordida é o "verbo extra" (segurar = morder sempre) |
| **Recompensa a cada poucos segundos**: XP, nível, baú, algo sempre acontecendo | Orbes de XP, plâncton, carcaças, combos, eventos com tempo, baús |
| **Recompensa variável** (reforço intermitente, a lógica do caça-níquel) | Baú-roleta: 1, 3 ou 5 prêmios ("TRIPLO!!", "JACKPOT!!!"), Alfas, espécies raras douradas |
| **Fantasia de poder crescente**: começar fraco e terminar destruindo a tela | 5 estágios de crescimento, evoluções lendárias, frenesi no combo 50 |
| **Feedback sensorial ("juice")** | Tom do XP que sobe a cada coleta seguida, hit-stop, tremor, números de crítico, onda de choque ao subir de nível |
| **Meta-progressão em camadas**: ouro → upgrades → desbloqueios → conquistas | Pérolas → loja ancestral; missões que desbloqueiam armas; bestiário; recompensa diária |
| **Competência e autonomia** (necessidades psicológicas) | Escolha de cartas, sinergias, dietas, espécies, rotas por bioma |

Escolhemos de propósito uma retenção **saudável**: recompensas vindas de
diversão e domínio, sem caixas de loot pagas, sem "energia" que bloqueia a
partida e sem punir quem não joga todo dia (a sequência diária volta para o dia 1,
mas nunca tira nada do jogador).

## 2. Inspirações de Everything is Crab

| Ideia | Aplicação |
|---|---|
| Você é só uma peça de um ecossistema vivo; os animais caçam uns aos outros | Cadeia alimentar completa (seção 4) com predação, fome, reprodução e carcaças |
| Afinidades definidas pelas suas escolhas | Afinidades de itens (6) + **dieta** (herbívoro / carnívoro / necrófago / onívoro) |
| Chefes são predadores de topo; dá para lutar ou se esconder em tocas até desistirem | Fique escondido por 12 s acumulados e o chefe desiste, deixando o **Alimento do Chefe** (mutação rara), mas sem o XP da carne |
| Inimigos Alfa derrubam materiais para rerrolar | Alfas com coroa derrubam **Escamas Alfa** (+1 rerrolagem) |
| Mutações que mudam o corpo | 12 mutações visuais em 4 slots, com arte própria para cada estágio |

## 3. Inspirações de Deeeep.io

| Ideia | Aplicação |
|---|---|
| Biomas distintos, cada um com animais e comida próprios | Recife de Coral (raso), Floresta de Kelp, Talude Continental, Fossa Abissal (fundo profundo) |
| Evolução por tiers e cadeia alimentar | Tiers 0–5 + ranking trófico; presas só são caçadas por quem está acima delas |
| Boost/arrancada | Botão de **Investida** com cargas e invulnerabilidade curta |
| Abismo escuro com plâncton luminoso, vulcões e peixes-lanterna | Fontes hidrotermais (luz + nutrientes), vermes tubulares, esteiras de bactérias, cardumes de peixe-lanterna bioluminescentes |

## 4. Ecossistema e ciclo de nutrientes

```
             luz do sol          fontes hidrotermais (quimiossíntese)
                 │                          │
   NUTRIENTES ──►│ PRODUTORES: kelp, fitoplâncton
       ▲         ▼
       │   HERBÍVOROS: sardinha, caramujo, ouriço, tartaruga, baiacu, peixe-lanterna
       │         ▼
       │   CARNÍVOROS: piranha, barracuda, lula, moreia, água-viva, lontra, caranguejo
       │         ▼
       │   PREDADORES: tubarão, peixe-pescador  ──►  MEGAPREDADOR: orca
       │         │ (toda morte deixa carcaça; digestão gera fezes / neve marinha)
       │         ▼
       └── DETRITÍVOROS: pepino-do-mar, isópode gigante, camarão  ◄── carcaças e detritos
```

- **Nutrientes** existem em 24 colunas do mapa. O kelp só cresce e o fitoplâncton
  só floresce onde há nutrientes (e luz, perto da superfície).
- **Detritos** (neve marinha) caem, repousam no fundo e apodrecem em nutrientes;
  os detritívoros aceleram essa reciclagem.
- **Ressurgência**: água profunda e rica sobe pelo talude e alimenta as regiões
  rasas; um pouco de "runoff" costeiro chega ao recife.
- **Fome e reprodução**: todo animal gasta energia. Bem alimentado, ele se
  reproduz (há limite por espécie); faminto, morre e vira carcaça. Predadores
  saciados deixam as presas em paz.
- **Espécie-chave**: lontras comem ouriços; sem elas, os ouriços devoram o kelp.
  Tartarugas controlam as águas-vivas.
- **Queda de baleia**: um esqueleto na fossa alimenta necrófagos o tempo todo.
- O painel **Pausa → Ecossistema** mostra as populações por nível trófico, os
  nutrientes por bioma e os nascimentos, predações e mortes de fome.

A imigração do diretor só socorre espécies que caíram abaixo de 50% da meta.
O resto da dinâmica vem da simulação.

## 5. Balanceamento (testes automatizados)

Um bot que joga de forma imprudente (vai atrás de tudo) serve de limite
inferior de habilidade:

- Sem modo imortal: ~2 em 3 partidas vencem os 4 chefes; derrotas vêm de
  tartarugas provocadas, orcas e matilhas no começo.
- Chefes duram ~45–60 s contra o bot.
- A cadeia alimentar se mantém estável por 10+ minutos: herbívoros ~40–65,
  carnívoros ~20–30 fora das ondas, predadores 2–8, nutrientes oscilando entre
  os biomas sem extinções.

Os números ficam em `scripts/autoload/db.gd` (criaturas, populações, bosses,
curva de XP) e em `scripts/game/director.gd` (dificuldade por ciclo).

## Fontes
- Vampire Survivors e psicologia do jogo: [University of Portsmouth](https://www.port.ac.uk/news-events-and-blogs/blogs/popular-culture/vampire-survivors-how-developers-used-gambling-psychology-to-create-a-bafta-winning-game), [HackerNoon](https://hackernoon.com/the-vampire-survivors-effect-how-developers-utilize-gambling-psychology-to-create-addictive-games), [Kokutech](https://www.kokutech.com/blog/gamedev/design-patterns/power-fantasy/vampire-survivors), [Platinum Paragon](https://platinumparagon.info/psychology-of-vampire-survivors/)
- Loops de recompensa sem manipulação: [Medium – Rakesh Roy](https://medium.com/@rakeshroyakula/designing-reward-loops-that-keep-players-hooked-without-manipulation-58447c858d4a), [Egmatic – game feel](https://egmatic.com/blog/how-to-make-your-game-feel-good)
- Everything is Crab: [Steam](https://store.steampowered.com/app/3526710/Everything_is_Crab_The_Animal_Evolution_Roguelite/), [Rogueliker](https://rogueliker.com/everything-is-crab-review/), [TheGamer](https://www.thegamer.com/everything-is-crab-review/), [Wiki](https://everythingiscrab.wiki.gg/wiki/Evolution)
- Deeeep.io: [Wiki – Mecânicas](https://deeeepio.fandom.com/wiki/Mechanics), [Guia de biomas](https://sites.google.com/view/deeeepio-guide/biomes), [Food & Diet](https://deeeepio.fandom.com/wiki/Food_%26_Diet)
- Ecologia marinha: [NOAA – Aquatic food webs](https://www.noaa.gov/education/resource-collections/marine-life/aquatic-food-webs), [MarineBio – Trophic structure](https://www.marinebio.org/conservation/marine-ecology/trophic-structure/), [Neve marinha (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8632794/)
