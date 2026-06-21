#!/usr/bin/env python3
"""
FRLG (ファイアレッド・リーフグリーン / 第3世代) 用マスタJSON生成スクリプト

PokeAPI のソースCSV (veekun data) から、アプリ同梱用のマスタを抽出する。
- 種族: 図鑑番号 / 日本語名 / 英語名 / タイプ / 覚える技(学習セット)
- 技:   日本語名 / 英語名 / タイプ / 分類(物理・特殊・変化 ※第3世代ルール=タイプ依存) / 威力 / 命中 / PP

出力: frlg_master.json
"""
import urllib.request
import csv
import io
import json
import sys

BASE = "https://raw.githubusercontent.com/PokeAPI/pokeapi/master/data/v2/csv/"
FRLG_VERSION_GROUP_ID = 7          # firered-leafgreen
# 対象種族: 第1〜2世代 (1..251) ＋ デオキシス(386)
INCLUDED_SPECIES = sorted(set(range(1, 252)) | {386})
INCLUDED_SET = set(INCLUDED_SPECIES)
OUT_PATH = "/mnt/user-data/outputs/frlg_master.json"

# 第3世代の物理/特殊はタイプで決まる
PHYSICAL_TYPES = {"normal", "fighting", "flying", "poison", "ground",
                  "rock", "bug", "ghost", "steel"}
SPECIAL_TYPES = {"fire", "water", "grass", "electric", "psychic",
                 "ice", "dragon", "dark"}


def fetch_csv(name):
    url = BASE + name
    req = urllib.request.Request(url, headers={"User-Agent": "frlg-tool"})
    raw = urllib.request.urlopen(req, timeout=120).read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(raw)))


def main():
    print("Downloading source CSVs ...")
    languages = fetch_csv("languages.csv")
    types = fetch_csv("types.csv")
    type_names = fetch_csv("type_names.csv")
    species = fetch_csv("pokemon_species.csv")
    species_names = fetch_csv("pokemon_species_names.csv")
    pokemon = fetch_csv("pokemon.csv")
    pokemon_types = fetch_csv("pokemon_types.csv")
    moves = fetch_csv("moves.csv")
    move_names = fetch_csv("move_names.csv")
    damage_classes = fetch_csv("move_damage_classes.csv")
    pokemon_moves = fetch_csv("pokemon_moves.csv")
    move_methods = fetch_csv("pokemon_move_methods.csv")
    version_groups = fetch_csv("version_groups.csv")
    types_past = fetch_csv("pokemon_types_past.csv")
    move_changelog = fetch_csv("move_changelog.csv")
    print("Done. Building ...")

    # 言語ID (日本語=ja-Hrkt 優先, 無ければ ja / 英語=en)
    lang_id = {l["identifier"]: int(l["id"]) for l in languages}
    JA = lang_id.get("ja-Hrkt") or lang_id.get("ja")
    EN = lang_id.get("en")

    # ダメージクラス id -> identifier (status / physical / special)
    dmg_class = {int(d["id"]): d["identifier"] for d in damage_classes}
    # わざ習得方法 id -> identifier (level-up / egg / tutor / machine ...)
    method_name = {int(m["id"]): m["identifier"] for m in move_methods}

    # タイプ id -> identifier
    type_ident = {int(t["id"]): t["identifier"] for t in types}
    type_ja, type_en = {}, {}
    for tn in type_names:
        tid = int(tn["type_id"])
        lid = int(tn["local_language_id"])
        if lid == JA:
            type_ja[tid] = tn["name"]
        elif lid == EN:
            type_en[tid] = tn["name"]

    # 種族名
    sp_ja, sp_en = {}, {}
    for n in species_names:
        sid = int(n["pokemon_species_id"])
        if sid not in INCLUDED_SET:
            continue
        lid = int(n["local_language_id"])
        if lid == JA:
            sp_ja[sid] = n["name"]
        elif lid == EN:
            sp_en[sid] = n["name"]

    # 種族 -> 既定フォームの pokemon_id (1..151 は species_id と一致)
    species_to_pokemon = {}
    for p in pokemon:
        sid = int(p["species_id"])
        if sid in INCLUDED_SET and p.get("is_default") == "1":
            species_to_pokemon[sid] = int(p["id"])

    # pokemon_id -> タイプ(スロット順)
    ptypes = {}
    for pt in pokemon_types:
        pid = int(pt["pokemon_id"])
        ptypes.setdefault(pid, []).append((int(pt["slot"]), int(pt["type_id"])))

    # === 第3世代へのロールバック準備 ===
    TARGET_GEN = 3
    vg_gen = {int(v["id"]): int(v["generation_id"]) for v in version_groups}

    # 過去タイプ pokemon_id -> {generation_id: [(slot, type_id)]}
    past_types = {}
    for r in types_past:
        pid = int(r["pokemon_id"]); g = int(r["generation_id"])
        past_types.setdefault(pid, {}).setdefault(g, []).append(
            (int(r["slot"]), int(r["type_id"])))

    def gen3_type_ids(pid):
        # 過去エントリのうち generation_id>=3 の最小を採用、無ければ現行
        if pid in past_types:
            gens = [g for g in past_types[pid] if g >= TARGET_GEN]
            if gens:
                g = min(gens)
                return [tid for _, tid in sorted(past_types[pid][g])]
        return [tid for _, tid in sorted(ptypes.get(pid, []))]

    # 技changelog move_id -> [(gen, vg, row)]。各rowは変更"前"の値を保持
    clog = {}
    for r in move_changelog:
        mid = int(r["move_id"]); vg = int(r["changed_in_version_group_id"])
        clog.setdefault(mid, []).append((vg_gen.get(vg, 99), vg, r))

    def gen3_move_field(mid, field, current):
        # 第3世代より後(>=gen4)の最も早い変更が記録する"変更前の値"＝第3世代の値
        cands = [(g, vg, r[field]) for g, vg, r in clog.get(mid, [])
                 if g >= TARGET_GEN + 1 and r[field] not in ("", None)]
        if cands:
            cands.sort()
            return cands[0][2]
        return current

    # 技マスタ(基礎情報)
    move_info = {}
    for m in moves:
        mid = int(m["id"])
        tid = int(gen3_move_field(mid, "type_id", m["type_id"]))
        tident = type_ident.get(tid, "")
        dc = dmg_class.get(int(m["damage_class_id"]), "")
        if dc == "status":
            category = "status"          # 変化
        elif tident in PHYSICAL_TYPES:
            category = "physical"        # 物理
        elif tident in SPECIAL_TYPES:
            category = "special"         # 特殊
        else:
            category = dc or "status"
        power = gen3_move_field(mid, "power", m["power"])
        acc = gen3_move_field(mid, "accuracy", m["accuracy"])
        pp = gen3_move_field(mid, "pp", m["pp"])
        move_info[mid] = {
            "identifier": m["identifier"],
            "type": tident,
            "category": category,
            "power": int(power) if power not in ("", None) else None,
            "accuracy": int(acc) if acc not in ("", None) else None,
            "pp": int(pp) if pp not in ("", None) else None,
        }

    move_ja, move_en = {}, {}
    for n in move_names:
        mid = int(n["move_id"])
        lid = int(n["local_language_id"])
        if lid == JA:
            move_ja[mid] = n["name"]
        elif lid == EN:
            move_en[mid] = n["name"]

    # 学習セット: FRLG(vg=7)を優先。FRLGに学習データが無い種族のみ、
    # 第3世代の他バージョン(emerald=6, ruby-sapphire=5)で補完する。
    valid_pokemon_ids = set(species_to_pokemon.values())
    learn = {pid: {} for pid in valid_pokemon_ids}

    def add_moves(target_vg, only_pids):
        touched = set()
        for pm in pokemon_moves:
            if int(pm["version_group_id"]) != target_vg:
                continue
            pid = int(pm["pokemon_id"])
            if pid not in only_pids:
                continue
            mid = int(pm["move_id"])
            method = method_name.get(int(pm["pokemon_move_method_id"]), "")
            level = int(pm["level"]) if pm["level"] not in ("", None) else 0
            entry = learn[pid].setdefault(mid, {"methods": set(), "level": None})
            entry["methods"].add(method)
            if method == "level-up" and level > 0:
                if entry["level"] is None or level < entry["level"]:
                    entry["level"] = level
            touched.add(pid)
        return touched

    has_frlg = add_moves(FRLG_VERSION_GROUP_ID, valid_pokemon_ids)
    need = valid_pokemon_ids - has_frlg
    fallback_used = set()
    for fb_vg in (6, 5):  # emerald, ruby-sapphire
        if not need:
            break
        got = add_moves(fb_vg, need)
        fallback_used |= got
        need -= got

    # 使われている技だけ MoveMaster に含める
    used_move_ids = set()
    for pid in valid_pokemon_ids:
        used_move_ids.update(learn[pid].keys())

    # ---- 出力構築 ----
    out_types = []
    seen_type = set()
    for sid in INCLUDED_SPECIES:
        pid = species_to_pokemon.get(sid)
        if not pid:
            continue
        for tid in gen3_type_ids(pid):
            if tid not in seen_type:
                seen_type.add(tid)
                out_types.append({
                    "id": type_ident.get(tid, ""),
                    "name_ja": type_ja.get(tid, ""),
                    "name_en": type_en.get(tid, ""),
                })

    out_species = []
    for sid in INCLUDED_SPECIES:
        pid = species_to_pokemon.get(sid)
        if not pid:
            continue
        tlist = [type_ident.get(tid, "") for tid in gen3_type_ids(pid)]
        ls = []
        for mid, info in learn[pid].items():
            ls.append({
                "move": move_info[mid]["identifier"],
                "methods": sorted(info["methods"]),
                "level": info["level"],
            })
        ls.sort(key=lambda x: x["move"])
        out_species.append({
            "dex": sid,
            "name_ja": sp_ja.get(sid, ""),
            "name_en": sp_en.get(sid, ""),
            "types": tlist,
            "learnset": ls,
        })

    out_moves = []
    for mid in sorted(used_move_ids):
        info = move_info[mid]
        out_moves.append({
            "id": info["identifier"],
            "name_ja": move_ja.get(mid, ""),
            "name_en": move_en.get(mid, ""),
            "type": info["type"],
            "category": info["category"],
            "power": info["power"],
            "accuracy": info["accuracy"],
            "pp": info["pp"],
        })

    result = {
        "meta": {
            "source": "PokeAPI (veekun data)",
            "version_group": "firered-leafgreen",
            "generation": 3,
            "species_scope": "第1〜2世代(全国図鑑1-251) + デオキシス(386)",
            "category_rule": "physical/special は第3世代ルール(タイプ依存)で判定",
            "learnset_rule": "FRLG優先。FRLG未収録の種族のみ emerald/ruby-sapphire で補完",
            "fallback_species_count": len(fallback_used),
            "caveat": "タイプ/威力/命中/PPは過去データ(pokemon_types_past, move_changelog)で第3世代相当に補正済み",
            "counts": {
                "types": len(out_types),
                "species": len(out_species),
                "moves": len(out_moves),
            },
        },
        "types": out_types,
        "species": out_species,
        "moves": out_moves,
    }

    with open(OUT_PATH, "w", encoding="utf-8") as f:
        json.dump(result, f, ensure_ascii=False, indent=2)

    print("counts:", result["meta"]["counts"])
    print("sample species:", json.dumps(out_species[0], ensure_ascii=False)[:300])
    print("sample move:", json.dumps(out_moves[0], ensure_ascii=False))
    print("wrote:", OUT_PATH)


if __name__ == "__main__":
    main()