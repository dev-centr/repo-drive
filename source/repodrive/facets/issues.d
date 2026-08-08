module repodrive.facets.issues;

import std.conv;
import std.string;
import std.json;
import std.array;
import repodrive.schema;
import repodrive.github_api;
import repodrive.vtree : VNode, VNodeKind;

VNode[] listIssuesFacet(RepoRef repo, string sub) {
	if (sub.length) return null;
	try {
		auto j = listIssuesJson(repo);
		VNode[] nodes;
		if (j.type != JSONType.array) return nodes;
		foreach (el; j.array) {
			if ("pull_request" in el) continue; // issues API includes PRs
			auto num = el["number"].integer;
			auto title = el["title"].str;
			auto safe = sanitize(title);
			nodes ~= VNode(to!string(num) ~ "-" ~ safe ~ ".md", VNodeKind.file);
		}
		return nodes;
	} catch (Exception) {
		return [VNode("README.txt", VNodeKind.file)];
	}
}

ubyte[] readIssuesFile(RepoRef repo, string sub) {
	if (sub == "README.txt")
		return cast(ubyte[]) "Issues facet: live GitHub API listings as markdown files.\n";
	try {
		auto numStr = sub.split("-")[0];
		auto num = to!int(numStr);
		auto j = listIssuesJson(repo, 100);
		foreach (el; j.array) {
			if (el["number"].integer != num) continue;
			auto body = ("body" in el && el["body"].type != JSONType.null_) ? el["body"].str : "";
			auto md = "# #" ~ to!string(num) ~ " " ~ el["title"].str ~ "\n\n"
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
	return o.length ? o : "issue";
}
