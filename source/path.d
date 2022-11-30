/// This module defines Path - the main structure that represent's highlevel interface to paths
module thepath.path;

static public import std.file: SpanMode;
static private import std.path;
static private import std.file;
static private import std.stdio;
private static import std.process;
private import std.path: expandTilde;
private import std.format: format;
private import std.exception: enforce;
private import thepath.utils: createTempPath, createTempDirectory;
private import thepath.exception: PathException;


/** Main struct to work with paths.
  **/
struct Path {
    // TODO: Deside if we need to make _path by default configured to current directory or to allow path to be null
    private string _path=null; //".";

    /** Main constructor to build new Path from string
      * Params:
      *    path = string representation of path to point to
      **/
    this(in string path) {
        _path = path;
    }

    /** Constructor that allows to build path from segments
      * Params:
      *     segments = array of segments to build path from
     **/
    this(in string[] segments...) {
        _path = std.path.buildNormalizedPath(segments);
    }

    ///
    unittest {
        import dshould;

        version(Posix) {
            Path("foo", "moo", "boo").toString.should.equal("foo/moo/boo");
            Path("/foo/moo", "boo").toString.should.equal("/foo/moo/boo");
        }
    }

    /** Check if path is null
      * Returns: true if this path is null (not set)
      **/
    bool isNull() const {
        return _path is null;
    }

    ///
    unittest {
        import dshould;

        Path().isNull.should.be(true);
        Path(".").isNull.should.be(false);
        Path("some-path").isNull.should.be(false);

        Path default_path;

        default_path.isNull.should.be(true);
    }

    /** Check if path is valid.
      * Returns: true if this is valid path.
      **/
    bool isValid() const {
        return std.path.isValidPath(_path);
    }

    ///
    unittest {
        import dshould;

        Path().isValid.should.be(false);
        Path(".").isValid.should.be(true);
        Path("some-path").isValid.should.be(true);
    }

    /// Check if path is absolute
    bool isAbsolute() const {
        return std.path.isAbsolute(_path);
    }

    ///
    unittest {
        import dshould;

        Path().isValid.should.be(false);
        Path(".").isAbsolute.should.be(false);
        Path("some-path").isAbsolute.should.be(false);

        version(Posix) {
            Path("/test/path").isAbsolute.should.be(true);
        }
    }

    /// Check if path starts at root directory (or drive letter)
    bool isRooted() const {
        return std.path.isRooted(_path);
    }

    /// Determine if path is file.
    bool isFile() const {
        return std.file.isFile(_path.expandTilde);
    }

    /// Determine if path is directory.
    bool isDir() const {
        return std.file.isDir(_path.expandTilde);
    }

    /// Determine if path is symlink
    bool isSymlink() const {
        return std.file.isSymlink(_path.expandTilde);
    }

    /// Check if path exists
    bool exists() const {
        return std.file.exists(_path.expandTilde);
    }

    ///
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

    /// Return path as string
    string toString() const {
        return _path;
    }


    /** Convert path to absolute path.
      * Returns: new instance of Path that represents current path converted to
      *          absolute path.
      *          Also, this method will automatically do tilde expansion and
      *          normalization of path.
      **/
    Path toAbsolute() const {
        return Path(
            std.path.buildNormalizedPath(
                std.path.absolutePath(_path.expandTilde)));
    }

    ///
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

    /** Expand tilde (~) in current path.
      * Returns: New path with tilde expaded
      **/
    Path expandTilde() const {
        return Path(std.path.expandTilde(_path));
    }

    /** Normalize path.
      * Returns: new normalized Path.
      **/
    Path normalize() const {
        import std.array : array;
        import std.exception : assumeUnique;
        auto result = std.path.asNormalizedPath(_path);
        return Path(assumeUnique(result.array));
    }

    ///
    unittest {
        import dshould;

        version(Posix) {
            Path("foo").normalize.toString.should.equal("foo");
            Path("../foo/../moo").normalize.toString.should.equal("../moo");
            Path("/foo/./moo/../bar").normalize.toString.should.equal("/foo/bar");
        }
    }

    /** Join multiple path segments and return single path.
      * Params:
      *     segments = Array of strings (or Path) to build new path..
      * Returns:
      *     New path build from current path and provided segments
      **/
    Path join(in string[] segments...) const {
        string[] args=[cast(string)_path];
        foreach(s; segments) args ~= s;
        return Path(std.path.buildPath(args));
    }

    /// ditto
    Path join(in Path[] segments...) const {
        string[] args=[];
        foreach(p; segments) args ~= p.toString();
        return this.join(args);
    }

    ///
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


    /** determine parent path of this path
      * Returns:
      *     Absolute Path to parent directory.
      **/
    Path parent() const {
        if (isAbsolute()) {
            return Path(std.path.dirName(_path));
        } else {
            return this.toAbsolute.parent;
        }
    }

    ///
    unittest {
        import dshould;
        version(Posix) {
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

    /** Return this path as relative to base
      * Params:
      *     base = base path to make this path relative to. Must be absolute.
      * Returns:
      *     new Path that is relative to base but represent same location
      *     as this path.
      * Throws:
      *     PathException if base path is not valid or not absolute
      **/
    Path relativeTo(in Path base) const {
        enforce!PathException(
            base.isValid && base.isAbsolute,
            "Base path must be valid and absolute");
        return Path(std.path.relativePath(_path, base._path));
    }

    /// ditto
    Path relativeTo(in string base) const {
        return relativeTo(Path(base));
    }

    ///
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

    /// Returns extension for current path
    string extension() const {
        return std.path.extension(_path);
    }

    /// Returns base name of current path
    string baseName() const {
        return std.path.baseName(_path);
    }

    ///
    unittest {
        import dshould;
        Path("foo").baseName.should.equal("foo");
        Path("foo", "moo").baseName.should.equal("moo");
        Path("foo", "moo", "test.txt").baseName.should.equal("test.txt");
    }

    /// Return size of file specified by path
    ulong getSize() const {
        return std.file.getSize(_path.expandTilde);
    }

    ///
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

    /** Resolve link and return real path.
      * Available only for posix systems.
      * If path is not symlink, then return it unchanged
      **/
    version(Posix) Path readLink() const {
        if (isSymlink()) {
            return Path(std.file.readLink(_path.expandTilde));
        } else {
            return this;
        }
    }

    /** Iterate over all files and directories inside path;
      *
      * Params:
      *     mode = The way to traverse directories. See [docs](https://dlang.org/phobos/std_file.html#SpanMode)
      *     followSymlink = do we need to follow symlinks of not. By default set to True.
      *
      * Examples:
      * ---
      * // Iterate over paths in current directory
      * foreach (Path p; Path(".").walk(SpanMode.breadth)) {
      *     if (p.isFile) writeln(p);
      * ---
      **/
    auto walk(SpanMode mode=SpanMode.shallow, bool followSymlink=true) const {
        import std.algorithm.iteration: map;
        return std.file.dirEntries(
            _path, mode, followSymlink).map!(a => Path(a));

    }

    /// Change current working directory to this.
    void chdir() const {
        std.file.chdir(_path.expandTilde);
    }

    ///
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

            // Change current working directory to tmp-dir-name
            Path("~", tmp_dir_name).chdir;
            std.file.getcwd.should.equal(home_tmp._path);
        }
    }

    /** Copy single file to destination.
      * If destination does not exists,
      * then file will be copied exactly to that path.
      * If destination already exists and it is directory, then method will
      * try to copy file inside that directory with same name.
      * If destination already exists and it is file,
      * then depending on `rewrite` param file will be owerwritten or
      * PathException will be thrown.
      * Params:
      *     dest = destination path to copy file to. Could be new file path,
      *            or directory where to copy file.
      *     rewrite = do we need to rewrite file if it already exists?
      * Throws:
      *     PathException if source file does not exists or
      *         if destination already exists and
      *         it is not a directory and rewrite is set to false.
      **/
    void copyFileTo(in Path dest, in bool rewrite=false) const {
        enforce!PathException(
            this.exists,
            "Cannot Copy! Source file %s does not exists!".format(_path));
        if (dest.exists) {
            if (dest.isDir) {
                this.copyFileTo(dest.join(this.baseName), rewrite);
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

    ///
    unittest {
        import dshould;

        // Prepare temporary path for test
        auto cdir = std.file.getcwd;
        Path root = createTempPath();
        scope(exit) {
            std.file.chdir(cdir);
            root.remove();
        }

        // Create test directory structure
        root.join("test-file.txt").writeFile("test");
        root.join("test-file-2.txt").writeFile("test-2");
        root.join("test-dst-dir").mkdir;

        // Test copy file by path
        root.join("test-dst-dir", "test1.txt").exists.should.be(false);
        root.join("test-file.txt").copyFileTo(root.join("test-dst-dir", "test1.txt"));
        root.join("test-dst-dir", "test1.txt").exists.should.be(true);

        // Test copy file by path with rewrite
        root.join("test-dst-dir", "test1.txt").readFile.should.equal("test");
        root.join("test-file-2.txt").copyFileTo(root.join("test-dst-dir", "test1.txt")).should.throwA!PathException;
        root.join("test-file-2.txt").copyFileTo(root.join("test-dst-dir", "test1.txt"), true);
        root.join("test-dst-dir", "test1.txt").readFile.should.equal("test-2");

        // Test copy file inside dir
        root.join("test-dst-dir", "test-file.txt").exists.should.be(false);
        root.join("test-file.txt").copyFileTo(root.join("test-dst-dir"));
        root.join("test-dst-dir", "test-file.txt").exists.should.be(true);

        // Test copy file inside dir with rewrite
        root.join("test-file.txt").writeFile("test-42");
        root.join("test-dst-dir", "test-file.txt").readFile.should.equal("test");
        root.join("test-file.txt").copyFileTo(root.join("test-dst-dir")).should.throwA!PathException;
        root.join("test-file.txt").copyFileTo(root.join("test-dst-dir"), true);
        root.join("test-dst-dir", "test-file.txt").readFile.should.equal("test-42");
    }

    /** Copy file or directory to destination
      * If source is a file, then copyFileTo will be use to copy it.
      * If source is a directory, then more complex logic will be applied:
      *     - if dest already exists and it is not dir, then exception will be raised.
      *     - if dest already exists and it is dir, then source dir will be copied inseide that dir with it's name
      *     - if dest does not exists, then current directory will be copied to dest path.
      *
      * Note, that work with symlinks have to be improved. Not tested yet.
      *
      * Params:
      *     dest = destination path to copy content of this.
      * Throws:
      *     PathException when cannot copy
      **/
    void copyTo(in Path dest) const {
        import std.stdio;
        if (isDir) {
            Path dst_root = dest.toAbsolute;
            if (dst_root.exists) {
                enforce!PathException(
                    dst_root.isDir,
                    "Cannot copy! Destination %s already exists and it is not directory!".format(dst_root));
                dst_root = dst_root.join(this.baseName);
                enforce!PathException(
                    !dst_root.exists,
                    "Cannot copy! Destination %s already exists!".format(dst_root));
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

    /// ditto
    void copyTo(in string dest) const {
        copyTo(Path(dest));
    }

    ///
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

        // Try again to copy non-empty dir to already existing dir
        // where dir with same base name already exists
        root.join("test-dir").copyTo(root.join("test-dir-cpy-2")).should.throwA!PathException;


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

    /** Remove file or directory referenced by this path.
      * This operation is recursive, so if path references to a direcotry,
      * then directory itself and all content inside referenced dir will be
      * removed
      **/
    void remove() const {
        if (isFile) std.file.remove(_path.expandTilde);
        else std.file.rmdirRecurse(_path.expandTilde);
    }

    ///
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

    /** Rename current path.
      *
      * Note: case of moving file/dir between filesystesm is not tested.
      *
      * Throws:
      *     PathException when destination already exists
      **/
    void rename(in Path to) const {
        // TODO: Add support to move files between filesystems
        enforce!PathException(
            !to.exists,
            "Destination %s already exists!".format(to));
        return std.file.rename(_path.expandTilde, to._path.expandTilde);
    }

    /// ditto
    void rename(in string to) const {
        return rename(Path(to));
    }

    ///
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

    /** Create directory by this path
      * Params:
      *     recursive = if set to true, then
      *         parent directories will be created if not exist
      * Throws:
      *     FileException if cannot create dir (it already exists)
      **/
    void mkdir(in bool recursive=false) const {
        if (recursive) std.file.mkdirRecurse(std.path.expandTilde(_path));
        else std.file.mkdir(std.path.expandTilde(_path));
    }

    ///
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

    ///
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

    /** Open file and return `std.stdio.File` struct with opened file
      * Params:
      *     openMode = string representing open mode with
      *         same semantic as in C standard lib
      *         $(HTTP cplusplus.com/reference/clibrary/cstdio/fopen.html, fopen) function.
      * Returns:
      *     std.stdio.File struct
      **/
    std.stdio.File openFile(in string openMode = "rb") const {
        static import std.stdio;

        return std.stdio.File(_path.expandTilde, openMode);
    }

    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        auto test_file = root.join("test-create.txt").openFile("wt");
        scope(exit) test_file.close();
        test_file.write("Test1");
        test_file.flush();
        root.join("test-create.txt").readFile().should.equal("Test1");
        test_file.write("12");
        test_file.flush();
        root.join("test-create.txt").readFile().should.equal("Test112");
    }

    /** Write data to file as is
      * Params:
      *     buffer = untypes array to write to file.
      * Throws:
      *     FileException in case of  error
      **/
    void writeFile(in void[] buffer) const {
        return std.file.write(_path.expandTilde, buffer);
    }

    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        root.join("test-write-1.txt").exists.should.be(false);
        root.join("test-write-1.txt").writeFile("Hello world");
        root.join("test-write-1.txt").exists.should.be(true);
        root.join("test-write-1.txt").readFile.should.equal("Hello world");

        ubyte[] data = [1, 7, 13, 5, 9];
        root.join("test-write-2.txt").exists.should.be(false);
        root.join("test-write-2.txt").writeFile(data);
        root.join("test-write-2.txt").exists.should.be(true);
        ubyte[] rdata = cast(ubyte[])root.join("test-write-2.txt").readFile;
        rdata.length.should.equal(5);
        rdata[0].should.equal(1);
        rdata[1].should.equal(7);
        rdata[2].should.equal(13);
        rdata[3].should.equal(5);
        rdata[4].should.equal(9);
    }

    /** Append data to file as is
      * Params:
      *     buffer = untypes array to write to file.
      * Throws:
      *     FileException in case of  error
      **/
    void appendFile(in void[] buffer) const {
        return std.file.append(_path.expandTilde, buffer);
    }

    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        ubyte[] data = [1, 7, 13, 5, 9];
        ubyte[] data2 = [8, 17];
        root.join("test-write-2.txt").exists.should.be(false);
        root.join("test-write-2.txt").writeFile(data);
        root.join("test-write-2.txt").appendFile(data2);
        root.join("test-write-2.txt").exists.should.be(true);
        ubyte[] rdata = cast(ubyte[])root.join("test-write-2.txt").readFile;
        rdata.length.should.equal(7);
        rdata[0].should.equal(1);
        rdata[1].should.equal(7);
        rdata[2].should.equal(13);
        rdata[3].should.equal(5);
        rdata[4].should.equal(9);
        rdata[5].should.equal(8);
        rdata[6].should.equal(17);
    }


    /** Read entire contents of file `name` and returns it as an untyped
      * array. If the file size is larger than `upTo`, only `upTo`
      * bytes are _read.
      * Params:
      *     upTo = if present, the maximum number of bytes to _read
      * Returns:
      *     Untyped array of bytes _read
      * Throws:
      *     FileException in case of error
      **/
    auto readFile(size_t upTo=size_t.max) const {
        return std.file.read(_path.expandTilde, upTo);
    }

    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        root.join("test-create.txt").exists.should.be(false);

        // Test file read/write/apppend
        root.join("test-create.txt").writeFile("Hello World");
        root.join("test-create.txt").exists.should.be(true);
        root.join("test-create.txt").readFile.should.equal("Hello World");
        root.join("test-create.txt").appendFile("!");
        root.join("test-create.txt").readFile.should.equal("Hello World!");

        // Try to remove file
        root.join("test-create.txt").exists.should.be(true);
        root.join("test-create.txt").remove();
        root.join("test-create.txt").exists.should.be(false);

        // Try to read data as bytes
        ubyte[] data = [1, 7, 13, 5, 9];
        root.join("test-write-2.txt").exists.should.be(false);
        root.join("test-write-2.txt").writeFile(data);
        root.join("test-write-2.txt").exists.should.be(true);
        ubyte[] rdata = cast(ubyte[])root.join("test-write-2.txt").readFile;
        rdata.length.should.equal(5);
        rdata[0].should.equal(1);
        rdata[1].should.equal(7);
        rdata[2].should.equal(13);
        rdata[3].should.equal(5);
        rdata[4].should.equal(9);
    }

    /** Read text content of the file.
      * Technicall just a call to $(REF readText, std, file).
      *
      * Params:
      *     S = template parameter that represents type of string to read
      * Returns:
      *     text read from file.
      * Throws:
      *     $(LREF FileException) if there is an error reading the file,
      *     $(REF UTFException, std, utf) on UTF decoding error.
      **/
    auto readFileText(S=string)() {
        return std.file.readText!S(_path.expandTilde);
    }


    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Write some utf-8 data from the file
        root.join("test-utf-8.txt").writeFile("Hello World");

        // Test that we read correct value
        root.join("test-utf-8.txt").readFileText.should.equal("Hello World");

        // Write some data in UTF-16 with BOM
        root.join("test-utf-16.txt").writeFile("\uFEFFhi humans"w);

        // Read utf-16 content
        auto content = root.join("test-utf-16.txt").readFileText!wstring;

        // Strip BOM if present.
        import std.algorithm.searching : skipOver;
        content.skipOver('\uFEFF');

        // Ensure we read correct value
        content.should.equal("hi humans"w);
    }

    /** Get attributes of the path
      *
      *  Returns:
      *      uint - represening attributes of the file
      **/
    auto getAttributes() {
        return std.file.getAttributes(_path.expandTilde);
    }

    /// Test if file has permission to run
    version(Posix) unittest {
        import dshould;
        import std.conv: octal;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Here we have to import bitmasks from system;
        import core.sys.posix.sys.stat;

        root.join("test-file.txt").writeFile("Hello World!");
        auto attributes = root.join("test-file.txt").getAttributes();

        // Test that file has permissions 644
        (attributes & octal!644).should.equal(octal!644);

        // Test that file is readable by user
        (attributes & S_IRUSR).should.equal(S_IRUSR);

        // Test that file is not writeable by others
        (attributes & S_IWOTH).should.not.equal(S_IWOTH);
    }

    /** Check if file has numeric attributes.
      * This method check if all bits specified by param 'attributes' are set.
      *
      * Params:
      *     attributes = numeric attributes (bit mask) to check
      *
      * Returns:
      *     true if all attributes present on file.
      *     false if at lease one bit specified by attributes is not set.
      *
      **/
    bool hasAttributes(in uint attributes) {
        return (this.getAttributes() & attributes) == attributes;

    }

    /// Example of checking attributes of file.
    version(Posix) unittest {
        import dshould;
        import std.conv: octal;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Here we have to import bitmasks from system;
        import core.sys.posix.sys.stat;

        root.join("test-file.txt").writeFile("Hello World!");

        // Check that file has numeric permissions 644
        root.join("test-file.txt").hasAttributes(octal!644).should.be(true);

        // Check that it is not 755
        root.join("test-file.txt").hasAttributes(octal!755).should.be(false);

        // Check that every user can read this file.
        root.join("test-file.txt").hasAttributes(octal!444).should.be(true);

        // Check that owner can read the file
        // (do not check access rights for group and others)
        root.join("test-file.txt").hasAttributes(octal!400).should.be(true);

        // Test that file is readable by user
        root.join("test-file.txt").hasAttributes(S_IRUSR).should.be(true);

        // Test that file is writable by user
        root.join("test-file.txt").hasAttributes(S_IWUSR).should.be(true);

        // Test that file is not writable by others
        root.join("test-file.txt").hasAttributes(S_IWOTH).should.be(false);
    }

    /** Set attributes of the path
      *
      *  Params:
      *      attributes = value representing attributes to set on path.
     **/

    void setAttributes(in uint attributes) {
        std.file.setAttributes(_path, attributes);
    }

    /// Example of changing attributes of file.
    version(Posix) unittest {
        import dshould;
        import std.conv: octal;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Here we have to import bitmasks from system;
        import core.sys.posix.sys.stat;

        root.join("test-file.txt").writeFile("Hello World!");

        // Check that file has numeric permissions 644
        root.join("test-file.txt").hasAttributes(octal!644).should.be(true);


        auto attributes = root.join("test-file.txt").getAttributes();

        // Test that file is readable by user
        (attributes & S_IRUSR).should.equal(S_IRUSR);

        // Test that file is not writeable by others
        (attributes & S_IWOTH).should.not.equal(S_IWOTH);

        // Add right to write file by others
        root.join("test-file.txt").setAttributes(attributes | S_IWOTH);

        // Test that file is now writable by others
        root.join("test-file.txt").hasAttributes(S_IWOTH).should.be(true);

        // Test that numeric permissions changed
        root.join("test-file.txt").hasAttributes(octal!646).should.be(true);

        // Set attributes as numeric value
        root.join("test-file.txt").setAttributes(octal!660);

        // Test that no group users can write the file
        root.join("test-file.txt").hasAttributes(octal!660).should.be(true);

        // Test that others do not have any access to the file
        root.join("test-file.txt").hasAttributes(octal!104).should.be(false);
        root.join("test-file.txt").hasAttributes(octal!106).should.be(false);
        root.join("test-file.txt").hasAttributes(octal!107).should.be(false);
        root.join("test-file.txt").hasAttributes(S_IWOTH).should.be(false);
        root.join("test-file.txt").hasAttributes(S_IROTH).should.be(false);
        root.join("test-file.txt").hasAttributes(S_IXOTH).should.be(false);
    }

    /** Execute the file pointed by path

        Params:
            args = arguments to be passed to program
            env = associative array that represent environment variables
               to be passed to program pointed by path
            workDir = Working directory for new process.
            config = Parameters for process creation.
               See See $(REF Config, std, process)
            maxOutput = Max bytes of output to be captured
        Returns:
            An $(D std.typecons.Tuple!(int, "status", string, "output")).
     **/
    auto execute(P=string)(in string[] args=[],
            in string[string] env=null,
            in P workDir=null,
            std.process.Config config=std.process.Config.none,
            size_t maxOutput=size_t.max)
    if (is(P == string)) {
        return std.process.execute(
            this._path ~ args, env, config, maxOutput, workDir);
    }

    /// ditto
    auto execute(P=string)(in string[] args=[],
            in string[string] env=null,
            in P workDir=null,
            std.process.Config config=std.process.Config.none,
            size_t maxOutput=size_t.max)
    if (is(P == Path)) {
        return std.process.execute(
            this._path ~ args, env, config, maxOutput, workDir.toString);
    }


    ///
    version(Posix) unittest {
        import dshould;
        import std.conv: octal;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Create simple test script that will print its arguments
        root.join("test-script").writeFile(
            "#!/usr/bin/env bash\necho \"$@\";");

        // Add permission to run this script
        root.join("test-script").setAttributes(octal!755);

        // Run test script without args
        auto status1 = root.join("test-script").execute;
        status1.status.should.be(0);
        status1.output.should.equal("\n");

        auto status2 = root.join("test-script").execute(["hello", "world"]);
        status2.status.should.be(0);
        status2.output.should.equal("hello world\n");

        auto status3 = root.join("test-script").execute(["hello", "world\nplus"]);
        status3.status.should.be(0);
        status3.output.should.equal("hello world\nplus\n");

        auto status4 = root.join("test-script").execute(
                ["hello", "world"],
                null,
                root);
        status4.status.should.be(0);
        status4.output.should.equal("hello world\n");
    }

    // TODO: to add:
    //       - match pattern
    //       - Handle symlinks
}
