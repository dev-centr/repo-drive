module repodrive.facets.meta;

import std.json;
import std.string;
import repodrive.schema;
import repodrive.github_api;
import repodrive.vtree : VNode, VNodeKind;

VNode[] listMetaFacet(RepoRef repo, string sub) {
	if (sub.length) return null;
	return [
		VNode("repo.json", VNodeKind.file),
		VNode("README.txt", VNodeKind.file),
	];
}

ubyte[] readMetaFile(RepoRef repo, string sub) {
	if (sub == "README.txt")
		return cast(ubyte[]) "Repository metadata from the forge API.\n";
	if (sub == "repo.json") {
		try {
			return cast(ubyte[]) repoMetaJson(repo).toPrettyString();
		} catch (Exception e) {
			return cast(ubyte[]) (`{"error":"` ~ e.msg ~ `"}`);
		}
	}
	return null;
}
