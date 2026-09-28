# Tutorial completo: publicando o Rogue Fish na Google Play

Este é o caminho inteiro, na ordem certa, do zero até o jogo aparecer na loja. Marque cada `[ ]` quando terminar.

**Quanto tempo leva:** umas **3 a 4 semanas**. Quase todo esse tempo é o teste fechado obrigatório de 14 dias
(Fase 6). O seu trabalho de verdade soma uns 2 ou 3 dias.

**O que o projeto já tem pronto** (feito por mim):
- o jogo em inglês e português;
- a exportação AAB para Android 16 (API 36), exigida pela Play em 2026;
- os workflows do GitHub que geram o AAB e o APK de teste;
- os textos, o ícone, o recurso gráfico e as capturas da loja (`docs/store/`);
- a política de privacidade (`docs/privacy.html`);
- o código dos vídeos e das compras, esperando só os plugins.

| Fase | O quê | Onde |
| --- | --- | --- |
| 1 | Conta de desenvolvedor | Play Console |
| 2 | Chave de assinatura e segredos | seu PC e GitHub |
| 3 | Política de privacidade online | GitHub Pages |
| 4 | Plugins de anúncios e compras | Godot, no seu PC |
| 5 | Criar o app e preencher a ficha | Play Console |
| 6 | Teste fechado: 12 testadores por 14 dias | Play Console |
| 7 | Produtos das compras | Play Console |
| 8 | Pedir acesso à produção e lançar | Play Console |
| 9 | Depois do lançamento | tudo |

---

## Fase 1 — Conta de desenvolvedor Google Play

1. [ ] Acesse <https://play.google.com/console/signup> com a conta Google que vai ser "dona" do jogo.
   - Use uma conta que você não vai perder, de preferência uma criada só para isso.
   - Ative a verificação em duas etapas.
2. [ ] Escolha o tipo de conta:
   - **Pessoal**: é o normal para quem é pessoa física. **Exige o teste fechado de 12 testadores por 14
     dias** antes de liberar a produção.
   - **Organização**: exige CNPJ e um número D-U-N-S (gratuito, mas leva dias para sair). Não precisa do teste
     de 14 dias. Só vale a pena se você já tem empresa.
3. [ ] Pague a taxa única de **US$ 25**.
4. [ ] Faça a **verificação de identidade**: documento com foto, endereço e telefone. Leva de horas a alguns dias.
5. [ ] Confirme que você tem um **celular Android** ligado à conta. A Play Console pede para instalar o app
   *Google Play Console* e verificar o aparelho.
6. [ ] **Verificação de desenvolvedor Android: importante para quem está no Brasil.**
   - A partir de **30 de setembro de 2026**, celulares Android certificados no Brasil (e também na Indonésia,
     em Singapura e na Tailândia) só instalam apps registrados por desenvolvedores verificados. No resto do
     mundo, a mesma regra chega a partir de 2027.
   - Apps publicados pela Play são registrados quase sempre de forma automática. Mesmo assim, olhe a página
     **Início** da Play Console: se aparecer um aviso para registrar o app, siga os passos.
   - O **APK de teste** que o GitHub gera (link `test-apk`) é assinado com outra chave. Duas saídas:
     - registrar essa chave na Play Console, que tem uma opção para apps distribuídos fora da loja;
     - ou instalar pelo "fluxo avançado" do Android, que avisa sobre o risco antes de deixar instalar.

     Para o jogo publicado na loja, isso não muda nada.
7. [ ] **Só se for vender compras dentro do app:** em *Configuração → Perfil de pagamentos*, crie o perfil de
   comerciante e informe a conta bancária e os dados fiscais. Sem isso, os produtos das compras não podem ser
   ativados (Fase 7).
   - A Play vai perguntar se você é "trader" (comerciante) pela lei europeia (DSA). Quem vende responde
     **sim**, e então o nome, o endereço e o telefone aparecem na ficha para os usuários da União Europeia.
   - Se não quiser isso, dá para tirar os países da UE da distribuição, na Fase 8.

---

## Fase 2 — Chave de assinatura e segredos do GitHub

A Play assina o app final com uma chave que o Google guarda (*Play App Signing*). Você só precisa de uma
**chave de upload**, que prova que foi você quem enviou o arquivo.

1. [ ] No seu PC, com o Java instalado, rode:
   ```bash
   keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
   ```
   - Use **a mesma senha** para o keystore e para a chave, porque o Godot usa uma só.
   - **Guarde `upload.jks` e a senha fora do git, com backup** (pendrive e nuvem). Sem eles você não publica
     atualizações. Se perder, dá para pedir um reset ao Google, mas leva dias.
2. [ ] No GitHub, abra o repositório e vá em **Settings → Secrets and variables → Actions → New repository
   secret**. Crie estes três segredos:

   | Nome | Valor |
   | --- | --- |
   | `ANDROID_KEYSTORE_BASE64` | a saída de `base64 -w0 upload.jks` (no macOS: `base64 -i upload.jks`; no Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("upload.jks"))`) |
   | `ANDROID_KEYSTORE_PASSWORD` | a senha |
   | `ANDROID_KEY_ALIAS` | `upload` |

3. [ ] **O nome do pacote é para sempre.** O projeto usa `com.roguefish.game`. Se quiser outro (por exemplo
   `com.seunome.roguefish`), troque **agora** em `export_presets.cfg` (`package/unique_name`, nos dois presets).
   Depois do primeiro envio, não dá mais para mudar.

---

## Fase 3 — Política de privacidade online

A Play exige um link público para a política. O arquivo já está pronto em `docs/privacy.html`.

1. [ ] Abra `docs/privacy.html` e troque `[SEU E-MAIL DE CONTATO]` por um e-mail de suporte. Crie um só para o
   jogo, por exemplo `roguefish.support@gmail.com`.
2. [ ] Faça merge do branch `claude/clever-hopper-ixpyr8` em `main`.
3. [ ] No GitHub, vá em **Settings → Pages → Deploy from a branch → `main` → `/docs` → Save**.
   - O GitHub Pages em **repositório privado** só funciona nos planos pagos. Se o seu repositório for privado,
     você tem duas saídas:
     - deixar o repositório público;
     - ou publicar a política em outro lugar gratuito (Google Sites, Notion público) e trocar a constante
       `PRIVACY_URL` em `scripts/data/offers.gd`.
4. [ ] Depois de 1 ou 2 minutos, abra `https://danilogl-coder.github.io/RogueFish/privacy.html` e confira se a
   página aparece. Esse link vai para a Play Console e é o do botão *Privacy* no jogo.

---

## Fase 4 — Plugins de anúncios e compras (no Godot)

Faça isso no seu PC, com o **Godot 4.5**. Sem os plugins, o jogo funciona, mas **esconde os vídeos** e **desliga a
loja de pérolas**. Você pode até lançar assim e ligar os plugins numa atualização.

### 4.1 Anúncios (AdMob)

Siga **`docs/ADMOB.md`** do começo ao fim: conta no AdMob, plugin da Poing Studios, o script de ponte (pronto
para colar) e o teste com anúncios de teste.

### 4.2 Compras (Google Play Billing)

O `scripts/autoload/billing.gd` já está escrito para o plugin oficial, **versão 3.x**, a atual para Godot 4.2+.
Ele detecta o plugin sozinho.

1. [ ] Baixe o zip da versão mais recente em
   <https://github.com/godot-sdk-integrations/godot-google-play-billing/releases>.
2. [ ] Descompacte e copie a pasta para `addons/GodotGooglePlayBilling/` dentro do projeto.
3. [ ] Em **Projeto → Configurações do Projeto → Plugins**, ative **GodotGooglePlayBilling**.
4. [ ] Em **Projeto → Exportar → Android**, confira que **Use Gradle Build** está ligado. Já vem ligado no preset
   "Android".
5. [ ] Faça o commit da pasta `addons/` (e da `android/`, se o plugin do AdMob a criou) e dê push. O workflow do
   GitHub passa a gerar o AAB já com os dois plugins.

---

## Fase 5 — Criar o app e preencher a ficha

### 5.1 Gerar o primeiro AAB

1. [ ] No GitHub, vá em **Actions → Android release (AAB) → Run workflow**:
   - `versionCode` = **1**;
   - `versionName` = **1.0.0**.
2. [ ] Quando terminar (uns 10 minutos), abra a execução e baixe o artefato **RogueFish-aab**. É um zip com o
   `RogueFish.aab` dentro.
3. **A cada envio novo, o `versionCode` precisa subir**: 2, 3, 4…

> Alternativa sem GitHub: no Godot, configure o keystore em **Projeto → Exportar → Android → Keystore →
> Release** e clique em **Exportar Projeto** com o preset "Android".

### 5.2 Criar o app

1. [ ] Na Play Console, clique em **Criar app**:
   - nome: **Rogue Fish: Larva to Legend**;
   - idioma padrão: **English (United States) – en-US**;
   - tipo: **Jogo**;
   - preço: **Gratuito** (não dá para mudar para pago depois);
   - aceite as declarações.

### 5.3 Conteúdo do app (Política → Conteúdo do app)

Responda cada item. As respostas certas para este jogo:

| Item | Resposta |
| --- | --- |
| Política de privacidade | o link da Fase 3 |
| Acesso ao app | "Todas as funcionalidades estão disponíveis sem restrições" (não tem login) |
| Anúncios | **Sim, meu app contém anúncios** (se você fez a Fase 4.1; senão, "Não") |
| Classificação de conteúdo | questionário IARC: categoria **Jogo**; violência **de desenho/fantasia** (animais se mordendo), sem sangue realista; sem interação entre usuários; sem compartilhamento de local; **compras digitais: sim** |
| Público-alvo | **13–15, 16–17 e 18+**. **Não marque menores de 13**, senão entram regras de "Famílias" que exigem anúncios certificados |
| Apps de notícias, de saúde, financeiros, governamentais | Não |
| ID de publicidade | **Sim, usa**, para anúncios (a permissão `AD_ID` já está no export) |
| Segurança dos dados | veja abaixo |

**Segurança dos dados**, com o AdMob instalado:
- **Coleta dados?** Sim.
- **Dados coletados:**
  - *Identificadores do dispositivo ou outros IDs* (ID de publicidade);
  - *Local aproximado* (pelo IP);
  - *Atividade no app* (interações com anúncios);
  - *Informações e desempenho do app* (falhas e diagnósticos).
- **Finalidade:** publicidade ou marketing, análise, prevenção de fraude.
- **Compartilhados** com terceiros: sim (Google AdMob).
- **Criptografados em trânsito:** sim.
- **O usuário pode pedir exclusão:** sim. O progresso fica só no aparelho e é apagado em *Options → Erase
  progress*.
- **Compras:** processadas pelo Google Play. O jogo não vê os dados de pagamento.

> Sem o AdMob, responda que o app **não coleta** dados.

### 5.4 Ficha da loja (Crescimento → Presença na loja → Versão principal)

| Campo | Onde está pronto |
| --- | --- |
| Nome do app | `Rogue Fish: Larva to Legend` |
| Descrição curta (80) | `docs/marketing/COPY.md`, seção 2 |
| Descrição completa | `docs/marketing/COPY.md`, seção 2 |
| Ícone 512×512 | `docs/store/icon_512.png` |
| Recurso gráfico 1024×500 | `docs/store/feature_graphic.png` |
| Capturas de celular (mín. 2; use as 8) | `docs/store/screenshots/01..08.png`, na ordem sugerida em COPY.md |
| Vídeo (opcional) | suba `docs/marketing/promo_googleplay_1920x1080.mp4` no YouTube (não listado) e cole o link |

1. [ ] Preencha os campos da tabela acima.
2. [ ] Em **Traduções → Adicionar idioma**, escolha **Português (Brasil)** e cole os textos de
   `docs/store/listing.md`. As imagens em português estão em `docs/store/pt-BR/`.
3. [ ] Em **Configurações da loja**:
   - categoria **Jogos → Ação**;
   - tags: *Roguelike*, *Pixel art*, *Offline*;
   - e-mail de contato: o mesmo da política.

---

## Fase 6 — Teste fechado (obrigatório em conta pessoal)

A regra: **pelo menos 12 testadores com o teste instalado, sem sair, por 14 dias seguidos**. Quem foi convidado
mas não instalou **não conta**.

### 6.1 Teste interno (opcional, rápido e recomendado)

1. [ ] Vá em **Testar e lançar → Teste interno → Criar nova versão**.
2. [ ] Aceite o **Play App Signing** quando pedir.
3. [ ] Envie o `RogueFish.aab`. Nas notas da versão, escreva "First build".
4. [ ] Em **Testadores**, crie uma lista só com o seu e-mail e copie o **link de participação**.
5. [ ] Abra o link no celular, aceite e instale pela Play Store.
6. [ ] Jogue uma partida. Confira:
   - os vídeos de teste do AdMob;
   - uma compra de teste. Adicione seu e-mail em **Configuração → Teste de licença** para comprar sem ser
     cobrado.

### 6.2 Teste fechado

1. [ ] Vá em **Testar e lançar → Teste fechado → Alpha → Criar nova versão** e envie o **mesmo AAB**, ou um
   novo com `versionCode` maior.
2. [ ] Em **Países/regiões**, marque todos (ou pelo menos Brasil e Estados Unidos).
3. [ ] Em **Testadores**, a forma mais fácil é um **Grupo do Google**:
   - crie o grupo em <https://groups.google.com> (ex.: `roguefish-testers`);
   - na Play Console, cole o e-mail do grupo;
   - quem entrar no grupo vira testador.
4. [ ] Envie a versão para revisão. A primeira revisão pode levar de 1 a 7 dias.
5. [ ] Quando for aprovada, divulgue o **link de participação** para pelo menos **15 a 20 pessoas**. É melhor
   sobrar, porque alguns desistem. Onde conseguir testadores:
   - amigos e família;
   - o post 4 da thread do X que te passei;
   - Discord ou Reddit (r/AndroidGaming aceita pedidos de teste);
   - comunidades de troca de testes (por exemplo, *Testers Community*).
6. [ ] Peça para **ninguém sair do teste nem desinstalar** durante os 14 dias. Mande uma versão nova no meio
   (com `versionCode` maior), com alguma correção. Isso mostra ao Google que o teste foi usado de verdade.

---

## Fase 7 — Produtos das compras

A aba de produtos só libera **depois do primeiro AAB enviado com o plugin de compras** (Fase 4.2).

1. [ ] Vá em **Monetizar → Produtos → Produtos no app → Criar produto** e crie os 6 produtos, com **exatamente
   estes IDs**:

   | ID | Nome (EN) | Preço (BR) | Tipo no jogo |
   | --- | --- | --- | --- |
   | `starter` | Starter Pack | R$ 7,90 | único |
   | `vip` | Abyssal VIP Pass | R$ 19,90 | único |
   | `pearls_1` | Handful of Pearls | R$ 4,90 | consumível |
   | `pearls_2` | Bag of Pearls | R$ 12,90 | consumível |
   | `pearls_3` | Chest of Pearls | R$ 24,90 | consumível |
   | `pearls_4` | Abyssal Treasure | R$ 59,90 | consumível |

   - Defina o preço em reais e clique em **Converter preços**, para a Play calcular os outros países.
   - "Único" e "consumível" é só o jogo que decide; na Play os 6 são produtos no app normais.
2. [ ] **Ative** cada produto.
3. [ ] Teste de novo com a conta de teste de licença. O preço que aparece no jogo passa a ser o da Play, em reais
   ou em dólar, conforme o país.

---

## Fase 8 — Acesso à produção e lançamento

1. [ ] Depois dos 14 dias com 12 ou mais testadores, vá em **Painel → Solicitar acesso à produção**. Responda o
   questionário com sinceridade e detalhes:
   - **Como recrutou os testadores:** "Friends, family and an online gaming community, via a Google Group opt-in
     link".
   - **Feedback recebido e o que mudou:** cite 2 ou 3 coisas reais, como ajuste de dificuldade ou um bug
     corrigido na versão X.
   - **Por que está pronto:** "Tested on N devices, no crashes in Android vitals, all features working".
   - A análise leva até **7 dias**. Se for recusada, o Google diz o motivo; normalmente pede mais testes.
2. [ ] Aprovado: vá em **Testar e lançar → Produção → Criar nova versão**.
   - Envie o AAB mais recente, com `versionCode` maior.
   - Notas da versão: "Rogue Fish is here! Hatch as a larva and evolve into a legend."
3. [ ] Em **Países/regiões**, marque **todos**. Sem o perfil de "trader", tire a União Europeia, como explicado
   na Fase 1.
4. [ ] Escolha o **lançamento gradual**: 20%, depois 50%, depois 100%, subindo a cada 2 ou 3 dias se não houver
   falhas.
5. [ ] Envie para revisão. Leva de algumas horas a alguns dias. Quando aprovar, o jogo aparece na busca.

> **Pré-registro (opcional, para marketing):** você pode abrir o pré-registro depois que o teste fechado estiver
> rodando. As pessoas se inscrevem e recebem um aviso no dia do lançamento. O plano em `docs/marketing/COPY.md`
> usa isso.

---

## Fase 9 — Depois do lançamento

- [ ] **AdMob:**
  - vincule o app à ficha da Play (*Apps → Configurações do app → Adicionar loja*);
  - publique o `app-ads.txt` (veja `docs/ADMOB.md`, Parte 1).
- [ ] Troque o link `[LINK]` dos textos de marketing pelo link da loja
  (`https://play.google.com/store/apps/details?id=com.roguefish.game`) e poste o lançamento.
- [ ] Acompanhe o **Android vitals** (falhas, ANRs) na primeira semana. Uma taxa de falhas acima de 1,09% derruba
  a visibilidade na loja.
- [ ] Responda **todas as avaliações**, principalmente as negativas.
- [ ] **Cada atualização:** rode o workflow com `versionCode` +1 e `versionName` novo (1.0.1…), envie em
  Produção e use o lançamento gradual.
- [ ] **Todo ano, em agosto,** a Play sobe o *target API* exigido. Em 2027 será provavelmente o API 37: troque
  `gradle_build/target_sdk` em `export_presets.cfg` e o `compileSdk` no workflow.
- [ ] Antes de investir pesado em marketing, **valide as compras num servidor** (veja `docs/MONETIZATION.md`).

---

## Problemas comuns

| Problema | Solução |
| --- | --- |
| "Você precisa usar um versionCode diferente" | Rode o workflow de novo com o número seguinte |
| "O APK/AAB não é assinado" ou "chave errada" | Os segredos da Fase 2 estão errados, ou você enviou com outra chave de upload |
| "Seu app segmenta o nível de API X" | Veja o `target_sdk` em `export_presets.cfg` (hoje é 36, o exigido em 2026) |
| A aba de produtos não aparece | Envie primeiro um AAB com o plugin de compras (Fase 4.2) |
| Os testadores não contam | Eles precisam aceitar o convite **e instalar** com a mesma conta Google |
| Pedido de produção recusado | Continue o teste por mais alguns dias, envie uma versão com melhorias e peça de novo com respostas mais detalhadas |
| O app fecha ao abrir, depois do AdMob | O App ID do AdMob não foi preenchido (veja `docs/ADMOB.md`) |

Fontes:
- [Play Console Help: requisitos de teste para contas pessoais novas](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
- [Android developer verification](https://developer.android.com/developer-verification)
- [Registro de apps na Play Console](https://developer.android.com/developer-verification/guides/google-play-console)
- [Plugin Google Play Billing para Godot](https://github.com/godot-sdk-integrations/godot-google-play-billing)
- [Plugin AdMob para Godot](https://github.com/poingstudios/godot-admob-plugin)
