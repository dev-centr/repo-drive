module repodrive.cache;

import std.file;
import std.path;
import std.string;
import std.digest.sha;
import std.conv;
import std.stdio;
import std.json;
import std.datetime;
import repodrive.paths;
import repodrive.schema;

/// On-disk sparse blob + tree-index cache.
struct SparseCache {
	string root;

	static SparseCache create(string configRoot = null) {
		SparseCache c;
		c.root = configRoot;
		ensureDirs(c.root);
		return c;
	}

	string blobPath(string sha) {
		auto s = sha.toLower;
		if (s.length < 4) s = s ~ "0000";
		return buildPath(blobCacheDir(root), s[0 .. 2], s[2 .. 4], s);
	}

	bool hasBlob(string sha) {
		return exists(blobPath(sha));
	}

	void putBlob(string sha, const(ubyte)[] data) {
		auto p = blobPath(sha);
		mkdirRecurse(dirName(p));
		std.file.write(p, data);
	}

	ubyte[] getBlob(string sha) {
		auto p = blobPath(sha);
		if (!exists(p)) return null;
		return cast(ubyte[]) std.file.read(p);
	}

	string treeIndexPath(RepoRef r, string refName) {
		auto key = r.host ~ "_" ~ r.owner.replace("/", "_") ~ "_" ~ r.name ~ "_" ~ refName.replace("/", "_");
		return buildPath(indexCacheDir(root), key ~ ".json");
	}

	void putTreeIndex(RepoRef r, string refName, string json) {
		auto p = treeIndexPath(r, refName);
		mkdirRecurse(dirName(p));
		std.file.write(p, json);
	}

	string getTreeIndex(RepoRef r, string refName) {
		auto p = treeIndexPath(r, refName);
		if (!exists(p)) return null;
		return readText(p);
	}

	/// Simple TTL check via file mtime.
	bool indexFresh(RepoRef r, string refName, Duration maxAge = dur!"minutes"(15)) {
		auto p = treeIndexPath(r, refName);
		if (!exists(p)) return false;
		auto m = timeLastModified(p);
		return Clock.currTime - m < maxAge;
	}
}
