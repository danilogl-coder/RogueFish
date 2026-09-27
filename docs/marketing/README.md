# Rogue Fish — Kit de marketing

Todos os arquivos desta pasta são gerados por código a partir da arte e do gameplay reais do jogo
(`tools/marketing/`), então dá para refazer tudo depois de qualquer atualização. Os textos prontos para postar estão
em [`COPY.md`](COPY.md).

## O que a pesquisa indicou (e como o kit segue isso)

| Achado | Como foi aplicado |
| --- | --- |
| Em vídeos curtos você tem de **0,5 a 3 s para prender** a atenção; conteúdo autêntico de gameplay rende mais que trailer polido, e vídeos abaixo de 60 s (idealmente 15 s) retêm melhor. | Cada short abre direto no momento mais forte (a bocarra do Titanacon, a larva) e dura de 11 a 20 s. |
| A maioria assiste **sem som**: legenda na tela é obrigatória. | Legendas grandes em pixel font, numa faixa própria que não cobre o gameplay. |
| Poste o mesmo vídeo no **TikTok, Reels e Shorts** e depois impulsione só o que já performou organicamente ("paid organic", de 100 a 200 dólares). | Um formato 9:16 serve para as 3 redes; o plano está em COPY.md. |
| **GIFs de 2 a 5 s com uma mecânica cada** funcionam melhor que screenshots no Reddit e no X, e o #ScreenshotSaturday é a vitrine recorrente. | 7 GIFs curtos, cada um mostrando uma ideia. |
| Na Play Store, **90% não passa da 3ª captura**; a primeira captura e o vídeo decidem a instalação. Cada captura deve ter uma mensagem, com legenda curta. O vídeo de 15 a 30 s precisa mostrar valor nos primeiros segundos. | Capturas em `docs/store/screenshots/` com os ganchos mais fortes primeiro; vídeo promocional de cerca de 30 s que abre com o chefe te engolindo. |
| Em pixel art, **evite zoom extremo** e só amplie em múltiplos inteiros, para a arte não parecer borrada. | Tudo é composto na resolução nativa e ampliado 2×, 3×, 4× ou 5× com o método "vizinho mais próximo". |
| Um press kit deve ter de 9 a 12 capturas, trailer, de 3 a 5 GIFs e key art em alta resolução. | Tudo nesta pasta mais `docs/store/`. |

## Arquivos

### Key art (pixel art)
| Arquivo | Uso |
| --- | --- |
| `keyart_1920x1080.png` | Capa do trailer no YouTube, press kit, post horizontal, página do jogo |
| `keyart_1920x1080_nologo.png` | Fundo para banners e para a imprensa montar a própria arte |
| `keyart_1080x1080.png` | Post quadrado no Instagram e Facebook, avatar de campanha |
| `keyart_1080x1920.png` | Stories, capa de TikTok e Reels, cartão final dos shorts |
| `header_1500x500.png` | Capa de perfil no X/Twitter e Bluesky |
| `youtube_thumb_1280x720.png` | Miniatura do YouTube |

### Animações "Larva to Legend"
| Arquivo | Uso |
| --- | --- |
| `short_larva_to_legend_1080x1920.mp4` | TikTok, Reels e Shorts: peixe-dourado, caranguejo e água-viva evoluindo |
| `post_larva_to_legend_1080x1080.mp4` | Feed do Instagram, X e Facebook |
| `gif_larva_to_legend_dourado.gif` / `_caranguejo.gif` / `_agua_viva.gif` | Reddit (r/PixelArt), X, Discord, press kit |

### Gameplay
| Arquivo | Uso |
| --- | --- |
| `short_swallowed_1080x1920.mp4` | **O vídeo mais forte.** "This boss can swallow you whole…" |
| `short_bosses_1080x1920.mp4` | Leviatã e Kraken |
| `short_horde_1080x1920.mp4` | Horda com build no máximo e combo alto |
| `gif_swallowed_by_titanacon.gif` | Post fixado do lançamento, r/indiegames |
| `gif_leviathan_chase.gif`, `gif_kraken_boss.gif`, `gif_horde_frenzy.gif` | #ScreenshotSaturday e Reddit |
| `promo_googleplay_1920x1080.mp4` | **Vídeo de prévia da Play Store** (suba no YouTube e cole o link na ficha) e trailer |

### Loja (em `docs/store/`)
Ícone 512, recurso gráfico 1024×500 e 8 capturas 1920×1080 com legendas, em inglês. As versões em português estão em
`docs/store/pt-BR/`.

## Como refazer depois de uma atualização

1. Grave os clipes com o piloto automático, usando a gravação do Godot, que gera uma sequência de PNGs e um WAV:
   ```bash
   xvfb-run godot --path . --resolution 640x360 --write-movie out/f.png --fixed-fps 30 \
     res://scenes/game.tscn -- --autotest --god --minutes=0.5 --species=orca --boss=5
   ```
   Opções úteis do piloto:
   - `--boss=N`: vai direto ao chefe N;
   - `--phase=wave`: começa na horda;
   - `--evolve-every=S`: evolui a cada S segundos;
   - `--stage=N`: começa no estágio N;
   - `--give=armas` e `--maxw`: dão armas e as deixam no nível máximo.
2. Gere as peças:
   - `python3 keyart.py` para a key art;
   - `python3 morph.py` para as animações de evolução;
   - `python3 clips.py <pasta das gravações> gif short promo` para GIFs, shorts e o vídeo promocional.

   O ffmpeg vem do pacote `pip install imageio-ffmpeg`.

## Fontes da pesquisa

- [presskit.gg – TikTok para jogos indie](https://presskit.gg/field-guides/tiktok-indie-game-marketing)
- [presskit.gg – GIFs para marketing de jogos](https://presskit.gg/field-guides/game-marketing-gifs-guide)
- [presskit.gg – Reddit para jogos indie](https://presskit.gg/field-guides/reddit-marketing-indie-games)
- [presskit.gg – guia de press kit 2026](https://presskit.gg/blog/indie-game-press-kit-guide)
- [Gamosy – TikTok paid organic](https://gamosy.com/blog/tiktok-game-marketing)
- [Acorn Games – guia de vídeo curto](https://acorngames.gg/blog/2026/5/19/an-indie-devs-guide-on-shortform-video-marketing)
- [Fungies – guia de marketing indie 2026](https://fungies.io/indie-game-marketing/)
- [ASOMobile – screenshots para lojas](https://asomobile.net/en/blog/screenshots-for-app-store-and-google-play-in-2025-a-complete-guide/)
- [AppFollow – estratégias de vídeo ASO](https://appfollow.io/blog/aso-video-strategies)
- [AppTweak – checklist ASO Google Play](https://www.apptweak.com/en/aso-blog/app-store-optimization-aso-checklist-for-google-play)
