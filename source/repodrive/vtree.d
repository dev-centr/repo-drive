module repodrive.vtree;

import std.string;
import std.algorithm;
import std.array;
import std.conv;
import std.json;
import repodrive.schema;
import repodrive.cache;
import repodrive.github_api;
import repodrive.facets.tree;
import repodrive.facets.issues;
import repodrive.facets.pulls;
import repodrive.facets.discussions;
import repodrive.facets.meta;
import repodrive.facets.docs;

enum VNodeKind {
	dir,
	file
}

struct VNode {
	string name;
	VNodeKind kind;
	ulong size;
	string content; /// for small synthetic files
}

/// Catalog of repos visible in the mount (populated by CLI/login sync).
struct RepoCatalog {
	RepoRef[] repos;

	void add(RepoRef r) {
		foreach (x; repos)
			if (x.host == r.host && x.owner == r.owner && x.name == r.name)
				return;
		repos ~= r;
	}
}

struct VirtualTree {
	MountSchema schema;
	SparseCache cache;
	RepoCatalog catalog;
	string refName = "HEAD";

	this(MountSchema s, SparseCache c) {
		schema = s;
		cache = c;
	}

	/// List directory at virtual path ("" = root).
	VNode[] readdir(string vpath) {
		auto p = vpath.strip("/");
		if (p.length == 0)
			return listRoot();

		RepoRef repo;
		string rest;
		if (!parseVirtualPath(schema, p, repo, rest)) {
			// Partial path matching schema prefix (e.g. owner only)
			return listPartial(p);
		}
		if (rest.length == 0) {
			VNode[] nodes;
			foreach (f; enabledFacetNames(schema))
				nodes ~= VNode(f, VNodeKind.dir);
			return nodes;
		}
		auto slash = rest.indexOf("/");
		string facet = slash < 0 ? rest : rest[0 .. slash];
		string sub = slash < 0 ? "" : rest[slash + 1 .. $];
		switch (facet) {
		case "tree":
			return listTreeFacet(repo, sub, refName, cache);
		case "issues":
			return listIssuesFacet(repo, sub);
		case "pull-requests":
		case "merge-requests":
			return listPullsFacet(repo, sub);
		case "discussions":
			return listDiscussionsFacet(repo, sub);
		case "meta":
			return listMetaFacet(repo, sub);
		case "docs":
			return listDocsFacet(repo, sub);
		default:
			return null;
		}
	}

	/// Read file contents at virtual path.
	ubyte[] readFile(string vpath) {
		RepoRef repo;
		string rest;
		if (!parseVirtualPath(schema, vpath.strip("/"), repo, rest))
			return null;
		auto slash = rest.indexOf("/");
		if (slash < 0) return null;
		auto facet = rest[0 .. slash];
		auto sub = rest[slash + 1 .. $];
		switch (facet) {
		case "tree":
			return readTreeFile(repo, sub, refName, cache);
		case "issues":
			return readIssuesFile(repo, sub);
		case "pull-requests":
		case "merge-requests":
			return readPullsFile(repo, sub);
		case "discussions":
			return readDiscussionsFile(repo, sub);
		case "meta":
			return readMetaFile(repo, sub);
		case "docs":
			return readDocsFile(repo, sub);
		default:
			return null;
		}
	}

	bool isDir(string vpath) {
		auto p = vpath.strip("/");
		if (p.length == 0) return true;
		RepoRef repo;
		string rest;
		if (!parseVirtualPath(schema, p, repo, rest)) {
			auto partial = listPartial(p);
			return partial.length > 0 || isPrefixOfAnyRepo(p);
		}
		if (rest.length == 0) return true;
		auto nodes = readdir(p);
		// if path ends at a file name under a facet, readdir of parent would list it
		auto parent = dirNameVirt(p);
		auto base = baseNameVirt(p);
		foreach (n; readdir(parent))
			if (n.name == base) return n.kind == VNodeKind.dir;
		return nodes.length > 0;
	}

private:
	VNode[] listRoot() {
		auto segs = patternSegments(schema.pathPattern);
		if (segs.length == 0) return null;
		if (segs[0] == "{host}") {
			string[] hosts;
			foreach (r; catalog.repos)
				if (!hosts.canFind(r.host)) hosts ~= r.host;
			return hosts.map!(h => VNode(h, VNodeKind.dir)).array;
		}
		if (segs[0] == "{owner}") {
			string[] owners;
			foreach (r; catalog.repos) {
				auto o = r.owner.replace("/", "_");
				if (!owners.canFind(o)) owners ~= o;
			}
			return owners.map!(o => VNode(o, VNodeKind.dir)).array;
		}
		// {repo} at root
		VNode[] nodes;
		foreach (r; catalog.repos)
			nodes ~= VNode(repoVirtualPath(schema, r, true).split("/")[0], VNodeKind.dir);
		return nodes;
	}

	VNode[] listPartial(string p) {
		auto segs = patternSegments(schema.pathPattern);
		auto parts = p.split("/");
		if (parts.length >= segs.length) return null;
		// next segment values from catalog
		string[] next;
		foreach (r; catalog.repos) {
			auto full = repoVirtualPath(schema, r).strip("/").split("/");
			if (full.length <= parts.length) continue;
			bool match = true;
			foreach (i, part; parts)
				if (full[i] != part) { match = false; break; }
			if (match && !next.canFind(full[parts.length]))
				next ~= full[parts.length];
		}
		return next.map!(n => VNode(n, VNodeKind.dir)).array;
	}

	bool isPrefixOfAnyRepo(string p) {
		foreach (r; catalog.repos) {
			auto full = repoVirtualPath(schema, r);
			if (full == p || full.startsWith(p ~ "/")) return true;
		}
		return false;
	}
}

string dirNameVirt(string p) {
	auto s = p.strip("/");
	auto i = s.lastIndexOf("/");
	if (i < 0) return "";
	return s[0 .. i];
}

string baseNameVirt(string p) {
	auto s = p.strip("/");
	auto i = s.lastIndexOf("/");
	if (i < 0) return s;
	return s[i + 1 .. $];
}
