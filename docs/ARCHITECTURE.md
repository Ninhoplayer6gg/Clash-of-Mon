# Arquitetura

Plano técnico curto da fundação. Tudo que é específico de um Pokémon é **dado** (JSON); o código só sabe executar tipos genéricos de ação.

## Fluxo de uma partida

```
Game.start_match(config) ──> core/match.tscn (match.gd)
  ├─ Arena            (arena/arena.gd)          chão TileMapLayer + obstáculos com colisão
  ├─ GroundFx         (combat/ground_fx.gd)     avisos no chão, zonas persistentes, mira
  ├─ Actors (y-sort)  obstáculos + Fighters     (pokemon/fighter.gd)
  ├─ CombatWorld      (combat/combat_world.gd)  projéteis/hitboxes em pool, resolução de golpes
  ├─ VfxLayer         partículas e afterimages (capacidade fixa)
  ├─ WorldOverlay     barras sobre os lutadores, números de dano
  ├─ MatchCamera      segue o jogador, zoom por proporção de tela, tremor
  ├─ PlayerController / BotController (por time) ──> FighterInput
  └─ CanvasLayers: Hud, MobileControls, PauseOverlay, ResultOverlay
```

Ordem por tick de física (60 Hz): controladores (prioridade −10) escrevem `FighterInput` → cada `Fighter` consome (movimento, dash, cast, timeline) → `CombatWorld` move projéteis/zonas e resolve acertos.

## Lutador (`Fighter`)

Estados: `IDLE`, `CASTING`, `DASHING`, `HITSTUN`, `DISABLED` (sono/congelamento/micro-atordoamento), `FAINTED`.

- Movimento com aceleração/desaceleração, knockback separado com atrito exponencial, movimento forçado (investidas, saltos, escavação) que pode atravessar paredes e depois procura um ponto livre.
- `try_cast(slot, aim, strength)`: checa cooldown/energia/carga da Ultimate, escolhe o *stage* (combo, variante ativa como Outrage, variante de curta distância como as garras do Charizard), resolve a mira (manual ou automática com previsão) e cria um `CastState`.
- Buffer de input de 0,22 s; o dash pode cancelar a recuperação de um golpe; super armor ignora hit stun/knockback.
- Recursos: HP, energia (dash, skills e básicos à distância), carga de Ultimate (dano causado/recebido + passiva lenta), carga de Mega.

## Habilidades (dados)

`AbilityDef` = metadados + lista de ações com tempo (`"at": 0.12` ou `"at": "hit"` = HitFrame da animação PMD). Tipos de ação (`abilities/action_executor.gd`):

| `do` | Uso |
|---|---|
| `projectile` | projétil em pool: velocidade, aceleração, alcance, raio, quantidade/abertura, teleguiado, perfurante, explosão (`explode`, com `linger` = chão em chamas) |
| `melee` | hitbox presa ao lutador: `circle`, `sector` (cone) ou `line`; multi-hit (`interval`, `hits`), canalizado (`bound`, `follow_aim`) |
| `aoe` | área em `self`/`target`/`forward` com aviso (`delay`), múltiplos impactos (`count`, `stagger`, `scatter`) |
| `beam` | feixe com aviso, para em paredes |
| `zone` | área persistente que causa dano/status periódico |
| `dash`, `leap`, `burrow`, `teleport`, `vanish` | mobilidade (com hitbox opcional, intocável no ar/subterrâneo/invisível) |
| `buff`, `cleanse`, `heal` | modificadores temporários (velocidade, dano, defesa, super armor, roubo de vida, variante de golpe) |
| `vfx`, `shake` | só visual |

Parâmetros de dano em qualquer ação: `power`, `type`, `category`, `knockback`, `kb_dir`, `hitstun`, `contact`, `status {id, chance, duration}`, `speed_scaling`.

Dano: `power × (atk/def)^0,6 × STAB × tipo × modificadores` (`combat/damage_calc.gd`). Passivas alteram `DamageInfo.mult` antes do cálculo e reagem depois (`pokemon/passives/`).

## Formas e Mega Evolução

`PokemonDef.forms` contém `base` e outras formas. Uma forma pode herdar de outra (`"inherits": "base"`) e trocar apenas o que muda: `sprite`, `portrait`, `anim_map`, `stats` / `stat_mult`, `types`, `abilities` (por slot), `passive`, `effects`, `dash`. Metadados: `trigger` (`"mega"`, `"primal"`...), `transform_duration`, `asset_status` (`approved` / `pending`: formas pendentes usam o sprite atual como placeholder).

`Fighter.apply_form(id)` troca tudo de uma vez mantendo a proporção de HP. A Mega: barra de carga → `start_mega()` (cast especial curto, invulnerável) → `apply_form("mega")` → volta à forma base após `transform_duration` (ou a regra do modo). Formas regionais/alternativas usam o mesmo caminho (`trigger` vazio, escolhidas na seleção no futuro).

## Entrada e mira

`FighterInput` é o único canal entre controlador e lutador (pronto para rede no futuro). `PlayerController` combina teclado/mouse, gamepad (analógico direito) e `MobileControls` (arrastar o botão). Sem direção explícita, a habilidade usa mira automática (inimigo mais próximo dentro do alcance, com previsão de movimento) ou a direção do movimento.

## Performance

- Pools (`core/object_pool.gd`) para projéteis e hitboxes; `VfxLayer` com arrays fixos (capacidade por qualidade gráfica).
- Desenho imediato em poucos canvas items (projéteis, zonas, overlay, partículas) — poucas draw calls e zero nós por efeito.
- StyleBoxes e arrays de UI reutilizados entre frames.
- Arte da arena gerada uma vez (atlas de tiles + texturas cacheadas).

## Arenas

`data/arenas/*.json`: tamanho, paleta, spawns, caminhos de terra, obstáculos (`rock`, `tree`, `wall`, `stump` destrutível, `pond` que bloqueia andar mas não projéteis), arbustos e espelhamento automático (`"mirror": "x"`) para mapas justos. Ganchos para interação futura: `Arena.on_projectile_impact`, `damage_obstacle`, `tags` por obstáculo.
