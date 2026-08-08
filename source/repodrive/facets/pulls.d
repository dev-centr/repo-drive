module repodrive.facets.pulls;

import std.conv;
import std.string;
import std.json;
import std.array;
import repodrive.schema;
import repodrive.github_api;
import repodrive.vtree : VNode, VNodeKind;

VNode[] listPullsFacet(RepoRef repo, string sub) {
	if (sub.length) return null;
	try {
		auto j = listPullsJson(repo);
		VNode[] nodes;
		foreach (el; j.array) {
			auto num = el["number"].integer;
			auto title = el["title"].str;
			nodes ~= VNode(to!string(num) ~ "-" ~ sanitize(title) ~ ".md", VNodeKind.file);
		}
		return nodes;
	} catch (Exception) {
		return [VNode("README.txt", VNodeKind.file)];
	}
}

ubyte[] readPullsFile(RepoRef repo, string sub) {
	if (sub == "README.txt")
		return cast(ubyte[]) "Pull requests facet (merge-requests on GitLab profiles).\n";
	try {
		auto num = to!int(sub.split("-")[0]);
		auto j = listPullsJson(repo, 100);
		foreach (el; j.array) {
			if (el["number"].integer != num) continue;
			auto body = ("body" in el && el["body"].type != JSONType.null_) ? el["body"].str : "";
			auto md = "# PR #" ~ to!string(num) ~ " " ~ el["title"].str ~ "\n\n"
				~ "State: " ~ el["state"].str ~ "\n"
				~ "URL: " ~ el["html_url"].str ~ "\n\n"
				~ body ~ "\n";
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
	return o.length ? o : "pr";
}
