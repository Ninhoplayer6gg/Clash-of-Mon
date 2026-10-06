#!/usr/bin/env python3
"""Generates CREDITS.md from the SpriteCollab credits files shipped in
assets/pmd (credits.txt per folder + credit_names.txt).

Usage: python3 tools/generate_credits.py > CREDITS.md
"""
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PMD = os.path.join(ROOT, "assets", "pmd")
REPO = "https://github.com/PMDCollab/SpriteCollab"

LICENSES = {
    "Unspecified": "Sem licença declarada — sprite **oficial** (Spike Chunsoft / Pokémon Mystery Dungeon). Não coberto por CC; usado apenas neste fangame gratuito e não-comercial.",
    "PMDCollab_1": "Licença PMDCollab 1 — uso, cópia, redistribuição e modificação permitidos mantendo o crédito ao artista original.",
    "PMDCollab_2": "Licença PMDCollab 2 — como a PMDCollab 1, e o trabalho não pode ter fins lucrativos.",
    "CC_BY-NC_4": "CC BY-NC 4.0 — atribuição obrigatória, uso não-comercial.",
}


def load_names():
    names = {}
    with open(os.path.join(PMD, "credit_names.txt"), encoding="utf-8") as f:
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if len(cols) < 2 or cols[0] == "Name":
                continue
            names[cols[1]] = (cols[0], cols[2] if len(cols) > 2 else "")
    return names


def read_credits(folder):
    rows = []
    path = os.path.join(folder, "credits.txt")
    if not os.path.exists(path):
        return rows
    with open(path, encoding="utf-8") as f:
        for line in f:
            cols = line.rstrip("\n").split("\t")
            if len(cols) >= 5:
                rows.append({"date": cols[0], "author": cols[1], "status": cols[2], "license": cols[3], "anims": cols[4].split(",")})
    return rows


def artist(names, aid):
    if aid == "CHUNSOFT":
        return "Spike Chunsoft (oficial)", "https://www.spike-chunsoft.com/"
    return names.get(aid, (aid, ""))


def table(names, rows, only=None):
    out = ["| Origem | Artista | Contato | Licença | Data | Animações / emoções |", "|---|---|---|---|---|---|"]
    for r in rows:
        anims = r["anims"]
        if only is not None:
            anims = [a for a in anims if a in only]
            if not anims:
                continue
        name, contact = artist(names, r["author"])
        kind = "Oficial" if r["author"] == "CHUNSOFT" else "Comunidade"
        status = "" if r["status"] == "CUR" else " (versão antiga, substituída)"
        out.append("| %s | %s%s | %s | `%s` | %s | %s |" % (kind, name, status, contact or "—", r["license"], r["date"][:10], ", ".join(anims)))
    return "\n".join(out)


def main():
    names = load_names()
    roster = json.load(open(os.path.join(ROOT, "data", "roster.json"), encoding="utf-8"))["pokemon"]
    commit = open(os.path.join(PMD, "SOURCE_COMMIT.txt")).read().strip()
    w = sys.stdout.write
    w("# Créditos — Clash of Mon\n\n")
    w("> Arquivo gerado por `tools/generate_credits.py` a partir dos `credits.txt` originais do SpriteCollab incluídos em `assets/pmd/`. **Não remova créditos.**\n\n")
    w("Clash of Mon é um **fangame gratuito e não-comercial**. Pokémon e todos os nomes, personagens e marcas relacionados pertencem a Nintendo, Creatures Inc. e GAME FREAK inc. Este projeto não é afiliado nem endossado por eles.\n\n")
    w("## Fonte dos sprites\n\n")
    w("- **PMDCollab / SpriteCollab** — %s (site: http://sprites.pmdcollab.org/)\n" % REPO)
    w("- Revisão usada: commit `%s` (branch `master`).\n" % commit)
    w("- Licença do repositório para contribuições da comunidade: CC BY-NC 4.0 (cópia em `assets/pmd/LICENSE.SpriteCollab.md`). Licenças históricas PMDCollab 1/2 em `assets/pmd/license_history/`.\n")
    w("- Nomes/contatos dos artistas: `assets/pmd/credit_names.txt` (recorte do arquivo original, apenas artistas usados aqui).\n\n")
    w("### Sprites oficiais × comunitários\n\n")
    w("O SpriteCollab mistura dois tipos de arquivo, e este projeto os distingue em todos os lugares (aqui, na tela **Créditos** e na tela **Pokémon** do jogo):\n\n")
    w("- **Oficial** (autor `CHUNSOFT`, licença `Unspecified`): sprites extraídos de *Pokémon Mystery Dungeon* (Spike Chunsoft). Não são licenciados pelo PMDCollab nem por Creative Commons — o status deles é o mesmo do restante do fangame (propriedade intelectual de terceiros usada sem fins lucrativos). Origem identificada, mas **sem licença explícita**.\n")
    w("- **Comunidade**: animações criadas por artistas do PMDCollab sob CC BY-NC 4.0 ou licenças PMDCollab, que exigem crédito e uso não-comercial.\n\n")
    w("### Licenças encontradas\n\n")
    for k, v in LICENSES.items():
        w("- `%s`: %s\n" % (k, v))
    w("\n### Modificações\n\n")
    w("- **Nenhum pixel foi alterado, redesenhado ou gerado por IA.** Os PNGs `*-Anim.png` e `*-Offsets.png`, o `AnimData.xml` e o `credits.txt` de cada pasta estão exatamente como no repositório de origem.\n")
    w("- Os arquivos `*-Shadow.png` não foram incluídos (a sombra é desenhada pelo jogo).\n")
    w("- Em tempo de execução o jogo apenas recorta frames da spritesheet, aplica escala, tintura de cor (status) e um flash branco ao levar dano. Isso não modifica os arquivos.\n\n")
    w("## Assets por Pokémon\n\n")
    for pid in roster:
        data = json.load(open(os.path.join(ROOT, "data", "pokemon", pid + ".json"), encoding="utf-8"))
        w("### %s (#%03d)\n\n" % (data["name"], data["dex"]))
        for fid, form in data["forms"].items():
            sprite = form.get("sprite") or data["forms"].get(form.get("inherits", ""), {}).get("sprite", "")
            portrait = form.get("portrait") or data["forms"].get(form.get("inherits", ""), {}).get("portrait", "")
            rel = sprite.replace("res://assets/pmd/", "")
            w("**Forma:** %s — status do asset: `%s`\n\n" % (form.get("name", fid), form.get("asset_status", "approved")))
            w("- Sprites: `assets/pmd/%s` ← %s/tree/master/%s\n\n" % (rel, REPO, rel))
            w(table(names, read_credits(os.path.join(ROOT, sprite.replace("res://", "")))) + "\n\n")
            if portrait:
                prel = os.path.dirname(portrait.replace("res://assets/pmd/", ""))
                w("- Retrato (apenas `Normal.png`): `assets/pmd/%s/Normal.png` ← %s/tree/master/%s\n\n" % (prel, REPO, prel))
                w(table(names, read_credits(os.path.join(ROOT, os.path.dirname(portrait.replace("res://", "")))), only={"Normal"}) + "\n\n")
    w("## Outros recursos\n\n")
    w("- **Arte das arenas** (grama, terra, pedras, árvores, muros, lago, arbustos), **efeitos visuais**, **ícone** e **sons**: gerados proceduralmente por código neste projeto (`arena/arena_art.gd`, `combat/*`, `audio/audio_manager.gd`). Nenhum asset externo.\n")
    w("- **Fonte**: fonte padrão embutida do Godot.\n")
    w("- **Motor**: Godot Engine 4 — MIT License — https://godotengine.org\n\n")
    w("## Pendências / verificação\n\n")
    w("- Nenhum asset com origem desconhecida foi integrado.\n")
    w("- Sprites oficiais (`Unspecified`) estão integrados por serem a base do projeto pedido (fangame com sprites do PMDCollab). Se for decidido usar apenas material com licença explícita, basta marcar a forma com `\"asset_status\": \"pending\"` no JSON do Pokémon (o jogo passa a usar o fallback) e substituir os arquivos.\n")
    w("- Mega Lucario usa sprites comunitários (CC BY-NC 4.0) e está disponível apenas com a opção experimental **Mega Evolução** ligada.\n")


if __name__ == "__main__":
    main()
