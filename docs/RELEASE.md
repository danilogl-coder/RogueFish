# Lançamento na Google Play – passo a passo

> **Tutorial completo e atualizado, fase por fase: [`TUTORIAL_PLAYSTORE.md`](TUTORIAL_PLAYSTORE.md).** Este arquivo
> fica como referência técnica resumida.

Estado do projeto:
- a exportação Android está configurada para o formato AAB, com targetSdk 36 (Android 16) e minSdk 24;
- o AAB é gerado por um workflow do GitHub Actions;
- os textos e as imagens da loja estão em `docs/store/`;
- a política de privacidade está em `docs/privacy.html`.

O que falta depende das suas contas (Google Play, AdMob, GitHub) e está marcado com ☐.

## 1. Chave de assinatura (upload key) ☐

No seu computador (precisa do Java instalado):

```bash
keytool -genkeypair -v -keystore upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

- Use **a mesma senha** para o keystore e para a chave: o Godot usa uma só.
- **Guarde `upload.jks` e a senha fora do git**, com backup. Sem eles você não publica atualizações. Se perder a
  chave, dá para pedir um reset ao Google, mas leva dias.

## 2. Segredos no GitHub ☐

No repositório, abra **Settings → Secrets and variables → Actions → New repository secret** e crie:

| Nome | Valor |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | a saída de `base64 -w0 upload.jks` (no macOS: `base64 -i upload.jks`) |
| `ANDROID_KEYSTORE_PASSWORD` | a senha |
| `ANDROID_KEY_ALIAS` | `upload` |

## 3. Gerar o AAB ☐

1. Abra **Actions → Android release (AAB) → Run workflow**.
2. Informe o `versionCode` (1 na primeira vez; some 1 a cada novo envio) e o `versionName` (1.0.0).
3. Ao terminar, baixe o artefato **RogueFish-aab**.

Também dá para disparar com uma tag, por exemplo `git tag v1.0.0 && git push --tags`.

## 4. Política de privacidade online ☐

1. Faça merge deste branch em `main`.
2. Em **Settings → Pages**, escolha *Deploy from a branch → main → /docs*.
3. A política ficará em `https://danilogl-coder.github.io/RogueFish/privacy.html`. Esse é o link do botão
   *Privacidade* no jogo e o que você deve pôr no formulário da Play Console.
4. **Edite `docs/privacy.html` e troque `[SEU E-MAIL DE CONTATO]`** pelo e-mail de suporte.

## 5. Anúncios e compras reais ☐

Sem isso o jogo funciona, mas **esconde os botões de vídeo**, e a loja de pérolas aparece desativada. Os detalhes
estão em `docs/MONETIZATION.md`.

- **AdMob:** passo a passo completo, com o script pronto, em **`docs/ADMOB.md`**.
  1. Crie o app no AdMob e um bloco "Premiado" (rewarded).
  2. Instale o plugin `poing-studios/godot-admob-plugin` e cole o script de ponte do MONETIZATION.md.
  3. Configure a mensagem de consentimento (GDPR/LGPD) em **Privacidade e mensagens**.
- **Billing:**
  1. Instale o plugin `godot-google-play-billing`.
  2. Na Play Console, em **Monetizar → Produtos no app**, crie os produtos `starter`, `vip`, `pearls_1`,
     `pearls_2`, `pearls_3` e `pearls_4`, com os preços de `scripts/data/offers.gd`.
  3. Os produtos só aparecem depois do primeiro AAB enviado com a permissão de billing.
- Os dois plugins exigem que a exportação use o Gradle, o que já está ligado.

## 6. Play Console ☐

1. **Criar app:**
   - nome *Rogue Fish: Da Larva à Lenda*;
   - idioma padrão **English (United States)**, com a tradução pt-BR adicionada em seguida;
   - tipo Jogo;
   - gratuito.
2. **Configurar o app:**
   - **Política de privacidade:** o link do passo 4.
   - **Acesso ao app:** todo o conteúdo fica disponível sem login.
   - **Anúncios:** *Sim, meu app contém anúncios*.
   - **Classificação de conteúdo (IARC):**
     - categoria Jogo;
     - violência: sim, de desenho animado (animais se mordendo), sem sangue realista;
     - sem interação entre usuários;
     - compras digitais: sim.
   - **Público-alvo:** marque **13+** (13–15, 16–17, 18+). Não inclua menores de 13: a política Famílias exige
     anúncios certificados e regras extras.
   - **Segurança dos dados** (dados coletados pelo SDK do AdMob):
     - **Coletados:**
       - *Identificadores do dispositivo ou outros IDs* (ID de publicidade);
       - *Local aproximado* (via IP);
       - *Atividade no app* (interações com anúncios);
       - *Informações e desempenho do app* (diagnósticos e falhas).
     - **Finalidade:** publicidade/marketing, análise e prevenção de fraude.
     - **Compartilhados** com o Google (AdMob).
     - **Criptografados em trânsito:** sim.
     - **Pode pedir exclusão:** sim. O progresso fica no aparelho e é apagado em *Opções → Apagar progresso*.
     - **Pagamentos:** processados pelo Google Play, que não os compartilha com o app.
   - **Categoria:** Ação.
   - **Detalhes de contato:** e-mail de suporte.
3. **Presença na loja:** textos de `docs/store/listing.md`, com o ícone, o recurso gráfico e as 8 capturas de
   `docs/store/`.
4. **Assinatura de apps do Google Play:** aceite. O Google guarda a chave final e você envia com a upload key.

## 7. Testes obrigatórios (contas pessoais novas) ☐

Contas de desenvolvedor pessoais criadas depois de novembro de 2023 precisam fazer um **teste fechado com pelo menos
12 testadores, ativos por 14 dias seguidos**, antes de liberar a produção.

1. **Teste interno:**
   1. Envie o AAB.
   2. Adicione o seu e-mail.
   3. Instale pelo link e jogue.
   4. Confira os vídeos e as compras de teste. Use contas de teste de licença em **Configurações → Teste de
      licença**: elas compram sem cobrança.
2. **Teste fechado:**
   1. Crie uma lista com 12 ou mais testadores (amigos, grupos de testers).
   2. Espere os 14 dias e colete o feedback.
3. **Produção:**
   1. Peça acesso à produção.
   2. Responda o questionário.
   3. Lance com *lançamento gradual* (20% → 50% → 100%).

## 8. Checklist técnico do jogo ✅

- [x] AAB, arm64 + armv7, targetSdk 36, minSdk 24, modo imersivo, paisagem.
- [x] Permissões mínimas: INTERNET, ACCESS_NETWORK_STATE e AD_ID. O billing é adicionado pelo plugin.
- [x] Save atômico com backup, salvo ao minimizar o app; save corrompido é recuperado do backup.
- [x] O jogo pausa sozinho ao ir para segundo plano; o botão voltar do Android abre a pausa ou volta menus.
- [x] A versão de release não mostra anúncio falso nem compra falsa sem SDK.
- [x] *Restaurar compras* e *Privacidade* em Opções.
- [x] Scripts de debug (`scripts/debug/`) e ferramentas (`tools/`) ficam fora da exportação.
- [x] Testes automáticos de partidas completas sem erros de script.
- [ ] Testar em 2 ou 3 celulares reais (um fraco, um médio e um com tela 20:9) pelo teste interno.
- [ ] Validar as compras num servidor antes de escalar o marketing (veja MONETIZATION.md).

## 9. APK para testar no celular

O preset **Android APK** (sem Gradle) gera um APK instalável direto, sem passar pela Play Store:

```bash
godot --headless --export-release "Android APK" builds/RogueFish.apk
```

O workflow **Android test APK** faz isso sozinho a cada push que muda o jogo e publica o arquivo na release
*test-apk*. Para baixar direto no celular:
`https://github.com/danilogl-coder/RogueFish/releases/download/test-apk/RogueFish.apk`

No celular, abra o arquivo e permita *Instalar apps desconhecidos* para o app que abriu o APK (navegador ou
gerenciador de arquivos). Esse APK é só para teste: ele é assinado com a chave de debug, então o Android não deixa
atualizar por cima dele com a versão da Play Store. Desinstale o de teste antes.

## 10. Depois do lançamento

- Acompanhe **Android vitals**: travamentos, ANRs e bateria.
- Toda atualização precisa de um `versionCode` maior.
- Metas de 2027: o target API sobe todo ano, em agosto. Atualize `gradle_build/target_sdk` em
  `export_presets.cfg` e o `compileSdk` no workflow.
