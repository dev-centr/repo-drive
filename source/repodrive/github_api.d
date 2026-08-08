module repodrive.github_api;

import std.net.curl;
import std.json;
import std.conv;
import std.string;
import std.array;
import std.algorithm;
import std.base64;
import forgeauth.tokens;
import repodrive.schema;
import repodrive.cache;

struct TreeEntry {
	string path;
	string type; /// blob | tree
	string sha;
	ulong size;
}

string githubGet(string url, string host = "github.com") {
	auto cred = resolveCredential(host);
	auto http = HTTP();
	http.addRequestHeader("Accept", "application/vnd.github+json");
	http.addRequestHeader("User-Agent", "RepoDrive/0.1");
	if (cred.token.length)
		http.addRequestHeader("Authorization", "Bearer " ~ cred.token);
	return cast(string) get(url, http);
}

string apiRoot(string host) {
	if (host == "github.com" || host.length == 0)
		return "https://api.github.com";
	return "https://" ~ host ~ "/api/v3";
}

/// List directory via Contents API.
TreeEntry[] listContents(RepoRef r, string path = "", string refName = "HEAD") {
	auto url = apiRoot(r.host) ~ "/repos/" ~ r.owner ~ "/" ~ r.name ~ "/contents";
	if (path.length) url ~= "/" ~ path.stripLeft("/");
	if (refName.length && refName != "HEAD")
		url ~= "?ref=" ~ refName;
	auto raw = githubGet(url, r.host);
	TreeEntry[] entries;
	auto j = parseJSON(raw);
	if (j.type == JSONType.array) {
		foreach (el; j.array) {
			TreeEntry e;
			e.path = el["name"].str;
			e.type = el["type"].str == "dir" ? "tree" : "blob";
			if ("sha" in el) e.sha = el["sha"].str;
			if ("size" in el) e.size = cast(ulong) el["size"].integer;
			entries ~= e;
		}
	}
	return entries;
}

/// Fetch file content (decoded). Uses blob cache when sha known.
ubyte[] fetchFile(RepoRef r, string path, string refName, SparseCache cache) {
	auto url = apiRoot(r.host) ~ "/repos/" ~ r.owner ~ "/" ~ r.name ~ "/contents/"
		~ path.stripLeft("/");
	if (refName.length && refName != "HEAD")
		url ~= "?ref=" ~ refName;
	auto raw = githubGet(url, r.host);
	auto j = parseJSON(raw);
	if ("sha" in j) {
		auto sha = j["sha"].str;
		if (cache.hasBlob(sha))
			return cache.getBlob(sha);
	}
	if ("content" in j && j["encoding"].str == "base64") {
		auto b64 = j["content"].str.replace("\n", "");
		auto data = Base64.decode(b64);
		if ("sha" in j)
			cache.putBlob(j["sha"].str, data);
		return data;
	}
	if ("download_url" in j && j["download_url"].type != JSONType.null_) {
		auto http = HTTP();
		http.addRequestHeader("User-Agent", "RepoDrive/0.1");
		auto cred = resolveCredential(r.host);
		if (cred.token.length)
			http.addRequestHeader("Authorization", "Bearer " ~ cred.token);
		auto data = cast(ubyte[]) get(j["download_url"].str, http);
		if ("sha" in j)
			cache.putBlob(j["sha"].str, data);
		return data;
	}
	return null;
}

JSONValue listIssuesJson(RepoRef r, int perPage = 30) {
	auto url = apiRoot(r.host) ~ "/repos/" ~ r.owner ~ "/" ~ r.name
		~ "/issues?state=all&per_page=" ~ to!string(perPage);
	return parseJSON(githubGet(url, r.host));
}

JSONValue listPullsJson(RepoRef r, int perPage = 30) {
	auto url = apiRoot(r.host) ~ "/repos/" ~ r.owner ~ "/" ~ r.name
		~ "/pulls?state=all&per_page=" ~ to!string(perPage);
	return parseJSON(githubGet(url, r.host));
}

JSONValue repoMetaJson(RepoRef r) {
	auto url = apiRoot(r.host) ~ "/repos/" ~ r.owner ~ "/" ~ r.name;
	return parseJSON(githubGet(url, r.host));
}

/// Best-effort GraphQL discussions list (GitHub only).
JSONValue listDiscussionsJson(RepoRef r, int first = 20) {
	auto q = `{"query":"query($o:String!,$n:String!){repository(owner:$o,name:$n){discussions(first:`
		~ to!string(first) ~ `){nodes{number title url createdAt author{login}}}}}",`
		~ `"variables":{"o":"` ~ r.owner ~ `","n":"` ~ r.name ~ `"}}`;
	auto http = HTTP();
	http.addRequestHeader("Accept", "application/json");
	http.addRequestHeader("User-Agent", "RepoDrive/0.1");
	http.addRequestHeader("Content-Type", "application/json");
	auto cred = resolveCredential(r.host);
	if (cred.token.length)
		http.addRequestHeader("Authorization", "Bearer " ~ cred.token);
	auto raw = cast(string) post("https://api.github.com/graphql", q, http);
	return parseJSON(raw);
}
