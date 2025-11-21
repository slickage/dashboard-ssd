#!/usr/bin/env python3
# Run instructions:
#   python3 -m venv .venv && source .venv/bin/activate
#   pip install requests beautifulsoup4 markdownify
#   python scripts/fireflies_scrape.py
# Output is written to docs/fireflies/ (markdown pages + index.json)
"""
Fireflies docs crawler (GraphQL API + Schema)

Purpose
- Crawl the Fireflies docs (Mintlify site) to extract all pages under
  the "GraphQL API" and "Schema" sections.
- Save each page as Markdown-ish content with fenced code blocks.
- Generate a manifest (index.json) describing the pages and any
  deprecation markers found.

Output layout
- docs/fireflies/index.json
- docs/fireflies/graphql-api/<mirrored path>.md
- docs/fireflies/schema/<mirrored path>.md

Notes
- This script is intended to be run locally where network is available.
- It makes polite requests and includes a small delay between requests.
- It does not attempt to render dynamic content; it parses the delivered HTML.

Usage
  python scripts/fireflies_scrape.py 

Requirements
  pip install requests beautifulsoup4
"""

from __future__ import annotations

import json
import os
import re
import time
from typing import List, Tuple
from urllib.parse import urljoin

import requests
from bs4 import BeautifulSoup, NavigableString
try:
    from markdownify import markdownify as md_convert
except Exception:  # pragma: no cover
    md_convert = None


BASE = "https://docs.fireflies.ai"
# Any page in the docs that includes the full sidebar will work as a seed
START = "/graphql-api/query/transcripts"

# Sections we care about: (url-prefix, output-subdir)
SECTIONS: List[Tuple[str, str]] = [
    ("/graphql-api/", "graphql-api"),
    ("/schema/", "schema"),
]

OUT_ROOT = os.path.join("docs", "fireflies")
# Additional clean output (reduced HTML scaffolding, just main content)
OUT_CLEAN_ROOT = os.path.join("docs", "fireflies_clean")
OUT_MD_ROOT = os.path.join("docs", "fireflies_md")
HEADERS = {"User-Agent": "fireflies-docs-scraper/1.0"}
DELAY_SECONDS = 0.35


def http_get(url: str) -> str:
    resp = requests.get(url, headers=HEADERS, timeout=20)
    resp.raise_for_status()
    return resp.text


def extract_links(html: str) -> List[str]:
    soup = BeautifulSoup(html, "html.parser")
    anchors: List[str] = []
    aside = soup.find("aside")
    scope = aside if aside else soup
    for prefix, _section in SECTIONS:
        for a in scope.select(f'a[href^="{prefix}"]'):
            href = a.get("href")
            if href and href.startswith(prefix):
                anchors.append(href)
    # Keep unique and sorted
    return sorted(set(anchors))


def extract_title(soup: BeautifulSoup) -> str:
    main = soup.find("main")
    if main:
        h1 = main.find(["h1"])
        if h1 and h1.get_text(strip=True):
            return h1.get_text(strip=True)
    title = soup.find("title")
    return (title.get_text(strip=True) if title else "").strip()


def reconstruct_code_blocks(container: BeautifulSoup) -> None:
    # Convert Mintlify-highlighted code (<pre><code><span class="line">...</span>...) to fenced Markdown
    for pre in container.find_all("pre"):
        code = pre.find("code")
        if not code:
            # Fallback: capture text within <pre>
            text = pre.get_text("\n")
            pre.replace_with(NavigableString(f"\n```\n{text.strip()}\n```\n"))
            continue

        # Mintlify often splits lines into spans; join them
        lines = code.select(".line")
        if lines:
            text = "\n".join(line.get_text() for line in lines)
        else:
            text = code.get_text("\n")

        # Try to infer language from class names like language-graphql
        lang = ""
        for c in code.get("class", []):
            if c.startswith("language-"):
                lang = c.split("-", 1)[1]
                break

        pre.replace_with(NavigableString(f"\n```{lang}\n{text.strip()}\n```\n"))


def extract_content(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    main = soup.find("main") or soup

    # Remove non-content elements
    for tag in main.find_all(["aside", "nav", "header", "footer"]):
        tag.decompose()

    reconstruct_code_blocks(main)

    # Keep HTML for structure; fenced code blocks are already plain text
    # If you prefer pure Markdown conversion, integrate a HTML→MD library here.
    return str(main)


def find_best_content_container(soup: BeautifulSoup) -> BeautifulSoup:
    """Heuristically find the central content container.

    Searches within <main> for article/section/divs and scores by number of
    headings and pre/code blocks and text length to pick the best content node.
    Fallback to <main> if nothing better is found.
    """
    main = soup.find("main") or soup
    candidates = main.find_all(["article", "section", "div"], recursive=True)
    best = main
    best_score = -1
    for el in candidates:
        # Skip obvious layout containers
        el_id = (el.get("id") or "").lower()
        if el.name == "div" and el_id in {"navbar", "sidebar", "sidebar-content"}:
            continue
        text_len = len(el.get_text(" "))
        headings = len(el.find_all(["h1", "h2", "h3", "h4"]))
        codeblocks = len(el.find_all(["pre", "code"]))
        score = headings * 5 + codeblocks * 3 + min(text_len // 800, 5)
        if score > best_score:
            best_score = score
            best = el
    return best


def extract_content_clean(html: str) -> str:
    soup = BeautifulSoup(html, "html.parser")
    content = find_best_content_container(soup)

    # Remove non-content elements
    for tag in content.find_all(["script", "style", "link", "header", "footer", "nav", "aside", "noscript", "iframe"]):
        tag.decompose()

    reconstruct_code_blocks(content)

    # Return inner HTML of the selected content node without outer <html>/<head>
    return "".join(str(child) for child in content.children)


def extract_deprecations(soup: BeautifulSoup) -> List[str]:
    # Heuristic: capture argument names near "This field is deprecated"
    text = soup.get_text(" \n").lower()
    deprecated = set()
    # Simple catch-all; callers can refine later using schema-typed pages
    for m in re.finditer(r"(\b[a-z_][a-z0-9_]*\b).*?this field is deprecated", text):
        deprecated.add(m.group(1))
    return sorted(deprecated)


def ensure_dir(path: str) -> None:
    os.makedirs(path, exist_ok=True)


def save_page(
    section_key: str,
    rel_path: str,
    title: str,
    url: str,
    content_html: str,
    deprecations: List[str],
    manifest: List[dict],
) -> None:
    out_dir = os.path.join(OUT_ROOT, section_key, os.path.dirname(rel_path).lstrip("/"))
    ensure_dir(out_dir)
    out_file = os.path.join(OUT_ROOT, section_key, rel_path.lstrip("/")) + ".md"
    ensure_dir(os.path.dirname(out_file))

    with open(out_file, "w", encoding="utf-8") as f:
        f.write(f"# {title}\n\n")
        f.write(f"_Source_: {url}\n\n")
        f.write(content_html)

    manifest.append(
        {
            "title": title,
            "url": url,
            "section": section_key,
            "slug": rel_path,
            "deprecated": deprecations,
        }
    )


def save_page_clean(
    section_key: str,
    rel_path: str,
    title: str,
    url: str,
    content_html: str,
) -> None:
    out_dir = os.path.join(OUT_CLEAN_ROOT, section_key, os.path.dirname(rel_path).lstrip("/"))
    ensure_dir(out_dir)
    out_file = os.path.join(OUT_CLEAN_ROOT, section_key, rel_path.lstrip("/")) + ".md"
    ensure_dir(os.path.dirname(out_file))

    with open(out_file, "w", encoding="utf-8") as f:
        f.write(f"# {title}\n\n")
        f.write(f"_Source_: {url}\n\n")
        f.write(content_html)


def html_to_markdown(html: str) -> str:
    """Convert HTML to Markdown using markdownify if available.

    If markdownify is not installed, return the original HTML as a fallback.
    """
    if md_convert is None:
        return html
    md = md_convert(
        html,
        heading_style="ATX",
        bullets="-",
        strip=None,
        convert_img=True,
        escape_asterisks=False,
    )
    return md.strip()


def save_page_markdown(
    section_key: str,
    rel_path: str,
    title: str,
    url: str,
    content_html: str,
) -> None:
    out_dir = os.path.join(OUT_MD_ROOT, section_key, os.path.dirname(rel_path).lstrip("/"))
    ensure_dir(out_dir)
    out_file = os.path.join(OUT_MD_ROOT, section_key, rel_path.lstrip("/")) + ".md"
    ensure_dir(os.path.dirname(out_file))

    md_body = html_to_markdown(content_html)
    with open(out_file, "w", encoding="utf-8") as f:
        f.write(f"# {title}\n\n")
        f.write(f"_Source_: {url}\n\n")
        f.write(md_body)


def run() -> None:
    start_url = urljoin(BASE, START)
    html = http_get(start_url)
    links = extract_links(html)
    if START not in links:
        links.append(START)

    manifest: List[dict] = []
    seen = set()

    for rel in links:
        if rel in seen:
            continue
        seen.add(rel)

        url = urljoin(BASE, rel)
        time.sleep(DELAY_SECONDS)
        page = http_get(url)
        soup = BeautifulSoup(page, "html.parser")
        title = extract_title(soup) or rel.strip("/") or "index"
        content_html = extract_content(page)
        content_clean = extract_content_clean(page)
        deprecations = extract_deprecations(soup)

        matched_prefix = None
        section_key = None
        for prefix, name in SECTIONS:
            if rel.startswith(prefix):
                matched_prefix = prefix
                section_key = name
                break
        if not section_key or not matched_prefix:
            continue

        rel_path = rel[len(matched_prefix) :].rstrip("/")
        if not rel_path:
            rel_path = "index"

        save_page(section_key, rel_path, title, url, content_html, deprecations, manifest)
        save_page_clean(section_key, rel_path, title, url, content_clean)
        save_page_markdown(section_key, rel_path, title, url, content_clean)

    ensure_dir(OUT_ROOT)
    with open(os.path.join(OUT_ROOT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    ensure_dir(OUT_CLEAN_ROOT)
    with open(os.path.join(OUT_CLEAN_ROOT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)
    ensure_dir(OUT_MD_ROOT)
    with open(os.path.join(OUT_MD_ROOT, "index.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    run()
