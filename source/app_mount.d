module app_mount;

import std.stdio;
import std.string;
import std.getopt;
import std.conv;
import core.stdc.string;
import core.stdc.stdlib;
import repodrive.paths;
import repodrive.schema;
import repodrive.cache;
import repodrive.vtree;
import repodrive.catalog;

// C ABI callbacks implemented in D; C shim calls these.
extern (C) {
	export int rd_getattr(const(char)* path, long* size, int* isDir) {
		try {
			auto p = fromStringz(path).idup;
			auto tree = gTree;
			if (tree is null) return -1;
			if (tree.isDir(p)) {
				*isDir = 1;
				*size = 0;
				return 0;
			}
			auto data = tree.readFile(p);
			if (data is null) {
				// might still be empty dir
				auto nodes = tree.readdir(p);
				if (nodes.length || p.strip("/").length == 0) {
					*isDir = 1;
					*size = 0;
					return 0;
				}
				return -2; // ENOENT
			}
			*isDir = 0;
			*size = cast(long) data.length;
			return 0;
		} catch (Exception) {
			return -1;
		}
	}

	export int rd_readdir(const(char)* path, void* buf, int function(void*, const(char)*, int isDir) filler) {
		try {
			auto p = fromStringz(path).idup;
			auto tree = gTree;
			if (tree is null) return -1;
			foreach (n; tree.readdir(p)) {
				auto namez = (n.name ~ "\0").dup;
				if (filler(buf, namez.ptr, n.kind == VNodeKind.dir ? 1 : 0) != 0)
					break;
			}
			return 0;
		} catch (Exception) {
			return -1;
		}
	}

	export int rd_read(const(char)* path, char* buf, ulong size, long offset) {
		try {
			auto p = fromStringz(path).idup;
			auto tree = gTree;
			if (tree is null) return -1;
			auto data = tree.readFile(p);
			if (data is null) return -2;
			if (offset >= cast(long) data.length) return 0;
			auto avail = data.length - cast(size_t) offset;
			auto n = avail < size ? avail : cast(size_t) size;
			memcpy(buf, data.ptr + cast(size_t) offset, n);
			return cast(int) n;
		} catch (Exception) {
			return -1;
		}
	}
}

__gshared VirtualTree* gTree;

// Declared in native shim
extern (C) int rd_fuse_main(int argc, char** argv);

void main(string[] args) {
	string rootOpt;
	string mountPoint = defaultMountPoint();
	getopt(args, "root", &rootOpt);
	if (args.length > 1)
		mountPoint = args[1];

	ensureDirs(rootOpt);
	auto schema = loadSchema(rootOpt);
	auto cache = SparseCache.create(rootOpt);
	auto tree = VirtualTree(schema, cache);
	tree.catalog = loadCatalog(rootOpt);
	gTree = &tree;

	writeln("RepoDrive mounting ", mountPoint);
	writeln("Schema path pattern: ", schema.pathPattern);
	writeln("Repos in catalog: ", tree.catalog.repos.length);

	// Build argv for fuse: program, mountpoint, -f (foreground)
	auto prog = args[0] ~ "\0";
	auto mnt = mountPoint ~ "\0";
	auto fflag = "-f\0";
	char*[4] argvC;
	argvC[0] = prog.dup.ptr;
	argvC[1] = mnt.dup.ptr;
	argvC[2] = fflag.dup.ptr;
	argvC[3] = null;
	auto rc = rd_fuse_main(3, argvC.ptr);
	if (rc != 0)
		stderr.writeln("FUSE mount exited with code ", rc);
}
