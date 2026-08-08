module repodrive.catalog;

import std.file;
import std.path;
import std.string;
import std.array;
import std.algorithm;
import sdlang;
import repodrive.paths;
import repodrive.schema;
import repodrive.vtree : RepoCatalog;

string catalogPath(string root = null) {
	return buildPath(configRoot(root), "catalog.sdl");
}

RepoCatalog loadCatalog(string root = null) {
	RepoCatalog c;
	auto path = catalogPath(root);
	if (!exists(path)) return c;
	try {
		Tag doc = parseSource(readText(path));
		foreach (tag; doc.tags) {
			if (tag.name != "repo") continue;
			RepoRef r;
			if (tag.values.length)
				r.name = tag.values[0].get!string;
			foreach (child; tag.tags) {
				if (child.values.length == 0) continue;
				auto v = child.values[0].get!string;
				switch (child.name) {
				case "host": r.host = v; break;
				case "owner": r.owner = v; break;
				case "name": r.name = v; break;
				default: break;
				}
			}
			if (r.host.length == 0) r.host = "github.com";
			if (r.owner.length && r.name.length)
				c.add(r);
		}
	} catch (Exception) {}
	return c;
}

void saveCatalog(RepoCatalog c, string root = null) {
	ensureDirs(root);
	string s = "// RepoDrive visible repositories\n";
	foreach (r; c.repos) {
		s ~= "repo \"" ~ escape(r.name) ~ "\" {\n";
		s ~= "    host \"" ~ escape(r.host) ~ "\"\n";
		s ~= "    owner \"" ~ escape(r.owner) ~ "\"\n";
		s ~= "    name \"" ~ escape(r.name) ~ "\"\n";
		s ~= "}\n";
	}
	std.file.write(catalogPath(root), s);
}

private string escape(string s) {
	return s.replace(`\`, `\\`).replace(`"`, `\"`);
}
