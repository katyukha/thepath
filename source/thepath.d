module thepath;

static public import std.file: SpanMode;
static private import std.path;
static private import std.file;
private import std.format: format;
private import std.exception: enforce;


// Mostly used for unitetests
private string createTempDirectory(string prefix="tmp") {
    import std.file : tempDir;
    return createTempDirectory(tempDir, prefix=prefix);
}

private string createTempDirectory(string path, string prefix="tmp") {
    version(Posix) {
        string tempdir_template= std.path.buildNormalizedPath(
            path, prefix ~ "-XXXXXX");
        import std.string : fromStringz;
        import std.conv: to;
        import core.sys.posix.stdlib : mkdtemp;
        char[] tempname_str = tempdir_template.dup ~ "\0";
        char* res = mkdtemp(tempname_str.ptr);
        enforce(res !is null, "Cannot create temporary directory");
        return to!string(res.fromStringz);
    } else {
        import std.ascii: letters;
        import std.random: uniform;

        string generate_temp_dir() {
            string suffix = "";
            for(ubyte i; i<6; i++) suffix ~= letters[uniform(0, $)];
            return std.path.buildNormalizedPath(path, prefix ~ suffix);
        }


        string temp_dir = generate_temp_dir();
        while (std.file.exists(temp_dir)) {
            temp_dir = generate_temp_dir();
        }
        std.file.mkdir(temp_dir);
        return temp_dir;
    }
}



class PathException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

enum CopyMode {
    Standard,
}

struct Path {
    private string _path=".";

    this(in string path) {
        _path = path;
    }

    bool isValid() const {
        return std.path.isValidPath(_path);
    }

    bool isAbsolute() const {
        return std.path.isAbsolute(_path);
    }

    bool isRooted() const {
        return std.path.isRooted(_path);
    }

    bool isFile() const {
        return std.file.isFile(_path);
    }

    bool isDir() const {
        return std.file.isDir(_path);
    }

    bool isSymlink() const {
        return std.file.isSymlink(_path);
    }

    bool exists() const {
        return std.file.exists(_path);
    }

    string toString() const {
        return _path;
    }

    Path toAbsolute() const {
        return Path(std.path.absolutePath(_path));
    }

    Path expandTilde() const {
        return Path(std.path.expandTilde(_path));
    }

    Path normalize() const {
        import std.array : array;
        import std.exception : assumeUnique;
        auto result = std.path.asNormalizedPath(_path);
        return Path(assumeUnique(result.array));
    }

    Path join(in string[] segments...) const {
        string[] args=[cast(string)_path];
        foreach(s; segments) args ~= s;
        return Path(std.path.buildPath(args));
    }

    Path join(in Path[] segments...) const {
        string[] args=[];
        foreach(p; segments) args ~= p.toString();
        return this.join(args);
    }

    Path parent() const {
        if (isAbsolute()) {
            return Path(std.path.dirName(_path));
        } else {
            return Path(
                std.path.dirName(std.path.absolutePath(_path)));
        }
    }

    Path relativeTo(in Path base) const
    in {
        assert(base.isValid && base.isAbsolute);
    } do {
        return Path(std.path.relativePath(_path, base._path));
    }

    Path relativeTo(in string base) const {
        return relativeTo(Path(base));
    }

    unittest {
        import dshould;
        Path("foo").relativeTo(std.file.getcwd).toString().should.equal("foo");

        version(Posix) {
            auto path1 = Path("/foo/root/child/subchild");
            auto root1 = Path("/foo/root");
            auto root2 = Path("/moo/root");
            auto rpath1 = path1.relativeTo(root1);

            assert(rpath1.toString == "child/subchild");
            assert(root2.join(rpath1).toString == "/moo/root/child/subchild");
            assert(path1.relativeTo(root2).toString == "../../foo/root/child/subchild");
        }
    }

    string extension() const {
        return std.path.extension(_path);
    }

    string baseName() const {
        return std.path.baseName(_path);
    }

    string dirName() const {
        return std.path.dirName(_path);
    }

    ulong getSize() const {
        return std.file.getSize(_path);
    }

    version(Posix) Path readLink() const {
        if (isSymlink()) {
            return Path(std.file.readLink(_path));
        } else {
            return this;
        }
    }

    auto walk(SpanMode mode=SpanMode.shallow, bool followSymlink=true) const {
        import std.algorithm.iteration: map;
        return std.file.dirEntries(
            _path, mode, followSymlink).map!(a => Path(a));

    }

    void chdir() const {
        std.file.chdir(_path);
    }

    void copyFileTo(in Path dest, in bool rewrite=false) const {
        debug {
            import std.stdio;
            writeln("Copying %s to %s".format(_path, dest._path));
        }
        enforce!PathException(
            this.exists,
            "Cannot Copy! Source file %s does not exists!".format(_path));
        if (dest.exists) {
            if (dest.isDir) {
                this.copyFileTo(dest.join(this.baseName));
            } else if (!rewrite) {
                throw new PathException(
                        "Cannot Copy! Destination file %s already exists exists!".format(dest._path));
            } else {
                std.file.copy(_path, dest._path);
            }
        } else {
            std.file.copy(_path, dest._path);
        }
    }

    void copyTo(in Path dest, CopyMode copy_mode=CopyMode.Standard) const {
        import std.stdio;
        if (isDir) {
            std.file.mkdirRecurse(dest._path);
            foreach (Path src; this.walk(SpanMode.breadth)) {
                auto dst = dest.join(src.relativeTo(_path));
                writeln("Copying %s to %s".format(src, dst));
                if (src.isFile) {
                    std.file.copy(src._path, dst._path);
                } else if (src.isSymlink) {
                    // TODO: Posix only
                    if (src.readLink.exists) {
                        std.file.copy(
                            std.file.readLink(src._path),
                            dst._path,
                        );
                    //} else {
                        // Log info about broken symlink
                    }
                } else {
                    std.file.mkdirRecurse(dst._path);
                }
            }
        } else {
            copyFileTo(dest);
        }
    }

    void remove(in bool recursive=false) const {
        if (isFile) std.file.remove(_path);
        else if (recursive) std.file.rmdirRecurse(_path);
        else std.file.rmdir(_path);
    }

    void rename(in Path to) const {
        return std.file.rename(_path, to._path);
    }

    void mkdir(in bool recursive=false) const {
        if (recursive) std.file.mkdirRecurse(_path);
        else std.file.mkdir(_path);
    }

    auto openFile(in string openMode = "rb") const {
        static import std.stdio;

        return std.stdio.File(_path, openMode);
    }

    void writeFile(in void[] buffer) const {
        return std.file.write(_path, buffer);
    }

    void appendFile(in void[] buffer) const {
        return std.file.append(_path, buffer);
    }

    auto readFile() const {
        return std.file.read(_path);
    }

    unittest {
        import dshould;
        string tmp_dir = createTempDirectory();
        scope(exit) std.file.rmdirRecurse(tmp_dir);

        version (Posix) {
            auto root = Path(tmp_dir);
            auto test_c_file = root.join("test-create.txt");
            root._path.should.equal(tmp_dir);
            test_c_file._path.should.equal(tmp_dir ~ "/test-create.txt");
            test_c_file.exists.should.be(false);
            test_c_file.isAbsolute.should.be(true);

            // Test file read/write
            test_c_file.writeFile("Hello World");
            test_c_file.exists.should.be(true);
            test_c_file.readFile.should.equal("Hello World");
            test_c_file.appendFile("!");
            test_c_file.readFile.should.equal("Hello World!");

            // Test copy file
            auto dst_dir = root.join("test-copy-dst", "test.txt");
            test_c_file.copyTo(dst_dir).should.throwA!PathException;
            
        }
    }




    // TODO: to add:
    //       - ability to do file operation (open, read, write, etc),
    //       - match pattern
    //       - Handle symlinks
}
