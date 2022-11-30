/** ThePath - easy way to work with paths and files
  *
  * Yet another attempt to implement high-level object-oriented interface
  * to manage path and files in D.
  * Inspired by [Python's pathlib](https://docs.python.org/3/library/pathlib.html)
  * and [D port of pathlib](https://code.dlang.org/packages/pathlib) but
  * implementing it in different way.
  *
  **/
module thepath;

public import thepath.path: Path;
public import thepath.utils: createTempDirectory, createTempPath;
public import thepath.exception: PathException;

