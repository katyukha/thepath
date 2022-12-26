# The Path

Yet another attempt to implement high-level object-oriented interface
to manage path and files in D.
Inspired by [Python's pathlib](https://docs.python.org/3/library/pathlib.html)
and [D port of pathlib](https://code.dlang.org/packages/pathlib) but
implementing it in different way.

**NOTE**: this is alpha version, and api is still subject for change

Following ideas used in this project
- Implement struct or class `Path` that have to represent
  single path to file or directory.
- Any operation on path have to create new instance of `Path`,
  thus no implicit modification of Path allowed to avoid side effects.
- Simplify naming for frequent operations
  (introducing new type for this allows to do it without name collisions).
- Automatic tilde expansion when needed (for example before file operations),
  thus allowing to easily work with patth like `~/my/path`
  without any special work needed.

**Warning**: Currently this lib is not tested on Windows or other platforms.
So, it surelly works on Posix (linux only), but possibly,
it should work on other platforms too.
If you want to help to make it crossplatform, then contact me (
the first thing needed to make it cross platform, is to set up CI to run
automated tests on other platforms).

## To Do


- [x] Override comparison operators
- [ ] Override operators join paths
- [ ] Implement alias this feature to make it easily convertible to string.
    - Do we need this
- [ ] match pattern
- [ ] Add ability to work with extensions
- [ ] Add automated tests for Windows


## Examples

```d
import thepath;


Path app_dir = Path("~/.local/my-app");
Path catalog_dir = app_dir.join("catalog");


void init() {
    if (!app_dir.exists) {
        app_dir.mkdir(true);  // create recursive
    }
    if (!catalog_dir.exists) {
        catalog_dir.mkdir(true);
    }
}

void list_dir {
    fopeach(Path p; catalog_dir.walk(SpanModel.breadth)) {
        writeln(p.toAbsolute().toString());
    }
}
```

For more example, check the documentation.

## License

This library is licensed under MPL-2.0 license
