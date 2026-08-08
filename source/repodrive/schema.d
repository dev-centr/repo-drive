module repodrive.schema;

import std.file;
import std.path;
import std.string;
import std.algorithm;
import std.array;
import std.stdio;
import std.conv;
import sdlang;
import repodrive.paths;

/// A repo identity resolved from a virtual path.
struct RepoRef {
	string host = "github.com";
	string owner;
	string name;
}

struct FacetConfig {
	string name;
	bool enabled = true;
}

struct MountSchema {
	string name = "default";
	string pathPattern = "{owner}/{repo}"; /// tokens: {host} {owner} {repo}
	FacetConfig[] facets;
}

MountSchema defaultSchema() {
	MountSchema s;
	s.facets = [
		FacetConfig("tree"),
		FacetConfig("issues"),
		FacetConfig("pull-requests"),
		FacetConfig("discussions"),
		FacetConfig("meta"),
		FacetConfig("docs"),
	];
	return s;
}

MountSchema loadSchema(string root = null) {
	auto path = schemaPath(root);
	if (!exists(path))
		return defaultSchema();
	try {
		Tag doc = parseSource(readText(path));
		MountSchema s = defaultSchema();
		foreach (tag; doc.tags) {
			if (tag.name != "schema") continue;
			if (tag.values.length)
				s.name = tag.values[0].get!string;
			FacetConfig[] facets;
			foreach (child; tag.tags) {
				if (child.name == "path" && child.values.length)
					s.pathPattern = child.values[0].get!string;
				else if (child.name == "facet") {
					FacetConfig f;
					if (child.values.length)
						f.name = child.values[0].get!string;
					foreach (gc; child.tags) {
						if (gc.name == "enabled" && gc.values.length)
							f.enabled = gc.values[0].get!bool;
					}
					facets ~= f;
				}
			}
			if (facets.length)
				s.facets = facets;
			return s;
		}
	} catch (Exception e) {
		stderr.writeln("repodrive: schema parse error: ", e.msg);
	}
	return defaultSchema();
}

void saveSchema(MountSchema s, string root = null) {
	ensureDirs(root);
	string outText = "// RepoDrive mount schema\n";
	outText ~= "schema \"" ~ escapeSdl(s.name) ~ "\" {\n";
	outText ~= "    path \"" ~ escapeSdl(s.pathPattern) ~ "\"\n\n";
	foreach (f; s.facets) {
		outText ~= "    facet \"" ~ escapeSdl(f.name) ~ "\" {\n";
		outText ~= "        enabled " ~ (f.enabled ? "true" : "false") ~ "\n";
		outText ~= "    }\n";
	}
	outText ~= "}\n";
	std.file.write(schemaPath(root), outText);
}

void initSchemaFromExample(string root = null) {
	ensureDirs(root);
	auto dest = schemaPath(root);
	if (exists(dest)) return;
	auto example = buildPath(thisExeDir(), "schema.example.sdl");
	if (!exists(example))
		example = "schema.example.sdl";
	if (exists(example))
		copy(example, dest);
	else
		saveSchema(defaultSchema(), root);
}

/// Compile pattern segments, e.g. ["{owner}","{repo}"] 
string[] patternSegments(string pattern) {
	return pattern.strip("/").split("/").filter!(p => p.length > 0).array;
}

bool facetEnabled(const ref MountSchema s, string name) {
	foreach (f; s.facets)
		if (f.name == name) return f.enabled;
	return false;
}

string[] enabledFacetNames(const ref MountSchema s) {
	string[] names;
	foreach (f; s.facets)
		if (f.enabled) names ~= f.name;
	return names;
}

/**
 * Build virtual path for a repo under the schema (no facet).
 * Collision policy for `{repo}`-only: use `{owner}__{repo}` when owner would be ambiguous —
 * callers pass disambiguate=true.
 */
string repoVirtualPath(const ref MountSchema s, RepoRef r, bool disambiguate = false) {
	auto segs = patternSegments(s.pathPattern);
	string[] outSegs;
	foreach (seg; segs) {
		if (seg == "{host}") outSegs ~= r.host;
		else if (seg == "{owner}") outSegs ~= r.owner.replace("/", "_");
		else if (seg == "{repo}") {
			if (disambiguate && !segs.canFind("{owner}"))
				outSegs ~= r.owner.replace("/", "_") ~ "__" ~ r.name;
			else
				outSegs ~= r.name;
		} else
			outSegs ~= seg;
	}
	return outSegs.join("/");
}

/// Parse a virtual path into RepoRef + remaining relative path (facet/...).
bool parseVirtualPath(const ref MountSchema s, string vpath, out RepoRef repo, out string rest) {
	auto parts = vpath.strip("/").split("/").filter!(p => p.length > 0).array;
	auto segs = patternSegments(s.pathPattern);
	if (parts.length < segs.length)
		return false;
	foreach (i, seg; segs) {
		auto val = parts[i];
		if (seg == "{host}") repo.host = val;
		else if (seg == "{owner}") repo.owner = val.replace("_", "/"); // best-effort
		else if (seg == "{repo}") {
			if (val.canFind("__") && !segs.canFind("{owner}")) {
				auto u = val.indexOf("__");
				repo.owner = val[0 .. u].replace("_", "/");
				repo.name = val[u + 2 .. $];
			} else
				repo.name = val;
		} else if (seg != val)
			return false;
	}
	if (repo.host.length == 0) repo.host = "github.com";
	rest = parts[segs.length .. $].join("/");
	return repo.owner.length > 0 && repo.name.length > 0;
}

/// Remap path pattern after setup (refactor schema).
void setPathPattern(ref MountSchema s, string pattern, string root = null) {
	s.pathPattern = pattern;
	saveSchema(s, root);
}

void setFacetEnabled(ref MountSchema s, string name, bool enabled, string root = null) {
	foreach (ref f; s.facets) {
		if (f.name == name) {
			f.enabled = enabled;
			saveSchema(s, root);
			return;
		}
	}
	s.facets ~= FacetConfig(name, enabled);
	saveSchema(s, root);
}

private string escapeSdl(string s) {
	return s.replace(`\`, `\\`).replace(`"`, `\"`);
}

private string thisExeDir() {
	try {
		import std.file : thisExePath;
		return dirName(thisExePath());
	} catch (Exception) {
		return ".";
	}
}
