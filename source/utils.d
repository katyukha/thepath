module thepath.utils;

private import std.exception: enforce;
private static import std.path;

private import thepath.exception: PathException;
private import thepath.path: Path;


/** Create temporary directory
  * Note, that caller is responsible to remove created directory.
  * The temp directory will be created inside specified path.
  * 
  * Params:
  *     path = path to already existing directory to create
  *         temp directory inside. Default: std.file.tempDir
  *     prefix = prefix to be used in name of temp directory. Default: "tmp"
  * Returns: string, representing path to created temporary directory
  * Throws: PathException in case of error
  **/
string createTempDirectory(in string prefix="tmp") {
    import std.file : tempDir;
    return createTempDirectory(tempDir, prefix);
}

/// ditto
string createTempDirectory(in string path, in string prefix) {
    version(Posix) {
        import std.string : fromStringz;
        import std.conv: to;
        import core.sys.posix.stdlib : mkdtemp;

        // Prepare template for mkdtemp function.
        // It have to be mutable array of chars ended with zero to be compatibale
        // with mkdtemp function.
        scope char[] tempname_str = std.path.buildNormalizedPath(
            std.path.expandTilde(path),
            prefix ~ "-XXXXXX").dup ~ "\0";

        // mkdtemp will modify tempname_str directly. and res is pointer to
        // tempname_str in case of success.
        char* res = mkdtemp(tempname_str.ptr);
        enforce!PathException(
            res !is null, "Cannot create temporary directory");

        // Converting to string will duplicate result.
        // But may be it have sense to do it in more obvious way
        // for example: return tempname_str[0..$-1].idup;
        return to!string(res.fromStringz);
    } else {
        import std.ascii: letters;
        import std.random: uniform;

        // Generate new random temp path to test using provided path and prefix
        // as template.
        string generate_temp_dir() {
            string suffix = "-";
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
Path createTempPath(in string prefix="tmp") {
    return Path(createTempDirectory(prefix));
}

/// ditto
Path createTempPath(in string path, in string prefix) {
    return Path(createTempDirectory(path, prefix));
}

/// ditto
Path createTempPath(in Path path, in string prefix) {
    return createTempPath(path.toString, prefix);
}


