# Adicionando um Pokémon (ou forma)

Nenhum código é necessário para um kit que use as ações existentes.

## 1. Assets

1. Encontre a pasta no SpriteCollab: `sprite/<dex com 4 dígitos>/` (formas ficam em subpastas, ex.: `sprite/0448/0001` = Mega Lucario). Confira o `tracker.json` (nome da forma e se está completa).
2. Leia o `credits.txt` da pasta: autor `CHUNSOFT` = oficial; outros = comunidade (licença na 4ª coluna). Só integre assets com origem identificável.
3. Copie para `assets/pmd/sprite/<dex>/...`: `AnimData.xml`, `credits.txt`, todos os `*-Anim.png` e `*-Offsets.png` (os `*-Shadow.png` são opcionais). Retrato: `assets/pmd/portrait/<dex>/Normal.png` + `credits.txt`.
4. Adicione os artistas novos em `assets/pmd/credit_names.txt` e rode `python3 tools/generate_credits.py > CREDITS.md`.

## 2. Dados

Crie `data/pokemon/<id>.json` (copie um existente) e adicione o id em `data/roster.json`.

```jsonc
{
  "id": "meu_pokemon", "name": "Nome", "dex": 123, "role": "Função",
  "ai": {"range": 120, "style": "kite", "retreat_hp": 0.25},   // "kite" ou "brawler"
  "forms": {
    "base": {
      "sprite": "res://assets/pmd/sprite/0123",
      "portrait": "res://assets/pmd/portrait/0123/Normal.png",
      "types": ["water"],
      "stats": {"hp": 3000, "attack": 100, "defense": 100, "sp_attack": 100, "sp_defense": 100,
                "move_speed": 125, "mass": 1.0, "radius": 10, "energy": 100, "energy_regen": 22},
      "anim_map": {"spin": ["Rotate"]},                    // opcional
      "passive": {"id": "nome_da_passiva", "name": "...", "description": "...", "params": {}},
      "abilities": { "basic": {...}, "skill1": {...}, "skill2": {...}, "skill3": {...}, "ult": {...} }
    }
  }
}
```

Habilidade:

```jsonc
"skill1": {
  "id": "water_pulse", "name": "Water Pulse", "icon": "WP", "description": "...",
  "type": "water", "category": "special",          // physical | special | status
  "cooldown": 5.0, "energy": 20, "range": 220,
  "aim": "direction",                               // direction | point | self
  "anim": "shoot", "cast_time": 0.4, "move_mult": 0.2,
  "ai": {"max": 210, "use": "poke"},                // poke | engage | escape | finisher | defense
  "actions": [
    {"at": "hit", "do": "projectile", "speed": 300, "range": 220, "radius": 8, "power": 300,
     "status": {"id": "slow", "chance": 0.5}, "vfx": {"style": "orb", "color": "#bfe4ff", "color2": "#3f8fff"}}
  ]
}
```

Veja a tabela de ações em `docs/ARCHITECTURE.md`. Para conferir as animações disponíveis e seus HitFrames use a tela **POKÉMON** ou `tests/dump_anims.gd`.

## 3. Passiva (opcional)

Se a passiva precisar de lógica, crie `pokemon/passives/<id>.gd` estendendo `PassiveBase` e sobrescreva os ganchos (`modify_outgoing`, `modify_incoming`, `on_hit_dealt`, `on_hit_taken`, `on_cast`, `on_dash`, `update`, `allow_status`, `aura_color`, `hud_text`). O arquivo é carregado automaticamente pelo `id`.

## 4. Formas / Mega

```jsonc
"mega": {
  "inherits": "base",
  "name": "Mega Nome",
  "trigger": "mega",
  "transform_duration": 25.0,
  "sprite": "res://assets/pmd/sprite/0123/0001",
  "portrait": "res://assets/pmd/portrait/0123/0001/Normal.png",
  "asset_status": "approved",                     // "pending" = usa o sprite atual até a licença ser verificada
  "stat_mult": {"attack": 1.2},
  "types": ["water", "dark"],
  "abilities": {"skill2": { ... }},               // substitui só os slots listados
  "passive": {"id": "...", "params": {}}
}
```

Sprites encomendados: coloque-os numa pasta com o mesmo formato do SpriteCollab (`AnimData.xml` + folhas) e aponte `sprite` para ela.

## 5. Testar

```bash
godot --headless --path . --import
godot --headless --fixed-fps 60 --path . -s tests/unit_tests.gd
godot --headless --fixed-fps 60 --path . -s tests/tournament.gd -- 1 2
```
