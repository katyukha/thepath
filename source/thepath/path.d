/// This module defines Path - the main structure that represent's highlevel interface to paths
module thepath.path;

static public import std.file: SpanMode;
static private import std.path;
static private import std.file;
static private import std.stdio;
static private import std.process;
static private import std.algorithm;
private import std.typecons: Nullable, nullable;
private import std.path: expandTilde;
private import std.format: format;
private import std.exception: enforce;
private import thepath.utils: createTempPath, createTempDirectory;
private import thepath.exception: PathException;


/** Path - struct that represents single path object, and provides convenient
  * interface to deal with filesystem paths.
  **/
struct Path {
    private string _path;

    /** Main constructor to build new Path from string
      * Params:
      *    path = string representation of path to point to
      **/
    @safe pure nothrow this(in string path) {
        _path = path;
    }

    /** Constructor that allows to build path from segments
      * Params:
      *     segments = array of segments to build path from
      **/
    @safe pure nothrow this(in string[] segments...) {
        _path = std.path.buildNormalizedPath(segments);
    }

    ///
    unittest {
        import dshould;

        version(Posix) {
            Path("foo", "moo", "boo").toString.should.equal("foo/moo/boo");
            Path("/foo/moo", "boo").toString.should.equal("/foo/moo/boo");
            Path("/", "foo", "moo").toString.should.equal("/foo/moo");
        }
    }

    invariant {
        // TODO: it seems that this invariant is not needed.
        //       Try to find test case when it is needed
        assert(_path !is null, "Attempt to use uninitialized path!");
    }

    /** Check if path is valid.
      * Returns: true if this is valid path.
      **/
    @safe pure nothrow bool isValid() const {
        return std.path.isValidPath(_path);
    }

    ///
    unittest {
        import dshould;

        Path("").isValid.should.be(false);
        Path(".").isValid.should.be(true);
        Path("some-path").isValid.should.be(true);
        Path("test.txt").isValid.should.be(true);
    }

    /// Check if path is absolute
    @safe pure nothrow bool isAbsolute() const {
        return std.path.isAbsolute(_path);
    }

    ///
    unittest {
        import dshould;

        Path("").isAbsolute.should.be(false);
        Path(".").isAbsolute.should.be(false);
        Path("some-path").isAbsolute.should.be(false);

        version(Posix) {
            Path("/test/path").isAbsolute.should.be(true);
        }
    }

    /// Check if path starts at root directory (or drive letter)
    @safe pure nothrow bool isRooted() const {
        return std.path.isRooted(_path);
    }

    /// Check if current path is root (does not have parent)
    @safe pure bool isRoot() const {
        import std.path: isDirSeparator;

        version(Posix) {
            return _path == "/";
        } else version (Windows) {
            if (_path.length == 3 && _path[1] == ':' &&
                    isDirSeparator(_path[2])) {
                return true;
            } else if (_path.length == 1 && isDirSeparator(_path[0])) {
                return true;
            }
            return false;
        }
        else static assert(0, "unsupported platform");
    }

    /// Posix
    version(Posix) unittest {
        import dshould;
        Path("/").isRoot.should.be(true);
        Path("/some-dir").isRoot.should.be(false);
        Path("local").isRoot.should.be(false);
        Path("").isRoot.should.be(false);
    }

    /// Windows
    version(Windows) unittest {
        import dshould;
        Path(r"C:\").isRoot.should.be(true);
        Path(r"D:\").isRoot.should.be(true);
        Path(r"D:\some-dir").isRoot.should.be(false);
        Path(r"\").isRoot.should.be(true);
        Path(r"\local").isRoot.should.be(false);
        Path("").isRoot.should.be(false);
    }

    /// Check if current path is inside other path
    @safe bool isInside(in Path other) const {
        // TODO: May be there is better way to check if path
        //       is inside another path
        return std.algorithm.startsWith(
            this.toAbsolute.segments,
            other.toAbsolute.segments);
    }

    ///
    unittest {
        import dshould;

        Path("my", "dir", "42").isInside(Path("my", "dir")).should.be(true);
        Path("my", "dir", "42").isInside(Path("oth", "dir")).should.be(false);
    }


    /** Split path on segments.
      * Under the hood, this method uses $(REF pathSplitter, std, path)
      **/
    @safe pure auto segments() const {
        return std.path.pathSplitter(_path);
    }

    ///
    unittest {
        import dshould;

        Path("t1", "t2", "t3").segments.should.equal(["t1", "t2", "t3"]);
    }

    /// Determine if path is file.
    @safe bool isFile() const {
        return std.file.isFile(_path.expandTilde);
    }

    /// Determine if path is directory.
    @safe bool isDir() const {
        return std.file.isDir(_path.expandTilde);
    }

    /// Determine if path is symlink
    @safe bool isSymlink() const {
        return std.file.isSymlink(_path.expandTilde);
    }

    /** Override comparison operators to use OS-specific case-sensitivity
      * rules. They could be used for sorting of path array for example.
      **/
	@safe pure nothrow int opCmp(in Path other) const
	{
		return std.path.filenameCmp(this._path, other._path);
	}

	/// ditto
	@safe pure nothrow int opCmp(in ref Path other) const
	{
		return std.path.filenameCmp(this._path, other._path);
	}

    /// Test comparison operators
    unittest {
        import dshould;
        import std.algorithm: sort;
        Path[] ap = [
            Path("a", "d", "c"),
            Path("a", "c", "e"),
            Path("g", "a", "d"),
            Path("ab", "c", "d"),
        ];

        ap.sort();

        // We just compare segments of paths
        // (to avoid calling code that have to checked by this test in check itself)
        ap[0].segments.should.equal(Path("a", "c", "e").segments);
        ap[1].segments.should.equal(Path("a", "d", "c").segments);
        ap[2].segments.should.equal(Path("ab", "c", "d").segments);
        ap[3].segments.should.equal(Path("g", "a", "d").segments);

        ap.sort!("a > b");

        // We just compare segments of paths
        // (to avoid calling code that have to checked by this test in check itself)
        ap[0].segments.should.equal(Path("g", "a", "d").segments);
        ap[1].segments.should.equal(Path("ab", "c", "d").segments);
        ap[2].segments.should.equal(Path("a", "d", "c").segments);
        ap[3].segments.should.equal(Path("a", "c", "e").segments);

        // Check simple comparisons
        Path("a", "d", "g").should.be.greater(Path("a", "b", "c"));
        Path("g", "d", "r").should.be.less(Path("m", "g", "x"));
    }

	/** Override equality comparison operators
      **/
    @safe pure nothrow bool opEquals(in Path other) const
	{
		return opCmp(other) == 0;
	}

	/// ditto
	@safe pure nothrow bool opEquals(in ref Path other) const
	{
		return opCmp(other) == 0;
	}

    /// Test equality comparisons
    unittest {
        import dshould;

        Path("a", "b").should.equal(Path("a", "b"));
        Path("a", "b").should.not.equal(Path("a"));
        Path("a", "b").should.not.equal(Path("a", "b", "c"));
        Path("a", "b").should.not.equal(Path("a", "c"));
    }

    /** Compute hash of the Path to be able to use it as key
      * in asociative arrays.
      **/
    @safe nothrow size_t toHash() const {
        return typeid(_path).getHash(&_path);
    }

    ///
    unittest {
        import dshould;

        string[Path] arr;
        arr[Path("my", "path")] = "hello";
        arr[Path("w", "42")] = "world";

        arr[Path("my", "path")].should.equal("hello");
        arr[Path("w", "42")].should.equal("world");

        import core.exception: RangeError;
        arr[Path("x", "124")].should.throwA!RangeError;
    }

    /// Return current path (as absolute path)
    @safe static Path current() {
        return Path(".").toAbsolute;
    }

    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Save current directory
        auto cdir = std.file.getcwd;
        scope(exit) std.file.chdir(cdir);

        // Create directory structure
        root.join("dir1", "dir2", "dir3").mkdir(true);
        root.join("dir1", "dir2", "dir3").chdir;

        // Check that current path is equal to dir1/dir2/dir3 (current dir)
        version(OSX) {
            // On OSX we have to resolve symbolic links,
            // because result of createTempPath contains symmbolic links
            // for some reason, but current returns path with symlinks resolved
            Path.current.toString.should.equal(
                    root.join("dir1", "dir2", "dir3").realPath.toString);
        } else {
            Path.current.toString.should.equal(
                    root.join("dir1", "dir2", "dir3").toString);
        }
    }

    /// Get system's temp directory
    @safe static Path tempDir() {
        return Path(std.file.tempDir);
    }

    ///
    unittest {
        import dshould;
        Path.tempDir._path.should.equal(std.file.tempDir);
    }

    /// Check if path exists
    @safe nothrow bool exists() const {
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
    @safe pure nothrow string toString() const {
        return _path;
    }

    /** Return path as 0-terminated string.
      * Usually, could be used to interface with C libraries.
      *
      * Important Note: When passing a char* to a C function,
      * and the C function keeps it around for any reason,
      * make sure that you keep a reference to it in your D code.
      * Otherwise, it may become invalid during a garbage collection
      * cycle and cause a nasty bug when the C code tries to use it.
      **/
    @safe pure nothrow auto toStringz() const {
        import std.string: toStringz;
        return _path.toStringz;
    }

    ///
    unittest {
        import dshould;
        import core.stdc.string: strlen;

        auto p = Path("test");
        auto sz = p.toStringz;

        strlen(sz).should.equal(4);
        sz[4].should.equal('\0');
    }

    /** Convert path to absolute path.
      * Returns: new instance of Path that represents current path converted to
      *          absolute path.
      *          Also, this method will automatically do tilde expansion and
      *          normalization of path.
      * Throws: Exception if the specified base directory is not absolute.
      **/
    @safe Path toAbsolute() const {
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

            // Change current working directory to /tmp"
            std.file.chdir("/tmp");

            version(OSX) {
                // On OSX /tmp is symlink to /private/tmp
                Path("/tmp").realPath.should.equal(Path("/private/tmp"));
                Path("foo/moo").toAbsolute.toString.should.equal(
                    "/private/tmp/foo/moo");
                Path("../my-path").toAbsolute.toString.should.equal("/private/my-path");
            } else {
                Path("foo/moo").toAbsolute.toString.should.equal("/tmp/foo/moo");
                Path("../my-path").toAbsolute.toString.should.equal("/my-path");
            }

            Path("/a/path").toAbsolute.toString.should.equal("/a/path");

            string home_path = "~".expandTilde;
            home_path[0].should.equal('/');

            Path("~/my/path").toAbsolute.toString.should.equal("%s/my/path".format(home_path));
        }
    }

    /** Expand tilde (~) in current path.
      * Returns: New path with tilde expaded
      **/
    @safe nothrow Path expandTilde() const {
        return Path(std.path.expandTilde(_path));
    }

    /** Normalize path.
      * Returns: new normalized Path.
      **/
    @safe pure nothrow Path normalize() const {
        return Path(std.path.buildNormalizedPath(_path));
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
    @safe pure nothrow auto join(in string[] segments...) const {
        auto args=[_path] ~ segments;
        return Path(std.path.buildPath(args));
    }

    /// ditto
    @safe pure nothrow Path join(in Path[] segments...) const {
        string[] args=[];
        foreach(p; segments) args ~= p._path;
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
    @safe Path parent() const {
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

            version(OSX) {
                Path("parent/child").parent.toString.should.equal(
                    "/private/tmp/parent");
            } else {
                Path("parent/child").parent.toString.should.equal(
                    "/tmp/parent");
            }

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
    @safe pure Path relativeTo(in Path base) const {
        enforce!PathException(
            base.isValid && base.isAbsolute,
            "Base path must be valid and absolute");
        return Path(std.path.relativePath(_path, base._path));
    }

    /// ditto
    @safe pure Path relativeTo(in string base) const {
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
    @safe pure nothrow string extension() const {
        return std.path.extension(_path);
    }

    /// Returns base name of current path
    @safe pure nothrow string baseName() const {
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
    @safe ulong getSize() const {
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
    version(Posix) @safe Path readLink() const {
        if (isSymlink()) {
            return Path(std.file.readLink(_path.expandTilde));
        } else {
            return this;
        }
    }

    /** Get real path with all symlinks resolved.
      * If any segment of path is symlink, then this method will automatically
      * resolve that segment.
      **/
    version(Posix) Path realPath() const {
        import core.sys.posix.stdlib : realpath;
        import core.stdc.stdlib: free;
        import std.string: toStringz, fromStringz;
        import std.exception: errnoEnforce;
        import std.conv: to;

        auto conv_path = _path.toStringz;
        auto result = realpath(conv_path, null);
        scope (exit) {
            if (result)
                free(result);
        }
        // TODO: Better handle errors with different exceptions
        //       See: https://man7.org/linux/man-pages/man3/realpath.3.html
        // TODO: Add tests on behavior with broken symlinks
        errnoEnforce(result, "Path.realPath raise error");
        return Path(to!(string)(result));
    }


    /** Check if path matches specified glob pattern.
      * See Also:
      * - https://en.wikipedia.org/wiki/Glob_%28programming%29
      * - https://dlang.org/phobos/std_path.html#globMatch
      **/
    @safe pure nothrow bool matchGlob(in string pattern) {
        return std.path.globMatch(_path, pattern);
    }

    /** Iterate over all files and directories inside path;
      *
      * Produces rangs with absolute paths found inside specific directory
      *
      * Params:
      *     mode = The way to traverse directories. See [docs](https://dlang.org/phobos/std_file.html#SpanMode)
      *     followSymlink = do we need to follow symlinks of not. By default set to True.
      *
      * Examples:
      * ---
      * // Iterate over paths in current directory
      * foreach (p; Path.current.walk(SpanMode.breadth)) {
      *     if (p.isFile)
      *         writeln(p);
      * ---
      **/
    auto walk(in SpanMode mode=SpanMode.shallow, bool followSymlink=true) const {
        import std.algorithm.iteration: map;
        return std.file.dirEntries(
            this.toAbsolute._path, mode, followSymlink).map!(a => Path(a));
    }

    ///
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Create sample directory structure
        root.join("d1", "d2").mkdir(true);
        root.join("d1", "test1.txt").writeFile("Test 1");
        root.join("d1", "d2", "test2.txt").writeFile("Test 2");

        // Walk through the derectory d1
        Path[] result;
        foreach(p; root.join("d1").walk(SpanMode.breadth)) {
            result ~= p;
        }

        import std.algorithm: sort;
        import std.array: array;

        result.sort.array.should.equal([
            root.join("d1", "d2"),
            root.join("d1", "d2", "test2.txt"),
            root.join("d1", "test1.txt"),
        ]);
    }

    /// Walk inside tilda-expandable path
    version(Posix) unittest {
        import dshould;
        import std.algorithm: startsWith;

        // Prepare test dir in user's home directory
        Path root = createTempPath("~", "tmp-d-test");
        scope(exit) root.remove();

        Path hroot = Path("~").join(root.relativeTo(std.path.expandTilde("~")));
        hroot._path.startsWith("~").should.be(true);

        // Create sample directory structure
        hroot.join("d1", "d2").mkdir(true);
        hroot.join("d1", "test1.txt").writeFile("Test 1");
        hroot.join("d1", "d2", "test2.txt").writeFile("Test 2");

        // Walk through the derectory d1
        Path[] result;
        foreach(p; hroot.join("d1").walk(SpanMode.breadth)) {
            result ~= p;
        }

        import std.algorithm: sort;
        import std.array: array;

        result.sort.array.should.equal([
            root.join("d1", "d2"),
            root.join("d1", "d2", "test2.txt"),
            root.join("d1", "test1.txt"),
        ]);
    }

    /// Just an alias for walk(SpanModel.depth)
    auto walkDepth(bool followSymlink=true) const {
        return walk(SpanMode.depth, followSymlink);
    }

    /// Just an alias for walk(SpanModel.breadth)
    auto walkBreadth(bool followSymlink=true) const {
        return walk(SpanMode.breadth, followSymlink);
    }

    /** Search files that match provided glob pattern inside current path.
      *
      * Params:
      *     pattern = The glob pattern to apply to paths inside current dir.
      *     mode = The way to traverse directories. See [docs](https://dlang.org/phobos/std_file.html#SpanMode)
      *     followSymlink = do we need to follow symlinks of not. By default set to True.
      * Returns:
      *     Range of absolute path inside specified directory, that match
      *     specified glob pattern.
      **/
    auto glob(in string pattern,
            in SpanMode mode=SpanMode.shallow,
            bool followSymlink=true) {
        import std.algorithm.iteration: filter;
        Path base = this.toAbsolute;
        return base.walk(mode, followSymlink).filter!(
            f => f.relativeTo(base).matchGlob(pattern));
    }

    ///
    unittest {
        import dshould;
        import std.array: array;
        import std.algorithm: sort;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Create sample directory structure
        root.join("d1").mkdir(true);
        root.join("d1", "d2").mkdir(true);
        root.join("d1", "test1.txt").writeFile("Test 1");
        root.join("d1", "test2.txt").writeFile("Test 2");
        root.join("d1", "test3.py").writeFile("print('Test 3')");
        root.join("d1", "d2", "test4.py").writeFile("print('Test 4')");
        root.join("d1", "d2", "test5.py").writeFile("print('Test 5')");
        root.join("d1", "d2", "test6.txt").writeFile("print('Test 6')");

        // Find py files in directory d1
        root.join("d1").glob("*.py").array.should.equal([
            root.join("d1", "test3.py"),
        ]);

        // Find py files in directory d1 recursively
        root.join("d1").glob("*.py", SpanMode.breadth).array.sort.array.should.equal([
            root.join("d1", "d2", "test4.py"),
            root.join("d1", "d2", "test5.py"),
            root.join("d1", "test3.py"),
        ]);

        // Find py files in directory d1 recursively
        root.join("d1").glob("*.txt", SpanMode.breadth).array.sort.array.should.equal([
            root.join("d1", "d2", "test6.txt"),
            root.join("d1", "test1.txt"),
            root.join("d1", "test2.txt"),
        ]);
    }

    /// Change current working directory to this.
    @safe void chdir() const {
        std.file.chdir(_path.expandTilde);
    }

    /** Change current working directory to path inside currect path
      *
      * Params:
      *     sub_path = relative path inside this, to change directory to
      **/
    @safe void chdir(in string[] sub_path...) const
    in {
        assert(
            sub_path.length > 0,
            "at least one path segment have to be provided");
        assert(
            !std.path.isAbsolute(sub_path[0]),
            "sub_path must not be absolute");
        version(Posix) assert(
            !std.algorithm.startsWith(sub_path[0], "~"),
            "sub_path must not start with '~' to " ~
            "avoid automatic tilde expansion!");
    } do {
        this.join(sub_path).chdir();
    }

    /// ditto
    @safe void chdir(in Path sub_path) const
    in {
        assert(
            !sub_path.isAbsolute,
            "sub_path must not be absolute");
        version(Posix) assert(
            !std.algorithm.startsWith(sub_path._path, "~"),
            "sub_path must not start with '~' to " ~
            "avoid automatic tilde expansion!");
    } do {
        this.join(sub_path).chdir();
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
        version(OSX) {
            std.file.getcwd.should.equal(root.realPath._path);
        } else {
            std.file.getcwd.should.equal(root._path);
        }

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

    ///
    unittest {
        import dshould;
        auto cdir = std.file.getcwd;
        Path root = createTempPath();
        scope(exit) {
            std.file.chdir(cdir);
            root.remove();
        }

        // Create some directories
        root.join("my-dir", "some-dir", "some-sub-dir").mkdir(true);
        root.join("my-dir", "other-dir").mkdir(true);

        // Check current path is not equal to root
        version (OSX) {
            Path.current.should.not.equal(root.realPath);
        } else {
            Path.current.should.not.equal(root);
        }

        // Change current working directory to test root, and check that it
        // was changed
        root.chdir;
        version (OSX) {
            Path.current.should.equal(root.realPath);
        } else {
            Path.current.should.equal(root);
        }

        // Try to change current working directory to "my-dir" inside our
        // test root dir
        root.chdir("my-dir");
        version (OSX) {
            Path.current.should.equal(root.join("my-dir").realPath);
        } else {
            Path.current.should.equal(root.join("my-dir"));
        }

        // Try to change current dir to some-sub-dir, and check if it works
        root.chdir(Path("my-dir", "some-dir", "some-sub-dir"));

        version(OSX) {
            Path.current.should.equal(
                root.join("my-dir", "some-dir", "some-sub-dir").realPath);
        } else {
            Path.current.should.equal(
                root.join("my-dir", "some-dir", "some-sub-dir"));
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
    @safe void copyFileTo(in Path dest, in bool rewrite=false) const {
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
      *
      * - if dest already exists and it is not dir,
      *   then exception will be raised.
      * - if dest already exists and it is dir,
      *   then source dir will be copied inside that dir with it's name
      * - if dest does not exists,
      *   then current directory will be copied to dest path.
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
                enforce!PathException(
                    src.isFile || src.isDir,
                    "Cannot copy %s: it is not file nor directory.");
                auto dst = dst_root.join(src.relativeTo(src_root));
                if (src.isFile)
                    std.file.copy(src._path, dst._path);
                else
                    std.file.mkdirRecurse(dst._path);
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

    /// Test behavior with symlinks
    version(Posix) unittest {
        import dshould;
        auto cdir = std.file.getcwd;
        Path root = createTempPath();
        scope(exit) {
            std.file.chdir(cdir);
            root.remove();
        }

        // Create test dir with content to test copying non-empty directory
        root.join("test-dir").mkdir();
        root.join("test-dir", "f1.txt").writeFile("f1");
        root.join("test-dir", "d2").mkdir();
        root.join("test-dir", "d2", "f2.txt").writeFile("f2");
        root.join("test-dir", "d2").symlink(root.join("test-dir", "d3-s"));
        root.join("test-dir", "d2", "f2.txt").symlink(
            root.join("test-dir", "f3.txt"));


        // Test that test-dir content created
        root.join("test-dir").exists.should.be(true);
        root.join("test-dir").isDir.should.be(true);
        root.join("test-dir", "f1.txt").exists.should.be(true);
        root.join("test-dir", "f1.txt").isFile.should.be(true);
        root.join("test-dir", "d2").exists.should.be(true);
        root.join("test-dir", "d2").isDir.should.be(true);
        root.join("test-dir", "d2").isSymlink.should.be(false);
        root.join("test-dir", "d2", "f2.txt").exists.should.be(true);
        root.join("test-dir", "d2", "f2.txt").isFile.should.be(true);
        root.join("test-dir", "d3-s").exists.should.be(true);
        root.join("test-dir", "d3-s").isDir.should.be(true);
        root.join("test-dir", "d3-s").isSymlink.should.be(true);
        root.join("test-dir", "f3.txt").exists.should.be(true);
        root.join("test-dir", "f3.txt").isFile.should.be(true);
        root.join("test-dir", "f3.txt").isSymlink.should.be(true);

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
        root.join("test-dir-cpy-1", "d3-s").exists.should.be(true);
        root.join("test-dir-cpy-1", "d3-s").isDir.should.be(true);
        root.join("test-dir-cpy-1", "d3-s").isSymlink.should.be(false);
        root.join("test-dir-cpy-1", "f3.txt").exists.should.be(true);
        root.join("test-dir-cpy-1", "f3.txt").isFile.should.be(true);
        root.join("test-dir-cpy-1", "f3.txt").isSymlink.should.be(false);
        root.join("test-dir-cpy-1", "f3.txt").readFileText.should.equal("f2");
    }

    /** Remove file or directory referenced by this path.
      * This operation is recursive, so if path references to a direcotry,
      * then directory itself and all content inside referenced dir will be
      * removed
      **/
    @safe void remove() const {
        // TODO: Implement in better way
        //       Implemented in this way, because isFile and isDir on broken
        //       symlink raises error.
        version(Posix) {
            // This approach does not work on windows
            if (isSymlink || isFile) std.file.remove(_path.expandTilde);
            else std.file.rmdirRecurse(_path.expandTilde);
        } else {
            if (isDir) std.file.rmdirRecurse(_path.expandTilde);
            else std.file.remove(_path.expandTilde);
        }
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

    /// Test removing broken symlink
    version(Posix) unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Try to create test file
        root.join("test-file.txt").exists.should.be(false);
        root.join("test-file.txt").writeFile("test");
        root.join("test-file.txt").exists.should.be(true);

        // Create symlink to that file
        root.join("test-file.txt").symlink(root.join("test-symlink.txt"));
        root.join("test-symlink.txt").exists.should.be(true);

        // Delete original file
        root.join("test-file.txt").remove();

        // Check that file was deleted, but symlink still exists
        root.join("test-file.txt").exists.should.be(false);
        root.join("test-symlink.txt").exists.should.be(true);

        // Delete symlink
        root.join("test-symlink.txt").remove();

        // Test that symlink was deleted too
        root.join("test-file.txt").exists.should.be(false);
        root.join("test-symlink.txt").exists.should.be(false);
    }

    /** Rename current path.
      *
      * Note: case of moving file/dir between filesystesm is not tested.
      *
      * Throws:
      *     PathException when destination already exists
      **/
    @safe void rename(in Path to) const {
        // TODO: Add support to move files between filesystems
        enforce!PathException(
            !to.exists,
            "Destination %s already exists!".format(to));
        return std.file.rename(_path.expandTilde, to._path.expandTilde);
    }

    /// ditto
    @safe void rename(in string to) const {
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
    @safe void mkdir(in bool recursive=false) const {
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

        version(Posix) {
            root.join("test-dir", "subdir").mkdir().should.throwA!(
                std.file.FileException);
        } else {
            import std.windows.syserror;
            root.join("test-dir", "subdir").mkdir().should.throwA!(
                WindowsException);
        }

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

    /** Create symlink for this file in dest path.
      *
      * Params:
      *     dest = Destination path.
      *
      * Throws:
      *     FileException
      **/
    version(Posix) @safe void symlink(in Path dest) const {
        std.file.symlink(_path, dest._path);
    }

    ///
    version(Posix) unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Create a file in some directory
        root.join("test-dir", "subdir").mkdir(true);
        root.join("test-dir", "subdir", "test-file.txt").writeFile("Hello!");

        // Create a symlink for created file
        root.join("test-dir", "subdir", "test-file.txt").symlink(
            root.join("test-symlink.txt"));

        // Create a symbolik link to directory
        root.join("test-dir", "subdir").symlink(root.join("dirlink"));

        // Test that symlink was created
        root.join("test-symlink.txt").exists.should.be(true);
        root.join("test-symlink.txt").isSymlink.should.be(true);
        root.join("test-symlink.txt").readFile.should.equal("Hello!");

        // Test that readlink and realpath works fine
        root.join("test-symlink.txt").readLink.should.equal(
            root.join("test-dir", "subdir", "test-file.txt"));
        version(OSX) {
            root.join("test-symlink.txt").realPath.should.equal(
                root.realPath.join("test-dir", "subdir", "test-file.txt"));
        } else {
            root.join("test-symlink.txt").realPath.should.equal(
                root.join("test-dir", "subdir", "test-file.txt"));
        }
        root.join("dirlink", "test-file.txt").readLink.should.equal(
            root.join("dirlink", "test-file.txt"));
        version(OSX) {
            root.join("dirlink", "test-file.txt").realPath.should.equal(
                root.realPath.join("test-dir", "subdir", "test-file.txt"));
        } else {
            root.join("dirlink", "test-file.txt").realPath.should.equal(
                root.join("test-dir", "subdir", "test-file.txt"));
        }


    }

    /** Open file and return `std.stdio.File` struct with opened file
      * Params:
      *     openMode = string representing open mode with
      *         same semantic as in C standard lib
      *         $(HTTP cplusplus.com/reference/clibrary/cstdio/fopen.html, fopen) function.
      * Returns:
      *     std.stdio.File struct
      **/
    @safe std.stdio.File openFile(in string openMode = "rb") const {
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
    @safe void writeFile(in void[] buffer) const {
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
    @safe void appendFile(in void[] buffer) const {
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
    @safe auto readFile(size_t upTo=size_t.max) const {
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
    @safe auto readFileText(S=string)() const {
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
    @safe auto getAttributes() const {
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
    @safe bool hasAttributes(in uint attributes) const {
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

    @safe void setAttributes(in uint attributes) const {
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
      *
      * Params:
      *     args = arguments to be passed to program
      *     env = associative array that represent environment variables
      *        to be passed to program pointed by path
      *     workDir = Working directory for new process.
      *     config = Parameters for process creation.
      *        See See $(REF Config, std, process)
      *     maxOutput = Max bytes of output to be captured
      * Returns:
      *     An $(D std.typecons.Tuple!(int, "status", string, "output")).
      **/
    @safe auto execute(in string[] args=[],
            in string[string] env=null,
            in Nullable!Path workDir=Nullable!Path.init,
            in std.process.Config config=std.process.Config.none,
            in size_t maxOutput=size_t.max) const {
        return std.process.execute(
            this._path ~ args,
            env,
            config,
            maxOutput,
            (workDir.isNull) ? null : workDir.get.toString);
    }

    /// ditto
    @safe auto execute(in string[] args,
            in string[string] env,
            in Path workDir,
            in std.process.Config config=std.process.Config.none,
            in size_t maxOutput=size_t.max) const {
        return execute(args, env, Nullable!Path(workDir), config, maxOutput);
    }


    /// Example of running execute to run simple script
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
                root.nullable);
        status4.status.should.be(0);
        status4.output.should.equal("hello world\n");
    }

    /// Example of running execute to run script that will print
    /// current working directory
    version(Posix) unittest {
        import dshould;
        import std.conv: octal;

        const Path current_dir = Path.current;
        scope(exit) current_dir.chdir;

        Path root = createTempPath();
        scope(exit) root.remove();

        // Create simple test script that will print its arguments
        root.join("test-script").writeFile(
            "#!/usr/bin/env bash\npwd;");

        // Add permission to run this script
        root.join("test-script").setAttributes(octal!755);

        // Change current working directory to our root;
        root.chdir;

        // Do not pass current working directory
        // (script have to print current working directory)
        auto status0 = root.join("test-script").execute(["hello", "world"]);
        status0.status.should.be(0);
        version(OSX) {
            status0.output.should.equal(root.realPath.toString ~ "\n");
        } else {
            status0.output.should.equal(root.toString ~ "\n");
        }

        // Create some other directory
        auto my_dir = root.join("my-dir");
        my_dir.mkdir();

        // Passs my-dir as workding directory for script
        auto status1 = root.join("test-script").execute(
                ["hello", "world"],
                null,
                my_dir.nullable);
        status1.status.should.be(0);
        version(OSX) {
            status1.output.should.equal(my_dir.realPath.toString ~ "\n");
        } else {
            status1.output.should.equal(my_dir.toString ~ "\n");
        }

        // Passs null path as workding direcotry for script
        auto status2 = root.join("test-script").execute(
                ["hello", "world"],
                null,
                Nullable!Path.init);
        status2.status.should.be(0);
        version(OSX) {
            status2.output.should.equal(root.realPath.toString ~ "\n");
        } else {
            status2.output.should.equal(root.toString ~ "\n");
        }

        // Passs my-dir as workding directory for script (without nullable)
        auto status3 = root.join("test-script").execute(
                ["hello", "world"],
                null,
                my_dir);
        status3.status.should.be(0);
        version(OSX) {
            status3.output.should.equal(my_dir.realPath.toString ~ "\n");
        } else {
            status3.output.should.equal(my_dir.toString ~ "\n");
        }

    }

    /** Search file by name in current directory and parent directories.
      * Usually, this could be used to find project config,
      * when current directory is somewhere inside project.
      *
      * If no file with specified name found, then return null path.
      *
      * Params:
      *     file_name = Name of file to search
      * Returns:
      *     Path to searched file, if such file was found.
      *     Otherwise return null Path.
      **/
    @safe Nullable!Path searchFileUp(in string file_name) const {
        return searchFileUp(Path(file_name));
    }

    /// ditto
    @safe Nullable!Path searchFileUp(in Path search_path) const {
        Path current_path = toAbsolute;
        while (!current_path.isRoot) {
            auto dst_path = current_path.join(search_path);
            if (dst_path.exists && dst_path.isFile) {
                return dst_path.nullable;
            }
            current_path = current_path.parent;

            if (current_path._path == current_path.parent._path)
                // It seems that if current path is same as parent path,
                // then it could be infinite loop. So, let's break the loop;
                break;
        }
        // Return null, that means - no path found
        return Nullable!Path.init;
    }


    /** Example of searching configuration file, when you are somewhere inside
      * project.
      **/
    unittest {
        import dshould;
        Path root = createTempPath();
        scope(exit) root.remove();

        // Save current directory
        auto cdir = std.file.getcwd;
        scope(exit) std.file.chdir(cdir);

        // Create directory structure
        root.join("dir1", "dir2", "dir3").mkdir(true);
        root.join("dir1", "my-conf.conf").writeFile("hello!");
        root.join("dir1", "dir4", "dir8").mkdir(true);
        root.join("dir1", "dir4", "my-conf.conf").writeFile("Hi!");
        root.join("dir1", "dir5", "dir6", "dir7").mkdir(true);

        // Change current working directory to dir7
        root.join("dir1", "dir5", "dir6", "dir7").chdir;

        // Find config file. It sould be dir1/my-conf.conf
        auto p1 = Path.current.searchFileUp("my-conf.conf");
        p1.isNull.should.be(false);
        version(OSX) {
            p1.get.toString.should.equal(
                root.join("dir1", "my-conf.conf").realPath.toString);
        } else {
            p1.get.toString.should.equal(
                root.join("dir1", "my-conf.conf").toAbsolute.toString);
        }

        // Try to get config, related to "dir8"
        auto p2 = root.join("dir1", "dir4", "dir8").searchFileUp(
            "my-conf.conf");
        p2.isNull.should.be(false);
        p2.get.should.equal(
                root.join("dir1", "dir4", "my-conf.conf"));

        // Test searching for some path (instead of simple file/string)
        auto p3 = root.join("dir1", "dir2", "dir3").searchFileUp(
            Path("dir4", "my-conf.conf"));
        p3.isNull.should.be(false);
        p3.get.should.equal(
                root.join("dir1", "dir4", "my-conf.conf"));

        // One more test
        auto p4 = root.join("dir1", "dir2", "dir3").searchFileUp(
            "my-conf.conf");
        p4.isNull.should.be(false);
        p4.get.should.equal(root.join("dir1", "my-conf.conf"));

        // Try to find up some unexisting file
        auto p5 = root.join("dir1", "dir2", "dir3").searchFileUp(
            "i-am-not-exist.conf");
        p5.isNull.should.be(true);

        import core.exception: AssertError;
        p5.get.should.throwA!AssertError;
    }
}

