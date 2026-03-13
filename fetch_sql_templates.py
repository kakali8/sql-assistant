#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
从 Metabase 指定看板拉取每个 card 的 SQL 查询，保存为 SQL 模板文件。
参考: /Users/lee/PycharmProjects/daily_report/src/fetch_data.py
"""

import json
import os
import time
import sys
from pathlib import Path
from typing import Optional, Dict, List

import requests
from requests.exceptions import ConnectionError, HTTPError, ReadTimeout, RequestException

BASE_URL = os.environ.get("METABASE_URL", "https://meta.lobah.net")
USERNAME = os.environ.get("METABASE_USER", "lijie@mozat.com")
PASSWORD = os.environ.get("METABASE_PASSWORD", "Mozat@2026")

DASHBOARD_IDS = [518, 522]

OUTPUT_DIR = Path(__file__).resolve().parent / "sql_templates"


def safe_metric_id(name: str) -> str:
    return (
        str(name).strip()
        .lower()
        .replace(" ", "_")
        .replace("-", "_")
        .replace("/", "_")
    )


def get_with_retry(
    session: requests.Session,
    url: str,
    timeout: int = 30,
    max_retries: int = 3,
    backoff_base: float = 1.5,
) -> Optional[requests.Response]:
    for attempt in range(max_retries + 1):
        try:
            resp = session.get(url, timeout=timeout)
            resp.raise_for_status()
            return resp
        except (ReadTimeout, ConnectionError) as e:
            if attempt >= max_retries:
                print(f"❌ FAIL url={url} after {attempt + 1} attempts: {type(e).__name__}")
                return None
            sleep_s = backoff_base ** attempt
            print(f"⏳ RETRY {attempt + 1}/{max_retries} sleep={sleep_s:.1f}s")
            time.sleep(sleep_s)
        except HTTPError as e:
            status = getattr(e.response, "status_code", None)
            if status and 500 <= status < 600 and attempt < max_retries:
                sleep_s = backoff_base ** attempt
                print(f"⏳ RETRY {attempt + 1}/{max_retries} (server {status}) sleep={sleep_s:.1f}s")
                time.sleep(sleep_s)
                continue
            print(f"❌ HTTP ERROR url={url} status={status}")
            return None
        except RequestException as e:
            print(f"❌ REQUEST ERROR url={url}: {e}")
            return None


def get_dashboard_cards(session: requests.Session, dashboard_id: int) -> List[Dict]:
    resp = get_with_retry(session, f"{BASE_URL}/api/dashboard/{dashboard_id}")
    if not resp:
        return []

    detail = resp.json()
    dashboard_name = str(detail.get("name") or f"dashboard_{dashboard_id}")

    dashcards = detail.get("dashcards", []) or []
    cards = []
    for dc in dashcards:
        card = dc.get("card") or {}
        card_id = dc.get("card_id")
        card_name = card.get("name")
        if not card_id or not card_name:
            continue
        cards.append({
            "card_id": card_id,
            "card_name": card_name,
            "dashboard_id": dashboard_id,
            "dashboard_name": dashboard_name,
        })

    print(f"✅ Dashboard {dashboard_id} ({dashboard_name}): {len(cards)} cards")
    return cards


def get_card_sql(session: requests.Session, card_id: int) -> Optional[Dict]:
    """获取单个 card 的详细信息，包括 SQL 查询"""
    resp = get_with_retry(session, f"{BASE_URL}/api/card/{card_id}")
    if not resp:
        return None

    card_detail = resp.json()
    dataset_query = card_detail.get("dataset_query", {})
    query_type = dataset_query.get("type")

    result = {
        "card_id": card_id,
        "name": card_detail.get("name"),
        "description": card_detail.get("description"),
        "query_type": query_type,
        "database_id": dataset_query.get("database"),
        "sql": None,
        "template_tags": None,
    }

    if query_type == "native":
        native = dataset_query.get("native", {})
        result["sql"] = native.get("query")
        result["template_tags"] = native.get("template-tags")
    elif query_type == "query":
        # 非 SQL 查询（GUI 构建的查询），保存原始结构
        result["structured_query"] = dataset_query.get("query")

    return result


def main():
    print(f"🐍 Python: {sys.version.split()[0]}")

    session = requests.Session()

    # Login
    login_resp = session.post(
        f"{BASE_URL}/api/session",
        json={"username": USERNAME, "password": PASSWORD},
        timeout=20,
    )
    login_resp.raise_for_status()
    print("✅ Login OK")

    # 创建输出目录
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    all_cards = []
    for dashboard_id in DASHBOARD_IDS:
        print(f"\n{'=' * 60}")
        print(f"📋 Dashboard {dashboard_id}")
        print('=' * 60)
        cards = get_dashboard_cards(session, dashboard_id)
        all_cards.extend(cards)

    print(f"\n📊 Total cards to fetch: {len(all_cards)}")

    results = []
    failed = []

    for c in all_cards:
        card_id = c["card_id"]
        card_name = c["card_name"]
        metric_id = safe_metric_id(card_name)

        card_info = get_card_sql(session, card_id)
        if not card_info:
            print(f"  ❌ Failed: card={card_id} ({card_name})")
            failed.append(c)
            continue

        sql = card_info.get("sql")
        query_type = card_info.get("query_type")

        if sql:
            # 保存 SQL 文件
            sql_path = OUTPUT_DIR / f"{metric_id}.sql"
            with open(sql_path, "w", encoding="utf-8") as f:
                f.write(f"-- metric_id: {metric_id}\n")
                f.write(f"-- card_name: {card_name}\n")
                f.write(f"-- card_id: {card_id}\n")
                f.write(f"-- dashboard: {c['dashboard_name']} (id={c['dashboard_id']})\n")
                if card_info.get("description"):
                    f.write(f"-- description: {card_info['description']}\n")
                f.write(f"-- query_type: {query_type}\n")
                f.write(f"\n{sql}\n")

            print(f"  ✅ {metric_id} (card={card_id}): SQL saved ({len(sql)} chars)")
        else:
            print(f"  ⚠️  {metric_id} (card={card_id}): query_type={query_type}, no native SQL")

        results.append({
            "card_id": card_id,
            "card_name": card_name,
            "metric_id": metric_id,
            "dashboard_id": c["dashboard_id"],
            "dashboard_name": c["dashboard_name"],
            "description": card_info.get("description"),
            "query_type": query_type,
            "has_sql": bool(sql),
            "sql_length": len(sql) if sql else 0,
        })

    # 保存汇总 JSON
    summary_path = OUTPUT_DIR / "_summary.json"
    with open(summary_path, "w", encoding="utf-8") as f:
        json.dump({
            "total_cards": len(results),
            "has_sql": sum(1 for r in results if r["has_sql"]),
            "no_sql": sum(1 for r in results if not r["has_sql"]),
            "failed": len(failed),
            "cards": results,
        }, f, ensure_ascii=False, indent=2)

    print(f"\n{'=' * 60}")
    print(f"📊 Summary:")
    print(f"  Total: {len(results)}")
    print(f"  Has SQL: {sum(1 for r in results if r['has_sql'])}")
    print(f"  No SQL (GUI query): {sum(1 for r in results if not r['has_sql'])}")
    print(f"  Failed: {len(failed)}")
    print(f"\n✅ Output: {OUTPUT_DIR}")
    print(f"✅ Summary: {summary_path}")


if __name__ == "__main__":
    main()
