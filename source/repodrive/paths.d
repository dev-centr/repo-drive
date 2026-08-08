module repodrive.paths;

import std.file;
import std.path;
import std.process;
import std.string;

string configRoot(string overrideRoot = null) {
	if (overrideRoot.length)
		return absolutePath(overrideRoot);
	auto env = environment.get("REPODRIVE_ROOT", "");
	if (env.length)
		return absolutePath(env);
	version (Windows) {
		auto appdata = environment.get("APPDATA", "");
		if (appdata.length)
			return buildPath(appdata, "RepoDrive");
	}
	auto xdg = environment.get("XDG_CONFIG_HOME", "");
	if (xdg.length)
		return buildPath(xdg, "repodrive");
	auto home = environment.get("HOME", environment.get("USERPROFILE", "."));
	return buildPath(home, ".config", "repodrive");
}

string schemaPath(string root = null) {
	return buildPath(configRoot(root), "schema.sdl");
}

string cacheRoot(string root = null) {
	auto env = environment.get("REPODRIVE_CACHE", "");
	if (env.length) return absolutePath(env);
	version (Windows) {
		auto local = environment.get("LOCALAPPDATA", "");
		if (local.length)
			return buildPath(local, "RepoDrive", "cache");
	}
	auto xdg = environment.get("XDG_CACHE_HOME", "");
	if (xdg.length)
		return buildPath(xdg, "repodrive");
	return buildPath(configRoot(root), "cache");
}

string blobCacheDir(string root = null) {
	return buildPath(cacheRoot(root), "blobs");
}

string indexCacheDir(string root = null) {
	return buildPath(cacheRoot(root), "index");
}

string defaultMountPoint() {
	auto env = environment.get("REPODRIVE_MOUNT", "");
	if (env.length) return env;
	version (Windows)
		return `G:\RepoDrive`;
	else
		return "/mnt/repodrive";
}

void ensureDirs(string root = null) {
	mkdirRecurse(configRoot(root));
	mkdirRecurse(blobCacheDir(root));
	mkdirRecurse(indexCacheDir(root));
}
