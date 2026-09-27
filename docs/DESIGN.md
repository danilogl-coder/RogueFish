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

### Chefes jogáveis e o Titanacon (v1.2)

- **Vencer um chefe o transforma em espécie jogável** (Tubarão-Rei, Kraken Jovem, Rainha Abissal, Leviatã,
  Titanacon). É uma meta-recompensa de longo prazo que dá motivo para voltar e dominar cada chefe,
  no espírito de Everything is Crab, onde você joga com os animais que evoluiu.
- **Titanacon** inverte a luta: em vez de fugir do chefe, o objetivo é **ser engolido**. Por fora as
  placas reduzem o dano a 12% (30% com a boca aberta); ao sugar o mar ele puxa o jogador para a boca. Dentro do estômago
  (visto em raio-x, preso ao corpo do titã, que continua nadando pelo mapa) só o **coração** e as **glândulas de ácido** ferem o titã, os **parasitas**
  os protegem, o **ácido** no fundo queima e a **digestão** tira vida aos poucos. Com 25% da vida dele
  tirados por dentro, ele cospe o jogador e fica atordoado (vulnerável) por alguns segundos.

### Parasitas: colônia dentro do jogador (v1.3)

- Pesquisa: o *Cymothoa exigua* entra pelas brânquias como macho; sem fêmea, um macho vira fêmea e o casal
  cruza dentro do hospedeiro. O verme-de-bobbit caça enterrado na areia. Poliquetas carregam larvas de parasitas.
- Objetivo de design: transformar a infecção numa **escolha de risco e recompensa**, não numa punição chata.
  Custos: -1,2% de velocidade e -2,2% de XP por parasita (máx. -28% e -50%). Ganhos: cura com vida abaixo de 30%,
  salva da morte (a partir de 4 parasitas, perde metade), e o **Enxame** ao chegar a 24 (dano contínuo
  escalado pelo seu dano). O jogador decide: **cultivar** a colônia (sobrevivência e enxames) ou **limpar**
  comendo camarões (velocidade e XP de volta).
- Visibilidade: painel de raio-x com o próprio sprite do jogador, piolhos animados, ovos que incham até
  eclodir, anéis nos eventos (entrada, cruzamento, eclosão, troca de sexo, limpeza) e piolhos visíveis no corpo.

### Marés Profundas (v1.4)

**Personagens e itens (Vampire Survivors).** No VS cada personagem começa com sua arma, e as armas
são liberadas por conquistas; relíquias liberam sistemas (Arcanas, Limit Break) e modos (Hyper,
Inverse, Endless) aumentam risco e recompensa. Aqui:
- o **item único** de cada personagem só entra no conjunto de cartas quando ele é liberado. Assim,
  cada personagem novo também amplia as builds possíveis de todos os outros (motivo para
  colecionar);
- os caminhos de desbloqueio misturam **compra** (metas curtas), **metas de jogo** (piranhas,
  moreias, ouriços, minhocas, dourados, orcas, carcaças, enxames) e **chefes**;
- a **Coroa de Coral** é o nosso Limit Break (nível 7), a **Rosa-dos-Ventos** libera as Marés
  (Arcanas) e os modos Mutante, Maré Alta e Abismo Invertido seguem Hyper e Inverse, com bônus de
  pérolas.

**Fusão.** No VS, a "Union" junta duas armas no nível máximo numa só (ex.: Peachone + Ebony Wings
= Vandalier). Aqui a fusão aparece como carta lendária assim que as duas armas da receita chegam ao
nível 5 (sem precisar de baú). A arma fundida libera um espaço e **continua subindo até o nível 10**:
+16% de dano e -3,5% de recarga por nível, +1 quantidade a cada 3 níveis e +1 perfuração a cada 4.

**Música que dá prazer (sem truques abusivos).** A pesquisa sobre música e recompensa mostra que o
prazer musical nasce da **antecipação e resolução** (dopamina liberada na expectativa e no clímax),
que trilhas **adaptativas** aumentam o tempo de jogo e que loops curtos cansam. Aplicado:
- um gancho melódico claro por faixa, repetido e variado (A, A', B, C), com clímax na seção C e
  virada de bateria + riser voltando ao refrão;
- **camadas adaptativas**: a camada calma toca sempre e a camada de tensão (bateria, baixo, lead)
  entra com o perigo, o combo e as ondas, então a música acompanha o momento da partida;
- sons de recompensa **no tom** da trilha (vinheta de nível em Ré maior) e vinhetas de vitória,
  derrota e fusão que abaixam a música por instantes;
- timbres suaves, agudos contidos e loops de 55 a 65 s sem emenda audível, para evitar fadiga.
Evitamos deliberadamente táticas de manipulação (recompensas enganosas, pressão artificial): o
objetivo é o jogador sentir prazer em jogar, não ser explorado.

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
- Vampire Survivors (evolução, união, relíquias, arcanas, modos): [VS Wiki – Evolution](https://vampire.survivors.wiki/w/Evolution), [Stages e modos](https://vampire.survivors.wiki/w/Stages), [Limit Break](https://vampire.survivors.wiki/w/Limit_Break), [Arcanas](https://vampire-survivors.fandom.com/wiki/Arcanas)
- Música e recompensa: [PNAS – dopamina e prazer musical](https://www.pnas.org/doi/10.1073/pnas.1811878116), [GameGrin – psicologia da música de jogos](https://www.gamegrin.com/articles/the-psychology-of-game-music-and-why-it-keeps-players-engaged/), [Metacore – som em jogos mobile](https://metacoregames.com/news/hear-me-out-designing-sound-for-mobile-games), [A Sound Effect – fadiga e repetição](https://www.asoundeffect.com/game-audio-immersion/), [Marius Masalar – trilha de Vampire Survivors](https://marius.ink/post/the-vampire-survivors-soundtrack-has-no-business-being-this-good)
- Ecologia marinha: [NOAA – Aquatic food webs](https://www.noaa.gov/education/resource-collections/marine-life/aquatic-food-webs), [MarineBio – Trophic structure](https://www.marinebio.org/conservation/marine-ecology/trophic-structure/), [Neve marinha (PMC)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8632794/)
