"""Regression cases for the deployed project-path website validation gate."""

from pathlib import Path
from tempfile import TemporaryDirectory
import unittest

from check_docs_site import check_site


BASE = "https://example.github.io/winutil-cn/"


class SiteChecks(unittest.TestCase):
    def setUp(self):
        self.temp = TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.site = Path(self.temp.name)
        for path in ("", "userguide/", "mcp/"):
            target = self.site / path / "index.html"
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(
                '<html lang="zh-cn"><head><link rel="canonical" href="'
                + BASE + path + '"></head><body id="top"><a href="'
                + BASE + 'userguide/#top">指南</a>'
                '<img src="/winutil-cn/example.png"></body></html>', encoding="utf-8")
        (self.site / "example.png").write_bytes(b"fixture")
        (self.site / "sitemap.xml").write_text(
            '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">'
            + "".join(f"<url><loc>{BASE}{path}</loc></url>" for path in ("", "userguide/", "mcp/"))
            + "</urlset>", encoding="utf-8")
        (self.site / "robots.txt").write_text(f"User-agent: *\nSitemap: {BASE}sitemap.xml\n", encoding="utf-8")

    def replace_home(self, before, after):
        path = self.site / "index.html"
        path.write_text(path.read_text(encoding="utf-8").replace(before, after), encoding="utf-8")

    def errors(self):
        return "\n".join(check_site(self.site, BASE)["Errors"])

    def test_project_path_and_fragment_are_valid(self):
        self.assertTrue(check_site(self.site, BASE)["Passed"])

    def test_root_relative_asset_cannot_escape_project(self):
        self.replace_home('/winutil-cn/example.png', '/example.png')
        self.assertIn("escapes the project base path", self.errors())

    def test_missing_image_and_anchor_are_reported(self):
        self.replace_home('example.png', 'missing.png')
        self.replace_home('#top', '#missing')
        self.assertIn("Missing local target", self.errors())
        self.assertIn("Missing anchor", self.errors())

    def test_absolute_canonical_and_sitemap_must_agree(self):
        self.replace_home(BASE + '">', '/winutil-cn/">')
        self.assertIn("Canonical is not absolute", self.errors())
        self.assertIn("has no generated canonical page", self.errors())

    def test_upstream_navigation_is_not_an_internal_link(self):
        self.replace_home(BASE + 'userguide/#top', 'https://winutil.christitus.com/userguide/')
        self.assertIn("Upstream documentation navigation", self.errors())

    def test_canonical_cannot_point_to_another_existing_page(self):
        self.replace_home(BASE + '">', BASE + 'mcp/">')
        self.assertIn("does not identify its own page", self.errors())

    def test_alias_can_point_to_its_existing_destination(self):
        (self.site / "old.html").write_text(
            '<html><head><link rel=canonical href="' + BASE + '">'
            '<meta http-equiv=refresh content="0; url=' + BASE + '"></head></html>', encoding="utf-8")
        self.assertTrue(check_site(self.site, BASE)["Passed"])

    def test_robots_must_allow_search_and_name_correct_sitemap(self):
        (self.site / "robots.txt").write_text("User-agent: *\nDisallow: /\n", encoding="utf-8")
        self.assertIn("blocks the whole site", self.errors())
        self.assertIn("does not declare", self.errors())


if __name__ == "__main__":
    unittest.main()
