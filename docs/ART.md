# Rogue Fish: direção de arte (pixel art)

Toda a arte é gerada por código (`tools/art/`). Este documento resume a pesquisa
sobre pixel art profissional e mostra onde cada técnica foi aplicada.

## 1. O que a pesquisa recomenda

| Técnica | O que é | Onde aplicamos |
|---|---|---|
| **Rampas com deslocamento de matiz (hue shifting)** | Sombras puxam para o azul/violeta e perdem valor; luzes puxam para o amarelo e perdem saturação. Rampas "retas" (só claro/escuro) ficam sem vida | `pro.ramp()`: o tom 4 é exatamente a cor base, os tons 0–3 esfriam e os 5–6 esquentam |
| **Uma fonte de luz (nada de *pillow shading*)** | Sombrear do contorno para o centro, sem direção de luz, deixa tudo com cara de "almofada" | Volume calculado a partir da forma 3D (elipsoide do corpo, domos, cilindros), com luz vinda de cima |
| **Poucos tons, clusters limpos, sem pixels órfãos** | Pixels soltos viram ruído; cada tom deve formar grupos com intenção | Quantização em 4–5 tons + `Layer.clean()`, que remove pixels isolados |
| **Evitar *banding* e *jaggies*** | Faixas paralelas de mesmo comprimento reforçam a grade; degraus irregulares quebram curvas | Silhuetas analíticas amostradas no centro do pixel, bordas de camadas com variação orgânica |
| **Contorno seletivo (selout)** | O contorno usa um tom escuro da própria cor e clareia onde a luz bate, em vez de preto chapado | `Layer.to_image()`: contorno com o tom 0 da rampa vizinha, tom 1 no lado iluminado |
| **Luz rebatida** | Uma borda mais clara no lado da sombra, vinda do ambiente | Barriga dos peixes ganha +1 tom junto do contorno inferior |
| **Contra-sombreamento** | Peixes reais têm dorso escuro e barriga clara | `countershade` / `backshade` no `fishpro` |
| **Animação: antecipação, *squash & stretch*, *follow-through*** | Antes do golpe, preparar; no impacto, achatar; partes soltas (nadadeiras) atrasam | Mordida em 4 quadros (preparo → boca escancarada → estalo achatado → retorno); nadadeiras e cauda com atraso de fase |
| **Cenário: camada caminhável mais detalhada** | A superfície concentra contraste e detalhe; camadas internas ficam mais escuras e calmas | Borda iluminada, grãos, seixos e tufos na superfície; subsolo com pedras e estratos esmaecendo |
| **Objetos apoiados no chão** | Objetos grandes precisam de chão nivelado, sombra de contato e base "enterrada" | Prateleiras planas no mapa de altura + faixa frontal do solo desenhada na frente das bases |

## 2. Peixes: a boca é parte da cabeça

Antes, a boca aberta era uma "máscara" vermelha pintada por cima da cabeça.
Agora cada peixe é um pequeno *rig* (`tools/art/fishpro.py`):

- A **mandíbula inferior** é uma peça rígida que gira em torno do canto da boca.
- A abertura revela a **cavidade** (mais escura no fundo da garganta), as
  **gengivas**, a **língua** e os **dentes**. Os dentes pertencem a cada
  mandíbula e se movem com ela.
- A **garganta estica**, preenchendo o vão entre a mandíbula caída e o corpo.
- O **opérculo** (tampa das brânquias) se abre e mostra o vermelho das brânquias.

Cada espécie tem sua anatomia de boca:

| Peixe | Boca |
|---|---|
| Dourado, neon, sardinha, peixe-lanterna | Terminal, pequena, sem dentes |
| Garoupa | Grande, lábios grossos, leve prognatismo, dentes pequenos |
| Piranha / mutação "Mandíbula de Piranha" | Queixo saliente vermelho, dentes triangulares à mostra mesmo fechada |
| Barracuda, moreia | Presas longas; a barracuda tem a mandíbula inferior projetada |
| Tubarões (inimigo e chefe) | Boca inferior, sob o focinho, com fileira de dentes triangulares; fendas branquiais |
| Peixe-pescador (inimigo e chefe) | Bocarra virada para cima, presas em agulha, isca luminosa que balança |
| Orca | Boca longa e reta com dentes cônicos |
| Baiacu | Bico curto com dentes fundidos |

**Quadros** (todas as folhas de peixe): 6 de natação (onda do corpo que
viaja até a cauda, escorço da nadadeira caudal, peitorais remando) + 4 de
mordida. O jogo lê a divisão nado/ação em `art_meta.json` e distribui os 4
quadros ao longo da duração do ataque (`Art.act_frame`).

**Mutações do jogador:** cabeça (piranha, espadarte, lanterna) e pele
(blindada, tóxica, bioluminescente) são desenhadas **junto do corpo** (16
variantes por espécie e estágio), porque mandíbula, rostro e isca fazem parte da
cabeça. Caudas e nadadeiras continuam em camadas separadas.

## 3. Cenário sem nada flutuando

A causa dos objetos flutuando era dupla: o desenho do fundo do mar não seguia a
mesma curva que o jogo usava para o chão, e objetos largos eram posicionados
pela altura do chão apenas no seu centro.

Agora:

1. `tools/art/terrain.py` gera **um único mapa de altura** (montes do recife,
   dunas da floresta de kelp, talude em degraus, planície abissal). Ele é salvo
   em `assets/art/terrain.json`, e `DB.floor_at()` lê exatamente esses valores.
2. As **texturas do terreno** (blocos de 240 px) são desenhadas a partir do mesmo
   mapa, então a areia desenhada e a colisão coincidem pixel a pixel.
3. Cada objeto grande tem uma **prateleira plana** esculpida no terreno:
   cavernas (incluindo uma em um degrau do talude), moitas, rochas de moreia,
   mesas das fontes hidrotermais e a queda de baleia.
4. Objetos menores são apoiados no **ponto mais baixo sob a sua base**
   (`DB.ground_under`) e só nascem em chão nivelado (`DB.ground_unevenness`).
   Pontos de interesse (baú, ostra, fenda) também passaram a nascer no chão.
5. Uma **faixa frontal do solo** (borda iluminada, seixos, tufos) é desenhada na
   frente das bases, "plantando" os objetos na areia.
6. Pedras, conchas, cascalho de coral e esteiras de bactérias estão **assados**
   na textura do terreno, então nunca ficam fora do chão.

## 4. Pipeline

```
pip install pillow numpy scipy
python3 tools/art/generate_all.py                    # tudo
python3 tools/art/generate_all.py player creatures   # grupos: player, creatures, env, terrain, fx, ui, icons, appicon
```

| Arquivo | Conteúdo |
|---|---|
| `tools/art/pro.py` | Rampas com hue shift, iluminação, quantização, utilitários geométricos |
| `tools/art/fishpro.py` | Rig do peixe: corpo, mandíbula, olhos, nadadeiras, caudas, quadros |
| `tools/art/player.py` | Atlas do jogador (3 espécies × 5 estágios, 28 linhas × 10 quadros) |
| `tools/art/fishes.py` | Peixes inimigos e chefes-peixe |
| `tools/art/critters.py` | Invertebrados, tartaruga, lontra, kraken, segmentos do leviatã |
| `tools/art/props.py` | Cavernas, moitas, rochas (Voronoi), corais, anêmonas, fontes, ossada, baú, ostra, kelp |
| `tools/art/terrain.py` | Mapa de altura, prateleiras e texturas do fundo do mar |

Para mover uma caverna ou moita, edite `SITES` em `terrain.py` e gere de novo o
grupo `terrain`: o jogo lê as posições de `terrain.json`.

## 5. Marés Profundas: personagens, itens e limpeza de pixels

- **Pixels soltos**: `tools/art/tidy.py` roda em todo quadro de criatura e atlas do jogador. Blocos
  pequenos (até 12 px) separados do corpo ou presos só pela quina (como a ponta da cauda do tubarão,
  cujo filete fino sumia e deixava só o contorno) são religados com uma linha 4-conectada na cor
  do contorno. Nos atlas do jogador cada camada é analisada junto da silhueta corpo + cauda, então
  nadadeiras separadas nunca são ligadas entre si. `tools/art/audit_islands.py` lista o que sobrar.
- **Critters jogáveis em qualquer tamanho** (`tools/art/mobs.py`): os desenhos de `critters.py` são
  funções de X e Y em "unidades de sprite". Para cada estágio a mesma função é amostrada numa grade
  mais fina, gerando pixel art de verdade em cada tamanho (sem ampliar pixels). As mutações são
  peças posicionadas por âncoras medidas em cada quadro (boca, traseira e linha do dorso), e cada
  estágio acrescenta um visual próprio.
- **Peixes jogáveis**: novas espécies no renderizador de peixes. Todos crescem com barbatanas mais
  altas (Adulto), cauda maior e cicatrizes (Veterano) e fotóforos (Leviatã).
- **Itens**: `tools/art/items.py` desenha 18 folhas de efeito (garra, chicote, mandíbulas, casco,
  muco, moedas, onda de impacto...) e todos os ícones 16x16. Os ícones de fusão combinam os dois
  ícones de origem numa diagonal com moldura rosa.
- **Bioma vulcânico**: `terrain.py` ganhou a crista de basalto das Fontes Hidrotermais, com fendas
  de magma brilhantes pintadas no próprio solo.

## Fontes

- Derek Yu, [Pixel Art Tutorial: Basics](https://www.derekyu.com/makegames/pixelart.html) (contornos, selout, AA, clusters)
- Arne (Androidarts), [Pixel Art Tutorial](https://androidarts.com/pixtut/pixelart.htm)
- Pedro Medeiros (Saint11), [Pixel Grimoire: Anti-alias e banding](https://medium.com/pixel-grimoire/how-to-start-making-pixel-art-4-ff4bfcd2d085), [Cluster sketching and painting](https://saint11.art/pixel_art_articles/article2/), [tutoriais de animação](https://saint11.art/blog/pixel-art-tutorials/)
- Pixel Parmesan, [Anti-Aliasing Fundamentals for Pixel Artists](https://pixelparmesan.com/blog/anti-aliasing-fundamentals-for-pixel-artists)
- The Logbook Project, [Banding, Anti-Aliasing, Pillow Shading](https://the-logbook-project.blogspot.com/2013/04/pixel-art-lessons-jiinchus-darkness.html)
- SLYNYRD, [Pixelblog 1: Color Palettes](https://www.slynyrd.com/blog/2018/1/10/pixelblog-1-color-palettes) (hue shifting) e [Pixelblog 28: Side View Tiles](https://www.slynyrd.com/blog/2020/5/21/pixelblog-28-side-view-tiles)
- Sprite-AI, [12 princípios da animação para sprites](https://www.sprite-ai.art/guides/animation-principles); Pixilart, [Squash & Stretch](https://www.pixilart.com/tutorial/animation-squash-stretch-61)
