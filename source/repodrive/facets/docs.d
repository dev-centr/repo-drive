module repodrive.facets.docs;

import std.json;
import std.string;
import repodrive.schema;
import repodrive.github_api;
import repodrive.vtree : VNode, VNodeKind;

VNode[] listDocsFacet(RepoRef repo, string sub) {
	if (sub.length) return null;
	return [
		VNode("LINKS.txt", VNodeKind.file),
		VNode("wiki.url", VNodeKind.file),
		VNode("pages.url", VNodeKind.file),
	];
}

ubyte[] readDocsFile(RepoRef repo, string sub) {
	auto base = "https://" ~ repo.host ~ "/" ~ repo.owner ~ "/" ~ repo.name;
	if (sub == "LINKS.txt") {
		auto text = "Complementary docs links for " ~ repo.owner ~ "/" ~ repo.name ~ "\n\n"
			~ "Wiki:  " ~ base ~ "/wiki\n"
			~ "Pages: https://" ~ repo.owner ~ ".github.io/" ~ repo.name ~ "/\n"
			~ "Open issues-browser for archived discussions/docs metadata.\n";
		return cast(ubyte[]) text;
	}
	if (sub == "wiki.url")
		return cast(ubyte[]) (base ~ "/wiki\n");
	if (sub == "pages.url")
		return cast(ubyte[]) ("https://" ~ repo.owner ~ ".github.io/" ~ repo.name ~ "/\n");
	return null;
}
