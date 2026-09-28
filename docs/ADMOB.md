# Passo a passo: ligando o AdMob (vídeos recompensados)

O jogo já está pronto para anúncios: os botões de vídeo, os limites diários e os prêmios estão em
`scripts/autoload/ads.gd`. Falta só ligar o SDK real do Google. São 3 partes:

1. contas (AdMob);
2. plugin no Godot;
3. um script de ponte.

Tudo abaixo foi conferido com o plugin **Poing Studios AdMob v5.2** (Godot 4.5+).

---

## Parte 1 — Conta e IDs no AdMob

1. Entre em <https://admob.google.com> com a mesma conta Google da Play Console e aceite os termos.
2. Em **Pagamentos**, preencha endereço e dados fiscais. Sem isso, a conta não recebe.
3. **Apps → Adicionar app**:
   - plataforma **Android**;
   - "O app está listado numa loja?" → **Não** por enquanto (depois do lançamento você vincula à ficha da Play);
   - nome: Rogue Fish.
4. Copie o **ID do app**. Ele tem um **til `~`**, por exemplo `ca-app-pub-1234567890123456~1234567890`.
5. **Blocos de anúncios → Adicionar → Premiado (Rewarded)**:
   - nome: `rewarded_all`;
   - recompensa: 1 item, "reward" (o jogo decide o prêmio de verdade).
6. Copie o **ID do bloco**. Ele tem uma **barra `/`**, por exemplo `ca-app-pub-1234567890123456/9876543210`.
7. **Privacidade e mensagens → GDPR → Criar mensagem**:
   - idioma inglês (adicione português também);
   - link da política: `https://danilogl-coder.github.io/RogueFish/privacy.html`;
   - publique a mensagem.

   Esse é o aviso de consentimento que o Google exige para jogadores da Europa e do Reino Unido.
8. **Configurações do app → app-ads.txt**:
   - o AdMob mostra uma linha de texto;
   - crie o arquivo `docs/app-ads.txt` com essa linha;
   - coloque o site `https://danilogl-coder.github.io/RogueFish/` no campo *Site* da ficha da Play Store.

   Sem o app-ads.txt, você perde parte da receita.

---

## Parte 2 — Plugin no Godot (no seu PC)

1. Abra o projeto no **Godot 4.5**.
2. Aba **AssetLib** (no topo do editor):
   - pesquise **AdMob**;
   - escolha o de **Poing Studios**;
   - clique em **Download → Install**.
3. **Projeto → Configurações do Projeto → Plugins**: marque **AdMob** como *Ativo*. As bibliotecas Android são
   baixadas sozinhas para `addons/admob/android/bin/`.
   - Se não baixarem: **Projeto → Ferramentas → AdMob Manager → Android → Download & Install**.
4. **Projeto → Instalar Modelo de Build do Android** (Install Android Build Template). Isso cria a pasta
   `android/`.
5. **Projeto → Configurações do Projeto → Geral → Admob → Android**:
   - marque **Enabled**;
   - em **App Id**, cole o ID **com til** da Parte 1, passo 4.
6. **Projeto → Exportar → Android**: confira que **Use Gradle Build** está ligado. Já vem ligado no preset
   "Android" do projeto.

> O preset "Android APK" (o de teste sem Gradle) **não** leva o AdMob. Anúncio só funciona no preset "Android"
> (AAB/Gradle) ou num APK exportado com Gradle.

---

## Parte 3 — Script de ponte

Crie o arquivo `scripts/autoload/admob_backend.gd` com o conteúdo abaixo.

**Comece com o ID de TESTE do Google, que já está no script**, e só troque pelo seu ID real (o da Parte 1,
passo 6) antes de publicar. Clicar nos seus próprios anúncios reais pode fazer o AdMob **bloquear sua conta**.

```gdscript
extends Node
## Liga o AdMob (plugin Poing Studios) ao autoload Ads.
## 1) pede o consentimento GDPR/LGPD quando necessário; 2) inicia o SDK;
## 3) deixa sempre um vídeo recompensado carregado.

# ID de TESTE do Google. Troque pelo seu bloco "Premiado" (com barra /) antes de publicar.
const UNIT := "ca-app-pub-3940256099942544/5224354917"

var _ad: RewardedAd
var _loading := false
var _started := false


func _ready() -> void:
	if OS.get_name() != "Android":
		return
	var req := ConsentRequestParameters.new()
	req.tag_for_under_age_of_consent = false
	UserMessagingPlatform.consent_information.update(req, _on_consent_updated, _on_consent_error)


func _on_consent_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_form_loaded, _on_consent_error)
	else:
		_start()


func _on_form_loaded(form: ConsentForm) -> void:
	var info := UserMessagingPlatform.consent_information
	if info.get_consent_status() == info.ConsentStatus.REQUIRED:
		form.show(_on_consent_error)  # quando fechar, segue em frente
	else:
		_start()


func _on_consent_error(_err: FormError = null) -> void:
	_start()


func _start() -> void:
	if _started:
		return
	_started = true
	MobileAds.initialize()
	Ads.set_backend(self)
	_load()


func _load() -> void:
	if _loading or _ad != null:
		return
	_loading = true
	var cb := RewardedAdLoadCallback.new()
	cb.on_ad_loaded = func(ad: RewardedAd) -> void:
		_loading = false
		_ad = ad
	cb.on_ad_failed_to_load = func(_e: LoadAdError) -> void:
		_loading = false
		get_tree().create_timer(30.0).timeout.connect(_load)  # tenta de novo em 30 s
	RewardedAdLoader.new().load(UNIT, AdRequest.new(), cb)


## Chamado pelo Ads.show_rewarded(). on_done.call(true) só se o jogador ganhou o prêmio.
func show_rewarded(_placement: String, on_done: Callable) -> void:
	if _ad == null:
		on_done.call(false)
		_load()
		return
	var ad := _ad
	_ad = null
	var earned := [false]
	var finish := func() -> void:
		ad.destroy()
		on_done.call(earned[0])
		_load()
	var fs := FullScreenContentCallback.new()
	fs.on_ad_dismissed_full_screen_content = finish
	fs.on_ad_failed_to_show_full_screen_content = func(_e: AdError) -> void:
		finish.call()
	ad.full_screen_content_callback = fs
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = func(_item: RewardedItem) -> void:
		earned[0] = true
	ad.show(listener)
```

Depois registre o script como autoload:

1. **Projeto → Configurações do Projeto → Globais (Autoload)**.
2. Caminho: `res://scripts/autoload/admob_backend.gd`; nome: `AdMobBackend`.
3. **Adicionar**.
4. Arraste para **depois** de `Ads` na lista.

Pronto: a partir do momento em que o SDK inicia, o `Ads` usa o vídeo real. Os botões **VIDEO +250**,
**CONTINUE?**, **DOUBLE PEARLS**, **x2 diária** e **REROLL** passam a aparecer no build de release.

---

## Parte 4 — Testar

1. Exporte com o preset **Android** e instale no celular. Você pode usar o teste interno da Play Console ou um APK
   exportado com Gradle (*Exportar → Android → Exportar Projeto*, com formato APK).
2. Na primeira abertura, pode aparecer o aviso de consentimento. Ele só aparece para quem está na Europa; para
   forçar o aviso no teste, veja "Forçar uma geografia" na documentação do plugin.
3. Toque em **VIDEO +250**. Deve abrir um vídeo com a etiqueta **"Test Ad"**. Assista até o fim: as pérolas entram.
4. Feche um vídeo no meio: você **não** ganha nada. Isso está certo.
5. Deu certo? Troque `UNIT` pelo seu ID real e gere o AAB final.
   - Nos primeiros dias, os anúncios reais podem demorar a aparecer ("no fill"). É normal em conta nova.
   - Nunca clique nos seus próprios anúncios reais.

---

## Parte 5 — Play Console (declarações)

Estas respostas já estão em `docs/RELEASE.md`, seção 6. Em resumo:

- **Anúncios:** "Sim, meu app contém anúncios".
- **Segurança dos dados:** ID de publicidade, local aproximado, interações com anúncios e diagnósticos,
  compartilhados com o Google para publicidade. A permissão `AD_ID` já está no export.
- **Público-alvo:** 13+ (não inclua menores de 13, senão a política Famílias exige outras regras).
- Depois do lançamento, volte ao AdMob e **vincule o app à ficha da Play Store** (Apps → Configurações do app).

---

## Problemas comuns

| Sintoma | Causa provável |
| --- | --- |
| O app fecha ao abrir | O App ID não foi preenchido (Parte 2, passo 5) ou o export não usou Gradle |
| Os botões de vídeo não aparecem | O autoload `AdMobBackend` não foi adicionado, ou o plugin não está ativo |
| O vídeo não carrega (`on_ad_failed_to_load`) | Sem internet; ou ID real em conta nova (use o de teste); ou falta app-ads.txt |
| O erro "MobileAds não declarado" no editor | O plugin AdMob não está ativado em Plugins |

Documentação do plugin: <https://github.com/poingstudios/godot-admob-plugin> (tem versão em português em
`docs/*.pt-BR.md`).
