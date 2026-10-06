# Clash of Mon

Fangame **gratuito e não-comercial** de luta 2D top-down com Pokémon, em tempo real, pensado primeiro para **celular (Android)** e feito em **Godot 4** (testado no 4.7, renderer *Compatibility*).

O jogador controla diretamente o Pokémon numa arena: movimento livre em 8 direções, ataque básico, 3 habilidades, Ultimate, dash/esquiva, energia, status, troca de Pokémon (3v3) e partidas rápidas. Sprites e animações vêm do **PMDCollab / SpriteCollab** (estilo Pokémon Mystery Dungeon) através do **PMD Sprite Importer** do projeto.

> Pokémon © Nintendo / Creatures / GAME FREAK. Projeto de fã sem fins lucrativos, sem afiliação. Veja **[CREDITS.md](CREDITS.md)** para a origem, artista e licença de cada asset.

## Como rodar

1. Instale o **Godot 4.7** (versão padrão, sem .NET).
2. Abra a pasta do projeto no Godot (`project.godot`) e aperte **F5**.
3. Menu: **JOGAR** (1v1 ou 3v3 contra bot), **POKÉMON** (ficha, golpes, todas as animações importadas e créditos), **TREINO**, **CONFIGURAÇÕES**, **CRÉDITOS**.

No PC os controles de toque aparecem se *Configurações → Controles de toque = Sempre* (o mouse simula um dedo).

### Controles

| Ação | Celular | Teclado + mouse | Gamepad |
|---|---|---|---|
| Mover | analógico flutuante (metade esquerda) | WASD / setas | analógico esquerdo |
| Mirar | arrastar o botão da habilidade | mouse | analógico direito |
| Ataque básico | botão grande (segurar = atirar sem parar, arrastar = mirar) | J / clique esquerdo | A / RT |
| Skill 1 / 2 / 3 | botões em arco (toque = mira automática, arrastar = mira manual, voltar ao centro = cancelar) | K / L / U (ou 1 2 3) | X / Y / B |
| Ultimate | botão com anel de carga | I / R / 4 | RB |
| Dash | botão `»` | Espaço / Shift | LB / LT |
| Trocar Pokémon (3v3) | retratos no topo | Q / E | D-pad ←/→ |
| Mega Evolução (experimental) | botão `M` | M | L3 |
| Pausa / debug / hitboxes | botão `II` | Esc / F3 / F4 | Start |

## O que já está jogável (milestone 1)

- 6 Pokémon com kits próprios: **Pikachu** (velocista/atirador), **Lucario** (lutador híbrido), **Charizard** (atirador/brigador, básico híbrido brasa/garra), **Blastoise** (tanque/atirador), **Gengar** (assassino/controle), **Garchomp** (brigador corpo a corpo). Nenhuma substituição foi necessária: os seis têm sprites completos no SpriteCollab (Blastoise e Garchomp não têm animação `Faint`; o importador cai para `Hurt`).
- Cada Pokémon: ataque básico, 3 skills, Ultimate (carregada causando/recebendo dano) e passiva exclusiva (Static, Aura, Blaze, Shell Armor, Cursed Body, Rough Skin).
- Combate: aceleração suave, colisões, dash com invulnerabilidade curta, knockback, hit stun curto, super armor, buffer de input, cancelamento de recuperação com dash, projéteis, cones, feixes, áreas com aviso no chão, zonas persistentes, saltos, escavação, teleporte, invisibilidade.
- Tipos com multiplicadores **moderados** (+15% / −13% / imunidade vira −25%, total limitado a 0,7–1,3), STAB 1,1 — tudo em `data/types.json`.
- Status em tempo real: Queimadura, Veneno (acumula), Paralisia (lentidão + micro-atordoamento), Congelamento e Sono (curtos, quebram com dano, dão imunidade temporária), Lentidão, Vulnerável. Imunidades canônicas por tipo (Fogo não queima etc.).
- 1v1 e **3v3 com troca** (cooldown de troca, Pokémon derrotado não volta), timer, vitória/derrota/empate, revanche.
- Treino: escolha de Pokémon/adversário/arena, HP infinito, cooldown instantâneo, hitboxes, bot parado/só se move/luta, revive automático.
- Bots com perfil por Pokémon: perseguem ou mantêm distância, desviam de projéteis e áreas, usam habilidades por intenção (poke/engage/escape/finisher), aproveitam sono/congelamento, recuam com pouco HP, trocam no 3v3.
- HUD: retrato, tipos, HP com rastro de dano, energia, Ultimate, status, passiva, timer, banco de troca, barra de skills com cooldown (teclado/gamepad).
- Debug (F3): FPS, frame time, physics time, draw calls, objetos, nós, memória, pools, projéteis, partículas, posição/velocidade/estado/animação/direção/cooldowns de cada lutador. F4 mostra hitboxes (vermelho), hurtboxes (verde) e projéteis.
- 2 arenas (Clareira Verdejante e Ruínas de Pedra) com pedras, árvores (copa fica translúcida sobre o jogador), muros, tocos destrutíveis, lago (bloqueia passagem mas não projéteis), arbustos e caminhos.
- Infraestrutura de **formas/Mega Evolução** funcionando com Mega Lucario (sprites comunitários CC BY-NC 4.0), atrás da opção experimental.

## PMD Sprite Importer

`pmd_importer/` lê diretamente uma pasta do SpriteCollab:

- `AnimData.xml`: `FrameWidth/Height`, `Durations` (ticks de 1/60 s), `RushFrame`, `HitFrame`, `ReturnFrame`, `CopyOf` (cadeias de alias), `ShadowSize`.
- `<Anim>-Anim.png`: colunas = frames, linhas = 8 direções (Baixo, Baixo-Dir., Dir., Cima-Dir., Cima, Cima-Esq., Esq., Baixo-Esq.); folhas de 1 linha (ex.: `Sleep`) são suportadas.
- `<Anim>-Offsets.png`: marcadores por frame — preto = cabeça, verde = centro, vermelho/azul = mãos. Usados para saber **de onde sai o projétil** (mãos/cabeça no HitFrame).
- `<Anim>-Shadow.png` (opcional): ponto exato do chão; sem ele usa o padrão PMD (centro + 4 px).
- `credits.txt`: créditos por animação, separando **oficial** (Chunsoft) de **comunidade**.

Nenhuma spritesheet é montada à mão: o `PMDAnimator` (um `Sprite2D` por lutador, uma draw call) só move o `region_rect`. A camada `animation/anim_library.gd` mapeia nomes de jogo (`idle`, `walk`, `attack`, `strike`, `shoot`, `special`, `hurt`, `faint`, `spin`...) para o que cada Pokémon tem, com fallbacks e overrides por Pokémon (`"anim_map": {"shell": ["Withdraw"]}`). O tempo dos golpes pode usar o HitFrame real: `"at": "hit"` numa ação dispara exatamente no frame de impacto da animação.

Para inspecionar o que foi importado: tela **POKÉMON** (toque nas animações, gire as direções) ou
`godot --headless --path . -s tests/dump_anims.gd -- res://assets/pmd/sprite/0025`.

## Estrutura

```
core/            autoloads (GameData, Settings, Game), partida (match), câmera, times, pools
combat/          CombatWorld (projéteis/hitboxes em pool), dano, tipos, geometria, VFX, overlay
pokemon/         Fighter, PokemonDef/FormDef (formas, Mega), passives/
abilities/       AbilityDef (dados), CastState (timeline), ActionExecutor (tipos de ação)
status/          StatusManager (status + modificadores temporários)
animation/       AnimLibrary (abstração de animações) e PMDAnimator
pmd_importer/    PMD Sprite Importer e leitura de créditos
input/           InputActions (teclado/gamepad), FighterInput, PlayerController (mira)
mobile_controls/ analógico + botões com arrastar para mirar
ai/              BotController
arena/           Arena (a partir de JSON) e arte procedural em pixel art
ui/              tema, menus, seleção, Pokédex, HUD, pausa, resultado, créditos
audio/           efeitos sonoros sintetizados (sem assets externos)
debug/           overlay de debug
assets/pmd/      sprites/retratos do SpriteCollab + credits.txt + licenças
data/            pokemon/*.json, arenas/*.json, types.json, status.json, game_config.json
tests/           testes headless (unitários, smoke, torneio, DPS, screenshots)
tools/           generate_credits.py
docs/            ARCHITECTURE.md, ADDING_POKEMON.md
```

Detalhes em [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Como criar um Pokémon novo (ou uma forma/Mega) só com dados: [docs/ADDING_POKEMON.md](docs/ADDING_POKEMON.md).

## Performance (Android primeiro)

- Renderer *GL Compatibility* (OpenGL ES 3), alvo 60 FPS com opção de **30 FPS** e qualidade Baixa/Média/Alta (limite de partículas, densidade de efeitos).
- Projéteis, hitboxes e partículas são **dados em pool** desenhados por um único canvas item cada (zero nós e zero alocações por tiro); lutadores = 1 sprite cada.
- Chão em `TileMapLayer` com atlas gerado uma vez; obstáculos em pixel art gerada e cacheada; sem shaders pesados (só um flash de dano por lutador).
- Física 60 Hz desacoplada da renderização; colisões de projétil por varredura (não atravessam alvos em FPS baixo).
- Sons sintetizados uma vez e salvos em `user://` (carregamento rápido nas próximas aberturas).
- Pausa automática quando o app vai para segundo plano.

## Exportar para Android

1. No Godot: *Editor → Gerenciar Templates de Exportação* → baixe os templates 4.7.
2. *Configurações do Editor → Exportar → Android*: caminho do Android SDK e do JDK 17+ (e um keystore de debug).
3. *Projeto → Exportar* → preset **Android** (já incluso em `export_presets.cfg`, arm64-v8a + armeabi-v7a, imersivo, permissão de vibração, inclui os `.xml/.txt/.json` necessários ao importador).

## Testes

```bash
godot --headless --path . --import                                   # primeira vez (cache de classes)
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd      # 126 verificações (núcleo)
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd -- res://tests/input_suite.gd   # teclado + toque
godot --headless --path . -s tests/check_scripts.gd                  # compila todos os scripts/cenas
godot --headless --fixed-fps 60 --path . -s tests/smoke_match.gd -- pikachu lucario
godot --headless --fixed-fps 60 --path . -s tests/tournament.gd -- 2 2   # todos x todos (bots)
godot --headless --fixed-fps 60 --path . -s tests/dps_test.gd -- 15 blastoise
xvfb-run godot --path . -s tests/screenshot.gd -- match /tmp/shot 400 pikachu lucario 1v1 verdant_glade on
```

## Próximos passos sugeridos

- Ajuste fino de balanceamento com jogadores humanos (os números atuais vêm de torneios entre bots).
- Mais formas/Megas (dados prontos; faltam sprites para algumas), mais arenas e interações com terreno (ex.: Fogo queimando árvores — o gancho `Arena.on_projectile_impact` já existe).
- Áudio/música definitivos e ícones de habilidade desenhados.
- Multiplayer (o `FighterInput` já isola comandos do lutador).
