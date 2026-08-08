module repodrive.facets.tree;

import std.string;
import std.array;
import std.algorithm;
import repodrive.schema;
import repodrive.cache;
import repodrive.github_api;
import repodrive.vtree : VNode, VNodeKind;

VNode[] listTreeFacet(RepoRef repo, string sub, string refName, SparseCache cache) {
	try {
		auto entries = listContents(repo, sub, refName);
		VNode[] nodes;
		foreach (e; entries) {
			VNode n;
			n.name = e.path.canFind("/") ? e.path[e.path.lastIndexOf("/") + 1 .. $] : e.path;
			n.kind = e.type == "tree" ? VNodeKind.dir : VNodeKind.file;
			n.size = e.size;
			nodes ~= n;
		}
		return nodes;
	} catch (Exception) {
		return null;
	}
}

ubyte[] readTreeFile(RepoRef repo, string sub, string refName, SparseCache cache) {
	try {
		return fetchFile(repo, sub, refName, cache);
	} catch (Exception) {
		return null;
	}
}
