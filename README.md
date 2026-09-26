# Rogue Fish

Roguelike de sobrevivência subaquático para celular (Godot 4.5, renderizador
Compatibility, paisagem). Você começa como um alevino, come para crescer,
monta builds com cartas estilo *Vampire Survivors*, sofre mutações que mudam a
aparência do peixe e enfrenta ondas e chefes até dominar o oceano.

## Requisitos atendidos

| Requisito | Onde |
|---|---|
| Peixe animado | `scripts/game/player_visual.gd`: camadas animadas (nado, mordida) |
| Movimento por joystick | `scripts/ui/touch_controls.gd`: joystick flutuante no lado esquerdo |
| Botão de ataque | Botão à direita (segure para morder sem parar), com mira assistida |
| Background com parallax | `world.gd` (3 camadas + fundo com raios de luz) e `ambient.gd` (neve marinha, cardumes distantes) |
| Crescimento do peixe | 5 estágios: Alevino, Juvenil, Adulto, Veterano e Leviatã. Sprite maior, mais vida e mordida; engole criaturas menores inteiras |
| Nível, status e pontos | XP → nível; cada nível dá 1 ponto de atributo (FOR/VIT/AGI/INS) + escolha de carta |
| Barra de vida | HUD + barras de vida nos inimigos feridos + barra do chefe |
| Cartas estilo Vampire Survivors | 7 armas, 11 passivas, 7 evoluções lendárias (arma nv5 + passiva parceira), rerrolagem |
| Ecossistema planta/herbívoro/predador | Cadeia alimentar completa com ciclo de nutrientes: produtores (kelp, fitoplâncton, quimiossíntese), detritívoros, herbívoros, carnívoros, predadores e a orca (megapredador). Fome, reprodução, carcaças e reciclagem. Veja `docs/DESIGN.md` |
| Esconderijos | Cavernas e moitas de algas: predadores perdem o rastro, você regenera (limitado pela barra de furtividade) |
| Pontos de interesse com tempo | Baú (morda 3x), ostra gigante (cura), fenda térmica (+30% dano, guardada por caranguejos) e cardume dourado. Aparecem com timer e setas na borda da tela |
| Tempo → Onda → Chefe | `director.gd`: EXPLORAR (timer) → ONDA (horda) → CHEFE. São 4 ciclos; depois da vitória há o modo infinito |
| Menu inicial, game over, upgrades rogue-lite | `main_menu.gd` (espécies, loja de evolução ancestral, guia, opções, créditos), `game_over.gd`, `pause_menu.gd` |
| Evoluções que mudam a aparência | 12 mutações em 4 slots (cabeça, nadadeiras, pele e cauda), cada uma com arte própria em todos os estágios e espécies |
| Sinergias | 6 afinidades (Elétrico, Veneno, Abissal, Coral, Predador, Corrente) com bônus em 2 e 4 itens + 3 combinações cruzadas |

### Mundo (v1.1)
4 biomas com relevo próprio: **Recife de Coral** (raso), **Floresta de Kelp**,
**Talude Continental** (declive com ressurgência) e **Fossa Abissal** (fontes
hidrotermais, vermes tubulares, queda de baleia, peixes-lanterna).

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

## Controles
- Celular: polegar esquerdo move (joystick flutuante); botão direito morde (segure para repetir).
- Teclado: WASD/setas movem, ESPAÇO/J morde, SHIFT/K dá investida, ESC/P pausa. O botão voltar do Android pausa o jogo.

## Estrutura

```
scripts/autoload/   DB (dados/balanceamento), Art (sprites + metadados), Profile (save), Sfx (áudio)
scripts/game/       game.gd (orquestra a partida), director.gd (ciclos/ondas/chefes/POIs),
                    player.gd (stats, mordida, mutações, sinergias), weapon.gd (7 armas + evoluções),
                    creatures/ (13 comportamentos), bosses/ (4 chefes), world.gd, poi.gd, ...
scripts/ui/         HUD, controles de toque, cartas, pausa, game over, menu principal, tema
tools/art/          gerador de pixel art (Python + Pillow)
tools/audio/        gerador de efeitos e trilhas chiptune
```

**Todo o balanceamento fica em `scripts/autoload/db.gd`**: vida, dano, XP,
populações do ecossistema por ciclo, tabelas de ondas, armas por nível, preços da
loja etc.

## Arte e áudio gerados
Todos os sprites (peixe em 3 espécies × 5 estágios × 19 camadas, criaturas,
chefes, cenário, efeitos, UI, ícones e logo) são gerados por código, para manter o
estilo consistente:

```
pip install pillow
python3 tools/art/generate_all.py            # tudo
python3 tools/art/generate_all.py creatures  # só um grupo: player, creatures, env, fx, ui, icons, appicon
python3 tools/audio/generate_sfx.py          # efeitos + temas do menu e do chefe
```

Paletas ficam em `tools/art/pixel.py` (`RAMPS`); formatos dos peixes/espécies em
`tools/art/player.py` e `tools/art/creatures.py`. Os PNGs também podem ser
editados à mão no Aseprite (as linhas do atlas do jogador seguem `Art.PLAYER_LAYERS`).

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
