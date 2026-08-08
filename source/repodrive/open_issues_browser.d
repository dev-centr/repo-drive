module repodrive.open_issues_browser;

import std.stdio;
import std.string;
import std.conv;
import std.socket;
import std.process;
import std.json;
import std.file;
import std.path;
import std.algorithm : canFind;
import std.datetime;
import core.time;
import repodrive.schema;

enum ushort issuesdPort = 17365;

/// Ask issuesd to open a repo (POST /open-repo). Falls back to launching GUI/CLI.
bool openInIssuesBrowser(RepoRef r, string archiveRoot = null) {
	if (tryIpcOpen(r, archiveRoot))
		return true;
	return launchIssuesBrowserProcess(r, archiveRoot);
}

bool tryIpcOpen(RepoRef r, string archiveRoot = null) {
	try {
		auto s = new TcpSocket();
		scope (exit) s.close();
		s.setOption(SocketOptionLevel.SOCKET, SocketOption.RCVTIMEO, dur!"seconds"(2));
		s.connect(new InternetAddress("127.0.0.1", issuesdPort));
		JSONValue body;
		body["host"] = r.host;
		body["owner"] = r.owner;
		body["name"] = r.name;
		if (archiveRoot.length)
			body["root"] = archiveRoot;
		auto payload = body.toString();
		auto req = "POST /open-repo HTTP/1.1\r\nHost: 127.0.0.1\r\nContent-Type: application/json\r\n"
			~ "Content-Length: " ~ to!string(payload.length) ~ "\r\nConnection: close\r\n\r\n" ~ payload;
		s.send(req);
		char[2048] buf;
		auto n = s.receive(buf[]);
		if (n <= 0) return false;
		auto resp = buf[0 .. n].idup;
		return resp.canFind("200") || resp.canFind(`"ok":true`);
	} catch (Exception) {
		return false;
	}
}

bool launchIssuesBrowserProcess(RepoRef r, string archiveRoot = null) {
	auto slug = r.owner ~ "/" ~ r.name;
	string[] candidates = ["issues-browser-gui", "issues-browser"];
	version (Windows) {
		candidates = ["issues-browser-gui.exe", "issues-browser.exe"];
	}
	foreach (bin; candidates) {
		try {
			string[] args = [bin, "--open-repo", slug];
			if (r.host.length && r.host != "github.com")
				args ~= ["--host", r.host];
			if (archiveRoot.length)
				args ~= ["--root", archiveRoot];
			spawnProcess(args);
			return true;
		} catch (Exception) {}
	}
	stderr.writeln("Could not reach issuesd or launch issues-browser. Install/start issues-browser, then retry.");
	stderr.writeln("Repo: ", r.host, "/", r.owner, "/", r.name);
	return false;
}

/// Resolve virtual path or owner/name slug to RepoRef using schema.
bool resolveRepoArg(string arg, MountSchema schema, out RepoRef r) {
	auto s = arg.strip().replace(`\`, "/");
	string rest;
	if (parseVirtualPath(schema, s, r, rest))
		return true;
	// owner/name or host/owner/name
	auto parts = s.strip("/").split("/");
	if (parts.length == 2) {
		r.host = "github.com";
		r.owner = parts[0];
		r.name = parts[1];
		return true;
	}
	if (parts.length >= 3) {
		r.host = parts[0];
		r.owner = parts[1 .. $ - 1].join("/");
		r.name = parts[$ - 1];
		return true;
	}
	return false;
}
