/// Rewrites `[[type:slug]]` / `[[type:slug|alias]]` wiki links into
/// markdown links on a relative `/wiki-link/` path — the SAME shape the
/// web uses (wiki/page.tsx:311) and the only one gpt_markdown renders
/// as a link: a custom `wikilink:` scheme degrades to literal text
/// (verified against gpt_markdown 1.3.1 — mailto/tel/relative/absolute
/// paths all link, custom schemes don't). [resolveTitle] maps the link
/// id to the target page's display title; the raw id is the fallback
/// for pages outside the inventory.
String rewriteWikiLinks(String body, String Function(String id) resolveTitle) {
  return body.replaceAllMapped(
    RegExp(r'\[\[(\w+:[\w-]+)(?:\|([^\]]+))?\]\]'),
    (m) => '[${m[2] ?? resolveTitle(m[1]!)}](/wiki-link/${m[1]!})',
  );
}

/// Splits a `/wiki-link/<id>` href back into the page id, or null when
/// the href isn't a wiki link.
String? wikiLinkTarget(String href) => href.startsWith('/wiki-link/')
    ? href.substring('/wiki-link/'.length)
    : null;
