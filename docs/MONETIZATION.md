# Monetização

O modelo é **híbrido**: anúncios recompensados, que são sempre opcionais, somados a compras dentro do jogo. É o
modelo que mais rende hoje em jogos mobile mid-core e casual. Tudo que se compra também pode ser ganho jogando.
Não há anúncio forçado, caixa de loot paga nem poder exclusivo à venda.

## Economia

- Todos os preços em pérolas (personagens, loja, evolução) estão **5× mais altos**.
- A renda por partida não mudou. Com isso, o jogador que não paga progride por:
  - partidas;
  - diária (até 400 com vídeo);
  - até 5 vídeos por dia de +250 pérolas;
  - dobrar pérolas ao fim da partida.
- Isso deixa o jogador gratuito em cerca de 60–70% do ritmo de quem paga, que é a faixa recomendada.

## Vídeos recompensados (`scripts/autoload/ads.gd`, `scripts/data/offers.gd`)

| Local | Prêmio | Limite |
| --- | --- | --- |
| Menu principal: botão **VÍDEO +250** | 250 pérolas | 5 por dia, 4 min entre vídeos |
| Ao morrer: tela **CONTINUAR?** (8 s) | revive com 50% de vida e limpa inimigos próximos | 1 por partida, 12 por dia |
| Fim da partida: **DOBRAR PÉROLAS** | repete o que a partida rendeu | 8 por dia |
| Recompensa diária: **x2** | diária em dobro | 1 por dia |
| Cartas de nível sem rerrolagem: **VÍDEO: REROLAR** | nova rolagem | 10 por dia, 30 s |

Os limites seguem as referências para jogos mid-core: de 3 a 6 vídeos por sessão e de 10 a 15 por dia.
O jogo **não tem intersticiais**: eles derrubam a retenção de um jogo de partidas longas. Se um dia forem
adicionados, devem aparecer só entre partidas, a partir do terceiro dia do jogador, e nunca para VIP.

## Compras (`scripts/autoload/billing.gd`)

| Produto | Preço | Conteúdo |
| --- | --- | --- |
| Pacote Inicial (1×) | R$ 7,90 | 6.000 pérolas + Tartaruga + Rosa-dos-Ventos (≈ 65% mais barato) |
| Passe VIP Abissal (1×) | R$ 19,90 | vídeos viram prêmio instantâneo e +25% de pérolas para sempre |
| Punhado | R$ 4,90 | 2.500 pérolas |
| Bolsa | R$ 12,90 | 7.500 pérolas (+15%) |
| Baú | R$ 24,90 | 17.000 pérolas (+35%) |
| Tesouro Abissal | R$ 59,90 | 48.000 pérolas (+57%) |

- O Pacote Inicial converte o primeiro pagamento, onde costuma estar de 20% a 40% da conversão.
- O VIP funciona como "remover anúncios" e aproveita o cansaço de ver vídeos.
- A escada de pacotes atende quem gasta pouco e quem gasta muito.

## Ligando as plataformas reais

Sem SDK, o jogo mostra um **vídeo simulado** de 5 s e uma **compra de teste**. A compra de teste só aparece em
builds de debug; em release, sem loja, os botões ficam desativados.

### AdMob

> Passo a passo atualizado, com consentimento GDPR e script testado, em [`ADMOB.md`](ADMOB.md).

Use o plugin `poing-studios/godot-admob-plugin` (Godot 4). Crie um script autoload depois de `Ads`:

```gdscript
extends Node
const UNIT := "ca-app-pub-3940256099942544/5224354917"  # ID de TESTE do Google: troque pelo seu
var _ad: RewardedAd

func _ready() -> void:
	MobileAds.initialize()
	Ads.set_backend(self)
	_load()

func _load() -> void:
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd): _ad = ad
	RewardedAdLoader.new().load(UNIT, AdRequest.new(), cb)

func show_rewarded(_placement: String, on_done: Callable) -> void:
	if _ad == null:
		on_done.call(false)
		_load()
		return
	var earned := [false]
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = func():
		on_done.call(earned[0])
		_ad.destroy()
		_ad = null
		_load()
	_ad.full_screen_content_callback = fs
	var rw := OnUserEarnedRewardListener.new()
	rw.on_user_earned_reward = func(_r): earned[0] = true
	_ad.show(rw)
```

Configure também:
- o consentimento GDPR/LGPD (UMP, que já vem no plugin);
- a classificação etária na Play Console.

### Google Play Billing

Instale o plugin oficial `godot-sdk-integrations/godot-google-play-billing`, **versão 3.x** (Godot 4.2+). O
`Billing` detecta o singleton `GodotGooglePlayBilling` sozinho. Os pacotes de pérolas só são entregues depois que
o Google confirma o consumo, então nenhuma compra é paga duas vezes. Passo a passo em
[`TUTORIAL_PLAYSTORE.md`](TUTORIAL_PLAYSTORE.md), Fase 4.2. Na Play Console, crie produtos "no app" com os mesmos IDs:
`starter`, `vip`, `pearls_1`, `pearls_2`, `pearls_3` e `pearls_4`.

- `vip` e `starter` não são consumíveis: são *reconhecidos* (acknowledge).
- Os pacotes de pérolas são consumidos.

**Antes de lançar:** valide o `purchase_token` num servidor pela Google Play Developer API antes de entregar o
item, e salve as compras na nuvem (login Google Play Games). Hoje a entrega acontece só no aparelho.

## Outras formas pesquisadas (próximos passos)

1. **Passe de temporada**, por R$ 14,90/mês ou por temporada:
   - uma trilha de 30 níveis com pérolas, skins e relíquias;
   - uma versão gratuita e uma premium;
   - é o terceiro pilar do modelo "tri-model" e o que mais aumenta o ARPDAU.
2. **Skins cosméticas** das formas lendárias (paletas mutantes, auras): monetizam sem mexer no equilíbrio.
3. **Ofertas por tempo limitado** ligadas a eventos, como "Semana do Megalodonte".
4. **Assinatura VIP mensal**, em vez do VIP único, se a retenção for alta.
5. **Versão premium no PC/Steam**, no modelo de Vampire Survivors: preço único baixo, sem anúncios e com DLCs das
   expansões. As expansões já existem no jogo.

Fontes:
- [Adapty – modelos de monetização 2026](https://adapty.io/blog/mobile-game-monetization/)
- [CAS.ai – monetização híbrida](https://cas.ai/blog/hybrid-monetization-in-mobile-games-a-practical-guide/)
- [AdReact – guia de vídeos recompensados](https://adreact.com/blog/rewarded-video-ads-mobile-game-monetization/)
- [RevenueFlex – frequência de recompensados](https://revenueflex.com/blog/rewarded-video-ads-mobile-game-monetization/)
- [Unity – guia de monetização](https://unity.com/resources/mobile-game-monetization-guide)
- [Next App – o que funciona em 2026](https://blog.nextappinc.com/best-mobile-game-monetization-for-revenue/)
