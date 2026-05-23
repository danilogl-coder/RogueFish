# Imagens do jogo

O prototipo ja roda sem imagens externas. Para usar seus arquivos, coloque-os
com estes nomes:

- `backgrounds/layer_1.png`: camada distante do parallax.
- `backgrounds/layer_2.png`: camada intermediaria.
- `backgrounds/layer_3.png`: camada frontal.
- `platform.png`: piso/plataforma. O sprite atual usa a faixa visivel de
  `Plataform1.png` como topo repetido do chao.
- `fish_blink_1.png`: corpo do peixe com olho aberto.
- `fish_blink_2.png`: frame intermediario da piscada.
- `fish_blink_3.png`: frame fechado da piscada.
- `fish_tail.png`: cauda separada, animada pelo script do peixe.
- `seaweed/seaweed_1.png`, `seaweed_2.png`, `seaweed_3.png`: animacao da
  entidade alga, gerada com chance de 20% e mantida no percurso ao voltar.

Os backgrounds devem ter a mesma proporcao entre si para o loop ficar suave.
PNG em 1280 x 720 ou maior funciona bem para orientacao horizontal.
