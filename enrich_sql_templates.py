#!/usr/bin/env python3
"""
Enrich SQL template files with metadata from:
  1. metrics_schema_v1.yaml  — metric definitions
  2. Lobah_DI_final.txt      — event tracking definitions (pipe-separated)

For each .sql file in sql_templates/:
  - Match metric_id to YAML schema
  - Extract referenced tables and event_names from SQL
  - Look up event field definitions from tracking doc
  - Rewrite file with enriched header + original SQL body
"""

import os
import re
import yaml
import glob as glob_mod


# ── paths ────────────────────────────────────────────────────────────────
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
YAML_PATH = os.path.join(_SCRIPT_DIR, "config", "metrics_schema_v1.yaml")
TRACKING_DOC_PATH = os.path.join(_SCRIPT_DIR, "config", "Lobah_DI_final.txt")
SQL_DIR = os.path.join(_SCRIPT_DIR, "sql_templates")


# ── 1. Load metric definitions from YAML ─────────────────────────────────
def load_metrics_schema(path: str) -> dict:
    """Return {metric_id: metric_dict}"""
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)
    metrics = {}
    for m in data.get("metrics", []):
        mid = m.get("metric_id")
        if mid:
            metrics[mid] = m
    return metrics


# ── 2. Load event definitions from tracking doc ─────────────────────────
def load_event_definitions(path: str) -> dict:
    """
    Parse pipe-separated rows.  Each data row looks like:
      Id | Name | Description | Properties | 补充说明 | ...
    Section headers (no numeric Id) are skipped.
    Returns {event_name: {id, name, description, properties, notes}}
    """
    events = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) < 5:
                continue
            raw_id = parts[0]
            # Skip header / section rows (non-numeric Id)
            if not raw_id.isdigit():
                continue
            event_name = parts[1].strip()
            if not event_name:
                continue
            description = parts[2].strip() if len(parts) > 2 else ""
            properties = parts[3].strip() if len(parts) > 3 else ""
            notes = parts[4].strip() if len(parts) > 4 else ""
            events[event_name] = {
                "id": raw_id,
                "name": event_name,
                "description": description,
                "properties": properties,
                "notes": notes,
            }
    return events


# ── 3. Parse existing SQL header fields ──────────────────────────────────
def parse_sql_header(sql_text: str) -> tuple[dict, str]:
    """
    Extract header comment fields (-- key: value) and return
    (header_dict, sql_body_without_old_header).

    Handles re-runs: if '-- [SQL]' marker is found, everything before it
    (inclusive) is treated as header and the body starts after it.
    """
    lines = sql_text.split("\n")
    header = {}

    # Check for [SQL] marker (from a previous enrichment run)
    sql_marker_idx = None
    for i, line in enumerate(lines):
        if line.strip() == "-- [SQL]":
            sql_marker_idx = i
            # Use the LAST occurrence in case of duplicates
    # Re-scan for last occurrence
    for i in range(len(lines) - 1, -1, -1):
        if lines[i].strip() == "-- [SQL]":
            sql_marker_idx = i
            break

    if sql_marker_idx is not None:
        # Parse key-value pairs from the header portion
        for line in lines[:sql_marker_idx]:
            stripped = line.strip()
            m = re.match(r"^--\s*(\w[\w()]*(?:\s*\w[\w()]*)*)\s*:\s*(.+)$", stripped)
            if m:
                key = m.group(1).strip().lower()
                val = m.group(2).strip()
                # Only keep original header fields (not enrichment-added ones
                # like source_tables, events_used, etc.)
                if key in ("metric_id", "card_name", "card_id", "dashboard",
                           "query_type"):
                    header[key] = val
        body_start = sql_marker_idx + 1
    else:
        # First-time enrichment: parse traditional header
        body_start = 0
        for i, line in enumerate(lines):
            stripped = line.strip()
            m = re.match(r"^--\s*(\w[\w()]*(?:\s*\w[\w()]*)*)\s*:\s*(.+)$", stripped)
            if m:
                key = m.group(1).strip().lower()
                val = m.group(2).strip()
                header[key] = val
                body_start = i + 1
            elif stripped == "--" or stripped == "":
                body_start = i + 1
            else:
                break

    # Trim leading blank lines from body
    while body_start < len(lines) and lines[body_start].strip() == "":
        body_start += 1

    body = "\n".join(lines[body_start:])
    return header, body


# ── 4. Extract referenced tables from SQL ────────────────────────────────
def extract_tables(sql_body: str) -> list[str]:
    """Find schema.table references like new_loops_activity.hab_app_events"""
    # Match schema.table patterns (word.word), but exclude aliases like t1.col
    pattern = r"\b([a-zA-Z_]\w+\.[a-zA-Z_]\w+)\b"
    candidates = set(re.findall(pattern, sql_body))

    # Filter: keep only plausible table references (schema-like prefixes)
    known_schemas = {
        "new_loops_activity",
        "rings_broadcast",
        "loops_billing",
        "rings_activity",
        "new_loops_broadcast",
    }
    tables = set()
    for c in candidates:
        schema, table = c.split(".", 1)
        if schema.lower() in known_schemas:
            tables.add(c)
    return sorted(tables)


# ── 5. Extract event_names from SQL ──────────────────────────────────────
def extract_event_names(sql_body: str) -> list[str]:
    """Find event_name = 'xxx' or event_name IN ('a','b',...)"""
    names = set()
    # Single equality
    for m in re.finditer(r"event_name\s*=\s*'([^']+)'", sql_body, re.IGNORECASE):
        names.add(m.group(1))
    # IN list
    for m in re.finditer(
        r"event_name\s+IN\s*\(([^)]+)\)", sql_body, re.IGNORECASE
    ):
        for item in re.findall(r"'([^']+)'", m.group(1)):
            names.add(item)
    return sorted(names)


# ── 6. Build key-field summary for an event ──────────────────────────────
def build_event_field_summary(event_info: dict) -> list[str]:
    """
    From the tracking-doc notes column, extract meaningful field->value mappings.
    Returns a list of lines like:
      status: 1=展示, 2=点击
      number: 1=in-app, 2=out-app
    """
    notes = event_info.get("notes", "")
    if not notes:
        return []

    # Fields we care about extracting value mappings for
    field_names = [
        "status_game", "status_user", "status",
        "type", "number", "bind", "panel",
        "second_diff", "amount", "content",
        "room_type", "gender", "other_gender",
    ]

    # Strategy: split the notes text at field-name boundaries, then extract
    # numbered value definitions from each block.
    # Build a regex that matches any field name as a boundary
    field_pattern = "|".join(re.escape(f) for f in field_names)

    # Find all field occurrences with their positions
    field_positions = []
    for m in re.finditer(
        rf"\b({field_pattern})\s*[:：<（(]",
        notes,
        re.IGNORECASE
    ):
        field_positions.append((m.start(), m.group(1).lower().strip()))

    # Also try without colon -- some fields are just "number 1: ..."
    for m in re.finditer(
        rf"\b({field_pattern})\s+(\d+)\s*[:：]",
        notes,
        re.IGNORECASE
    ):
        fname = m.group(1).lower().strip()
        if not any(fp[1] == fname and abs(fp[0] - m.start()) < 5 for fp in field_positions):
            field_positions.append((m.start(), fname))

    field_positions.sort(key=lambda x: x[0])

    lines = []
    processed = set()

    for idx, (pos, fname) in enumerate(field_positions):
        if fname in processed:
            continue
        # Determine the text block for this field
        end_pos = field_positions[idx + 1][0] if idx + 1 < len(field_positions) else len(notes)
        block = notes[pos:end_pos]

        # Extract number: description pairs
        pairs = re.findall(
            r"(\d+)\s*[:：-]\s*(.+?)(?=\s+\d+\s*[:：-]|\s*$)",
            block
        )
        if pairs:
            seen_nums = set()
            pair_strs = []
            for num, desc in pairs:
                if num not in seen_nums:
                    seen_nums.add(num)
                    # Clean description
                    desc_clean = desc.strip().rstrip(",;，；）) ")
                    # Remove trailing field-name-like tokens
                    desc_clean = re.split(r"\s+(?:" + field_pattern + r")\s*$", desc_clean, flags=re.IGNORECASE)[0].strip()
                    # Truncate very long descriptions
                    if len(desc_clean) > 60:
                        desc_clean = desc_clean[:57] + "..."
                    if desc_clean:
                        pair_strs.append(f"{num}={desc_clean}")
            if pair_strs:
                lines.append(f"{fname}: {', '.join(pair_strs)}")
                processed.add(fname)

    return lines


# ── 7. Build enriched header ─────────────────────────────────────────────
def build_enriched_header(
    old_header: dict,
    metric_schema: dict | None,
    tables: list[str],
    event_names: list[str],
    event_defs: dict,
) -> str:
    """Compose the full enriched comment header."""

    # Merge: prefer schema values, fall back to old header
    def get(schema_key, header_key=None, default=""):
        if header_key is None:
            header_key = schema_key
        if metric_schema and schema_key in metric_schema:
            val = metric_schema[schema_key]
            if isinstance(val, list):
                return ", ".join(str(v) for v in val)
            return str(val) if val is not None else default
        return old_header.get(header_key, default)

    metric_id = get("metric_id")
    metric_name = get("metric_name")
    card_name = old_header.get("card_name", "")
    card_id = old_header.get("card_id", "")
    dashboard = old_header.get("dashboard", "")
    business_domain = get("business_domain")
    owner = get("owner")
    definition = get("definition")
    description = get("description")

    # evaluation method
    evaluation = ""
    if metric_schema and "evaluation" in metric_schema:
        ev = metric_schema["evaluation"]
        if isinstance(ev, dict):
            evaluation = ev.get("method", "")
        else:
            evaluation = str(ev)

    # related_metrics
    related = ""
    if metric_schema and "related_metrics" in metric_schema:
        rm = metric_schema["related_metrics"]
        if isinstance(rm, list):
            related = ", ".join(str(r) for r in rm)
        elif rm:
            related = str(rm)

    lines = []
    lines.append(f"-- metric_id: {metric_id}")
    lines.append(f"-- metric_name: {metric_name}")
    lines.append(f"-- card_name: {card_name}")
    lines.append(f"-- card_id: {card_id}")
    lines.append(f"-- dashboard: {dashboard}")
    lines.append(f"-- business_domain: {business_domain}")
    lines.append(f"-- owner: {owner}")
    lines.append(f"-- definition: {definition}")
    if description and description != definition:
        lines.append(f"-- description: {description}")
    lines.append(f"-- evaluation: {evaluation}")
    lines.append(f"-- related_metrics: {related}")
    lines.append(f"-- source_tables: {', '.join(tables)}")
    lines.append(f"-- events_used: {', '.join(event_names)}")

    # Key fields section
    event_field_blocks = []
    for ename in event_names:
        if ename in event_defs:
            einfo = event_defs[ename]
            field_lines = build_event_field_summary(einfo)
            block = [f"-- event: {ename}"]
            if einfo.get("description"):
                block.append(f"--   desc: {einfo['description']}")
            for fl in field_lines:
                block.append(f"--   {fl}")
            # If no fields extracted but there are notes, include a condensed note
            if not field_lines and einfo.get("notes"):
                # Truncate long notes
                note_text = einfo["notes"][:200]
                block.append(f"--   raw_notes: {note_text}")
            event_field_blocks.append("\n".join(block))

    if event_field_blocks:
        lines.append("--")
        lines.append("-- [KEY FIELDS]")
        for block in event_field_blocks:
            lines.append(block)

    lines.append("--")
    lines.append("-- [SQL]")
    return "\n".join(lines)


# ── 8. Main ──────────────────────────────────────────────────────────────
def main():
    print("Loading metrics schema...")
    metrics = load_metrics_schema(YAML_PATH)
    print(f"  Loaded {len(metrics)} metric definitions")

    print("Loading event tracking doc...")
    events = load_event_definitions(TRACKING_DOC_PATH)
    print(f"  Loaded {len(events)} event definitions")

    sql_files = sorted(glob_mod.glob(os.path.join(SQL_DIR, "*.sql")))
    print(f"Found {len(sql_files)} SQL templates\n")

    stats = {
        "total": len(sql_files),
        "matched_schema": 0,
        "with_events": 0,
        "enriched": 0,
        "no_metric_match": [],
    }

    for fpath in sql_files:
        fname = os.path.basename(fpath)
        print(f"Processing: {fname}")

        with open(fpath, "r", encoding="utf-8") as f:
            sql_text = f.read()

        old_header, sql_body = parse_sql_header(sql_text)
        metric_id = old_header.get("metric_id", "")

        # Match to schema
        schema_entry = metrics.get(metric_id)
        if schema_entry:
            stats["matched_schema"] += 1
            print(f"  ✓ Schema match: {metric_id}")
        else:
            stats["no_metric_match"].append(metric_id or fname)
            print(f"  ✗ No schema match for: {metric_id or '(no metric_id)'}")

        # Extract tables and events from the full SQL (including commented-out code
        # is fine, but we focus on the active body)
        tables = extract_tables(sql_body)
        event_names = extract_event_names(sql_body)

        if event_names:
            stats["with_events"] += 1
            matched_events = [e for e in event_names if e in events]
            print(f"  Tables: {tables}")
            print(f"  Events: {event_names} (matched defs: {len(matched_events)}/{len(event_names)})")
        else:
            print(f"  Tables: {tables}")
            print(f"  Events: (none)")

        # Build enriched header
        enriched_header = build_enriched_header(
            old_header, schema_entry, tables, event_names, events
        )

        # Write back
        new_content = enriched_header + "\n" + sql_body
        # Ensure file ends with newline
        if not new_content.endswith("\n"):
            new_content += "\n"

        with open(fpath, "w", encoding="utf-8") as f:
            f.write(new_content)

        stats["enriched"] += 1

    # Summary
    print("\n" + "=" * 60)
    print("SUMMARY")
    print("=" * 60)
    print(f"Total SQL files:          {stats['total']}")
    print(f"Enriched:                 {stats['enriched']}")
    print(f"Schema matched:           {stats['matched_schema']}")
    print(f"With event references:    {stats['with_events']}")
    if stats["no_metric_match"]:
        print(f"\nNo schema match ({len(stats['no_metric_match'])}):")
        for mid in stats["no_metric_match"]:
            print(f"  - {mid}")
    print("\nDone.")


if __name__ == "__main__":
    main()
