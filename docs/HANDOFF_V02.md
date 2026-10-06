# Handoff — continuação da v0.2 (Clash of Mon)

Documento para quem continuar o desenvolvimento (ex.: Codex). Leia também `README.md`, `docs/ARCHITECTURE.md` e `docs/ADDING_POKEMON.md`.

## Contexto

- Fangame **gratuito e não-comercial**, arena fighter 2D top-down em tempo real, foco em **celular (Android)**.
- **Godot 4.7**, renderer *GL Compatibility*, GDScript tipado. Interface em **português (pt-BR)**, comentários de código em inglês.
- Sprites do **PMDCollab/SpriteCollab**, lidos pelo PMD Sprite Importer do projeto (`pmd_importer/`).
- O código da v0.1 está no branch **`ccr-28de97ed-o7gefn`** (o `main` só tem o commit inicial). Use esse branch como base.

## Estado dos branches da v0.2

Todos partem de `ccr-28de97ed-o7gefn` @ `e15849c` e estão no GitHub.

| Branch | Commit | Estado | Testes |
|---|---|---|---|
| `v02/arenas` | `c0dba15` | **Completo.** Sistema de terreno (`arena/arena_terrain.gd`): grama alta que esconde (concealment), lava (dano + queimadura, Fogo imune), água rasa (lenta para não-Água, rápida para Água, apaga queimadura), fogo queima a grama e ela volta a crescer. Arenas novas `volcano_crater` (Cratera Vulcânica) e `tropical_lagoon` (Lagoa Tropical); grama alta na Clareira. Bots respeitam concealment e evitam lava. | unit 126/126, input 15/15, `tests/arena_suite.gd` 104/104 |
| `v02/polish` | `31c7d64` | **Funcional, falta revisão visual.** Hit-stop + câmera lenta no nocaute decisivo (`core/hit_stop.gd`), efeitos por tipo para os 18 tipos (`combat/type_vfx.gd`), ícones de habilidade desenhados por código (`ui/skill_icons.gd`), setas de inimigo fora da tela (`ui/offscreen_indicator.gd`), tutorial "Como jogar" (`ui/tutorial_overlay.gd`), vinheta/flash de dano (`ui/screen_feedback.gd`), SFX mais ricos. | unit 126/126, input 15/15, `tests/polish_suite.gd` 186/186 |
| `v02/mega` | `57cf94a` | **Só assets.** Sprites e retratos de Mega Charizard X (`sprite/0006/0001`) e Mega Gengar (`sprite/0094/0001`) + linhas de artistas em `assets/pmd/credit_names.txt`. Todo o resto está por fazer. | — |
| `v02/roster` | `91da6dc` | **Só pastas de sprite** de Venusaur (`0003`), Tyranitar (`0248`), Gardevoir (`0282`), Mega Gardevoir (`0282/0001`) e Greninja (`0658`). Faltam: **sprite do Mega Tyranitar (`0248/0001`)**, todos os retratos (`portrait/<dex>[/0001]/Normal.png` + `credits.txt`), linhas em `credit_names.txt` e todo o código e os dados. | — |

## Plano de trabalho (ordem recomendada)

1. **Integração**: crie `v02/integration` a partir de `ccr-28de97ed-o7gefn`. Faça merge de `v02/arenas`, depois de `v02/polish`. Resolva os conflitos mantendo **as duas** funcionalidades. Arquivos prováveis: `combat/combat_world.gd`, `core/match.gd`, `ui/hud.gd`, `combat/world_overlay.gd`, `pokemon/fighter.gd`, `ai/bot_controller.gd`. Depois faça merge de `v02/mega` e `v02/roster` (só assets). Rode todos os testes e tire screenshots (ver abaixo) para revisar o polimento.
2. **Elenco novo + mecânicas de motor** (seção "Elenco" abaixo).
3. **Mega Evolução no jogo normal** (seção "Megas").
4. **Modos de jogo** (seção "Modos").
5. **Balanceamento e IA dos 10 Pokémon**: use `tests/tournament.gd` e `tests/dps_test.gd`. Meta aproximada: nenhum Pokémon com menos de 35% ou mais de 65% de vitórias entre bots, nas arenas `verdant_glade` e `stone_ruins`.
6. **Fechamento**: regenere os créditos (`python3 tools/generate_credits.py > CREDITS.md`). O gerador usa um único `assets/pmd/SOURCE_COMMIT.txt`: os assets novos vêm do commit `c41815df752d5581e9462346b2d967f6fe783fc6` do SpriteCollab (os da v0.1 vêm de `51eda301e151d3528466f3f65734bf7c70c373a6`), então registre os dois. Atualize o README (funcionalidades, controles, testes), commit e push.

## Elenco: 4 Pokémon novos + mecânicas de motor

Adicione `venusaur`, `greninja`, `gardevoir` e `tyranitar` a `data/roster.json`, depois de `garchomp`. Siga o formato dos JSON da v0.1: básico + 3 skills + Ultimate + passiva única, nomes de golpes reais, descrições em pt-BR e dicas de IA (`"ai": {range, style, retreat_hp}` e, por habilidade, `"ai": {min, max, use}`). Para ver as animações disponíveis: `tests/dump_anims.gd`. Use `anim_map` quando ajudar (Gardevoir tem Appeal/SpAttack, Tyranitar tem Twirl, Venusaur tem Dance/Shake, Greninja tem QuickStrike/RearUp/Rumble).

Licenças já conferidas: os sprites base de Venusaur, Gardevoir e Tyranitar são oficiais (CHUNSOFT). Greninja, Mega Gardevoir e Mega Tyranitar são comunitários (PMDCollab_1 ou CC BY-NC 4.0). Mesmo assim, leia cada `credits.txt`.

- **Venusaur** (Planta/Venenoso), tanque de controle de zona:
  - Básico Razor Leaf: 3 folhas em leque estreito.
  - Leech Seed: novo status `leech_seed`, dano por tempo que **cura quem aplicou**.
  - Solar Beam: carga longa com super armor, feixe grosso.
  - Vine Whip: linha que **puxa** o alvo.
  - Ultimate Frenzy Plant: raízes em linha (círculos com aviso ao longo da mira) que aplicam o novo status `root`, que impede de andar mas permite atacar.
  - Passiva tipo Chlorophyll: regenera ~1,5–2% do HP/s após ~2,5 s sem levar dano.
- **Greninja** (Água/Sombrio), assassino frágil e muito móvel:
  - Básico Water Shuriken: 2 shurikens.
  - Night Slash: investida que atravessa, com bônus pelas costas.
  - Double Team: some ~1 s e o próximo acerto causa +40% (modificador com a nova flag `consume_on_hit`).
  - Shadow Sneak: dash com **2 cargas** (novo sistema de cargas por habilidade).
  - Ultimate Shuriken Storm: 3 rajadas teleguiadas.
  - Passiva **Protean**: o tipo de Greninja vira o tipo do último golpe por ~4 s e volta depois (inclusive ao sair de campo).
- **Gardevoir** (Psíquico/Fada), maga de controle e suporte:
  - Básico Fairy Wind: orbe que perfura.
  - Psychic: área no ponto que **puxa** para o centro.
  - Moonblast: aplica o novo status `weakened` (−15% de dano causado por 3 s).
  - Light Screen: **escudo** de ~20–25% do HP máximo por ~3 s + limpeza de status.
  - Ultimate Future Sight: área enorme que explode após ~1,1 s e cura Gardevoir.
  - Passiva **Synchronize**: quem aplica status em Gardevoir recebe o mesmo status (com cooldown interno).
  - **Mega Gardevoir**: herda a base, mais At. Esp. e velocidade, passiva Pixilate (golpes Normal viram Fada, +20%).
- **Tyranitar** (Pedra/Sombrio), tanque pesado:
  - Básico Crunch: mordida larga.
  - Stone Edge: espinhos em linha.
  - Rock Tomb: rocha arremessada que **cria um obstáculo temporário** na arena (~4 s, bloqueia passagem e projéteis) e deixa o alvo lento.
  - Sandstorm: zona de 5 s que acompanha Tyranitar, causa dano leve e lentidão nos inimigos, e reduz o dano que ele recebe.
  - Ultimate Rock Wrecker: salto + impacto grande.
  - Passiva Sand Stream: −12–15% de dano recebido, ~30% durante a Sandstorm.
  - **Mega Tyranitar**: mais Ataque e Defesa, passiva mais forte.

Mecânicas de motor (genéricas, guiadas por dados):

1. Status em `data/status.json` com suporte no `StatusManager`:
   - `root`: flag de imobilizar, com imunidade curta depois.
   - `weakened`: multiplicador de dano causado.
   - `leech_seed`: flag de curar a fonte; tipos Planta são imunes.
   - Inclua os três nos chips do HUD.
2. Flag de modificador `consume_on_hit`: o modificador é removido após o próximo acerto, no `CombatWorld.apply_hit`.
3. **Cargas por habilidade**: chaves `"charges"` e `"charge_time"`. Mostre a contagem nos botões de toque e na barra de skills.
4. **Escudo**: ação `"shield"` com `{pct, duration}`. Absorve dano (inclusive DoT) antes do HP e aparece como bolha e como segmento branco na barra.
5. Ação **`aoe_line`**: N círculos ao longo da mira, com `spacing`, `stagger`, `radius` e `delay`.
6. `Arena.spawn_temp_obstacle(pos, radius, duration)`: rocha temporária que nunca prende um lutador. Exposta via chave de projétil `"spawn_obstacle": {radius, duration}`.
7. Passivas novas em `pokemon/passives/`. `Fighter.apply_form` deve restaurar os tipos.

Testes em `tests/roster_suite.gd`, rodados com `tests/unit_tests.gd -- res://tests/roster_suite.gd`: cada mecânica nova e cada Pokémon/forma carrega e resolve as animações.

## Megas no jogo normal

A infraestrutura já existe: `FormDef` com herança, `Fighter.start_mega`/`_finish_mega`/`revert_form`, `mega_charge` e a forma Mega Lucario.

1. Formas `"mega"` em `data/pokemon/charizard.json` e `gengar.json`, usando os assets de `v02/mega`:
   - **Mega Charizard X**: Fogo/Dragão, passiva Tough Claws (golpes de contato +20%) e ajuste do kit.
   - **Mega Gengar**: passiva Shadow Tag (inimigos perto ficam lentos e não podem trocar).
   - Revise Mega Lucario. Mega Gardevoir e Mega Tyranitar entram com o elenco.
2. Regras em `data/game_config.json`, seção `"mega"`:
   - Mega **ligada por padrão** no JOGAR. Mantenha a opção na seleção, renomeada para "Mega Evolução".
   - **Uma Mega por time por partida**: flag no `TeamState`, mostrada no HUD.
   - Duração configurável. Sugestão: até sair de campo ou 30 s; documente a escolha.
   - A Mega deve acontecer por volta do meio de uma luta 1v1 típica.
3. UX:
   - Barra de Mega no card do HUD.
   - Botão Mega pulsando nos controles de toque quando pronto.
   - Slot "M" na barra de skills do desktop.
   - **Cinemática curta** (~0,8 s, sem ser injusta): zoom na câmera, câmera lenta breve, faixa "MEGA EVOLUÇÃO!" com o nome da forma, anel colorido, som e invulnerabilidade.
   - A Pokédex mostra as formas Mega com retrato, stats e créditos.
4. IA: os bots usam a Mega com inteligência e respeitam a regra de uma por time.
5. Testes em `tests/mega_suite.gd`.

## Modos de jogo (contra bots)

Adicione a escolha de modo na tela JOGAR, com a lógica de cada modo separada do `match.gd`. Sugestão: `core/modes/*.gd`, com uma classe base `ModeRules` e ganchos `on_start`, `on_fighter_fainted`, `physics_tick`, `hud_text` e `check_end`, e o `match.gd` delegando para ela.

- **Duelo**: o 1v1/3v3 atual.
- **Sobrevivência**: ondas de bots em sequência com dificuldade crescente. Entre ondas, recupera ~30% do HP. Pontuação = ondas vencidas, com recorde salvo em `user://`.
- **Torneio**: 3 rodadas (quartas, semi, final) contra adversários aleatórios cada vez mais difíceis. Tela entre rodadas. Perdeu, está eliminado. Tela de troféu no fim.
- **Zona de Controle** (rei da colina): círculo no centro da arena. Ficar sozinho nele soma pontos; zona disputada não pontua. Vence quem fizer 100 pontos, ou quem tiver mais aos 2:00. Nocaute = renascer após 3 s no spawn. Os bots vão para a zona.

Cada modo precisa de HUD próprio (placar, onda, rodada), tela de resultado adequada e testes em `tests/modes_suite.gd`.

## Padrões e armadilhas deste projeto (importante)

1. `var x := dict.get(...)` não compila (inferência de Variant). Use tipo explícito: `var x: float = d.get("k", 0.0)`.
2. Não use como nome de variável ou método: `range`, `log`, `set`, `get`, `name`/`owner` em Nodes, `_set_size` (conflita com `Control`), nem outros métodos virtuais da engine.
3. Arrays *Packed* são passados por **valor**: redimensione cada um explicitamente.
4. Depois de criar um script com `class_name`, rode `godot --headless --path . --import` para atualizar o cache de classes.
5. Scripts `SceneTree` rodados com `-s` **não** podem referenciar autoloads (`GameData`, `Settings`...) em tempo de compilação. Escreva suítes de teste como `extends Node` e rode pelo runner `tests/unit_tests.gd -- res://tests/<suite>.gd` (veja `tests/input_suite.gd`).
6. Em JSON de habilidade, `"at"` é o **tempo na timeline** (número ou `"hit"` = HitFrame do PMD). A âncora de área é `"where"` (`self`/`target`/`forward`).
7. Lógica de jogo em `_physics_process` (60 Hz), visual em `_process`. Controladores rodam com `process_physics_priority = -10`.
8. Desempenho em celular fraco: **nenhuma alocação por frame** (reutilize StyleBoxes e arrays; use os pools existentes) e partículas limitadas por `Settings.quality`.
9. Não mexa em `tests/unit_suite.gd` nem em `tests/input_suite.gd` sem necessidade. Elas devem continuar 100% verdes.

## Assets e licenças (regras do projeto)

- Fonte: SpriteCollab no commit `c41815df752d5581e9462346b2d967f6fe783fc6`. Baixe com `https://raw.githubusercontent.com/PMDCollab/SpriteCollab/<commit>/<caminho>`. Para listar arquivos: `git clone --filter=blob:none --no-checkout --depth 1 https://github.com/PMDCollab/SpriteCollab.git` e depois `git ls-tree`.
- Copie **só** `AnimData.xml`, `credits.txt`, `*-Anim.png` e `*-Offsets.png`. **Nunca** copie `*-Shadow.png`, nunca altere pixels e nunca gere ou redesenhe sprites.
- Retratos: `portrait/<dex>[/<forma>]/Normal.png` + `credits.txt`.
- Integre só assets com origem e licença identificáveis no `credits.txt` (CHUNSOFT/Unspecified = oficial; PMDCollab_1, PMDCollab_2 ou CC_BY-NC_4 = comunidade). Copie as linhas de artistas novos do `credit_names.txt` original para `assets/pmd/credit_names.txt`.
- Não edite o `CREDITS.md` à mão: rode o gerador.

## Testes (todos devem passar antes de cada push)

```bash
godot --headless --path . --import > /dev/null 2>&1
godot --headless --path . -s tests/check_scripts.gd                                   # "CHECK: N files, 0 failed"
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd                       # núcleo
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd -- res://tests/input_suite.gd
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd -- res://tests/arena_suite.gd
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd -- res://tests/polish_suite.gd
godot --headless --fixed-fps 60 --path . -s tests/smoke_match.gd -- pikachu lucario
godot --headless --fixed-fps 60 --path . -s tests/tournament.gd -- 1 2 [arena]       # todos x todos (bots)
# screenshots (precisa de xvfb):
xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 \
  -s tests/screenshot.gd -- match /tmp/shot 400 pikachu,lucario garchomp,gengar 3v3 verdant_glade on
```

Para instalar o Godot 4.7 num ambiente Linux:

```bash
curl -L -o /tmp/godot.zip https://github.com/godotengine/godot/releases/download/4.7-stable/Godot_v4.7-stable_linux.x86_64.zip
unzip -o /tmp/godot.zip -d /tmp/godot && ln -sf /tmp/godot/Godot_v4.7-stable_linux.x86_64 /usr/local/bin/godot
```
