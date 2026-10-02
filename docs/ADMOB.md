# AdMob — anúncios premiados

Integração Android instalada com o plugin da Poing Studios **v5.1.0** para Godot 4.5. O jogo usa somente anúncios premiados opcionais; os limites diários e os prêmios continuam em `scripts/autoload/ads.gd`.

## IDs do Rogue Fish

| Uso | ID |
| --- | --- |
| App Android (manifesto) | `ca-app-pub-4135973528608195~4893817109` |
| Bloco premiado `rewarded_all` | `ca-app-pub-4135973528608195/2395735562` |
| Bloco de teste oficial Android | `ca-app-pub-3940256099942544/5224354917` |

O ID do app está em `project.godot`. Os IDs dos blocos estão em `scripts/autoload/admob_backend.gd`. Os binários Android da Poing estão em `addons/admob/android/bin/ads/` e precisam acompanhar o repositório para o GitHub Actions exportar o AAB.

## Teste fechado

O preset `Android` usa a feature `admob_test_ads` em `export_presets.cfg`. Assim, mesmo o AAB de release destinado ao teste fechado carrega **anúncios de teste do Google**. A recompensa só é concedida quando o callback `on_user_earned_reward` é recebido. Fechar ou falhar antes dele não entrega prêmio.

Para testar no celular:

1. Gere o AAB pelo workflow `Android release (AAB)` e instale pelo teste fechado da Play Console.
2. Abra o jogo com internet e espere o bloco premiado carregar. O botão ficará indisponível durante o carregamento.
3. Use `VÍDEO +250`, assista ao anúncio marcado como teste e confirme o crédito das pérolas.
4. Repita fechando o anúncio antes da recompensa: não deve haver crédito.
5. Confira também reviver, dobrar pérolas, diária x2 e rerrolar cartas.

Na publicação comercial, remova `admob_test_ads` de `custom_features` no preset. O backend passará a usar `rewarded_all`. Faça isso somente depois de verificar consentimento, declarações de dados da Play Console e liberação da conta/app no AdMob.

## Situação da conta

O app Android e `rewarded_all` foram criados em 2 de outubro de 2026. A página inicial do AdMob ainda indicava **conta em verificação**. A veiculação real também depende da revisão do app e de associá-lo à ficha da Play Store quando ela estiver disponível publicamente. O painel `Privacidade e mensagens` apresentou erro de carregamento durante esta configuração; é preciso voltar ali para publicar a mensagem de consentimento antes de usar anúncios reais para público internacional.

Documentação: [instalação do plugin](https://github.com/poingstudios/godot-admob-plugin/blob/master/docs/index.md) · [anúncios premiados](https://github.com/poingstudios/godot-admob-plugin/blob/master/docs/ad_formats/rewarded.md).
