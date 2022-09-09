module thepath;

static public import std.file: SpanMode;
static private import std.path;
static private import std.file;
private import std.path: expandTilde;
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
            std.path.expandTilde(path), prefix ~ "-XXXXXX");
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
            return std.path.buildNormalizedPath(
                std.path.expandTilde(path), prefix ~ suffix);
        }


        string temp_dir = generate_temp_dir();
        while (std.file.exists(temp_dir)) {
            temp_dir = generate_temp_dir();
        }
        std.file.mkdir(temp_dir);
        return temp_dir;
    }
}

private Path createTempPath(string prefix="tmp") {
    return Path(createTempDirectory(prefix));
}

private Path createTempPath(string path, string prefix="tmp") {
    return Path(createTempDirectory(path, prefix));
}

private Path createTempPath(Path path, string prefix="tmp") {
    return createTempPath(path.toString, prefix);
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
    // TODO: Deside if we need to make _path by default configured to current directory or to allow path to be null
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
        return std.file.isFile(_path.expandTilde);
    }

    bool isDir() const {
        return std.file.isDir(_path.expandTilde);
    }

    bool isSymlink() const {
        return std.file.isSymlink(_path.expandTilde);
    }

    bool exists() const {
        return std.file.exists(_path.expandTilde);
    }

    unittest {
        import dshould;

        version(Posix) {
            import std.algorithm: startsWith;
            // Prepare test dir in user's home directory
            Path home_tmp = createTempPath("~", "tmp-d-test");
            scope(exit) home_tmp.remove();
            Path home_rel = Path("~").join(home_tmp.baseName);
            home_rel.toString.startsWith("~/tmp-d-test").should.be(true);

            home_rel.join("test-dir").exists.should.be(false);
            home_rel.join("test-dir").mkdir;
            home_rel.join("test-dir").exists.should.be(true);

            home_rel.join("test-file").exists.should.be(false);
            home_rel.join("test-file").writeFile("test");
            home_rel.join("test-file").exists.should.be(true);
        }
    }

    string toString() const {
        return _path;
    }

    Path toAbsolute() const {
        return Path(
            std.path.buildNormalizedPath(
                std.path.absolutePath(_path.expandTilde)));
    }

    unittest {
        import dshould;

        version(Posix) {
            auto cdir = std.file.getcwd;
            scope(exit) std.file.chdir(cdir);
            std.file.chdir("/tmp");

            Path("foo/moo").toAbsolute.toString.should.equal("/tmp/foo/moo");
            Path("../my-path").toAbsolute.toString.should.equal("/my-path");
            Path("/a/path").toAbsolute.toString.should.equal("/a/path");

            string home_path = "~".expandTilde;
            home_path[0].should.equal('/');

            Path("~/my/path").toAbsolute.toString.should.equal("%s/my/path".format(home_path));
        }
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

    unittest {
        import dshould;

        version(Posix) {
            Path("foo").normalize.toString.should.equal("foo");
            Path("../foo/../moo").normalize.toString.should.equal("../moo");
            Path("/foo/./moo/../bar").normalize.toString.should.equal("/foo/bar");
        }
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

    unittest {
        import dshould;
        string tmp_dir = createTempDirectory();
        scope(exit) std.file.rmdirRecurse(tmp_dir);

        auto ps = std.path.dirSeparator;

        Path("tmp").join("test1", "subdir", "2").toString.should.equal(
            "tmp" ~ ps ~ "test1" ~ ps ~ "subdir" ~ ps ~ "2");

        Path root = Path(tmp_dir);
        root._path.should.equal(tmp_dir);
        auto test_c_file = root.join("test-create.txt");
        test_c_file._path.should.equal(tmp_dir ~ ps ~"test-create.txt");
        test_c_file.isAbsolute.should.be(true);

        version(Posix) {
            Path("/").join("test2", "test3").toString.should.equal("/test2/test3");
        }

    }


    Path parent() const {
        if (isAbsolute()) {
            return Path(std.path.dirName(_path));
        } else {
            return this.toAbsolute.parent;
        }
    }

    unittest {
        import dshould;
        version(Posix) {
            Path root = Path("/tmp");

            Path("/tmp").parent.toString.should.equal("/");
            Path("/").parent.toString.should.equal("/");
            Path("/tmp/parent/child").parent.toString.should.equal("/tmp/parent");

            Path("parent/child").parent.toString.should.equal(
                Path(std.file.getcwd).join("parent").toString);

            auto cdir = std.file.getcwd;
            scope(exit) std.file.chdir(cdir);

            std.file.chdir("/tmp");

            Path("parent/child").parent.toString.should.equal("/tmp/parent");

            Path("~/test-dir").parent.toString.should.equal(
                "~".expandTilde);
        }
    }

    Path relativeTo(in Path base) const {
        enforce!PathException(
            base.isValid && base.isAbsolute,
            "Base path must be valid and absolute");
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

            rpath1.toString.should.equal("child/subchild");
            root2.join(rpath1).toString.should.equal("/moo/root/child/subchild");
            path1.relativeTo(root2).toString.should.equal("../../foo/root/child/subchild");

            // Base path must be absolute, so this should throw error
            Path("~/my/path/1").relativeTo("~/my").should.throwA!PathException;
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
        return std.file.getSize(_path.expandTilde);
    }

    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        ubyte[4] data = [1, 2, 3, 4];
        root.join("test-file.txt").writeFile(data);
        root.join("test-file.txt").getSize.should.equal(4);

        version(Posix) {
            // Prepare test dir in user's home directory
            Path home_tmp = createTempPath("~", "tmp-d-test");
            scope(exit) home_tmp.remove();
            string tmp_dir_name = home_tmp.baseName;

            Path("~/%s/test-file.txt".format(tmp_dir_name)).writeFile(data);
            Path("~/%s/test-file.txt".format(tmp_dir_name)).getSize.should.equal(4);
        }
    }

    version(Posix) Path readLink() const {
        if (isSymlink()) {
            return Path(std.file.readLink(_path.expandTilde));
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
        std.file.chdir(_path.expandTilde);
    }

    unittest {
        import dshould;
        auto cdir = std.file.getcwd;
        Path root = createTempPath();
        scope(exit) {
            std.file.chdir(cdir);
            root.remove();
        }

        std.file.getcwd.should.not.equal(root._path);
        root.chdir;
        std.file.getcwd.should.equal(root._path);

        version(Posix) {
            // Prepare test dir in user's home directory
            Path home_tmp = createTempPath("~", "tmp-d-test");
            scope(exit) home_tmp.remove();
            string tmp_dir_name = home_tmp.baseName;
            std.file.getcwd.should.not.equal(home_tmp._path);
            Path("~/%s".format(tmp_dir_name)).chdir;
            std.file.getcwd.should.equal(home_tmp._path);
        }
    }

    void copyFileTo(in Path dest, in bool rewrite=false) const {
        enforce!PathException(
            this.exists,
            "Cannot Copy! Source file %s does not exists!".format(_path));
        if (dest.exists) {
            if (dest.isDir) {
                this.copyFileTo(dest.join(this.baseName));
            } else if (!rewrite) {
                throw new PathException(
                        "Cannot copy! Destination file %s already exists!".format(dest._path));
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
            Path dst_root = dest.toAbsolute;
            if (dst_root.exists) {
                enforce!PathException(
                    dest.isDir,
                    "Cannot copy! Destination %s already exists and it is not directory!".format(dest));
                dst_root = dst_root.join(this.baseName);
            }
            std.file.mkdirRecurse(dst_root._path);
            auto src_root = this.toAbsolute();
            foreach (Path src; src_root.walk(SpanMode.breadth)) {
                auto dst = dst_root.join(src.relativeTo(src_root));
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

    void copyTo(in string dest, CopyMode copy_mode=CopyMode.Standard) const {
        copyTo(Path(dest), copy_mode);
    }

    unittest {
        import dshould;
        auto cdir = std.file.getcwd;
        Path root = createTempPath();
        scope(exit) {
            std.file.chdir(cdir);
            root.remove();
        }

        auto test_c_file = root.join("test-create.txt");

        // Create test file to copy
        test_c_file.exists.should.be(false);
        test_c_file.writeFile("Hello World");
        test_c_file.exists.should.be(true);

        // Test copy file when dest dir does not exists
        test_c_file.copyTo(
            root.join("test-copy-dst", "test.txt")
        ).should.throwA!(std.file.FileException);

        // Test copy file where dest dir exists and dest name specified
        root.join("test-copy-dst").exists().should.be(false);
        root.join("test-copy-dst").mkdir();
        root.join("test-copy-dst").exists().should.be(true);
        root.join("test-copy-dst", "test.txt").exists.should.be(false);
        test_c_file.copyTo(root.join("test-copy-dst", "test.txt"));
        root.join("test-copy-dst", "test.txt").exists.should.be(true);

        // Try to copy file when it is already exists in dest folder
        test_c_file.copyTo(
            root.join("test-copy-dst", "test.txt")
        ).should.throwA!PathException;

        // Try to copy file, when only dirname specified
        root.join("test-copy-dst", "test-create.txt").exists.should.be(false);
        test_c_file.copyTo(root.join("test-copy-dst"));
        root.join("test-copy-dst", "test-create.txt").exists.should.be(true);

        // Try to copy empty directory with its content
        root.join("test-copy-dir-empty").mkdir;
        root.join("test-copy-dir-empty").exists.should.be(true);
        root.join("test-copy-dir-empty-cpy").exists.should.be(false);
        root.join("test-copy-dir-empty").copyTo(
            root.join("test-copy-dir-empty-cpy"));
        root.join("test-copy-dir-empty").exists.should.be(true);
        root.join("test-copy-dir-empty-cpy").exists.should.be(true);

        // Create test dir with content to test copying non-empty directory
        root.join("test-dir").mkdir();
        root.join("test-dir", "f1.txt").writeFile("f1");
        root.join("test-dir", "d2").mkdir();
        root.join("test-dir", "d2", "f2.txt").writeFile("f2");

        // Test that test-dir content created
        root.join("test-dir").exists.should.be(true);
        root.join("test-dir").isDir.should.be(true);
        root.join("test-dir", "f1.txt").exists.should.be(true);
        root.join("test-dir", "f1.txt").isFile.should.be(true);
        root.join("test-dir", "d2").exists.should.be(true);
        root.join("test-dir", "d2").isDir.should.be(true);
        root.join("test-dir", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir", "d2", "f2.txt").isFile.should.be(true);

        // Copy non-empty dir to unexisting location
        root.join("test-dir-cpy-1").exists.should.be(false);
        root.join("test-dir").copyTo(root.join("test-dir-cpy-1"));

        // Test that dir copied successfully
        root.join("test-dir-cpy-1").exists.should.be(true);
        root.join("test-dir-cpy-1").isDir.should.be(true);
        root.join("test-dir-cpy-1", "f1.txt").exists.should.be(true);
        root.join("test-dir-cpy-1", "f1.txt").isFile.should.be(true);
        root.join("test-dir-cpy-1", "d2").exists.should.be(true);
        root.join("test-dir-cpy-1", "d2").isDir.should.be(true);
        root.join("test-dir-cpy-1", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir-cpy-1", "d2", "f2.txt").isFile.should.be(true);

        // Copy non-empty dir to existing location
        root.join("test-dir-cpy-2").exists.should.be(false);
        root.join("test-dir-cpy-2").mkdir;
        root.join("test-dir-cpy-2").exists.should.be(true);

        // Copy directory to already existing dir
        root.join("test-dir").copyTo(root.join("test-dir-cpy-2"));

        // Test that dir copied successfully
        root.join("test-dir-cpy-2", "test-dir").exists.should.be(true);
        root.join("test-dir-cpy-2", "test-dir").isDir.should.be(true);
        root.join("test-dir-cpy-2", "test-dir", "f1.txt").exists.should.be(true);
        root.join("test-dir-cpy-2", "test-dir", "f1.txt").isFile.should.be(true);
        root.join("test-dir-cpy-2", "test-dir", "d2").exists.should.be(true);
        root.join("test-dir-cpy-2", "test-dir", "d2").isDir.should.be(true);
        root.join("test-dir-cpy-2", "test-dir", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir-cpy-2", "test-dir", "d2", "f2.txt").isFile.should.be(true);

        // Change dir to our temp directory and test copying using
        // relative paths
        root.chdir;

        // Copy content using relative paths
        root.join("test-dir-cpy-3").exists.should.be(false);
        Path("test-dir-cpy-3").exists.should.be(false);
        Path("test-dir").copyTo("test-dir-cpy-3");

        // Test that content was copied in right way
        root.join("test-dir-cpy-3").exists.should.be(true);
        root.join("test-dir-cpy-3").isDir.should.be(true);
        root.join("test-dir-cpy-3", "f1.txt").exists.should.be(true);
        root.join("test-dir-cpy-3", "f1.txt").isFile.should.be(true);
        root.join("test-dir-cpy-3", "d2").exists.should.be(true);
        root.join("test-dir-cpy-3", "d2").isDir.should.be(true);
        root.join("test-dir-cpy-3", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir-cpy-3", "d2", "f2.txt").isFile.should.be(true);

        // Try to copy to already existing file
        root.join("test-dir-cpy-4").writeFile("Test");

        // Expect error
        root.join("test-dir").copyTo("test-dir-cpy-4").should.throwA!PathException;

        version(Posix) {
            // Prepare test dir in user's home directory
            Path home_tmp = createTempPath("~", "tmp-d-test");
            scope(exit) home_tmp.remove();

            // Test if home_tmp created in right way and ensure that
            // dest for copy dir does not exists
            home_tmp.parent.toString.should.equal(std.path.expandTilde("~"));
            home_tmp.isAbsolute.should.be(true);
            home_tmp.join("test-dir").exists.should.be(false);

            // Copy test-dir to home_tmp
            import std.algorithm: startsWith;
            auto home_tmp_rel = home_tmp.baseName;
            string home_tmp_tilde = "~/%s".format(home_tmp_rel);
            home_tmp_tilde.startsWith("~/tmp-d-test").should.be(true);
            root.join("test-dir").copyTo(home_tmp_tilde);

            // Test that content was copied in right way
            home_tmp.join("test-dir").exists.should.be(true);
            home_tmp.join("test-dir").isDir.should.be(true);
            home_tmp.join("test-dir", "f1.txt").exists.should.be(true);
            home_tmp.join("test-dir", "f1.txt").isFile.should.be(true);
            home_tmp.join("test-dir", "d2").exists.should.be(true);
            home_tmp.join("test-dir", "d2").isDir.should.be(true);
            home_tmp.join("test-dir", "d2", "f2.txt").exists.should.be(true);
            home_tmp.join("test-dir", "d2", "f2.txt").isFile.should.be(true);
        } 



    }

    void remove() const {
        if (isFile) std.file.remove(_path.expandTilde);
        else std.file.rmdirRecurse(_path.expandTilde);
    }

    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Try to remove unexisting file
        root.join("unexising-file.txt").remove.should.throwA!(std.file.FileException);

        // Try to remove file
        root.join("test-file.txt").exists.should.be(false);
        root.join("test-file.txt").writeFile("test");
        root.join("test-file.txt").exists.should.be(true);
        root.join("test-file.txt").remove();
        root.join("test-file.txt").exists.should.be(false);

        // Create test dir with contents
        root.join("test-dir").mkdir();
        root.join("test-dir", "f1.txt").writeFile("f1");
        root.join("test-dir", "d2").mkdir();
        root.join("test-dir", "d2", "f2.txt").writeFile("f2");

        // Ensure test dir with contents created
        root.join("test-dir").exists.should.be(true);
        root.join("test-dir").isDir.should.be(true);
        root.join("test-dir", "f1.txt").exists.should.be(true);
        root.join("test-dir", "f1.txt").isFile.should.be(true);
        root.join("test-dir", "d2").exists.should.be(true);
        root.join("test-dir", "d2").isDir.should.be(true);
        root.join("test-dir", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir", "d2", "f2.txt").isFile.should.be(true);

        // Remove test directory
        root.join("test-dir").remove();

        // Ensure directory was removed
        root.join("test-dir").exists.should.be(false);
        root.join("test-dir", "f1.txt").exists.should.be(false);
        root.join("test-dir", "d2").exists.should.be(false);
        root.join("test-dir", "d2", "f2.txt").exists.should.be(false);


        version(Posix) {
            // Prepare test dir in user's home directory
            Path home_tmp = createTempPath("~", "tmp-d-test");
            scope(exit) home_tmp.remove();

            // Create test dir with contents
            home_tmp.join("test-dir").mkdir();
            home_tmp.join("test-dir", "f1.txt").writeFile("f1");
            home_tmp.join("test-dir", "d2").mkdir();
            home_tmp.join("test-dir", "d2", "f2.txt").writeFile("f2");

            // Remove created directory
            Path("~").join(home_tmp.baseName).toAbsolute.toString.should.equal(home_tmp.toString);
            Path("~").join(home_tmp.baseName, "test-dir").remove();

            // Ensure directory was removed
            home_tmp.join("test-dir").exists.should.be(false);
            home_tmp.join("test-dir", "f1.txt").exists.should.be(false);
            home_tmp.join("test-dir", "d2").exists.should.be(false);
            home_tmp.join("test-dir", "d2", "f2.txt").exists.should.be(false);
        }
    }

    void rename(in Path to) const {
        // TODO: Add support for recursive renames
        // TODO: Add support to move files between filesystems
        enforce!PathException(
            !to.exists,
            "Destination %s already exists!".format(to));
        return std.file.rename(_path.expandTilde, to._path.expandTilde);
    }

    void rename(in string to) const {
        return rename(Path(to));
    }

    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Create file
        root.join("test-file.txt").exists.should.be(false);
        root.join("test-file-new.txt").exists.should.be(false);
        root.join("test-file.txt").writeFile("test");
        root.join("test-file.txt").exists.should.be(true);
        root.join("test-file-new.txt").exists.should.be(false);

        // Rename file
        root.join("test-file.txt").exists.should.be(true);
        root.join("test-file-new.txt").exists.should.be(false);
        root.join("test-file.txt").rename(root.join("test-file-new.txt"));
        root.join("test-file.txt").exists.should.be(false);
        root.join("test-file-new.txt").exists.should.be(true);

        // Try to move file to existing directory
        root.join("my-dir").mkdir;
        root.join("test-file-new.txt").rename(root.join("my-dir")).should.throwA!PathException;

        // Try to rename one olready existing dir to another
        root.join("other-dir").mkdir;
        root.join("my-dir").exists.should.be(true);
        root.join("other-dir").exists.should.be(true);
        root.join("my-dir").rename(root.join("other-dir")).should.throwA!PathException;

        // Create test dir with contents
        root.join("test-dir").mkdir();
        root.join("test-dir", "f1.txt").writeFile("f1");
        root.join("test-dir", "d2").mkdir();
        root.join("test-dir", "d2", "f2.txt").writeFile("f2");

        // Ensure test dir with contents created
        root.join("test-dir").exists.should.be(true);
        root.join("test-dir").isDir.should.be(true);
        root.join("test-dir", "f1.txt").exists.should.be(true);
        root.join("test-dir", "f1.txt").isFile.should.be(true);
        root.join("test-dir", "d2").exists.should.be(true);
        root.join("test-dir", "d2").isDir.should.be(true);
        root.join("test-dir", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir", "d2", "f2.txt").isFile.should.be(true);

        // Try to rename directory
        root.join("test-dir").rename(root.join("test-dir-new"));

        // Ensure old dir does not exists anymore
        root.join("test-dir").exists.should.be(false);
        root.join("test-dir", "f1.txt").exists.should.be(false);
        root.join("test-dir", "d2").exists.should.be(false);
        root.join("test-dir", "d2", "f2.txt").exists.should.be(false);

        // Ensure test dir was renamed successfully
        root.join("test-dir-new").exists.should.be(true);
        root.join("test-dir-new").isDir.should.be(true);
        root.join("test-dir-new", "f1.txt").exists.should.be(true);
        root.join("test-dir-new", "f1.txt").isFile.should.be(true);
        root.join("test-dir-new", "d2").exists.should.be(true);
        root.join("test-dir-new", "d2").isDir.should.be(true);
        root.join("test-dir-new", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir-new", "d2", "f2.txt").isFile.should.be(true);


        version(Posix) {
            // Prepare test dir in user's home directory
            Path home_tmp = createTempPath("~", "tmp-d-test");
            scope(exit) home_tmp.remove();

            // Ensure that there is no test dir in our home/based temp dir;
            home_tmp.join("test-dir").exists.should.be(false);
            home_tmp.join("test-dir", "f1.txt").exists.should.be(false);
            home_tmp.join("test-dir", "d2").exists.should.be(false);
            home_tmp.join("test-dir", "d2", "f2.txt").exists.should.be(false);

            root.join("test-dir-new").rename(
                    Path("~").join(home_tmp.baseName, "test-dir"));

            // Ensure test dir was renamed successfully
            home_tmp.join("test-dir").exists.should.be(true);
            home_tmp.join("test-dir").isDir.should.be(true);
            home_tmp.join("test-dir", "f1.txt").exists.should.be(true);
            home_tmp.join("test-dir", "f1.txt").isFile.should.be(true);
            home_tmp.join("test-dir", "d2").exists.should.be(true);
            home_tmp.join("test-dir", "d2").isDir.should.be(true);
            home_tmp.join("test-dir", "d2", "f2.txt").exists.should.be(true);
            home_tmp.join("test-dir", "d2", "f2.txt").isFile.should.be(true);
        }
    }

    void mkdir(in bool recursive=false) const {
        if (recursive) std.file.mkdirRecurse(std.path.expandTilde(_path));
        else std.file.mkdir(std.path.expandTilde(_path));
    }

    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        root.join("test-dir").exists.should.be(false);
        root.join("test-dir", "subdir").exists.should.be(false);

        root.join("test-dir", "subdir").mkdir().should.throwA!(std.file.FileException);

        root.join("test-dir").mkdir();
        root.join("test-dir").exists.should.be(true);
        root.join("test-dir", "subdir").exists.should.be(false);

        root.join("test-dir", "subdir").mkdir();

        root.join("test-dir").exists.should.be(true);
        root.join("test-dir", "subdir").exists.should.be(true);
    }

    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        root.join("test-dir").exists.should.be(false);
        root.join("test-dir", "subdir").exists.should.be(false);

        root.join("test-dir", "subdir").mkdir(true);

        root.join("test-dir").exists.should.be(true);
        root.join("test-dir", "subdir").exists.should.be(true);
    }


    auto openFile(in string openMode = "rb") const {
        static import std.stdio;

        return std.stdio.File(_path.expandTilde, openMode);
    }

    void writeFile(in void[] buffer) const {
        return std.file.write(_path.expandTilde, buffer);
    }

    void appendFile(in void[] buffer) const {
        return std.file.append(_path.expandTilde, buffer);
    }

    auto readFile() const {
        return std.file.read(_path.expandTilde);
    }

    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        auto test_c_file = root.join("test-create.txt");
        test_c_file.exists.should.be(false);

        // Test file read/write
        test_c_file.writeFile("Hello World");
        test_c_file.exists.should.be(true);
        test_c_file.readFile.should.equal("Hello World");
        test_c_file.appendFile("!");
        test_c_file.readFile.should.equal("Hello World!");

        // Try to remove file
        test_c_file.exists.should.be(true);
        test_c_file.remove();
        test_c_file.exists.should.be(false);
    }




    // TODO: to add:
    //       - match pattern
    //       - Handle symlinks
}
