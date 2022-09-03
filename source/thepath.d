module thepath;

static public import std.file: SpanMode;
static private import std.path;
static private import std.file;


struct Path {
    private string _path=null;

    this(in string path) {
        _path = path;
    }

    bool isNull() const {
        return (_path is null);
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

    auto walk(SpanMode mode=SpanMode.shallow, bool followSymlink=true) {
        import std.algorithm.iteration: map;
        return std.file.dirEntries(
            _path, mode, followSymlink).map!(a => Path(a));

    }

    void chdir() const {
        std.file.chdir(_path);
    }

    void remove(in bool recursive=false) const {
        if (isFile) std.file.remove(_path);
        else if (recursive) std.file.rmdirRecurse(_path);
        else std.file.rmdir(_path);
    }

    void mkdir(in bool recursive=false) const {
        if (recursive) std.file.mkdirRecurse(_path);
        else std.file.mkdir(_path);
    }

    auto openFile(in string openMode = "rb") const {
        static import std.stdio;

        return std.stdio.File(_path, openMode);
    }


    // TODO: to add:
    //       - ability to do file operation (open, read, write, etc),
    //       - match pattern
    //       - Handle symlinks
}
