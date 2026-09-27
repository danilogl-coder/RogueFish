# Rogue Fish

Roguelike de sobrevivência subaquático para celular (Godot 4.5, renderizador
Compatibility, paisagem). Você começa como um alevino, come para crescer,
monta builds com cartas estilo *Vampire Survivors*, sofre mutações que mudam a
aparência do peixe e enfrenta ondas e chefes até dominar o oceano.

## Requisitos atendidos

| Requisito | Onde |
|---|---|
| Peixe animado | 6 quadros de nado + 4 de mordida com mandíbula articulada (a boca abre de verdade, com dentes, língua e brânquias). `scripts/game/player_visual.gd` |
| Movimento por joystick | `scripts/ui/touch_controls.gd`: joystick flutuante no lado esquerdo |
| Botão de ataque | Botão à direita (segure para morder sem parar), com mira assistida |
| Background com parallax | `world.gd` (3 camadas + fundo com raios de luz) e `ambient.gd` (neve marinha, cardumes distantes) |
| Crescimento do peixe | 5 estágios: Alevino, Juvenil, Adulto, Veterano e Leviatã. Sprite maior, mais vida e mordida; engole criaturas menores inteiras |
| Nível, status e pontos | XP → nível; cada nível dá 1 ponto de atributo (FOR/VIT/AGI/INS) + escolha de carta |
| Barra de vida | HUD + barras de vida nos inimigos feridos + barra do chefe |
| Cartas estilo Vampire Survivors | 36 itens, 11 passivas, 7 evoluções lendárias (arma nv5 + passiva parceira), 18 FUSÕES (duas armas nv5 viram uma que sobe até o nível 10), rerrolagem e banimento |
| Ecossistema planta/herbívoro/predador | Cadeia alimentar completa com ciclo de nutrientes: produtores (kelp, fitoplâncton, quimiossíntese), detritívoros, herbívoros, carnívoros, predadores e a orca (megapredador). Fome, reprodução, carcaças e reciclagem. Veja `docs/DESIGN.md` |
| Esconderijos | Cavernas e moitas de algas: predadores perdem o rastro, você regenera (limitado pela barra de furtividade) |
| Pontos de interesse com tempo | Baú (morda 3x), ostra gigante (cura), fenda térmica (+30% dano, guardada por caranguejos) e cardume dourado. Aparecem com timer e setas na borda da tela |
| Tempo → Onda → Chefe | `director.gd`: EXPLORAR (timer) → ONDA (horda) → CHEFE. São 5 ciclos; depois da vitória há o modo infinito |
| Menu inicial, game over, upgrades rogue-lite | `main_menu.gd` (espécies, loja de evolução ancestral, guia, opções, créditos), `game_over.gd`, `pause_menu.gd` |
| Evoluções que mudam a aparência | 12 mutações em 4 slots (cabeça, nadadeiras, pele e cauda), cada uma com arte própria em todos os estágios e espécies. Cabeça e pele são desenhadas junto do corpo (a Mandíbula de Piranha é a própria mandíbula do peixe) |
| Sinergias | 6 afinidades (Elétrico, Veneno, Abissal, Coral, Predador, Corrente) com bônus em 2 e 4 itens + 3 combinações cruzadas |

### Marés Profundas (v1.4): a grande expansão
- **30+ personagens jogáveis**: todo bicho do oceano (peixes, invertebrados, a lontra, a orca, a
  minhoca, o piolho...) e os chefes vencidos. Cada um tem **atributos**, um **TRAÇO** exclusivo
  (esquiva, bloqueio, inflar, emboscada, devorar, colônia, jato de tinta...) e um **ITEM ÚNICO**.
  Como em *Vampire Survivors*, o item só aparece nas cartas depois que você libera o personagem
  (compra com pérolas, meta de jogo como "derrote 250 piranhas" ou vencendo o chefe).
- **Aparência que evolui**: cada personagem tem 5 estágios desenhados (barbatanas maiores,
  cicatrizes, fotóforos no estágio Leviatã; nos invertebrados, pintas, marcas e bioluminescência),
  e aceita todas as 12 mutações.
- **Motor de itens por arquétipos** (`scripts/data/arsenal.gd` + `Weapon`): tiro, nova, órbita,
  aura, chicote, raio, armadilha, bumerangue, ricochete, bote, impacto, invocação, rastro,
  arremesso, tentáculos, vórtice e feixes giratórios.
- **FUSÃO**: duas armas específicas no nível 5 viram uma arma fundida (libera um espaço) que sobe
  até o **nível 10**. Receitas na tela COLEÇÃO; a aba ARSENAL da pausa mostra o que falta.
- **LOJA DO RECIFE** (`scripts/data/shop.gd`): expansões, relíquias, marés e modos.
  - Expansões: **Fontes Hidrotermais** (bioma novo, o mapa passa de 4800 m para 6000 m, chaminés em
    erupção, Caranguejo-Yeti e Verme-Tubo), **Criaturas Luminosas** (Peixe-Víbora e Lula-Vampira) e
    **Megalodonte** (6º chefe, vira personagem ao ser vencido).
  - Relíquias: Coroa de Coral (armas até nv 7), Âncora do Banimento, Rosa-dos-Ventos (libera as
    marés), Âmbar Ancestral, Garrafa de Mensagens, Pérola Negra, Ampulheta Abissal, Olho de Netuno e
    Caixa de Música (escolha a trilha).
  - Marés (como as Arcanas): Vermelha, Prata, Negra, Elétrica, Viva e Dourada.
  - Modos: **Mutante** (variantes Fúria, Tóxico, Blindado, Sombra e Tesouro), **Maré Alta** e
    **Abismo Invertido**, cada um com bônus de pérolas.
- **Trilha sonora nova e adaptativa** (`tools/audio/compose_music.py`): a música antiga foi removida.
  A partida toca duas camadas sincronizadas (calma + tensão) e a camada de tensão sobe com o perigo,
  o combo e as ondas. Chefes e menu têm temas próprios, e as vinhetas de nível ficam no tom da música.
- **Correções visuais**: os cardumes do fundo usavam o tamanho de quadro antigo (apareciam cortados)
  e seguiam a câmera (saíam da água); a ponta da cauda do tubarão se soltava. Todo quadro de sprite
  agora passa por `tools/art/tidy.py`, que reconecta pontas soltas, e `tools/art/audit_islands.py`
  audita o resultado.

### Mundo (v1.1)
4 biomas com relevo próprio: **Recife de Coral** (raso), **Floresta de Kelp**,
**Talude Continental** (degraus com ressurgência) e **Fossa Abissal** (fontes
hidrotermais, vermes tubulares, queda de baleia, peixes-lanterna).

O fundo do mar vem de um único mapa de altura (`assets/art/terrain.json`)
usado tanto pela arte quanto por `DB.floor_at()`: cavernas, moitas, fontes e a
baleia ficam em prateleiras planas, e a borda da areia é desenhada na frente das
bases para que nada flutue. Detalhes em `docs/ART.md`.

### Retenção (v1.1)
Combo com multiplicador de XP e frenesi, tom do XP que sobe a cada coleta
seguida, baú-roleta (1/3/5 prêmios), onda de choque ao subir de nível, Alfas
com escamas, dieta que dá bônus, investida (dash), chefes que desistem se você
se esconder, 25 missões com desbloqueios, bestiário e recompensa diária.
Pesquisa e justificativas em `docs/DESIGN.md`.

### Criaturas e comportamentos
Pepino-do-mar e Isópode gigante (recicladores do fundo), Ouriço (devora o kelp),
Lontra-marinha (espécie-chave que come ouriços), Peixe-lanterna (cardume
bioluminescente), Orca (megapredador que caça até tubarões),
Camarão (salta para fugir), Sardinha (cardume com boids), Caramujo (pasta algas e
se fecha na concha), Baiacu (infla com espinhos), Tartaruga (pacífica, investe se
atacada), Piranha (matilha com botes), Barracuda (espreita, sinaliza e dispara em
linha reta), Água-viva (deriva, queima, prende presas), Moreia (emboscada na
toca), Tubarão (circula e investe), Peixe-pescador (isca luminosa atrai presas no
abismo), Caranguejo (salta do fundo), Lula (mantém distância, cospe tinta,
foge soltando nuvem).

### Chefes
1. **Mandíbula, o Tubarão-Rei**: circula, investidas sinalizadas, invoca piranhas; na fúria faz investidas duplas.
2. **Kraken das Marés**: tentáculos golpeiam áreas marcadas e soltam rajadas de tinta; na fúria, golpes duplos e lulas.
3. **Rainha Abissal**: escurece o oceano, some e reaparece para morder, anéis de orbes teleguiados.
4. **Leviatã Elétrico**: serpente segmentada, mergulhos, bolas elétricas e corpo eletrificado.
5. **Titanacon, o Devorador**: um titã blindado enorme (ocupa quase a tela) que suga o mar e **engole você**. Ele continua nadando pelo oceano com você dentro, e o interior aparece em "raio-x" em tempo real. Por fora, as placas
   ósseas quase não sentem dano; por dentro você ataca os **órgãos vitais** (coração e glândulas de ácido)
   enquanto **parasitas** os defendem, o ácido do estômago queima e a digestão corrói sua vida. Causando dano
   suficiente por dentro, ele **te cospe** para fora e fica atordoado. Repita até derrubá-lo.

### Chefes viram espécies jogáveis
Derrotar um chefe libera a espécie dele na tela "Escolha seu peixe" (a faixa pode ser arrastada):
**Tubarão-Rei** (Peixes-Piloto), **Kraken Jovem** (Tinta), **Rainha Abissal** (Sonar, com isca própria),
**Leviatã** (Pulso Elétrico) e **Titanacon** (Redemoinho). Todas aceitam as 12 mutações, e saves antigos
liberam na hora os chefes que já foram vencidos.

## Controles
- Celular: polegar esquerdo move (joystick flutuante); botão direito morde (segure para repetir).
- Teclado: WASD/setas movem, ESPAÇO/J morde, SHIFT/K dá investida, ESC/P pausa. O botão voltar do Android pausa o jogo.

## Estrutura

```
scripts/autoload/   DB (dados/balanceamento + mapa de altura), Art (sprites + metadados), Profile (save), Sfx (áudio)
scripts/game/       game.gd (orquestra a partida), director.gd (ciclos/ondas/chefes/POIs),
                    player.gd (stats, mordida, mutações, sinergias), weapon.gd (7 armas + evoluções),
                    creatures/ (16 comportamentos), bosses/ (5 chefes + estômago do Titanacon), world.gd, poi.gd, ...
scripts/ui/         HUD, controles de toque, cartas, pausa, game over, menu principal, tema
tools/art/          gerador de pixel art (Python + Pillow/NumPy/SciPy)
tools/audio/        gerador de efeitos e trilhas chiptune
```

**Todo o balanceamento fica em `scripts/autoload/db.gd`**: vida, dano, XP,
populações do ecossistema por ciclo, tabelas de ondas, armas por nível, preços da
loja etc.

## Arte e áudio gerados
Todos os sprites (peixe em 3 espécies × 5 estágios × 28 camadas × 10 quadros,
criaturas, chefes, terreno, cenário, efeitos, UI, ícones e logo) são gerados por
código, para manter o estilo consistente. A pesquisa de pixel art e as técnicas
aplicadas (rampas com hue shifting, luz única, contorno seletivo, clusters
limpos, rig da mandíbula, terreno aterrado) estão em `docs/ART.md`.

```
pip install pillow numpy scipy
python3 tools/art/generate_all.py            # tudo
python3 tools/art/generate_all.py creatures  # só um grupo: player, creatures, env, terrain, fx, ui, icons, appicon
python3 tools/audio/generate_sfx.py          # efeitos + temas do menu e do chefe
```

Rampas de cor ficam em `tools/art/pro.py` (`PAL`); o rig dos peixes em
`tools/art/fishpro.py`; espécies do jogador em `tools/art/player.py`; peixes
inimigos em `tools/art/fishes.py`; demais criaturas em `tools/art/critters.py`;
objetos do cenário em `tools/art/props.py`; o fundo do mar em
`tools/art/terrain.py`. Os PNGs também podem ser editados à mão no Aseprite (os
nomes das linhas do atlas do jogador ficam em `art_meta.json`).

Fontes: Pixelify Sans (texto, SIL OFL) e Press Start 2P (números, SIL OFL).

## Teste automatizado
Um bot joga sozinho para teste de fumaça e balanceamento:

```
godot --headless --path . res://scenes/game.tscn -- --autotest --speed=10 --minutes=16
# --god (imortal)  --boss=N (pula para o chefe N)  --x=4200 (começa nesse x)  --idle
# --shots=/pasta (capturas; exige janela). O log [eco] mostra a cadeia alimentar.
```

## Publicar na Play Store
1. No Godot: *Editor → Gerenciar modelos de exportação* e *Projeto → Instalar modelo de build Android*.
2. Crie uma keystore de release (`keytool -genkeypair ...`) e configure-a em *Exportar → Android → Keystore (release)*. Não versione a keystore.
3. Troque `package/unique_name` (hoje `com.roguefish.game`) pelo seu identificador definitivo antes do primeiro envio; ele não pode mudar depois.
4. A Play Store exige **AAB**: marque `gradle_build/use_gradle_build` e `export_format = AAB`, e use target SDK atual.
5. Suba `version/code` a cada envio.
6. Ícone da loja: `assets/icon/icon_512.png`. Ícones adaptativos já estão configurados.

### Monetização sugerida (ainda não integrada)
- Anúncio recompensado para **reviver** ou **dobrar as pérolas** no game over (plugin AdMob para Godot).
- Compra única "sem anúncios" + pacotes de pérolas; espécies extras como DLC.
- Os ganchos naturais estão em `game_over.gd` (resultado/reviver) e `Profile.add_pearls`.
