module app_cli;

import std.stdio;
import std.getopt;
import std.string;
import std.conv;
import std.file;
import std.path;
import std.process;
import forgeauth;
import repodrive.paths;
import repodrive.schema;
import repodrive.cache;
import repodrive.vtree;
import repodrive.catalog;
import repodrive.open_issues_browser;
import repodrive.github_api;

void main(string[] args) {
	string rootOpt;
	string mountPoint;
	string setPath;
	string facetName;
	string addRepo;
	string openArg;
	string loginHost;
	string storePatHost;
	bool facetEnable;
	bool facetDisable;
	bool schemaInit;
	bool schemaShow;
	bool help;
	bool listCatalog;

	getopt(args,
		"root", &rootOpt,
		"mount", &mountPoint,
		"schema-init", &schemaInit,
		"schema-show", &schemaShow,
		"set-path", &setPath,
		"facet-enable", &facetName,
		"enable", &facetEnable,
		"facet-disable", &facetDisable,
		"add-repo", &addRepo,
		"list-repos", &listCatalog,
		"open-issues", &openArg,
		"login", &loginHost,
		"store-pat", &storePatHost,
		"help|h", &help
	);

	// positional: repodrive <command>
	string cmd;
	if (args.length > 1)
		cmd = args[1];

	if (help || (args.length == 1 && !schemaInit && !schemaShow && !mountPoint.length
			&& !setPath.length && !addRepo.length && !openArg.length && !loginHost.length
			&& !listCatalog && facetName.length == 0)) {
		printHelp();
		return;
	}

	ensureDirs(rootOpt);
	auto schema = loadSchema(rootOpt);

	if (schemaInit || cmd == "schema" && args.length > 2 && args[2] == "init") {
		initSchemaFromExample(rootOpt);
		writeln("Schema at ", schemaPath(rootOpt));
		return;
	}
	if (schemaShow || (cmd == "schema" && args.length > 2 && args[2] == "show")) {
		schema = loadSchema(rootOpt);
		writeln("name: ", schema.name);
		writeln("path: ", schema.pathPattern);
		foreach (f; schema.facets)
			writeln("facet ", f.name, " enabled=", f.enabled);
		return;
	}
	if (setPath.length || (cmd == "schema" && args.length > 3 && args[2] == "set-path")) {
		if (setPath.length == 0) setPath = args[3];
		schema.setPathPattern(setPath, rootOpt);
		writeln("path pattern => ", setPath);
		return;
	}
	if (facetName.length) {
		auto en = facetEnable || !facetDisable;
		if (cmd == "schema" && args.length > 2 && args[2] == "facet-disable")
			en = false;
		schema.setFacetEnabled(facetName, en, rootOpt);
		writeln("facet ", facetName, " => ", en);
		return;
	}

	if (addRepo.length || (cmd == "add-repo" && args.length > 2)) {
		if (addRepo.length == 0) addRepo = args[2];
		RepoRef r;
		if (!resolveRepoArg(addRepo, schema, r)) {
			stderr.writeln("Invalid repo: ", addRepo);
			return;
		}
		auto cat = loadCatalog(rootOpt);
		cat.add(r);
		saveCatalog(cat, rootOpt);
		writeln("Added ", r.host, "/", r.owner, "/", r.name);
		return;
	}
	if (listCatalog || cmd == "list-repos") {
		foreach (r; loadCatalog(rootOpt).repos)
			writeln(r.host, "/", r.owner, "/", r.name);
		return;
	}

	if (openArg.length || (cmd == "open-issues" && args.length > 2)) {
		if (openArg.length == 0) openArg = args[2];
		RepoRef r;
		if (!resolveRepoArg(openArg, schema, r)) {
			stderr.writeln("Could not resolve: ", openArg);
			return;
		}
		if (openInIssuesBrowser(r))
			writeln("Opened ", r.owner, "/", r.name, " in issues-browser");
		return;
	}

	if (loginHost.length || (cmd == "login" && args.length > 2)) {
		if (loginHost.length == 0) loginHost = args[2];
		try {
			auto tok = loginInstance(loginHost);
			writeln("Logged in to ", loginHost, " (token length ", tok.length, ")");
		} catch (Exception e) {
			stderr.writeln(e.msg);
			stderr.writeln("Hint: set oauth_client_id in instances.sdl, or use --store-pat / FORGE_TOKEN.");
		}
		return;
	}
	if (storePatHost.length && args.length > 2) {
		// --store-pat host  (token from stdin or next arg)
		string tok = args.length > 2 ? args[2] : "";
		if (cmd == "store-pat" && args.length > 3) {
			storePatHost = args[2];
			tok = args[3];
		}
		if (tok.length == 0) {
			stderr.writeln("Usage: repodrive --store-pat <host> <token>");
			return;
		}
		storePat(storePatHost, tok);
		writeln("Stored PAT for ", storePatHost);
		return;
	}

	if (mountPoint.length || cmd == "mount") {
		if (mountPoint.length == 0)
			mountPoint = args.length > 2 ? args[2] : defaultMountPoint();
		auto mountBin = "repodrive-mount";
		version (Windows) mountBin ~= ".exe";
		try {
			auto pid = spawnProcess([mountBin, mountPoint, "--root", repodrive.paths.configRoot(rootOpt)]);
			writeln("Mounting at ", mountPoint, " (pid ", pid.processID, ")");
			writeln("Requires WinFsp / macFUSE / libfuse3.");
		} catch (Exception e) {
			stderr.writeln("Failed to spawn ", mountBin, ": ", e.msg);
			stderr.writeln("Build with: dub build --config=mount");
			// Fallback: run demo tree listing
			demoList(rootOpt);
		}
		return;
	}

	if (cmd == "ls" && args.length > 2) {
		auto tree = makeTree(rootOpt);
		foreach (n; tree.readdir(args[2]))
			writeln(n.kind == VNodeKind.dir ? "d " : "f ", n.name);
		return;
	}

	printHelp();
}

VirtualTree makeTree(string rootOpt) {
	auto schema = loadSchema(rootOpt);
	auto cache = SparseCache.create(rootOpt);
	auto tree = VirtualTree(schema, cache);
	tree.catalog = loadCatalog(rootOpt);
	return tree;
}

void demoList(string rootOpt) {
	auto tree = makeTree(rootOpt);
	writeln("Virtual root listing (no FUSE):");
	foreach (n; tree.readdir(""))
		writeln("  ", n.name, "/");
}

void printHelp() {
	writeln("DevCentr RepoDrive — read-only forge repo drive");
	writeln("  repodrive schema-init|schema-show");
	writeln("  repodrive --set-path \"{host}/{owner}/{repo}\"");
	writeln("  repodrive --facet-enable tree|--facet-disable discussions");
	writeln("  repodrive add-repo owner/name");
	writeln("  repodrive list-repos");
	writeln("  repodrive mount [path]");
	writeln("  repodrive open-issues <virtual-path|owner/name>");
	writeln("  repodrive login <host>");
	writeln("  repodrive --store-pat <host> <token>");
	writeln("  repodrive ls <virtual-path>");
	writeln("  --root <dir>   config root (REPODRIVE_ROOT)");
}
