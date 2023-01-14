# The Path

Yet another attempt to implement high-level object-oriented interface
to manage path and files in D.
Inspired by [Python's pathlib](https://docs.python.org/3/library/pathlib.html)
and [D port of pathlib](https://code.dlang.org/packages/pathlib) but
implementing it in different way.

**NOTE**: this is alpha version, and api is still subject for change

Following ideas used in design of this lib:
- Implement struct or class `Path` that have to represent
  single path to file or directory.
- Avoid implicit modification of created path as much as reasonably possible.
  Any operation on path have to create new instance of `Path`,
  instead of modifying original.
- Simplify naming for frequent operations
  (introducing new type for this allows to do it without name collisions).
- Automatic tilde (`~`) expansion when needed
  (for example before file operations),
  thus allowing to easily work with path like `~/my/path`,
  that will be resolved implicitly, without any special work needed.
- Make this lib as convenient as possible.
- Do not touch other paths (like URL), except filesystem path.
  Easy construction of path from segments and easy conversion of path
  to segments (that is array of strings) could help to deal with coversion
  to and from other paths (URL).
- It is designed to work with file system paths of OS it is compiled for.
  Thus, there is no sense to work with windows-style paths under the linux, etc.
  Are there any cases when such thing have to be supported?
- This lib have to be well tested.

**Warning**: Currently this lib is not tested on Windows or other platforms.
So, it surelly works on Posix (tested on linux only), but possibly,
it should work on other platforms too.
If you want to help to make it crossplatform, then contact me (
the first thing needed to make it cross platform, is to set up CI to run
automated tests on other platforms).

## Features

- automatic expansion of `~` when needed (before passing path to std.file or std.stdio funcs)
- single method to copy path (file or directory) to dest path
- single method to remove path (file or directory)
- simple method to `walk` through the path
- simple constuction of paths from parts:
    - `Path("a", "b", "c")`
    - `Path("a").join("b", "c")`
- simple deconstruction of paths
    - `Path("a/b/c/d").segments == ["a", "b", "c", "d"]`
- overriden comparison operators for paths.
    - `Path("a", "b") == Path("a", "b")`
    - `Path("a", "b") != Path("a", "c")`
    - `Path("a", "b") < Path("a", "c")`
- `hasAttributes` / `getAttributes` / `setAttributes` methods to work with file attrs
- file operations as methods:
    - `Path("my-path").readFile()`
    - `Path("my-path").writeFile("Hello world")`
- support search by glob-pattern


## To Do


- [ ] Override operators join paths, to be able to do things like:
    - `Path("a") ~ Path("b") == Path("a").join(Path("b"))`
    - `Path("a") ~ "b" == Path("a").join("b")`
    - Do we need this? It seems that `Path("a").join("b", "c")` looks good enough.
- [ ] Implement `alias this` feature to make it easily convertible to string.
    - Do we need this feature?
      It seems that it is better to avoid implicit conversion to string,
      at least unless multiple `alias this` supported in D.
- [ ] Add automated tests for Windows
- Any other features needed?


## Examples

```d
import thepath;


Path app_dir = Path("~/.local/my-app");
Path catalog_dir = app_dir.join("catalog");


void init() {
    // Note, that automatic '~' expansion will be done before checking the
    // existense of directory
    if (!app_dir.exists) {
        app_dir.mkdir(true);  // create recursive
    }
    if (!catalog_dir.exists) {
        catalog_dir.mkdir(true);
    }
}

void list_dir() {
    // Easily print content of the catalog directory
    foreach(Path p; catalog_dir.walkBreadth) {
        writeln(p.toAbsolute().toString());
    }
}

// Print all python files in current directory
void find_python_files() {
    foreach(path; Path.current.glob("*.py", SpanMode.breadth))
        // Print paths relative to current directory
        writeln(p.relativeTo(Path.current).toString);
}

Path findConfig() {
    // Search for "my-project.conf" in current directories and in
    // its parent directories
    auto config = Path.current.searchFileUp("my-project.conf");
    enforce(!config.isNull);
    return config.get;
}
```

For more examples, check the documentation and unittests.

## License

This library is licensed under MPL-2.0 license
