/// Rewrites `[[type:slug]]` / `[[type:slug|alias]]` wiki links into
/// markdown links under a private scheme the preview renderer's
/// onLinkTap intercepts — the Dart take on the web's `/wiki-link/`
/// rewrite (wiki/page.tsx:311, same regex). [resolveTitle] maps the
/// link id to the target page's display title; the raw id is the
/// fallback for pages outside the inventory.
String rewriteWikiLinks(String body, String Function(String id) resolveTitle) {
  return body.replaceAllMapped(
    RegExp(r'\[\[(\w+:[\w-]+)(?:\|([^\]]+))?\]\]'),
    (m) => '[${m[2] ?? resolveTitle(m[1]!)}](wikilink:${m[1]!})',
  );
}

/// Splits a `wikilink:type:slug` href back into the page id, or null
/// when the href isn't a wiki link.
String? wikiLinkTarget(String href) =>
    href.startsWith('wikilink:') ? href.substring('wikilink:'.length) : null;
