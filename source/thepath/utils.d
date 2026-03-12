/// Utility functions to work with paths
module thepath.utils;

private import std.exception: enforce, errnoEnforce;
private static import std.path;

private import thepath.exception: PathException;
private import thepath.path: Path;


// Max attempts to create temp directory
private immutable ushort MAX_TMP_ATTEMPTS = 1000;


/** Create temporary directory
  * Note, that caller is responsible to remove created directory.
  * The temp directory will be created inside specified path.
  * 
  * Params:
  *     path = path to already existing directory to create
  *         temp directory inside. Default: std.file.tempDir
  *     prefix = prefix to be used in name of temp directory. Default: "tmp"
  * Returns: string, representing path to created temporary directory
  * Throws:
  *     ErrnoException (Posix) incase if mkdtemp was not able to create tempdir
  *     PathException (Windows) in case of failure of creation of temp dir
  **/
@safe string createTempDirectory(in string prefix="tmp") {
    import std.file : tempDir;
    return createTempDirectory(tempDir, prefix);
}

/// ditto
@safe string createTempDirectory(in string path, in string prefix) {
    version(Posix) {
        import std.string : fromStringz;
        import std.conv: to;
        import core.sys.posix.stdlib : mkdtemp;

        // Make trusted version of mkdtemp
        char* t_mkdtemp(scope char* tmpl) @trusted nothrow => mkdtemp(tmpl);

        // Prepare template for mkdtemp function.
        // It have to be mutable array of chars ended with zero to be compatibale
        // with mkdtemp function.
        scope char[] tempname_str = std.path.buildNormalizedPath(
            std.path.expandTilde(path),
            prefix ~ "-XXXXXX").dup ~ '\0';

        // mkdtemp will modify tempname_str directly.
        // and res will be pointer to tempname_str in case of success.
        // in case of failure, res will be set to null.
        char* res = t_mkdtemp(&tempname_str[0]);
        errnoEnforce(res !is null, "Cannot create temporary directory");

        // Convert tempname to string.
        // Just remove trailing \0 symbol, and duplicate.
        return tempname_str[0 .. $-1].idup;
    } else version (Windows) {
        import std.ascii: letters;
        import std.random: uniform;
        import std.file;
        import core.sys.windows.winerror;
        import std.windows.syserror;
        import std.format: format;

        // Generate new random temp path to test using provided path and prefix
        // as template.
        string generate_temp_dir() {
            string suffix = "-";
            for(ubyte i; i<6; i++) suffix ~= letters[uniform(0, $)];
            return std.path.buildNormalizedPath(
                std.path.expandTilde(path), prefix ~ suffix);
        }

        // Make trusted funcs to get windows error code and msg
        auto get_err_code(WindowsException e) @trusted {
            return e.code;
        }
        string get_err_str(WindowsException e) @trusted {
            return sysErrorString(e.code);
        }

        // Try to create new temp directory
        for(ushort i=0; i<MAX_TMP_ATTEMPTS; i++) {
            string temp_dir = generate_temp_dir();
            try {
                std.file.mkdir(temp_dir);
            } catch (WindowsException e) {
                if (get_err_code(e) == ERROR_ALREADY_EXISTS)
                    continue;
                throw new PathException(
                    "Cannot create temporary directory: %s".format(
                        get_err_str(e)));
            }
            return temp_dir;
        }
        throw new PathException(
            "Cannot create temporary directory: No usable name found!");
    } else assert(0, "Not supported platform!");
}

version(Posix) @system unittest {
    import dshould;
    import std.exception;
    createTempDirectory("/some/unexisting/path").should.throwA!ErrnoException;
}

version(Windows) @system unittest {
    import dshould;
    import std.exception;
    createTempDirectory("/some/unexisting/path").should.throwA!PathException;
}


/** Create temporary directory
  * Note, that caller is responsible to remove created directory.
  * The temp directory will be created inside specified path.
  *
  * Params:
  *     path = path to already existing directory to create
  *         temp directory inside. Default: std.file.tempDir
  *     prefix = prefix to be used in name of temp directory. Default: "tmp"
  * Returns: Path to created temp directory
  * Throws: PathException in case of error
  **/
@safe Path createTempPath(in string prefix="tmp") {
    return Path(createTempDirectory(prefix));
}

/// ditto
@safe Path createTempPath(in string path, in string prefix) {
    return Path(createTempDirectory(path, prefix));
}

/// ditto
@safe Path createTempPath(in Path path, in string prefix) {
    return createTempPath(path.toString, prefix);
}


/** Create a temporary directory, pass it to the delegate, and remove it
  * after the delegate completes (whether it returns normally or throws).
  *
  * This is the recommended way to work with temporary directories, as it
  * guarantees cleanup without requiring manual `scope(exit)` at every call site.
  *
  * All arguments except the delegate are forwarded to `createTempPath`,
  * so any overload of `createTempPath` is supported automatically.
  *
  * Params:
  *     args = arguments forwarded to `createTempPath` (prefix, path, etc.)
  *     dg = delegate to execute with the temporary directory path
  * Returns: The value returned by the delegate (if non-void)
  **/
@safe auto withTempDir(Dg, Args...)(Args args, Dg dg)
if (is(typeof(createTempPath(args))) && is(typeof(dg(Path.init)))) {
    auto tmp = createTempPath(args);
    scope(exit) tmp.remove();
    static if (is(typeof(dg(tmp)) == void)) {
        dg(tmp);
    } else {
        return dg(tmp);
    }
}

/// ditto — no-args overload (uses default prefix)
@safe auto withTempDir(Dg)(Dg dg)
if (is(typeof(dg(Path.init)))) {
    auto tmp = createTempPath();
    scope(exit) tmp.remove();
    static if (is(typeof(dg(tmp)) == void)) {
        dg(tmp);
    } else {
        return dg(tmp);
    }
}

/// withTempDir with void delegate (no args)
@system unittest {
    import dshould;

    Path saved;
    withTempDir((Path tmp) {
        tmp.exists.should.be(true);
        tmp.isDir.should.be(true);
        saved = tmp;
    });
    saved.exists.should.be(false);
}

/// withTempDir with void delegate and prefix
@system unittest {
    import dshould;

    Path saved;
    withTempDir("test-with-tmp", (Path tmp) {
        tmp.exists.should.be(true);
        tmp.isDir.should.be(true);
        tmp.baseName[0..14].should.equal("test-with-tmp-");
        saved = tmp;
    });
    // temp dir should be removed after delegate returns
    saved.exists.should.be(false);
}

/// withTempDir with return value
@system unittest {
    import dshould;

    auto result = withTempDir("test-ret", (Path tmp) {
        tmp.exists.should.be(true);
        tmp.join("hello.txt").writeFile("world");
        return tmp.join("hello.txt").readFileText();
    });
    result.should.equal("world");
}

/// withTempDir with custom base path
@system unittest {
    import dshould;
    import std.file : tempDir;

    Path saved;
    withTempDir(tempDir, "test-custom-base", (Path tmp) {
        tmp.exists.should.be(true);
        saved = tmp;
    });
    saved.exists.should.be(false);
}

/// withTempDir cleans up even on exception
@system unittest {
    import dshould;
    import std.exception : assertThrown;

    Path saved;
    assertThrown!Exception(
        withTempDir("test-exc", (Path tmp) {
            saved = tmp;
            tmp.exists.should.be(true);
            throw new Exception("test error");
        })
    );
    saved.exists.should.be(false);
}
