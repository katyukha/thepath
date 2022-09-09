# The Path

Yet another attempt to implement high-level object-oriented interface
to manage path and files in D.
Inspired by [Python's pathlib](https://docs.python.org/3/library/pathlib.html)
and [D port of pathlib](https://code.dlang.org/packages/pathlib) but
implementing it in different way.

Following principles used in this project
- Implement struct or class `Path`
- Any operation on path have to produce new instance of `Path`
  to avoid side effects
- Simplify naming for frequent operations (introducing new type for this allows to do it).
- Automatic tilde expansion when needed (for example before file operations);


## Examples

```d
import thepath;


Path app_dir = Path("~/.local/my-app");
Path catalog_dir = app_dir.join('catalog');


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
        writeln(p.expandTilde.toAbsolute().toString());
    }
}
```
