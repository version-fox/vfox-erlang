"""Build the bilingual documentation site using Python's standard library."""
import argparse
import html
import json
from pathlib import Path
import re
import shutil
from urllib.parse import urlsplit, urlunsplit

ROOT = Path(__file__).resolve().parent
TOKEN = re.compile(r"\{\{([a-z0-9_]+)\}\}")


def build(destination, base_url=None):
    config = json.loads((ROOT / "site.json").read_text(encoding="utf-8"))
    default_url = config.pop("site_url")
    base_url = (base_url or default_url).rstrip("/")
    parts = urlsplit(base_url)
    if parts.scheme not in {"http", "https"} or not parts.netloc or parts.query or parts.fragment:
        raise ValueError("base URL must be an HTTP(S) URL without query or fragment")
    base_url = urlunsplit(parts._replace(scheme="https"))
    metadata = (ROOT.parent / "metadata.lua").read_text(encoding="utf-8")
    version = re.search(r'PLUGIN.version = "([0-9.]+)"', metadata).group(1)
    minimum = re.search(r'PLUGIN.minRuntimeVersion = "([0-9.]+)"', metadata).group(1)
    template = (ROOT / "template.html").read_text(encoding="utf-8")
    keys = set(TOKEN.findall(template))
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copytree(ROOT / "assets", destination / "assets", dirs_exist_ok=True)
    locale_keys = []
    for locale, route, lang in [("zh", "", "zh-CN"), ("en", "en/", "en")]:
        messages = json.loads((ROOT / "locales" / f"{locale}.json").read_text(encoding="utf-8"))
        locale_keys.append(set(messages))
        messages = {key: value.format(min_version=minimum) for key, value in messages.items()}
        copy_data = json.dumps({key: messages[key] for key in ("copy", "copied", "copy_error")}, ensure_ascii=False)
        messages.pop("copied")
        messages.pop("copy_error")
        messages.update(config, lang=lang, version=version, copy_data=copy_data,
                        asset_prefix="../" if route else "", language_href="../" if route else "en/",
                        language_lang="zh-CN" if route else "en", canonical=base_url + "/" + route,
                        site_url=base_url)
        if set(messages) != keys:
            raise ValueError(f"{locale}: missing {keys - set(messages)}, unused {set(messages) - keys}")
        rendered = TOKEN.sub(lambda m: html.escape(messages[m[1]], quote=True), template)
        output = destination / route
        output.mkdir(parents=True, exist_ok=True)
        (output / "index.html").write_text(rendered, encoding="utf-8")
    if locale_keys[0] != locale_keys[1]:
        raise ValueError("Chinese and English translation keys differ")
    (destination / ".nojekyll").touch()
    (destination / "robots.txt").write_text(f"User-agent: *\nAllow: /\nSitemap: {base_url}/sitemap.xml\n", encoding="utf-8")
    urls = "".join(f"<url><loc>{html.escape(base_url + '/' + route)}</loc></url>\n" for route in ("", "en/"))
    (destination / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n' + urls + '</urlset>\n', encoding="utf-8")
    print(f"Built Chinese and English pages for plugin {version}: {destination}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT.parent / "_site")
    parser.add_argument("--base-url")
    args = parser.parse_args()
    build(args.output, args.base_url)
