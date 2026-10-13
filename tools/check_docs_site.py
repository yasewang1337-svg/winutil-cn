"""Validate a built Hugo project site without requesting external URLs."""

import argparse
import json
import re
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import unquote, urljoin, urlsplit
import xml.etree.ElementTree as ET


class Page(HTMLParser):
    def __init__(self, source):
        super().__init__(convert_charrefs=True)
        self.references = []
        self.ids = set()
        self.canonicals = []
        self.language = None
        self.redirect = False
        self.feed(source)

    def handle_starttag(self, tag, attributes):
        attrs = dict(attributes)
        if attrs.get("id"):
            self.ids.add(attrs["id"])
        if tag == "a" and attrs.get("name"):
            self.ids.add(attrs["name"])
        if tag == "html":
            self.language = attrs.get("lang", "").lower()
        if tag == "meta" and attrs.get("http-equiv", "").lower() == "refresh":
            self.redirect = True
        if tag == "meta" and (attrs.get("property") or attrs.get("name")) in ("og:image", "twitter:image"):
            if attrs.get("content"):
                self.references.append((tag, "content", attrs["content"]))
        if tag == "link" and "canonical" in attrs.get("rel", "").split():
            self.canonicals.append(attrs.get("href", ""))
        for attribute in ("href", "src", "poster"):
            if attrs.get(attribute):
                self.references.append((tag, attribute, attrs[attribute]))
        if attrs.get("srcset") and not attrs["srcset"].startswith("data:"):
            for candidate in attrs["srcset"].split(","):
                if candidate.strip():
                    self.references.append((tag, "srcset", candidate.strip().split()[0]))


def check_site(site, base_url):
    site = Path(site).resolve()
    base_url = base_url.rstrip("/") + "/"
    base = urlsplit(base_url)
    if base.scheme != "https" or not base.netloc or base.query or base.fragment:
        raise ValueError("base-url must be an absolute HTTPS site URL")
    errors = []
    references_checked = 0
    pages = {}
    required = ("index.html", "userguide/index.html", "mcp/index.html")
    for name in required:
        if not (site / name).is_file():
            errors.append(f"Missing entry page: {name}")
    for path in sorted(site.rglob("*.html")):
        pages[path] = Page(path.read_text(encoding="utf-8"))
    if not pages:
        errors.append("No HTML pages were generated")

    def page_url(path):
        relative = path.relative_to(site).as_posix()
        if relative.endswith("index.html"):
            relative = relative[:-len("index.html")]
        return urljoin(base_url, relative)

    def resolve_reference(raw, origin, location, check_fragment=True):
        nonlocal references_checked
        parsed = urlsplit(urljoin(origin, raw))
        if parsed.hostname == "winutil.christitus.com":
            errors.append(f"Upstream documentation navigation: {location}: {raw}")
            return None
        if parsed.scheme not in ("http", "https") or parsed.netloc != base.netloc:
            return None
        references_checked += 1
        if parsed.scheme != base.scheme or not parsed.path.startswith(base.path):
            errors.append(f"URL escapes the project base path: {location}: {raw}")
            return None
        relative = unquote(parsed.path[len(base.path):])
        target = (site / relative).resolve()
        if not target.is_relative_to(site):
            errors.append(f"URL escapes the output directory: {location}: {raw}")
            return None
        if target.is_dir():
            target /= "index.html"
        if not target.is_file():
            errors.append(f"Missing local target: {location}: {raw}")
            return None
        fragment = unquote(parsed.fragment)
        # Chromium text fragments do not name HTML elements.
        fragment = fragment.split(":~:text=", 1)[0]
        if check_fragment and fragment and target in pages and fragment not in pages[target].ids:
            errors.append(f"Missing anchor: {location}: {raw}")
        return target

    canonical_urls = set()
    for path, page in pages.items():
        location = path.relative_to(site).as_posix()
        origin = page_url(path)
        if page.language not in ("zh", "zh-cn", "zh-hans"):
            # Hugo alias redirects have no html language or visible content.
            if not page.redirect:
                errors.append(f"Page is not marked as Chinese: {location}")
        if location != "404.html":
            if len(page.canonicals) != 1:
                errors.append(f"Expected one canonical URL: {location}")
            for canonical in page.canonicals:
                if not canonical.startswith(base_url):
                    errors.append(f"Canonical is not absolute under the base URL: {location}: {canonical}")
                if not page.redirect and canonical != origin:
                    errors.append(f"Canonical does not identify its own page: {location}: {canonical}")
                if resolve_reference(canonical, origin, location, False):
                    canonical_urls.add(canonical)
        for tag, attribute, value in page.references:
            resolve_reference(value, origin, f"{location} [{tag}.{attribute}]")

    css_references = 0
    for path in sorted(site.rglob("*.css")):
        origin = urljoin(base_url, path.relative_to(site).as_posix())
        for match in re.finditer(r"url\(\s*(['\"]?)(.*?)\1\s*\)", path.read_text(encoding="utf-8")):
            value = match.group(2).strip()
            if value and not value.startswith(("data:", "#")):
                css_references += 1
                resolve_reference(value, origin, path.relative_to(site).as_posix(), False)

    sitemap_urls = []
    try:
        sitemap = ET.parse(site / "sitemap.xml")
        sitemap_urls = [element.text or "" for element in sitemap.findall(".//{*}loc")]
        if not sitemap_urls:
            errors.append("Sitemap contains no URLs")
        for address in sitemap_urls:
            if not address.startswith(base_url):
                errors.append(f"Sitemap URL is outside the base URL: {address}")
            if address not in canonical_urls:
                errors.append(f"Sitemap URL has no generated canonical page: {address}")
            resolve_reference(address, base_url, "sitemap.xml", False)
        for name in required:
            address = page_url(site / name)
            if address not in sitemap_urls:
                errors.append(f"Entry page missing from sitemap: {address}")
        for path, page in pages.items():
            if path.name != "404.html" and not page.redirect and page_url(path) not in sitemap_urls:
                errors.append(f"Page missing from sitemap: {page_url(path)}")
    except (OSError, ET.ParseError) as exc:
        errors.append(f"Missing or invalid sitemap.xml: {exc}")

    robots = site / "robots.txt"
    if not robots.is_file():
        errors.append("Missing robots.txt")
    else:
        text = robots.read_text(encoding="utf-8")
        sitemap_lines = re.findall(r"^sitemap:\s*(\S+)", text, re.I | re.M)
        if base_url + "sitemap.xml" not in sitemap_lines:
            errors.append("robots.txt does not declare this site's sitemap")
        if re.search(r"^disallow:\s*/\s*$", text, re.I | re.M):
            errors.append("robots.txt blocks the whole site")
    if (site / "CNAME").exists():
        errors.append("Unexpected CNAME: the deployment uses the GitHub project URL")

    return {
        "BaseUrl": base_url,
        "HtmlPages": len(pages),
        "LocalReferencesChecked": references_checked,
        "CssReferencesChecked": css_references,
        "SitemapUrls": len(sitemap_urls),
        "Errors": sorted(set(errors)),
        "Passed": not errors,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--site", required=True, type=Path)
    parser.add_argument("--base-url", required=True)
    parser.add_argument("--report", type=Path)
    args = parser.parse_args()
    result = check_site(args.site, args.base_url)
    text = json.dumps(result, ensure_ascii=False, indent=2)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(text + "\n", encoding="utf-8")
    print(text)
    return 0 if result["Passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
