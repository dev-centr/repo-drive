module repodrive.facets.discussions;

import std.conv;
import std.string;
import std.json;
import std.array;
import repodrive.schema;
import repodrive.github_api;
import repodrive.vtree : VNode, VNodeKind;

VNode[] listDiscussionsFacet(RepoRef repo, string sub) {
	if (sub.length) return null;
	try {
		auto j = listDiscussionsJson(repo);
		VNode[] nodes;
		auto nodesJ = j["data"]["repository"]["discussions"]["nodes"];
		foreach (el; nodesJ.array) {
			auto num = el["number"].integer;
			auto title = el["title"].str;
			nodes ~= VNode(to!string(num) ~ "-" ~ sanitize(title) ~ ".md", VNodeKind.file);
		}
		return nodes;
	} catch (Exception) {
		return [VNode("README.txt", VNodeKind.file)];
	}
}

ubyte[] readDiscussionsFile(RepoRef repo, string sub) {
	if (sub == "README.txt")
		return cast(ubyte[]) "Discussions facet (GitHub GraphQL). Offline fallback via issues-browser index/backup.\n";
	try {
		auto num = to!int(sub.split("-")[0]);
		auto j = listDiscussionsJson(repo, 50);
		foreach (el; j["data"]["repository"]["discussions"]["nodes"].array) {
			if (el["number"].integer != num) continue;
			auto md = "# Discussion #" ~ to!string(num) ~ " " ~ el["title"].str ~ "\n\n"
				~ "URL: " ~ el["url"].str ~ "\n";
			return cast(ubyte[]) md;
		}
	} catch (Exception) {}
	return null;
}

private string sanitize(string s) {
	string o;
	foreach (c; s) {
		if ((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || (c >= '0' && c <= '9') || c == '-' || c == '_')
			o ~= c;
		else if (c == ' ')
			o ~= '-';
	}
	if (o.length > 60) o = o[0 .. 60];
	return o.length ? o : "discussion";
}
